extends Node
## The game session: what lasts while the game runs as the player goes between the ship and the wreck (nothing is
## saved yet, so quitting starts a new game). It keeps the ship's stash, the bitcoin wallet, the hydrogen and
## antimatter tanks with the antimatter on order, the day and the jump drive's recharge, the star system the ship is in
## (a StarSystem, with the wrecks still there to board) and its trader hub, every system revealed so far
## (on arrival or by intel, each keeping what is left in it) with the visited ones' hubs, the route through them, where
## the ship is in the system (at the hub, docked with a wreck, or where a wreck it boarded was), the clone number and
## the runs boarded. It hands what the player carries (the kit: their inventory, whose gun keeps its loaded clip's heat)
## from one scene's player to the next, and the docked wreck's roll to the wreck boarded; records how each run ended
## (RunSummary), and unloads a haul into the stash after an extraction; and changes the scene between the ship and
## the wreck, playing the travel sounds itself so they carry on through the change. Only the first clone of a new
## game gets the basic kit: a death hands no kit over, and the next clone wakes empty-handed and arms from the stash. Flying within the system, jumping to another, refuelling,
## ordering antimatter, buying intel, selling and buying go through here, since the tanks, the stash and the wallet
## live here; all but flying only at the hub. A system never strands the player: while the ship can't jump on yet,
## easy wrecks turn up when too few are left to wait for it, or to earn the antimatter he can't afford.
## Autoloaded as GameSession, after ItemIcons. It has no class_name, which would clash with the autoload's name.

## Emitted whenever the game travels to another scene, with its path, also while travel_enabled is off.
signal travelled(scene_path: String)
## Emitted whenever the bitcoin in the wallet changes, with the new amount.
signal bitcoin_changed(bitcoin: int)
## Emitted whenever the hydrogen in the tank changes, with the new amount.
signal hydrogen_changed(hydrogen: int)
## Emitted whenever the antimatter in the tank or on order changes, with the amount in the tank.
signal antimatter_changed(antimatter: int)
## Emitted whenever a day passes, with the new day.
signal day_changed(day: int)
## Emitted whenever the ship flies somewhere in the system (and so docks with a wreck, or reaches the hub), and when
## it jumps to another system.
signal ship_moved

## How the player arrives on the ship: waking as a new clone in the clone pod, or back through the airlock.
enum Arrival { NEW_CLONE, EXTRACTED }
## Whether a jump to a system can go ahead (OK), or why not.
enum Jump { OK, HERE, OUT_OF_RANGE, AWAY_FROM_HUB, RECHARGING, ORDER_PENDING, SHORT_OF_ANTIMATTER }
## Whether intel on a system can be bought (OK), or why not.
enum Intel { OK, KNOWN, OUT_OF_RANGE, AWAY_FROM_HUB, SHORT_OF_BITCOIN }

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
## The stash's columns, and the rows it never shrinks below. It has no size limit: it grows, always keeping
## STASH_SPARE_ROWS empty rows below its last stack, so storing, unloading and buying never need room.
const STASH_SIZE := Vector2i(8, 4)
const STASH_SPARE_ROWS := 1
## The little bitcoin a new game starts with: not enough for antimatter, so the first system already needs runs.
const STARTING_BITCOIN := 500
## The antimatter a new game starts with: too little for any jump (the shortest burns 5), so the first order is
## cheaper. A tuning lever.
const STARTING_ANTIMATTER := 2
## How much hydrogen the ship's tank holds; a new game starts with it full.
const HYDROGEN_TANK := 24
## How much antimatter the ship's tank holds: a jump of up to 10 light years.
const ANTIMATTER_TANK := 10
## Days the jump drive recharges after a jump, so the player boards a ship in every system before jumping on.
const RECHARGE_DAYS := 1
## When the player can't afford the antimatter to move on and fewer than STRANDED_SHIPS wrecks are left, easy ones
## turn up until the system holds STRANDED_TOP_UP of them; easy ones are rolled at EASY_LEVEL.
const STRANDED_SHIPS := 3
const STRANDED_TOP_UP := Vector2i(3, 4)
const EASY_LEVEL := 1

