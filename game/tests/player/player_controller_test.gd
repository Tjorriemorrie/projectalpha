extends GdUnitTestSuite
## Plays the player controller in the greybox test scene with simulated keys, and checks how it moves.
## Positions refer to the layout of res://scenes/test/player_test.tscn.

const TEST_SCENE := "res://scenes/test/player_test.tscn"
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch_hold", &"crouch_toggle",
	&"flashlight"]
## Obstacles stand in a row at this z; the player walks towards -z.
const OBSTACLE_Z := 2.0
const SPEED_TOLERANCE := 0.05
const HEIGHT_TOLERANCE := 0.02

var _runner: GdUnitSceneRunner
var _player: Player


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_player = _runner.find_child("Player") as Player


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_walks_at_walk_speed() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	assert_float(_horizontal_speed()).is_equal_approx(_player.walk_speed, SPEED_TOLERANCE)
	assert_int(_player.movement_state).is_equal(MovementRules.State.WALK)
	assert_float(_player.global_position.z).is_less(8.0)


func test_sprints_forward_at_sprint_speed() -> void:
	await _place(Vector3(0.0, 0.0, 12.0))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_float(_horizontal_speed()).is_equal_approx(_player.sprint_speed, SPEED_TOLERANCE)
	assert_int(_player.movement_state).is_equal(MovementRules.State.SPRINT)


func test_does_not_sprint_while_strafing() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"move_right")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_float(_horizontal_speed()).is_equal_approx(_player.walk_speed, SPEED_TOLERANCE)
	assert_int(_player.movement_state).is_equal(MovementRules.State.WALK)


func test_slides_to_a_stop() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	Input.action_release(&"move_forward")
	await _physics_frames(3)
	assert_float(_horizontal_speed()).is_greater(0.0)
	await _physics_frames(20)
	assert_float(_horizontal_speed()).is_equal(0.0)
	assert_int(_player.movement_state).is_equal(MovementRules.State.IDLE)


func test_emits_movement_state_changes() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	var changes: Array = []
	_player.movement_state_changed.connect(func(previous, current): changes.append([previous, current]))
	Input.action_press(&"move_forward")
	await _physics_frames(5)
	assert_array(changes).contains_exactly([[MovementRules.State.IDLE, MovementRules.State.WALK]])


func test_steps_over_low_obstacles(obstacle_x: float, obstacle_height: float, test_parameters := [
	[-3.0, 0.15],
	[-1.0, 0.25],
	[1.0, 0.35],
	[5.0, 0.3],
]) -> void:
	await _place(Vector3(obstacle_x, 0.0, OBSTACLE_Z + 2.0))
	Input.action_press(&"move_forward")
	var highest := 0.0
	var airborne_frames := 0
	for frame in 240:
		await _physics_frames(1)
		highest = maxf(highest, _player.global_position.y)
		airborne_frames += 0 if _player.is_on_floor() else 1
	assert_float(highest).is_equal_approx(obstacle_height, HEIGHT_TOLERANCE)
	assert_float(_player.global_position.y).is_equal_approx(0.0, HEIGHT_TOLERANCE)
	assert_float(_player.global_position.z).is_less(OBSTACLE_Z - 1.0)
	assert_int(airborne_frames).is_equal(0)


func test_is_blocked_by_taller_obstacle() -> void:
	await _place(Vector3(3.0, 0.0, OBSTACLE_Z + 2.0))
	Input.action_press(&"move_forward")
	await _physics_frames(120)
	assert_float(_player.global_position.y).is_equal_approx(0.0, HEIGHT_TOLERANCE)
	assert_float(_player.global_position.z).is_greater(OBSTACLE_Z + 0.5)


func test_crouches_while_held() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"crouch_hold")
	await _physics_frames(3)
	assert_bool(_player.is_crouched).is_true()
	assert_int(_player.movement_state).is_equal(MovementRules.State.CROUCH_IDLE)
	Input.action_release(&"crouch_hold")
	await _physics_frames(3)
	assert_bool(_player.is_crouched).is_false()


func test_toggles_crouch() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	await _tap(&"crouch_toggle")
	assert_bool(_player.is_crouched).is_true()
	await _physics_frames(10)
	assert_bool(_player.is_crouched).is_true()
	await _tap(&"crouch_toggle")
	assert_bool(_player.is_crouched).is_false()


func test_crouch_walks_at_crouch_speed() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"crouch_hold")
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	assert_float(_horizontal_speed()).is_equal_approx(_player.crouch_speed, SPEED_TOLERANCE)
	assert_int(_player.movement_state).is_equal(MovementRules.State.CROUCH_WALK)


func test_sprint_stands_up_from_toggled_crouch() -> void:
	await _place(Vector3(0.0, 0.0, 12.0))
	await _tap(&"crouch_toggle")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(3)
	assert_bool(_player.is_crouched).is_false()
	assert_int(_player.movement_state).is_equal(MovementRules.State.SPRINT)
	Input.action_release(&"sprint")
	await _physics_frames(3)
	assert_int(_player.movement_state).is_equal(MovementRules.State.WALK)


func test_stays_crouched_without_headroom() -> void:
	# The crawl space runs from z = 2 to z = -2 with 1.1 m of headroom.
	await _place(Vector3(8.0, 0.0, 3.0))
	await _tap(&"crouch_toggle")
	Input.action_press(&"move_forward")
	await _physics_frames(170)
	assert_float(_player.global_position.z).is_between(-1.5, 1.5)
	await _tap(&"crouch_toggle")
	assert_bool(_player.is_crouched).is_true()
	await _physics_frames(260)
	assert_float(_player.global_position.z).is_less(-2.5)
	assert_bool(_player.is_crouched).is_false()


func test_rides_elevator_up_and_down() -> void:
	# The elevator platform starts flush with the floor and rises 4 m to the upper deck.
	var start := Vector3(-6.75, 0.0, 0.0)
	await _place(start)
	var reached_top := false
	var airborne_frames := 0
	for frame in 720:
		await _physics_frames(1)
		airborne_frames += 0 if _player.is_on_floor() else 1
		if _player.global_position.y > 3.99:
			reached_top = true
		if reached_top and _player.global_position.y < 0.01:
			break
	assert_bool(reached_top).is_true()
	assert_float(_player.global_position.y).is_equal_approx(0.0, HEIGHT_TOLERANCE)
	assert_float(Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()) \
			.is_less(0.01)
	assert_int(airborne_frames).is_equal(0)


func test_toggles_flashlight() -> void:
	await _place(Vector3(0.0, 0.0, 8.0))
	assert_bool(_player.is_flashlight_on()).is_false()
	await _tap(&"flashlight")
	assert_bool(_player.is_flashlight_on()).is_true()
	await _tap(&"flashlight")
	assert_bool(_player.is_flashlight_on()).is_false()


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _physics_frames(5)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(1)
	Input.action_release(action)
	await _physics_frames(1)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()
