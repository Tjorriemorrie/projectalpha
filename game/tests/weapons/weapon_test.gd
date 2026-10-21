extends GdUnitTestSuite
## Plays the laser pistol and the player's health in the greybox test scene with simulated input: shooting the
## targets, charging, the fire rate, peeking, reloading, sprinting, aiming, and a firing watcher killing the player.
## Positions refer to the layout of res://scenes/test/player_test.tscn; the targets stand in a row at z = -4 facing
## the player, who faces north (-z). The runner plays 5x fast by running more physics frames per second, so a
## physics frame is still 1/60 s of game time.

const TEST_SCENE := "res://scenes/test/player_test.tscn"
const ACTIONS: Array[StringName] = [
	&"shoot", &"aim", &"reload", &"peek", &"move_forward", &"sprint", &"crouch_hold"]
## Physics frames per second of game time at the runner's time factor.
const FRAMES_PER_SECOND := 60
## 3 m south of the centre target, looking slightly down at the middle of its plate.
const FACING_TARGET := Vector3(0.0, 0.0, -1.0)
const LOOK_AT_PLATE := -0.12
## In the open south of the targets, with room to sprint north.
const SPRINT_START := Vector3(0.0, 0.0, 12.0)
## In the open 2.5 m from WatcherCrate, in its sight.
const IN_WATCHER_SIGHT := Vector3(8.0, 0.0, 6.0)

var _runner: GdUnitSceneRunner
var _player: Player
var _weapon: Weapon
var _target: ShootingTarget
var _watchers: Array[ExposureWatcher] = []


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_player = _runner.find_child("Player") as Player
	_player.reload_on_death = false
	_weapon = _player.get_weapon()
	_weapon.rng.seed = 5
	_target = _runner.find_child("TargetCentre") as ShootingTarget
	_watchers = [_runner.find_child("WatcherCrate") as ExposureWatcher,
		_runner.find_child("WatcherPillar") as ExposureWatcher]
	for watcher in _watchers:
		watcher.fire_enabled = false


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_player_starts_armed_with_five_clips() -> void:
	assert_bool(_weapon.is_equipped()).is_true()
	assert_str(_weapon.definition.id).is_equal("base:laser_pistol")
	assert_float(_player.clips.heat).is_equal(0.0)
	# One loaded, two in the pockets and two in the backpack.
	assert_int(_player.clips.fresh).is_equal(2)
	assert_int(_player.clips.packed).is_equal(2)
	assert_int(_player.clips.spent).is_equal(0)
	assert_float(_player.get_health().health).is_equal(100.0)


func test_shot_damages_target_and_heats_clip() -> void:
	await _face_target()
	await _tap()
	assert_int(_weapon.shots_fired).is_equal(1)
	assert_float(_target.get_health().health).is_equal(75.0)
	assert_float(_player.clips.heat).is_equal_approx(0.05, 0.0001)


func test_full_charge_does_four_times_the_damage() -> void:
	await _face_target()
	Input.action_press(&"shoot")
	await _physics_frames(roundi(1.5 * FRAMES_PER_SECOND))
	assert_float(_weapon.charge).is_equal(1.0)
	Input.action_release(&"shoot")
	await _physics_frames(2)
	assert_int(_weapon.shots_fired).is_equal(1)
	assert_float(_target.get_health().health).is_equal(0.0)
	assert_float(_player.clips.heat).is_equal_approx(0.15, 0.0001)


func test_fire_rate_is_capped() -> void:
	await _face_target()
	var shot_frames: Array[int] = []
	var frame := [0]
	_weapon.fired.connect(func(_charge: float, _kick: float) -> void: shot_frames.append(frame[0]))
	for tap in 8:
		Input.action_press(&"shoot")
		for wait in 6:
			await _physics_frames(1)
			frame[0] += 1
			if wait == 1:
				Input.action_release(&"shoot")
	await _physics_frames(FRAMES_PER_SECOND)
	# Ten clicks a second for 0.8 s give at most three shots, at least a fire interval (20 frames) apart.
	assert_int(shot_frames.size()).is_between(2, 3)
	for i in range(1, shot_frames.size()):
		assert_int(shot_frames[i] - shot_frames[i - 1]).is_greater_equal(20)


