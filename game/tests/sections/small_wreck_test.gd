extends GdUnitTestSuite
## Plays the small wreck with simulated keys and checks its doors, vents, elevator and interaction.
## Positions refer to the layout of res://scenes/wreck/small_wreck.tscn: cell centres sit on multiples of 4 m,
## deck 1 has its floor at y = 0 and deck 2 at y = 4.

const WRECK_SCENE := "res://scenes/wreck/small_wreck.tscn"
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch_hold", &"crouch_toggle",
	&"interact", &"flashlight"]
const KIT_PIECES: Array[String] = [
	"airlock.tscn", "corridor_corner.tscn", "corridor_end.tscn", "corridor_straight.tscn", "corridor_t.tscn",
	"elevator.tscn", "room_large.tscn", "room_small.tscn", "vent_corner.tscn", "vent_straight.tscn"]
const NORTH := 0.0
const WEST := PI / 2.0
const SOUTH := PI
const HEIGHT_TOLERANCE := 0.05

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _elevator: Elevator


func before_test() -> void:
	_runner = scene_runner(WRECK_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	_elevator = _runner.find_child("Elevator") as Elevator


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_assembles_without_errors() -> void:
	assert_array(_wreck.assembly_errors).is_empty()
	assert_int(_wreck.sections.size()).is_equal(14)
	assert_int(_wreck.plan.joins).is_equal(15)
	assert_int(_wreck.plan.count_openings(Socket.Opening.DOORWAY)).is_equal(5)
	assert_int(_wreck.plan.count_openings(Socket.Opening.VENT_MOUTH)).is_equal(4)


func test_uses_every_kit_piece() -> void:
	var used := _wreck.sections.map(func(section: Section) -> String: return section.scene_file_path.get_file())
	assert_array(used).contains(KIT_PIECES)


func test_starts_in_the_airlock_facing_its_door() -> void:
	assert_that(WreckAssembly.to_cell(_player.global_position)).is_equal(Vector3i(0, 0, 1))
	var facing := -_player.global_basis.z
	assert_float(facing.x).is_equal_approx(1.0, 0.01)


func test_automatic_door_opens_and_closes() -> void:
	# The store room's door is in its south wall at z = 2; the player walks north into the room.
	var door := _door("StoreRoom", "SocketSouth")
	await _place(Vector3(4.0, 0.0, 4.6), NORTH)
	assert_bool(door.is_closed()).is_true()
	Input.action_press(&"move_forward")
	assert_bool(await _wait_until(door.is_fully_open, 180)).is_true()
	assert_bool(await _wait_until(func() -> bool: return _player.global_position.z < -0.3, 300)).is_true()
	Input.action_release(&"move_forward")
	assert_bool(door.is_closed()).is_false()
	assert_bool(await _wait_until(door.is_closed, 240)).is_true()


func test_closed_door_blocks_the_player() -> void:
	# The elevator's deck 1 door stays shut until the elevator is called.
	var door := _door("Elevator", "SocketDeck1")
	await _place(Vector3(12.0, 0.0, 4.5), SOUTH)
	Input.action_press(&"move_forward")
	await _physics_frames(120)
	assert_bool(door.is_closed()).is_true()
	assert_float(_player.global_position.z).is_less(6.0)


func test_crouches_through_vent_into_the_hold() -> void:
	# A vent runs west from the corridor at x = 12 on deck 2 into the hold, whose east wall is at x = 6.
	await _place(Vector3(12.0, 4.0, 4.0), WEST)
	await _tap(&"crouch_toggle")
	Input.action_press(&"move_forward")
	assert_bool(await _wait_until(func() -> bool: return _player.global_position.x < 5.0, 720)).is_true()
	assert_float(_player.global_position.y).is_equal_approx(4.0, HEIGHT_TOLERANCE)
	assert_bool(_player.is_crouched).is_true()


func test_cannot_walk_through_vent_standing() -> void:
	await _place(Vector3(12.0, 4.0, 4.0), WEST)
	Input.action_press(&"move_forward")
	await _physics_frames(180)
	assert_float(_player.global_position.x).is_greater(10.8)


func test_shows_prompt_for_call_button() -> void:
	var button := _runner.find_child("CallButtonDeck1") as Interactable
	await _place(Vector3(12.0, 0.0, 5.0), SOUTH)
	await _look_at(button.global_position)
	assert_object(_player.interact_target).is_same(button)
	assert_str((_runner.find_child("Hud") as Hud).prompt_text).is_equal("E Call elevator")
	await _place(Vector3(12.0, 0.0, 4.0), NORTH)
	assert_object(_player.interact_target).is_null()
	assert_str((_runner.find_child("Hud") as Hud).prompt_text).is_empty()


func test_rides_elevator_to_deck_2() -> void:
	var lower_door := _door("Elevator", "SocketDeck1")
	var upper_door := _door("Elevator", "SocketDeck2")
	var dings: Array = []
	_elevator.dinged.connect(func(deck: int, _position: Vector3) -> void: dings.append(deck))

	# Call the platform, which waits at deck 1, then walk in.
	await _place(Vector3(12.0, 0.0, 5.0), SOUTH)
	await _look_at((_runner.find_child("CallButtonDeck1") as Node3D).global_position)
	await _tap(&"interact")
	assert_bool(await _wait_until(lower_door.is_fully_open, 120)).is_true()
	_player.set_look(SOUTH)
	Input.action_press(&"move_forward")
	assert_bool(await _wait_until(func() -> bool: return _player.global_position.z > 7.6, 300)).is_true()
	Input.action_release(&"move_forward")
	await _physics_frames(20)

	# Send it up: the lower door shuts before the platform moves, and stays shut on the way.
	await _look_at((_runner.find_child("SendButton") as Node3D).global_position)
	await _tap(&"interact")
	var lower_door_shut_while_away := true
	for frame in 600:
		await _physics_frames(1)
		if _elevator.get_platform_height() > 0.01 and not lower_door.is_closed():
			lower_door_shut_while_away = false
		if not dings.is_empty():
			break
	assert_array(dings).is_equal([1])
	assert_bool(lower_door_shut_while_away).is_true()
	assert_float(_player.global_position.y).is_equal_approx(4.0, HEIGHT_TOLERANCE)
	assert_bool(_player.is_on_floor()).is_true()
	assert_bool(await _wait_until(upper_door.is_fully_open, 120)).is_true()

	# Step out; the doors close a few seconds later.
	_player.set_look(NORTH)
	Input.action_press(&"move_forward")
	assert_bool(await _wait_until(func() -> bool: return _player.global_position.z < 5.0, 300)).is_true()
	Input.action_release(&"move_forward")
	assert_bool(await _wait_until(upper_door.is_closed, 360)).is_true()


func test_call_brings_the_platform_back() -> void:
	var lower_door := _door("Elevator", "SocketDeck1")
	var dings: Array = []
	_elevator.dinged.connect(func(deck: int, _position: Vector3) -> void: dings.append(deck))
	_elevator.send()
	assert_bool(await _wait_until(func() -> bool: return dings.size() == 1, 600)).is_true()
	(_runner.find_child("CallButtonDeck1") as Interactable).interact()
	assert_bool(await _wait_until(func() -> bool: return dings.size() == 2, 900)).is_true()
	assert_array(dings).is_equal([1, 0])
	assert_float(_elevator.get_platform_height()).is_equal_approx(0.0, 0.001)
	assert_bool(await _wait_until(lower_door.is_fully_open, 120)).is_true()


func _door(section: String, socket: String) -> SlidingDoor:
	return (_runner.find_child(section).get_node(socket) as Socket).door


func _place(position: Vector3, yaw: float) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(yaw)
	_player.reset_physics_interpolation()
	await _physics_frames(5)


## Turns the camera towards a point and gives the look ray a few frames to find it.
func _look_at(target: Vector3) -> void:
	var to_target := target - (_player.global_position + Vector3.UP * _player.stand_eye_height)
	var flat := Vector2(to_target.x, to_target.z).length()
	_player.set_look(atan2(-to_target.x, -to_target.z), atan2(to_target.y, flat))
	await _physics_frames(5)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(1)
	Input.action_release(action)
	await _physics_frames(1)


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for frame in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
