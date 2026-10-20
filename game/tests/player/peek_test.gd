extends GdUnitTestSuite
## Plays the free peek in the cover area of the greybox test scene (its south-east corner) with simulated keys and
## mouse motion, and checks where the head goes and what the debug watchers can see.
## Positions refer to the layout of res://scenes/test/player_test.tscn; the player faces north (-z), so right is +x.

const TEST_SCENE := "res://scenes/test/player_test.tscn"
const ACTIONS: Array[StringName] = [
	&"peek", &"aim", &"move_forward", &"move_left", &"move_right", &"sprint", &"crouch_hold"]
## Crouched south of the 1 m crate, pressed against it. WatcherCrate stands north of the crate.
const BEHIND_CRATE := Vector3(10.0, 0.0, 10.75)
## Standing west of the pillar, 0.05 m from its side.
const BESIDE_PILLAR := Vector3(12.25, 0.0, 10.0)
## In the open, away from cover and watchers.
const OPEN := Vector3(0.0, 0.0, 8.0)
## Mouse motion that moves the head well past the edge of its range.
const FAR := 1000.0
const OFFSET_TOLERANCE := 0.01
const SPEED_TOLERANCE := 0.05

var _runner: GdUnitSceneRunner
var _player: Player
var _crate_watcher: ExposureWatcher
var _pillar_watcher: ExposureWatcher


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_player = _runner.find_child("Player") as Player
	_crate_watcher = _runner.find_child("WatcherCrate") as ExposureWatcher
	_pillar_watcher = _runner.find_child("WatcherPillar") as ExposureWatcher
	# The watchers only watch here; weapon_test.gd covers them firing.
	_crate_watcher.fire_enabled = false
	_pillar_watcher.fire_enabled = false


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_peek_moves_head_and_keeps_view() -> void:
	await _place(OPEN)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(20)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	assert_vector(_player.head_offset).is_equal_approx(Vector2(_player.peek_side_reach, 0.0), _tolerance())
	assert_float(_player.rotation.y).is_equal_approx(0.0, 0.0001)
	Input.action_release(&"peek")
	await _physics_frames(20)
	assert_int(_player.peek_state).is_equal(PeekRules.State.NONE)
	assert_vector(_player.head_offset).is_equal(Vector2.ZERO)


func test_peek_reaches_up_and_down() -> void:
	await _place(OPEN)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(0.0, -FAR))
	await _physics_frames(20)
	assert_vector(_player.head_offset).is_equal_approx(Vector2(0.0, _player.peek_up_reach), _tolerance())
	_player.move_head(Vector2(0.0, 2.0 * FAR))
	await _physics_frames(20)
	assert_vector(_player.head_offset).is_equal_approx(Vector2(0.0, -_player.peek_down_reach), _tolerance())


func test_view_tilts_towards_lean() -> void:
	await _place(OPEN)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(20)
	await get_tree().process_frame
	var roll := rad_to_deg((_player.get_node("Camera3D") as Camera3D).global_basis.get_euler().z)
	assert_float(roll).is_equal_approx(-_player.peek_tilt, 0.1)


func test_head_stops_at_wall() -> void:
	await _place(BESIDE_PILLAR)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(20)
	# The pillar is 0.35 m from the eyes and the head is 0.15 m across, so it stops 0.2 m out.
	assert_float(_player.head_offset.x).is_between(0.15, 0.21)


func test_peeking_slows_to_crouch_speed_and_blocks_sprint() -> void:
	await _place(Vector3(0.0, 0.0, 12.0))
	Input.action_press(&"peek")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_float(_horizontal_speed()).is_equal_approx(_player.crouch_speed, SPEED_TOLERANCE)
	assert_int(_player.movement_state).is_not_equal(MovementRules.State.SPRINT)


func test_aim_without_peek_stays_plain() -> void:
	await _place(OPEN)
	Input.action_press(&"aim")
	await _physics_frames(5)
	assert_int(_player.peek_state).is_equal(PeekRules.State.NONE)
	assert_bool(_arm().is_active()).is_false()


func test_aim_while_centred_stays_a_peek() -> void:
	await _place(OPEN)
	Input.action_press(&"peek")
	await _physics_frames(2)
	Input.action_press(&"aim")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(20)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	assert_bool(_arm().is_active()).is_false()


