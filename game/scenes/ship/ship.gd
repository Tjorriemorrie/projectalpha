class_name Ship
extends Wreck
## The player's ship: home between runs. It assembles from the same kit sections as a wreck, but has no robots or
## loot, and its lamps are warm and steady. A new clone wakes up in the clone pod; a player back from the wreck arrives
## in the airlock. The cockpit console opens the system map, to fly to a wreck; once one is docked, its hull shows
## outside the window and cycling the airlock's outer door boards it, and while nothing is docked the outer door is
## shut. The stash keeps what is safe. The scene's player has the pistol holstered and no floor to drop things on.

## The colour of the ship's lamps: warm white, about 3800 K.
@export var lamp_color := Color(1.0, 0.8, 0.62)
## How much stronger the ship's lamps are than the wreck's.
@export var lamp_energy := 1.6
## A warm fill light under every lamp, so the walls are lit too, not only the floor under the lamp.
@export var fill_energy := 0.7
@export var fill_range := 4.5
## What cycling the airlock does here and its sign, filled in with the docked wreck's layout and what the scan says
## about its robots, and how long interact is held.
@export var board_prompt := "Board the %s · %s"
@export var board_sign := "%s DOCKED"
@export var board_time := 1.0
## The airlock's sign while nothing is docked.
@export var empty_sign := "NOTHING DOCKED"

@onready var _clone_pod: ClonePod = %ClonePod
@onready var _arrival_spawn: Marker3D = %ArrivalSpawn
## What shows outside the window while a wreck is docked: its hull and the docking tube.
@onready var _docked_outside: Array[Node3D] = [$Outside/Hull, $Outside/DockingTube]


func _ready() -> void:
	super()
	var lamps: Array[Node] = []
	_collect(self, CeilingLamp, lamps)
	for lamp: CeilingLamp in lamps:
		lamp.set_steady(lamp_color, lamp_energy)
		var fill := OmniLight3D.new()
		fill.name = "Fill"
		fill.light_color = lamp_color
		fill.light_energy = fill_energy
		fill.omni_range = fill_range
		fill.position = Vector3(0.0, -0.5, 0.0)
		lamp.add_child(fill)
	_show_docked()
	GameSession.ship_moved.connect(_show_docked)
	_place_player()
	Log.info("🚀 Ship ready: ship=%s, lamps=%d, airlocks=%d, arrival=%s, clone=%d, stash_items=%d, at_hub=%s" % [
		name, lamps.size(), airlocks.size(), GameSession.Arrival.keys()[GameSession.arrival], GameSession.clone_number,
		GameSession.stash.items.size(), GameSession.at_hub])


## The airlock says which wreck is docked and what the scan says about its robots: "Board the hauler · about 4 robots
## active" under a "HAULER DOCKED" sign, with its hull outside the window. With nothing docked the outer door is shut,
## under a "NOTHING DOCKED" sign, and the window shows only stars. Runs again whenever the ship flies.
func _show_docked() -> void:
	var docked := GameSession.docked
	for node in _docked_outside:
		node.visible = docked != null
	if docked == null:
		for airlock in airlocks:
			airlock.set_purpose("", empty_sign, board_time)
			airlock.set_usable(false)
		Log.info("🚀 Nothing docked, the airlock is shut: ship=%s, at_hub=%s" % [name, GameSession.at_hub])
		return
	var layout := docked.definition.display_name
	var prompt := board_prompt % [layout.to_lower(), docked.robots_estimate()]
	var sign_text := board_sign % layout.to_upper()
	for airlock in airlocks:
		airlock.set_purpose(prompt, sign_text, board_time)
		airlock.set_usable(true)
	Log.info("🚀 Docked wreck shown at the airlock: ship=%s, layout=%s, prompt=%s, sign=%s" % [
		name, docked.definition.id, prompt, sign_text])


## A new clone wakes up in the clone pod; a player back from the wreck stands in the airlock, facing into the ship.
func _place_player() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 No player on the ship to place: ship=%s" % name)
		return
	var spawn := _arrival_spawn
	if GameSession.arrival == GameSession.Arrival.NEW_CLONE:
		spawn = _clone_pod.get_spawn()
		_clone_pod.wake()
	player.global_position = spawn.global_position
	player.set_look(spawn.global_rotation.y)
	player.reset_physics_interpolation()
	Log.info("🚀 Player placed: arrival=%s, spawn=%s, position=%s" % [
		GameSession.Arrival.keys()[GameSession.arrival], spawn.name, player.global_position])


## On the ship, cycling the airlock boards the wreck.
func _on_airlock_cycled(airlock: Airlock) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 Airlock cycled with no player to board: ship=%s, airlock=%s" % [name, airlock.name])
		return
	Log.info("🚀 Player boarding the wreck: ship=%s, airlock=%s" % [name, airlock.name])
	player.board()