## The ship's stash: safe whatever happens on a run, and never full.
var stash: ItemGrid
## Bitcoin in the wallet: never lost, whatever happens on a run.
var bitcoin := STARTING_BITCOIN
## Hydrogen in the tank, which flights within the system burn. Bought at the hub.
var hydrogen := HYDROGEN_TANK
## Antimatter in the tank, which jumps burn. Ordered at the hub, it arrives there days later.
var antimatter := 0
## Antimatter on order and the day it arrives at the hub, where the player collects it; no order while order_units is 0.
var order_units := 0
var order_day := 0
## Days gone since the game started (day 0). Only boarding and jumping pass a day.
var day := 0
## The day the jump drive is charged again after a jump.
var drive_ready_day := 0
## The star system the ship is in, with the wrecks still there to board; null only when no system is registered.
var system: StarSystem
## Every system revealed so far, on arrival or by intel, by its definition's ID: what is left in it stays as it is
## while the ship is elsewhere.
var revealed: Dictionary[String, StarSystem] = {}
## The systems the ship has arrived in, in order from the start system (one again for every return).
var route: Array[StarSystemDefinition] = []
## Where the ship is on the system map, in map units from the star.
var ship_position := Vector2.ZERO
## Whether the ship is at the system's trader hub, the only place to trade and refuel.
var at_hub := true
## The trader hub of the system the ship is in.
var trader: Trader
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
## Each visited system's hub, by its definition's ID, so its prices stay the same when the ship comes back.
var _hubs: Dictionary[String, Trader] = {}
var _value_in := 0
var _sound: AudioStreamPlayer


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.name = "TravelSound"
	add_child(_sound)
	new_game()


## Starts over on day 0: an empty stash, a little bitcoin, a full hydrogen tank and a little antimatter, the ship
## at the hub of a random star system on the galaxy's outer ring with nothing else revealed, and the first clone waking
## up in the clone pod with the basic kit.
func new_game() -> void:
	stash = ItemGrid.new(STASH_SIZE, STASH_SPARE_ROWS)
	bitcoin = STARTING_BITCOIN
	hydrogen = HYDROGEN_TANK
	antimatter = STARTING_ANTIMATTER
	order_units = 0
	order_day = 0
	day = 0
	drive_ready_day = 0
	system = null
	revealed.clear()
	route.clear()
	_hubs.clear()
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
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	arrive_in(Galaxy.pick_start(systems, rng))
	Log.info("🧬 New game: stash=%s, bitcoin=%d, hydrogen=%d, antimatter=%d, day=%d, clone=%d, system=%s, from_middle=%.1f ly" % [
		STASH_SIZE, bitcoin, hydrogen, antimatter, day, clone_number, system.definition.id,
		system.definition.map_position.length()])


## The ship arrives in a star system, at its hub: the system is revealed if it wasn't yet, with its wrecks rolled now,
## and otherwise holds what was left in it; its hub keeps its prices from an earlier visit. Then, if the ship can't jump
## on yet and too few wrecks are left, easy ones turn up (see _keep_from_stranding()).
func arrive_in(definition: StarSystemDefinition) -> void:
	var returning := known_system(definition) != null
	system = reveal(definition)
	if not _hubs.has(definition.id):
		_hubs[definition.id] = Trader.new(randi(), definition.hub_name())
	trader = _hubs[definition.id]
	route.append(definition)
	_dock_at_hub(system.hub_position)
	var turned_up := _keep_from_stranding("arrival")
	if system.wrecks.is_empty() and ContentRegistry.get_all(WreckDefinition).is_empty():
		Log.error("🧬 Arrived in a system with no wrecks, no wreck layouts are registered: system=%s" % definition.id)
		return
	Log.info("🧬 Arrived in a star system: system=%s, map_id=%s, returning=%s, places=%d, wrecks=%d, turned_up=%d, hub=%s, route=%d, layouts=%s" % [
		definition.id, definition.map_id, returning, definition.places.size(), system.wrecks.size(), turned_up,
		trader.title, route.size(), system.wrecks.map(func(wreck: SystemWreck) -> String:
			return wreck.roll.definition.id)])


