extends Node
## The game session: what lasts while the game runs as the player goes between the ship and the wreck (nothing is
## saved yet, so quitting starts a new game). It keeps the ship's stash, the bitcoin wallet, the hydrogen tank, the
## day, the star system the ship is in (a StarSystem, with the wrecks still there to board) and its trader hub and sell
## crate, where the ship is in the system (at the hub, docked with a wreck, or where a wreck it boarded was), the clone
## number and the runs boarded. It hands what the player carries (the kit: their inventory, whose gun keeps its loaded
## clip's heat) from one scene's player to the next, and the docked wreck's roll to the wreck boarded; records how each
## run ended (RunSummary); and changes the scene between the ship and the wreck, playing the travel sounds itself so
## they carry on through the change. Only the first clone of a new game gets the basic kit: a death hands no kit over,
## and the next clone wakes empty-handed and arms from the stash. Flying within the system, refuelling, selling and
## buying go through here, since the tank, the stash and the wallet live here; the last three only at the hub.
## Autoloaded as GameSession, after ItemIcons. It has no class_name, which would clash with the autoload's name.

## Emitted whenever the game travels to another scene, with its path, also while travel_enabled is off.
signal travelled(scene_path: String)
## Emitted whenever the bitcoin in the wallet changes, with the new amount.
signal bitcoin_changed(bitcoin: int)
## Emitted whenever the hydrogen in the tank changes, with the new amount.
signal hydrogen_changed(hydrogen: int)
## Emitted whenever the ship flies somewhere in the system (and so docks with a wreck, or reaches the hub).
signal ship_moved

## How the player arrives on the ship: waking as a new clone in the clone pod, or back through the airlock.
enum Arrival { NEW_CLONE, EXTRACTED }

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const STASH_SIZE := Vector2i(10, 8)
## The trader hub's sell crate, where items wait to be sold.
const CRATE_SIZE := Vector2i(6, 4)
## The little bitcoin a new game starts with: not enough for antimatter, so the first system already needs runs.
const STARTING_BITCOIN := 500
## How much hydrogen the ship's tank holds; a new game starts with it full.
const HYDROGEN_TANK := 24

## The ship's stash: safe whatever happens on a run.
var stash: ItemGrid
## Bitcoin in the wallet: never lost, whatever happens on a run.
var bitcoin := STARTING_BITCOIN
## Hydrogen in the tank, which flights within the system burn. Bought at the hub.
var hydrogen := HYDROGEN_TANK
## Days gone since the game started (day 0). Only boarding passes a day (and jumping, in 012).
var day := 0
## The star system the ship is in, with the wrecks still there to board; null only when no system is registered.
var system: StarSystem
## Where the ship is on the system map, in map units from the star.
var ship_position := Vector2.ZERO
## Whether the ship is at the system's trader hub, the only place to trade and refuel.
var at_hub := true
## The trader hub of the system the ship is in.
var trader: Trader
## The hub's sell crate: what is in it is sold together. The hub screen puts anything left in it back into the stash
## when it closes; what doesn't fit stays here for the next visit.
var crate: ItemGrid
## The clone the player is now, counted from 1, one more for every death.
var clone_number := 1
## Runs boarded this session.
var runs := 0
## How the player arrives on the ship next.
var arrival := Arrival.NEW_CLONE
## Whether the next player with no kit handed over gets the basic kit: the first clone of a new game does (and so does
## a level started on its own); after a death the next clone wakes empty-handed.
var basic_kit_next := true
## How the last run ended, or null before any has.
var last_run: RunSummary
## The roll of the wreck docked at the ship's airlock, boarded next: the wreck the ship last flew to, until it is
## boarded. Null at the hub, and after a run, since a wreck once boarded is gone.
var docked: WreckRoll
## Whether the next scene's player fades in from black: a new game wakes up, and every travel arrives.
var fade_in_next := true
## Off in tests, so ending a run never changes the scene under the test runner; travelled is still emitted.
var travel_enabled := true

## The inventory handed to the next scene's player, or null when it gets the basic kit or nothing.
var _carried: Inventory
## The roll of the wreck being boarded, until that wreck takes it.
var _boarding: WreckRoll
var _value_in := 0
var _sound: AudioStreamPlayer


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.name = "TravelSound"
	add_child(_sound)
	new_game()


