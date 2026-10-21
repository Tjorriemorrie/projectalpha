extends Node
## The game session: what lasts while the game runs as the player goes between the ship and the wreck (nothing is
## saved yet, so quitting starts a new game). It keeps the ship's stash, the clone number and the runs boarded; hands
## what the player carries (the kit: their inventory and the loaded clip's heat) from one scene's player to the next;
## records how each run ended (RunSummary); and changes the scene between the ship and the wreck, playing the travel
## sounds itself so they carry on through the change. A death hands no kit over, so the next clone wakes with the
## basic kit. Autoloaded as GameSession, after ItemIcons. It has no class_name, which would clash with the autoload's
## name.

## Emitted whenever the game travels to another scene, with its path, also while travel_enabled is off.
signal travelled(scene_path: String)

## How the player arrives on the ship: waking as a new clone in the clone pod, or back through the airlock.
enum Arrival { NEW_CLONE, EXTRACTED }

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const WRECK_SCENE := "res://scenes/wreck/small_wreck.tscn"
const STASH_SIZE := Vector2i(10, 8)

## The ship's stash: safe whatever happens on a run.
var stash: ItemGrid
## The clone the player is now, counted from 1, one more for every death.
var clone_number := 1
## Runs boarded this session.
var runs := 0
## How the player arrives on the ship next.
var arrival := Arrival.NEW_CLONE
## How the last run ended, or null before any has.
var last_run: RunSummary
## Whether the next scene's player fades in from black: a new game wakes up, and every travel arrives.
var fade_in_next := true
## Off in tests, so ending a run never changes the scene under the test runner; travelled is still emitted.
var travel_enabled := true
## The loaded clip's heat in the kit handed over, read with take_carried().
var carried_heat := 0.0

## The inventory handed to the next scene's player, or null when it gets the basic kit.
var _carried: Inventory
var _value_in := 0
var _sound: AudioStreamPlayer


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.name = "TravelSound"
	add_child(_sound)
	new_game()


## Starts over: an empty stash, the first clone waking up in the clone pod with the basic kit.
func new_game() -> void:
	stash = ItemGrid.new(STASH_SIZE)
	clone_number = 1
	runs = 0
	arrival = Arrival.NEW_CLONE
	last_run = null
	fade_in_next = true
	carried_heat = 0.0
	_carried = null
	_value_in = 0
	Log.info("🧬 New game: stash=%s, clone=%d" % [STASH_SIZE, clone_number])


## The kit handed over from the last scene's player, for this scene's player to carry on with, once; null when there
## is none (a new game, or a death), so the player builds the basic kit. carried_heat is its loaded clip's heat.
func take_carried() -> Inventory:
	var carried := _carried
	_carried = null
	if carried:
		Log.info("🧬 Kit taken over: items=%d, value=%d, heat=%.0f%%" % [
			carried.item_count(), carried.value(), carried_heat * 100.0])
	else:
		Log.info("🧬 No kit to take over, the player gets the basic kit: clone=%d" % clone_number)
	return carried


## The player boards the wreck with what they carry, which is now at risk. Travels to the wreck.
func board(carried: Inventory, heat: float) -> void:
	runs += 1
	_value_in = carried.value()
	_hand_over(carried, heat)
	Log.info("🧬 Boarding the wreck: run=%d, clone=%d, items=%d, value_in=%d, heat=%.0f%%, stash_items=%d" % [
		runs, clone_number, carried.item_count(), _value_in, heat * 100.0, stash.items.size()])
	_travel(WRECK_SCENE)


## The player got out alive with what they carry: it goes to the ship with them, where they arrive in the airlock.
## Returns the run's summary; continue_to_ship() travels.
func extract(carried: Inventory, heat: float) -> RunSummary:
	last_run = RunSummary.make_extracted(carried.item_count(), carried.value(), _value_in, clone_number)
	arrival = Arrival.EXTRACTED
	_hand_over(carried, heat)
	Log.info("🧬 Extracted: run=%d, clone=%d, items=%d, value=%d, gained=%d, heat=%.0f%%" % [
		runs, clone_number, last_run.items, last_run.value, last_run.gained, heat * 100.0])
	return last_run


## The player died: everything they carried is lost, and the next clone wakes up in the clone pod with the basic
## kit. Returns the run's summary; continue_to_ship() travels.
func die(carried: Inventory) -> RunSummary:
	clone_number += 1
	var items := carried.item_count() if carried else 0
	var value := carried.value() if carried else 0
	last_run = RunSummary.make_died(items, value, clone_number)
	arrival = Arrival.NEW_CLONE
	_carried = null
	carried_heat = 0.0
	Log.info("🧬 Died, everything carried is lost: run=%d, items_lost=%d, value_lost=%d, next_clone=%d" % [
		runs, items, value, clone_number])
	return last_run


## After the run summary: back to the ship, where the player arrives as arrival says.
func continue_to_ship() -> void:
	Log.info("🧬 Continuing to the ship: arrival=%s, clone=%d, kit=%s" % [
		Arrival.keys()[arrival], clone_number, "carried" if _carried else "basic"])
	_travel(SHIP_SCENE)


## Plays a sound that carries on through the scene change, such as docking during the fade.
func play_travel_sound(stream: AudioStream) -> void:
	if stream == null:
		Log.warning("🧬 No travel sound to play")
		return
	_sound.stream = stream
	_sound.play()


func _hand_over(carried: Inventory, heat: float) -> void:
	_carried = carried
	carried_heat = heat


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
