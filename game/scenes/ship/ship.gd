class_name Ship
extends Wreck
## The player's ship, docked at the wreck: home between runs. It assembles from the same kit sections as a wreck, but
## has no robots or loot, and its lamps are warm and steady. A new clone wakes up in the clone pod; a player back from
## the wreck arrives in the airlock, where cycling the outer door boards the wreck. The stash keeps what is safe. The
## scene's player has the pistol holstered and no floor to drop things on.

## The colour of the ship's lamps: warm white, about 3800 K.
@export var lamp_color := Color(1.0, 0.8, 0.62)
## How much stronger the ship's lamps are than the wreck's.
@export var lamp_energy := 1.6
## A warm fill light under every lamp, so the walls are lit too, not only the floor under the lamp.
@export var fill_energy := 0.7
@export var fill_range := 4.5
## What cycling the airlock does here, its sign, and how long interact is held.
@export var board_prompt := "Board the wreck"
@export var board_sign := "WRECK DOCKED"
@export var board_time := 1.0

@onready var _clone_pod: ClonePod = %ClonePod
@onready var _arrival_spawn: Marker3D = %ArrivalSpawn


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
	for airlock in airlocks:
		airlock.set_purpose(board_prompt, board_sign, board_time)
	_place_player()
	Log.info("🚀 Ship ready: ship=%s, lamps=%d, airlocks=%d, arrival=%s, clone=%d, stash_items=%d" % [
		name, lamps.size(), airlocks.size(), GameSession.Arrival.keys()[GameSession.arrival], GameSession.clone_number,
		GameSession.stash.items.size()])


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