## Starts over on day 0: an empty stash, a little bitcoin, a full tank, the ship at the hub of a random star system
## (012 picks one on the outer ring), and the first clone waking up in the clone pod with the basic kit.
func new_game() -> void:
	stash = ItemGrid.new(STASH_SIZE)
	crate = ItemGrid.new(CRATE_SIZE)
	bitcoin = STARTING_BITCOIN
	hydrogen = HYDROGEN_TANK
	day = 0
	clone_number = 1
	runs = 0
	arrival = Arrival.NEW_CLONE
	basic_kit_next = true
	last_run = null
	fade_in_next = true
	_carried = null
	_boarding = null
	_value_in = 0
	var systems := ContentRegistry.get_all(StarSystemDefinition)
	if systems.is_empty():
		system = null
		trader = Trader.new(randi())
		_dock_at_hub(Vector2.ZERO)
		Log.error("🧬 New game with no star systems registered: no wrecks to board, hub=%s" % trader.title)
		return
	arrive_in(systems[randi_range(0, systems.size() - 1)])
	Log.info("🧬 New game: stash=%s, bitcoin=%d, hydrogen=%d, day=%d, clone=%d, system=%s" % [
		STASH_SIZE, bitcoin, hydrogen, day, clone_number, system.definition.id])


## The ship arrives in a star system, at its hub: the system is revealed, with its wrecks rolled now, and the hub's
## prices with it.
func arrive_in(definition: StarSystemDefinition) -> void:
	system = StarSystem.reveal(definition, ContentRegistry.get_all(WreckDefinition), RandomNumberGenerator.new())
	trader = Trader.new(randi(), definition.hub_name())
	_dock_at_hub(system.hub_position)
	if system.wrecks.is_empty():
		Log.error("🧬 Arrived in a system with no wrecks, are no wreck layouts registered? system=%s" % definition.id)
		return
	Log.info("🧬 Arrived in a star system: system=%s, map_id=%s, places=%d, wrecks=%d, hub=%s, layouts=%s" % [
		definition.id, definition.map_id, definition.places.size(), system.wrecks.size(), trader.title,
		system.wrecks.map(func(wreck: SystemWreck) -> String: return wreck.roll.definition.id)])


## The kit handed over from the last scene's player, for this scene's player to carry on with, once; null when there
## is none (a new game, or a death), so the player builds the basic kit if basic_kit_next says so, or starts
## empty-handed.
func take_carried() -> Inventory:
	var carried := _carried
	_carried = null
	if carried:
		var gun := carried.gun()
		Log.info("🧬 Kit taken over: items=%d, value=%d, gun=%s, heat=%.0f%%" % [
			carried.item_count(), carried.value(), gun.definition.id if gun else "none",
			gun.clip_heat * 100.0 if gun else 0.0])
	else:
		Log.info("🧬 No kit to take over: clone=%d, basic_kit=%s" % [clone_number, basic_kit_next])
	return carried


## Hydrogen a flight from where the ship is to a spot on the system map burns.
func flight_cost(to: Vector2) -> int:
	return StarSystem.hydrogen_between(ship_position, to)


## Hydrogen the tank must hold to fly to a spot on the map: the flight, and from there the way back to the hub, so the
## ship can never be stranded away from it.
func hydrogen_needed(to: Vector2) -> int:
	var back := StarSystem.hydrogen_between(to, system.hub_position) if system else 0
	return flight_cost(to) + back


## Flies the ship to a wreck in the system and docks with it, burning hydrogen. Refused (false) when the wreck isn't
## in the system any more or the tank couldn't get the ship there and back to the hub.
func fly_to_wreck(wreck: SystemWreck) -> bool:
	if system == null or not system.wrecks.has(wreck):
		Log.warning("🧬 Can't fly to a wreck that isn't in the system: layout=%s" % (
			wreck.roll.definition.id if wreck else "none"))
		return false
	var needed := hydrogen_needed(wreck.position)
	if needed > hydrogen:
		Log.info("🧬 Not enough hydrogen to fly to the wreck and back to the hub: layout=%s, where=%s, needed=%d, hydrogen=%d" % [
			wreck.roll.definition.id, wreck.where(), needed, hydrogen])
		return false
	var cost := flight_cost(wreck.position)
	_set_hydrogen(hydrogen - cost)
	ship_position = wreck.position
	at_hub = false
	docked = wreck.roll
	ship_moved.emit()
	Log.info("🧬 Flew to a wreck and docked: layout=%s, level=%d, robots=%d, where=%s, burned=%d, hydrogen=%d" % [
		docked.definition.id, docked.level, docked.robots, wreck.where(), cost, hydrogen])
	return true