## A system revealed: the one already known (with what is left in it), or else rolled now, wrecks and all, and kept
## from then on.
func reveal(definition: StarSystemDefinition) -> StarSystem:
	var known := known_system(definition)
	if known:
		Log.info("🧬 Star system already known: system=%s, wrecks=%d" % [definition.id, known.wrecks.size()])
		return known
	var rolled := StarSystem.reveal(definition, ContentRegistry.get_all(WreckDefinition), RandomNumberGenerator.new())
	revealed[definition.id] = rolled
	Log.info("🧬 Star system revealed: system=%s, wrecks=%d, revealed=%d" % [
		definition.id, rolled.wrecks.size(), revealed.size()])
	return rolled


## What is known of a system: the one the ship is in, or one revealed before (visited, or by intel); null while it is
## unknown.
func known_system(definition: StarSystemDefinition) -> StarSystem:
	if definition == null:
		return null
	if system and system.definition == definition:
		return system
	return revealed.get(definition.id)


## Whether the ship has been in a system this game.
func has_visited(definition: StarSystemDefinition) -> bool:
	return route.has(definition) or (system != null and system.definition == definition)


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


## Whether the tank can fly the ship to any wreck in the system and from there back to the hub. When it can't, and
## nothing is docked, the only flight left is back to the hub, to buy more hydrogen.
func can_reach_a_wreck() -> bool:
	if system == null:
		return false
	for wreck in system.wrecks:
		if hydrogen_needed(wreck.position) <= hydrogen:
			return true
	return false


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


## Flies the ship back to the system's hub, burning hydrogen; antimatter on order that has arrived waits there to be
## collected at the trader terminal. Refused (false) when the tank is short, which the rule for flying out
## (hydrogen_needed()) never lets happen.
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
	Log.info("🧬 Flew back to the hub: hub=%s, burned=%d, hydrogen=%d, antimatter_to_collect=%d" % [
		trader.title, cost, hydrogen, order_units if order_arrived() else 0])
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


## The systems a jump from this one can reach, nearest first.
func jump_targets() -> Array[StarSystemDefinition]:
	if system == null:
		return []
	return Galaxy.in_range(system.definition, ContentRegistry.get_all(StarSystemDefinition))


## Antimatter a jump from this system to another burns.
func jump_cost(to: StarSystemDefinition) -> int:
	return Galaxy.antimatter_between(system.definition, to) if system and to else 0


## Whether the jump drive has recharged since the last jump.
func drive_charged() -> bool:
	return day >= drive_ready_day


## Whether a jump to a system can go ahead now (Jump.OK), or why not: it is this one, it is out of range, the ship is
## away from the hub, the drive is still recharging, antimatter is on order or waiting to be collected (a jump would
## leave it behind), or the tank can't fly it.
func check_jump(to: StarSystemDefinition) -> Jump:
	if system == null or to == null:
		return Jump.OUT_OF_RANGE
	if to == system.definition:
		return Jump.HERE
	if Galaxy.distance(system.definition, to) > Galaxy.JUMP_RANGE:
		return Jump.OUT_OF_RANGE
	if not at_hub:
		return Jump.AWAY_FROM_HUB
	if not drive_charged():
		return Jump.RECHARGING
	if order_units > 0:
		return Jump.ORDER_PENDING
	if jump_cost(to) > antimatter:
		return Jump.SHORT_OF_ANTIMATTER
	return Jump.OK


## Jumps the ship from the hub to another system's hub, burning antimatter by distance. It takes a day, and the drive
## then recharges for RECHARGE_DAYS. The system left keeps what is left in it. Refused (false) unless check_jump()
## says OK.
func jump_to(to: StarSystemDefinition) -> bool:
	var check := check_jump(to)
	if check != Jump.OK:
		Log.info("🧬 Jump refused: to=%s, why=%s, antimatter=%d, cost=%d, at_hub=%s, day=%d, drive_ready_day=%d, order=%d" % [
			to.id if to else "none", Jump.keys()[check], antimatter, jump_cost(to), at_hub, day, drive_ready_day,
			order_units])
		return false
	var from := system
	var cost := jump_cost(to)
	revealed[from.definition.id] = from
	_set_antimatter(antimatter - cost)
	_set_day(day + 1)
	drive_ready_day = day + RECHARGE_DAYS
	Log.info("🧬 Jumping: from=%s, to=%s, distance=%.1f ly, burned=%d, antimatter=%d, day=%d, wrecks_left_behind=%d" % [
		from.definition.id, to.id, Galaxy.distance(from.definition, to), cost, antimatter, day, from.wrecks.size()])
	arrive_in(to)
	ship_moved.emit()
	Log.info("🧬 Jumped: system=%s, wrecks=%d, drive_ready_day=%d, route=%d" % [
		to.id, system.wrecks.size(), drive_ready_day, route.size()])
	return true


