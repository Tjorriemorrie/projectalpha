extends Node
## The game session: what lasts while the game runs as the player goes between the ship and the wreck (nothing is
## saved yet, so quitting starts a new game). It keeps the ship's stash, the bitcoin wallet, the system's trader hub
## and its sell crate, the clone number and the runs boarded; hands what the player carries (the kit: their inventory,
## whose gun keeps its loaded clip's heat) from one scene's player to the next; records how each run ended
## (RunSummary); and changes the scene between the ship and the wreck, playing the travel sounds itself so they carry
## on through the change. Only the first clone of a new game gets the basic kit: a death hands no kit over, and the
## next clone wakes empty-handed and arms from the stash. Selling and buying at the hub go through here, since the
## stash and the wallet live here. Autoloaded as GameSession, after ItemIcons. It has no class_name, which would clash
## with the autoload's name.

## Emitted whenever the game travels to another scene, with its path, also while travel_enabled is off.
signal travelled(scene_path: String)
## Emitted whenever the bitcoin in the wallet changes, with the new amount.
signal bitcoin_changed(bitcoin: int)

## How the player arrives on the ship: waking as a new clone in the clone pod, or back through the airlock.
enum Arrival { NEW_CLONE, EXTRACTED }

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const WRECK_SCENE := "res://scenes/wreck/small_wreck.tscn"
const STASH_SIZE := Vector2i(10, 8)
## The trader hub's sell crate, where items wait to be sold.
const CRATE_SIZE := Vector2i(6, 4)
## The little bitcoin a new game starts with: not enough for antimatter, so the first system already needs runs.
const STARTING_BITCOIN := 500

## The ship's stash: safe whatever happens on a run.
var stash: ItemGrid
## Bitcoin in the wallet: never lost, whatever happens on a run.
var bitcoin := STARTING_BITCOIN
## The trader hub of the system the ship is in (there is only one system until the star map).
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
## Whether the next scene's player fades in from black: a new game wakes up, and every travel arrives.
var fade_in_next := true
## Off in tests, so ending a run never changes the scene under the test runner; travelled is still emitted.
var travel_enabled := true

## The inventory handed to the next scene's player, or null when it gets the basic kit or nothing.
var _carried: Inventory
var _value_in := 0
var _sound: AudioStreamPlayer


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.name = "TravelSound"
	add_child(_sound)
	new_game()


## Starts over: an empty stash, a little bitcoin, a hub with freshly rolled prices, and the first clone waking up in the
## clone pod with the basic kit.
func new_game() -> void:
	stash = ItemGrid.new(STASH_SIZE)
	crate = ItemGrid.new(CRATE_SIZE)
	bitcoin = STARTING_BITCOIN
	trader = Trader.new(randi())
	clone_number = 1
	runs = 0
	arrival = Arrival.NEW_CLONE
	basic_kit_next = true
	last_run = null
	fade_in_next = true
	_carried = null
	_value_in = 0
	Log.info("🧬 New game: stash=%s, bitcoin=%d, hub_seed=%d, clone=%d" % [
		STASH_SIZE, bitcoin, trader.price_seed, clone_number])


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


## The player boards the wreck with what they carry, which is now at risk. Travels to the wreck.
func board(carried: Inventory) -> void:
	runs += 1
	_value_in = carried.value()
	_carried = carried
	Log.info("🧬 Boarding the wreck: run=%d, clone=%d, items=%d, value_in=%d, armed=%s, stash_items=%d" % [
		runs, clone_number, carried.item_count(), _value_in, carried.gun() != null, stash.items.size()])
	_travel(WRECK_SCENE)


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
## bitcoin earned (0 for an empty crate).
func sell_crate() -> int:
	var sold: Array[Item] = crate.items.duplicate()
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
## wallet is short or the stash has no room for it.
func buy(definition: ItemDefinition) -> Item:
	var price := trader.buy_price(definition)
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