func test_aim_out_pushes_further_and_releases_back_to_peek() -> void:
	await _place(OPEN)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(20)
	Input.action_press(&"aim")
	await _physics_frames(20)
	assert_int(_player.peek_state).is_equal(PeekRules.State.AIM_OUT)
	assert_vector(_player.head_offset).is_equal_approx(Vector2(_player.aim_out_side_reach, 0.0), _tolerance())
	assert_bool(_arm().is_active()).is_true()
	Input.action_release(&"aim")
	await _physics_frames(20)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	assert_vector(_player.head_offset).is_equal_approx(Vector2(_player.peek_side_reach, 0.0), _tolerance())
	assert_bool(_arm().is_active()).is_false()


func test_emits_peek_state_changes() -> void:
	await _place(OPEN)
	var changes: Array = []
	_player.peek_state_changed.connect(func(previous, current): changes.append([previous, current]))
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(FAR, 0.0))
	await _physics_frames(5)
	Input.action_press(&"aim")
	await _physics_frames(2)
	Input.action_release(&"peek")
	await _physics_frames(2)
	assert_array(changes).contains_exactly([
		[PeekRules.State.NONE, PeekRules.State.PEEK],
		[PeekRules.State.PEEK, PeekRules.State.AIM_OUT],
		[PeekRules.State.AIM_OUT, PeekRules.State.NONE],
	])


func test_watcher_sees_head_when_peeking_and_arm_when_aiming_out() -> void:
	Input.action_press(&"crouch_hold")
	await _place(BEHIND_CRATE)
	await _physics_frames(20)
	assert_array(_crate_watcher.seen_parts).is_empty()

	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(0.0, -FAR))
	await _physics_frames(20)
	assert_array(_crate_watcher.seen_parts).contains_exactly([Hitbox.Part.HEAD])

	Input.action_press(&"aim")
	await _physics_frames(20)
	assert_array(_crate_watcher.seen_parts).contains_exactly([Hitbox.Part.HEAD, Hitbox.Part.ARM])

	Input.action_release(&"aim")
	await _physics_frames(20)
	assert_array(_crate_watcher.seen_parts).contains_exactly([Hitbox.Part.HEAD])

	Input.action_release(&"peek")
	await _physics_frames(20)
	assert_array(_crate_watcher.seen_parts).is_empty()


## Aiming out and strafing slowly into the doorway ("slicing the pie") must never let the player see a watcher
## that can't see the player, or the player could shoot around corners unseen.
func test_slicing_the_pie_never_sees_a_watcher_unseen(start: Vector3, head_motion: Vector2, move: String,
		stop_x: float, test_parameters := [
	# Leaning right round the doorframe's west edge, and left round its east edge.
	[Vector3(8.2, 0.0, 13.2), Vector2(FAR, 0.0), "move_right", 10.0],
	[Vector3(11.8, 0.0, 13.2), Vector2(-FAR, 0.0), "move_left", 10.0],
]) -> void:
	await _place(start)
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(head_motion)
	await _physics_frames(20)
	Input.action_press(&"aim")
	await _physics_frames(20)
	Input.action_press(move)
	var saw_a_watcher := false
	var unseen_sightings: Array[String] = []
	for frame in 240:
		await _physics_frames(1)
		for watcher in [_crate_watcher, _pillar_watcher]:
			var sees_watcher := _player_sees(watcher)
			saw_a_watcher = saw_a_watcher or sees_watcher
			if sees_watcher and watcher.seen_parts.is_empty():
				unseen_sightings.append("%s at x=%.2f" % [watcher.name, _player.global_position.x])
		var x := _player.global_position.x
		var through_doorway := x > stop_x if move == "move_right" else x < stop_x
		if through_doorway:
			break
	Input.action_release(move)
	assert_bool(saw_a_watcher).is_true()
	assert_array(unseen_sightings).is_empty()


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0)
	_player.reset_physics_interpolation()
	await _physics_frames(5)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


## Whether the player's eye, at the centre of the head hitbox, has a clear line to the watcher's eye.
func _player_sees(watcher: ExposureWatcher) -> bool:
	var eye := _player.get_hitboxes()[Hitbox.Part.HEAD].global_position
	var watcher_eye := (watcher.get_node("Eye") as Node3D).global_position
	var query := PhysicsRayQueryParameters3D.create(eye, watcher_eye, ExposureWatcher.SIGHT_MASK)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _arm() -> Hitbox:
	return _player.get_hitboxes()[Hitbox.Part.ARM]


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _tolerance() -> Vector2:
	return Vector2.ONE * OFFSET_TOLERANCE