## Flies the ship back to the system's hub, burning hydrogen. Refused (false) when the tank is short, which the rule
## for flying out (hydrogen_needed()) never lets happen.
func fly_to_hub() -> bool:
	if system == null:
		Log.warning("🧬 Can't fly to the hub, there is no system")
		return false
	var cost := flight_cost(system.hub_position)
	if cost > hydrogen:
		Log.warning("🧬 Not enough hydrogen to fly back to the hub: needed=%d, hydrogen=%d, position=%s" % [
			cost, hydrogen, ship_position])
		return false
	_set_hydrogen(hydrogen - cost)
	_dock_at_hub(system.hub_position)
	ship_moved.emit()
	Log.info("🧬 Flew back to the hub: hub=%s, burned=%d, hydrogen=%d" % [trader.title, cost, hydrogen])
	return true


## Fills the tank at the hub with as much hydrogen as it holds and the wallet pays for. Returns the units bought: none
## away from the hub, with a full tank or an empty wallet.
func refuel() -> int:
	if not at_hub:
		Log.info("🧬 Can't refuel away from the hub: hydrogen=%d, position=%s" % [hydrogen, ship_position])
		return 0
	var units := trader.affordable_hydrogen(HYDROGEN_TANK - hydrogen, bitcoin)
	if units <= 0:
		Log.info("🧬 No hydrogen bought: hydrogen=%d, tank=%d, bitcoin=%d" % [hydrogen, HYDROGEN_TANK, bitcoin])
		return 0
	var price := trader.hydrogen_price(units)
	_set_bitcoin(bitcoin - price)
	_set_hydrogen(hydrogen + units)
	Log.info("🧬 Refuelled: units=%d, price=%d, hydrogen=%d, bitcoin=%d" % [units, price, hydrogen, bitcoin])
	return units


## The docked wreck's roll, handed to the wreck being boarded, once; null when there is none for this layout (a
## layout scene started on its own), so the wreck rolls its own.
func take_boarding(layout: WreckDefinition) -> WreckRoll:
	var boarding := _boarding
	_boarding = null
	if boarding == null:
		Log.info("🧬 No wreck roll to hand over: layout=%s" % layout.id)
		return null
	if boarding.definition != layout:
		Log.warning("🧬 The wreck roll is for another layout, not handed over: layout=%s, roll=%s" % [
			layout.id, boarding.definition.id])
		return null
	Log.info("🧬 Wreck roll handed over: layout=%s, level=%d, seed=%d" % [layout.id, boarding.level, boarding.roll_seed])
	return boarding


## The player boards the docked wreck with what they carry, which is now at risk. It takes a day, and the wreck leaves
## the system for good, whether the android extracts or dies. Travels to the wreck.
func board(carried: Inventory) -> void:
	if docked == null:
		Log.error("🧬 Can't board, no wreck docked: run=%d, clone=%d" % [runs, clone_number])
		return
	runs += 1
	day += 1
	_value_in = carried.value()
	_carried = carried
	_boarding = docked
	docked = null
	var wreck := system.wreck_with(_boarding) if system else null
	if wreck:
		system.remove(wreck)
	Log.info("🧬 Boarding the wreck: run=%d, day=%d, clone=%d, layout=%s, level=%d, items=%d, value_in=%d, armed=%s, wrecks_left=%d" % [
		runs, day, clone_number, _boarding.definition.id, _boarding.level, carried.item_count(), _value_in,
		carried.gun() != null, system.wrecks.size() if system else 0])
	_travel(_boarding.definition.get_scene_path())


## The player got out alive with what they carry: it goes to the ship with them, where they arrive in the airlock.
## Returns the run's summary; continue_to_ship() travels.
func extract(carried: Inventory) -> RunSummary:
	last_run = RunSummary.make_extracted(carried.item_count(), carried.value(), _value_in, clone_number)
	arrival = Arrival.EXTRACTED
	_carried = carried
	Log.info("🧬 Extracted: run=%d, clone=%d, items=%d, value=%d, gained=%d" % [
		runs, clone_number, last_run.items, last_run.value, last_run.gained])
	return last_run