func test_peek_cannot_shoot() -> void:
	await _face_target()
	# Held together with peek, aim would aim out (which can shoot), so this is a plain peek.
	Input.action_release(&"aim")
	Input.action_press(&"peek")
	await _physics_frames(2)
	_player.move_head(Vector2(1000.0, 0.0))
	await _physics_frames(5)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	await _tap()
	await _physics_frames(5)
	assert_int(_weapon.shots_fired).is_equal(0)
	assert_float(_player.clips.heat).is_equal(0.0)


func test_a_charge_is_kept_through_a_peek_and_fires_once_aimed_out() -> void:
	await _face_target()
	Input.action_press(&"shoot")
	await _physics_frames(roundi(0.5 * FRAMES_PER_SECOND))
	# With aim held, peek is a plain peek until the head moves, and a peek can't shoot: the charge waits.
	Input.action_press(&"peek")
	await _physics_frames(3)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	assert_float(_weapon.charge).is_greater(0.0)
	_player.move_head(Vector2(1000.0, 0.0))
	await _physics_frames(10)
	assert_int(_player.peek_state).is_equal(PeekRules.State.AIM_OUT)
	var charge := _weapon.charge
	assert_float(charge).is_greater(0.3)
	Input.action_release(&"shoot")
	await _physics_frames(2)
	assert_int(_weapon.shots_fired).is_equal(1)
	assert_float(_player.clips.heat).is_equal_approx(WeaponRules.shot_heat(_weapon.definition, charge), 0.02)


func test_a_charge_released_during_a_peek_is_dropped() -> void:
	await _face_target()
	Input.action_release(&"aim")
	Input.action_press(&"shoot")
	await _physics_frames(roundi(0.5 * FRAMES_PER_SECOND))
	Input.action_press(&"peek")
	await _physics_frames(3)
	assert_int(_player.peek_state).is_equal(PeekRules.State.PEEK)
	assert_float(_weapon.charge).is_greater(0.0)
	Input.action_release(&"shoot")
	await _physics_frames(3)
	assert_float(_weapon.charge).is_less(0.0)
	assert_int(_weapon.shots_fired).is_equal(0)
	assert_float(_player.clips.heat).is_equal(0.0)


func test_saturated_clip_cannot_fire() -> void:
	await _face_target()
	_player.clips.heat = 1.0
	await _tap()
	await _physics_frames(5)
	assert_int(_weapon.shots_fired).is_equal(0)


func test_reload_takes_its_time_and_swaps_the_clip() -> void:
	await _face_target()
	await _tap()
	Input.action_press(&"reload")
	await _physics_frames(2)
	Input.action_release(&"reload")
	assert_bool(_weapon.is_reloading).is_true()
	# Shooting does nothing while reloading.
	await _tap()
	assert_int(_weapon.shots_fired).is_equal(1)
	await _physics_frames(roundi(2.5 * FRAMES_PER_SECOND))
	assert_bool(_weapon.is_reloading).is_true()
	# The fresh clip left the pockets when the reload started; its cell waits for the spent one.
	assert_int(_player.clips.fresh).is_equal(1)
	assert_int(_player.clips.spent).is_equal(0)
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(_weapon.is_reloading).is_false()
	assert_int(_player.clips.fresh).is_equal(1)
	assert_int(_player.clips.packed).is_equal(2)
	assert_int(_player.clips.spent).is_equal(1)
	assert_float(_player.clips.heat).is_equal(0.0)


func test_reload_with_an_unused_clip_does_nothing() -> void:
	await _face_target()
	Input.action_press(&"reload")
	await _physics_frames(2)
	assert_bool(_weapon.is_reloading).is_false()
	assert_int(_player.clips.fresh).is_equal(2)