## Orders the antimatter that fills the tank at the hub, paid at once: an order always fills every empty unit, or is
## refused. It arrives at the hub Trader.DELIVERY_DAYS later. Returns the units ordered: none away from the hub, with
## an order already on its way, a full tank or a wallet that can't pay for filling it.
func order_antimatter() -> int:
	var missing := ANTIMATTER_TANK - antimatter
	if not at_hub:
		Log.warning("🧬 Can't order antimatter away from the hub: antimatter=%d, position=%s" % [antimatter, ship_position])
		return 0
	if order_units > 0:
		Log.info("🧬 Antimatter already on order: units=%d, arrives_day=%d, day=%d" % [order_units, order_day, day])
		return 0
	if missing <= 0:
		Log.info("🧬 No antimatter ordered, the tank is full: antimatter=%d" % antimatter)
		return 0
	var price := trader.antimatter_price(missing)
	if price > bitcoin:
		Log.info("🧬 No antimatter ordered, not enough bitcoin to fill the tank: missing=%d, price=%d, bitcoin=%d" % [
			missing, price, bitcoin])
		return 0
	_set_bitcoin(bitcoin - price)
	order_units = missing
	order_day = day + Trader.DELIVERY_DAYS
	antimatter_changed.emit(antimatter)
	Log.info("🧬 Antimatter ordered to fill the tank: units=%d, price=%d, bitcoin=%d, day=%d, arrives_day=%d, hub=%s" % [
		order_units, price, bitcoin, day, order_day, trader.title])
	_keep_from_stranding("order")
	return order_units


## Whether antimatter is on order and has arrived at the hub, waiting there to be collected.
func order_arrived() -> bool:
	return order_units > 0 and day >= order_day


## Collects the antimatter on order into the tank (from the trader terminal), once it has arrived and the ship is at
## the hub. Returns the units loaded: none before then.
func collect_antimatter() -> int:
	if not at_hub or not order_arrived():
		Log.info("🧬 No antimatter to collect: at_hub=%s, order=%d, arrives_day=%d, day=%d" % [
			at_hub, order_units, order_day, day])
		return 0
	var units := mini(order_units, ANTIMATTER_TANK - antimatter)
	order_units = 0
	_set_antimatter(antimatter + units)
	Log.info("🧬 Antimatter collected at the hub: units=%d, antimatter=%d, day=%d, hub=%s" % [
		units, antimatter, day, trader.title])
	return units


## Days the player still has to board ships before the ship can jump on: for the antimatter on order to arrive, and
## for the drive to recharge.
func wait_days() -> int:
	var delivery := order_day - day if order_units > 0 else 0
	return maxi(maxi(delivery, drive_ready_day - day), 0)


## Whether intel on a system can be bought now (Intel.OK), or why not: it is known already (the system the ship is in,
## one visited, or one with intel), it is out of jump range, the ship is away from the hub, or the wallet is short.
func check_intel(to: StarSystemDefinition) -> Intel:
	if to == null or known_system(to) != null:
		return Intel.KNOWN
	if system == null or Galaxy.distance(system.definition, to) > Galaxy.JUMP_RANGE:
		return Intel.OUT_OF_RANGE
	if not at_hub:
		return Intel.AWAY_FROM_HUB
	if trader.intel_price() > bitcoin:
		return Intel.SHORT_OF_BITCOIN
	return Intel.OK