## The player died: everything they carried is lost, gun included, and the next clone wakes up in the clone pod
## empty-handed. Returns the run's summary; continue_to_ship() travels.
func die(carried: Inventory) -> RunSummary:
	clone_number += 1
	var items := carried.item_count() if carried else 0
	var value := carried.value() if carried else 0
	last_run = RunSummary.make_died(items, value, clone_number)
	arrival = Arrival.NEW_CLONE
	basic_kit_next = false
	_carried = null
	Log.info("🧬 Died, everything carried is lost: run=%d, items_lost=%d, value_lost=%d, next_clone=%d" % [
		runs, items, value, clone_number])
	return last_run


## After the run summary: back to the ship, where the player arrives as arrival says.
func continue_to_ship() -> void:
	Log.info("🧬 Continuing to the ship: arrival=%s, clone=%d, kit=%s" % [
		Arrival.keys()[arrival], clone_number, "carried" if _carried else "basic" if basic_kit_next else "none"])
	_travel(SHIP_SCENE)


## Sells everything in the sell crate to the hub: the items go, and the wallet gets the hub's offer. Returns the
## bitcoin earned (0 for an empty crate, or away from the hub).
func sell_crate() -> int:
	var sold: Array[Item] = crate.items.duplicate()
	if not at_hub:
		Log.warning("🧬 Can't sell away from the hub: crate_items=%d, position=%s" % [sold.size(), ship_position])
		return 0
	if sold.is_empty():
		Log.info("🧬 Nothing in the crate to sell: bitcoin=%d" % bitcoin)
		return 0
	var total := trader.offer(sold)
	for item in sold:
		crate.remove(item)
	_set_bitcoin(bitcoin + total)
	Log.info("🧬 Sold the crate: items=%d, earned=%d, bitcoin=%d, first=%s" % [
		sold.size(), total, bitcoin, sold[0].definition.id])
	return total


## Buys one of an item from the hub into the first free spot in the stash. Returns the new item, or null when the
## ship is away from the hub, the wallet is short or the stash has no room for it.
func buy(definition: ItemDefinition) -> Item:
	var price := trader.buy_price(definition)
	if not at_hub:
		Log.warning("🧬 Can't buy away from the hub: item=%s, position=%s" % [definition.id, ship_position])
		return null
	if price > bitcoin:
		Log.info("🧬 Can't afford it: item=%s, price=%d, bitcoin=%d" % [definition.id, price, bitcoin])
		return null
	var item := Item.new(definition)
	if not stash.add(item):
		Log.info("🧬 No room in the stash for it: item=%s, price=%d, bitcoin=%d, stash_free=%d" % [
			definition.id, price, bitcoin, stash.free_cells()])
		return null
	_set_bitcoin(bitcoin - price)
	Log.info("🧬 Bought: item=%s, price=%d, bitcoin=%d, stash_cell=%s, stash_items=%d" % [
		definition.id, price, bitcoin, item.cell, stash.items.size()])
	return item


## Puts what is left in the sell crate back into the stash, each item in the first spot it fits. Returns how many
## stayed in the crate for want of room.
func return_crate() -> int:
	var left := 0
	var returned := 0
	for item: Item in crate.items.duplicate():
		crate.remove(item)
		if stash.add(item):
			returned += 1
		else:
			crate.place(item, item.cell, item.orientation)
			left += 1
	if left > 0:
		Log.warning("🧬 No room in the stash for everything in the crate, the rest waits there: returned=%d, left=%d" % [
			returned, left])
		return left
	Log.info("🧬 Crate emptied back into the stash: returned=%d, stash_items=%d" % [returned, stash.items.size()])
	return left


## Plays a sound that carries on through the scene change, such as docking during the fade.
func play_travel_sound(stream: AudioStream) -> void:
	if stream == null:
		Log.warning("🧬 No travel sound to play")
		return
	_sound.stream = stream
	_sound.play()


func _set_bitcoin(amount: int) -> void:
	bitcoin = amount
	bitcoin_changed.emit(bitcoin)


func _set_hydrogen(amount: int) -> void:
	hydrogen = amount
	hydrogen_changed.emit(hydrogen)


## Puts the ship at the hub, with nothing docked.
func _dock_at_hub(hub_position: Vector2) -> void:
	ship_position = hub_position
	at_hub = true
	docked = null


func _travel(scene_path: String) -> void:
	fade_in_next = true
	travelled.emit(scene_path)
	if not travel_enabled:
		Log.info("🧬 Travel recorded, scene left as it is: to=%s" % scene_path)
		return
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		Log.error("🧬 Failed to travel: to=%s, error=%s" % [scene_path, error_string(error)])
		return
	Log.info("🧬 Travelling: to=%s" % scene_path)