func test_reloading_blocks_sprint() -> void:
	await _place(SPRINT_START)
	_player.clips.heat = 0.5
	Input.action_press(&"reload")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_bool(_weapon.is_reloading).is_true()
	assert_int(_player.movement_state).is_equal(MovementRules.State.WALK)


func test_trigger_ends_sprint_and_fires_once_raised() -> void:
	await _place(SPRINT_START)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_int(_player.movement_state).is_equal(MovementRules.State.SPRINT)
	assert_float(_weapon.raise).is_equal(0.0)
	Input.action_press(&"shoot")
	await _physics_frames(1)
	assert_int(_player.movement_state).is_not_equal(MovementRules.State.SPRINT)
	# Raising takes 0.25 s (15 frames); the shot can't start charging before then.
	await _physics_frames(10)
	assert_float(_weapon.charge).is_less(0.0)
	await _physics_frames(10)
	assert_float(_weapon.raise).is_equal(1.0)
	assert_float(_weapon.charge).is_greater_equal(0.0)
	Input.action_release(&"shoot")
	await _physics_frames(2)
	assert_int(_weapon.shots_fired).is_equal(1)


func test_aiming_slows_to_crouch_speed_and_zooms() -> void:
	await _place(SPRINT_START)
	var camera := _player.get_node("Camera3D") as Camera3D
	var hip_fov := camera.fov
	Input.action_press(&"aim")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	assert_bool(_weapon.is_aiming).is_true()
	assert_float(Vector2(_player.velocity.x, _player.velocity.z).length()).is_equal_approx(_player.crouch_speed, 0.05)
	await get_tree().process_frame
	assert_float(camera.fov).is_less(hip_fov - 5.0)


func test_head_hits_do_double_damage() -> void:
	var head := _player.get_hitboxes()[Hitbox.Part.HEAD]
	head.take_hit(10.0, Vector3(0.0, 1.5, 0.0))
	assert_float(_player.get_health().health).is_equal(80.0)
	await _physics_frames(1)
	assert_str(_hud().health_text).is_equal("80")


func test_firing_watcher_damages_and_kills_the_player() -> void:
	var died := [0]
	_player.died.connect(func() -> void: died[0] += 1)
	await _place(IN_WATCHER_SIGHT)
	# Ten body hits kill, so the watcher fires quickly to get there.
	_watchers[0].fire_interval = 0.5
	_watchers[0].fire_enabled = true
	for frame in 30 * FRAMES_PER_SECOND:
		await _physics_frames(1)
		if _player.is_dead:
			break
	assert_bool(_player.is_dead).is_true()
	assert_int(died[0]).is_equal(1)
	assert_float(_player.get_health().health).is_equal(0.0)
	for hitbox in _player.get_hitboxes():
		assert_bool(hitbox.is_active()).is_false()

	# The controls stop: the body stays where it fell and the pistol doesn't fire.
	await _physics_frames(FRAMES_PER_SECOND)
	var fallen_at := _player.global_position
	Input.action_press(&"move_forward")
	await _tap()
	await _physics_frames(FRAMES_PER_SECOND)
	assert_float(_player.global_position.distance_to(fallen_at)).is_less(0.01)
	assert_int(_weapon.shots_fired).is_equal(0)


func _face_target() -> void:
	await _place(FACING_TARGET)
	_player.set_look(0.0, LOOK_AT_PLATE)
	Input.action_press(&"aim")
	await _physics_frames(10)


## A quick click (two frames, well under the charge delay), so the shot is uncharged.
func _tap() -> void:
	Input.action_press(&"shoot")
	await _physics_frames(2)
	Input.action_release(&"shoot")
	await _physics_frames(2)


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0)
	_player.reset_physics_interpolation()
	await _physics_frames(5)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _player.get_node("Hud") as Hud