## Buys intel on a system in jump range at the hub: the system is revealed now, its wrecks rolled and kept as they are
## until the ship arrives. Returns the revealed system, or null unless check_intel() says OK.
func buy_intel(to: StarSystemDefinition) -> StarSystem:
	var check := check_intel(to)
	if check != Intel.OK:
		Log.info("🧬 Intel not bought: system=%s, why=%s, bitcoin=%d, at_hub=%s" % [
			to.id if to else "none", Intel.keys()[check], bitcoin, at_hub])
		return null
	var price := trader.intel_price()
	_set_bitcoin(bitcoin - price)
	var known := reveal(to)
	Log.info("🧬 Intel bought: system=%s, price=%d, bitcoin=%d, wrecks=%d, hub=%s" % [
		to.id, price, bitcoin, known.wrecks.size(), trader.title])
	return known


## What everything the player owns on the ship would sell for at the hub: the stash, and the kit carried home from a
## run.
func ship_worth() -> int:
	var items: Array[Item] = stash.items.duplicate()
	if _carried:
		for grid in _carried.grids():
			items.append_array(grid.items)
	return trader.offer(items)


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
	_set_day(day + 1)
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


## The player got out alive with what they carry: it goes to the ship with them, where they arrive in the airlock,
## and the haul in the pockets and the backpack can be unloaded into the stash first (unload()). Returns the run's
## summary; continue_to_ship() travels.
func extract(carried: Inventory) -> RunSummary:
	var haul := carried.haul()
	var haul_items := 0
	var haul_value := 0
	for item in haul:
		haul_items += item.quantity
		haul_value += item.value()
	last_run = RunSummary.make_extracted(carried.item_count(), carried.value(), _value_in, clone_number, haul_items,
		haul_value)
	arrival = Arrival.EXTRACTED
	_carried = carried
	Log.info("🧬 Extracted: run=%d, clone=%d, items=%d, value=%d, gained=%d, haul_items=%d, haul_value=%d" % [
		runs, clone_number, last_run.items, last_run.value, last_run.gained, haul_items, haul_value])
	return last_run


## After an extraction, unloads the haul the player brought home into the stash in one go: every stack in the pockets
## and the backpack, topping up stacks of its kind in the stash or taking free slots (the stash always has room). The
## gun in the weapon slot and the clips in the ammo slots stay. The run's summary records it. Returns the items
## unloaded: none after a death, or when it was unloaded already.
func unload(carried: Inventory) -> int:
	if last_run == null or not last_run.extracted or last_run.unloaded:
		Log.info("🧬 Nothing to unload: last_run=%s" % last_run)
		return 0
	var items := 0
	var value := 0
	var stacks := carried.haul()
	for item in stacks:
		var from := carried.grid_of(item)
		var quantity := item.quantity
		var worth := item.value()
		from.remove(item)
		if not stash.add(item):
			# A growing stash always has room, so this shouldn't happen; if it does, the rest stays carried.
			from.add(item)
			Log.error("🧬 No room in the stash to unload a stack, it stays carried: item=%s, left=%d" % [
				item.definition.id, item.quantity])
			continue
		items += quantity
		value += worth
	last_run.unloaded = true
	last_run.unloaded_items = items
	last_run.unloaded_value = value
	Log.info("🧬 Haul unloaded into the stash: stacks=%d, items=%d, value=%d, stash_stacks=%d, stash_rows=%d" % [
		stacks.size(), items, value, stash.items.size(), stash.size.y])
	return items


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


## After the run summary: back to the ship, where the player arrives as arrival says. If the ship can't jump on yet
## and too few wrecks are left, easy ones turn up first (see _keep_from_stranding()).
func continue_to_ship() -> void:
	var turned_up := _keep_from_stranding("run")
	Log.info("🧬 Continuing to the ship: arrival=%s, clone=%d, kit=%s, wrecks_turned_up=%d" % [
		Arrival.keys()[arrival], clone_number, "carried" if _carried else "basic" if basic_kit_next else "none",
		turned_up])
	_travel(SHIP_SCENE)


## Sells up to amount of a stack in the stash to the hub: they leave the stack (all of it takes the stack out), and
## the wallet gets the hub's price for each. Returns the bitcoin earned: none away from the hub, for a stack that
## isn't in the stash, or for no amount.
func sell(item: Item, amount: int) -> int:
	if not at_hub:
		Log.warning("🧬 Can't sell away from the hub: item=%s, amount=%d, position=%s" % [
			item.definition.id, amount, ship_position])
		return 0
	if not stash.has(item) or amount <= 0:
		Log.warning("🧬 Nothing to sell: item=%s, amount=%d, in_stash=%s" % [item.definition.id, amount,
			stash.has(item)])
		return 0
	var sold := stash.take(item, amount)
	var earned := trader.sell_price(sold.definition) * sold.quantity
	_set_bitcoin(bitcoin + earned)
	Log.info("🧬 Sold: item=%s, sold=%d, left=%d, earned=%d, bitcoin=%d" % [
		sold.definition.id, sold.quantity, item.quantity if stash.has(item) else 0, earned, bitcoin])
	return earned


## Buys one of an item from the hub into the stash: onto a stack of it with room, else into the first free slot
## (the stash always has one). Returns the stack it went onto, or null when the ship is away from the hub or the
## wallet is short.
func buy(definition: ItemDefinition) -> Item:
	var price := trader.buy_price(definition)
	if not at_hub:
		Log.warning("🧬 Can't buy away from the hub: item=%s, position=%s" % [definition.id, ship_position])
		return null
	if price > bitcoin:
		Log.info("🧬 Can't afford it: item=%s, price=%d, bitcoin=%d" % [definition.id, price, bitcoin])
		return null
	var item := stash.add_one(definition)
	if item == null:
		Log.error("🧬 No room in the stash for it, which a growing stash always has: item=%s, price=%d" % [
			definition.id, price])
		return null
	_set_bitcoin(bitcoin - price)
	Log.info("🧬 Bought: item=%s, price=%d, bitcoin=%d, stash_cell=%s, stack=%d, stash_stacks=%d" % [
		definition.id, price, bitcoin, item.cell, item.quantity, stash.items.size()])
	return item


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


func _set_antimatter(amount: int) -> void:
	antimatter = amount
	antimatter_changed.emit(antimatter)


func _set_day(value: int) -> void:
	day = value
	day_changed.emit(day)


## A system never strands the player. While the ship can't jump on yet (the drive is recharging, or the tank and the
## antimatter on order are short of the shortest jump out), easy wrecks turn up: when fewer are left than days still to
## wait, enough to wait it out; and when the tank holds too little and the player can't afford to fill it (the wallet
## plus what the ship holds would sell for) and fewer than STRANDED_SHIPS are left, until the system holds
## STRANDED_TOP_UP. A player who can afford it but hasn't ordered it gets none. Returns how many turned up.
func _keep_from_stranding(why: String) -> int:
	if system == null:
		Log.warning("🧬 No system to keep the player from being stranded in: why=%s" % why)
		return 0
	var targets := jump_targets()
	if targets.is_empty():
		Log.warning("🧬 No system in jump range, nowhere to move on to: why=%s, system=%s" % [why, system.definition.id])
		return 0
	var shortest := jump_cost(targets[0])
	var coming := antimatter + order_units
	var wait := wait_days()
	var left := system.wrecks.size()
	if wait == 0 and coming >= shortest:
		Log.info("🧬 The ship can jump on, no wrecks need to turn up: why=%s, antimatter=%d, shortest_jump=%d, wrecks=%d" % [
			why, coming, shortest, left])
		return 0
	var wanted := wait
	# An order always fills the tank, so that is what moving on costs while the tank holds too little.
	var missing := ANTIMATTER_TANK - coming if coming < shortest else 0
	var worth := bitcoin + ship_worth()
	var short := missing > 0 and trader.antimatter_price(missing) > worth
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if short and left < STRANDED_SHIPS:
		wanted = maxi(wanted, rng.randi_range(STRANDED_TOP_UP.x, STRANDED_TOP_UP.y))
	if wanted <= left:
		Log.info("🧬 Enough wrecks left to wait or earn the antimatter: why=%s, wrecks=%d, wait=%d, missing=%d, worth=%d, short=%s" % [
			why, left, wait, missing, worth, short])
		return 0
	system.add_wrecks(ContentRegistry.get_all(WreckDefinition), wanted - left, rng, EASY_LEVEL)
	var added := system.wrecks.size() - left
	Log.info("🧬 Easy wrecks turned up so the player isn't stranded: why=%s, system=%s, added=%d, wrecks=%d, wait=%d, missing=%d, worth=%d, short=%s" % [
		why, system.definition.id, added, system.wrecks.size(), wait, missing, worth, short])
	return added


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
