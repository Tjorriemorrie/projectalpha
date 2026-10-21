extends GdUnitTestSuite
## Plays the turret in the robot test level: lock-on times, peeking, firing and how its fire walks in, venting, a
## charged shot to the eye, the wreckage and the salvage pried out of it, the combat music, and seeing in the dark. The drone is taken out so it
## can't interfere.
## Positions refer to the layout of res://scenes/test/robot_test.tscn: the turret hangs from the hall's ceiling at
## (0, 3, -5.5), facing south down the lit hall towards the door at (0, 0, 2), clear of the pillar in the middle of
## the hall; the entrance stub south of the corridor is dark and out of its sight.

const TEST_SCENE := "res://scenes/test/robot_test.tscn"
const ACTIONS: Array[StringName] = [&"shoot", &"aim", &"flashlight", &"interact"]
## Physics frames per second of game time at the runner's time factor.
const FRAMES_PER_SECOND := 60
## In the lit hall under a lamp, 5.5 m in front of the turret.
const IN_SIGHT := Vector3(0.0, 0.0, 0.0)
## Under the turret's nose, 2 m in front of it, so a shot at its eye can't miss.
const UNDER_THE_TURRET := Vector3(0.0, 0.0, -3.5)
## In the dark entrance stub behind the closed door.
const OUT_OF_SIGHT := Vector3(0.0, 0.0, 8.0)
## Almost under the turret, within reach of its wreckage.
const BELOW_THE_TURRET := Vector3(0.0, 0.0, -4.7)

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _turret: Turret


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	_player.reload_on_death = false
	for robot in _wreck.robots:
		if robot is Turret:
			_turret = robot
		else:
			robot.queue_free()
	_turret.rng.seed = 3
	_player.get_weapon().rng.seed = 3
	_steady_lamps()
	await _physics_frames(2)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_turret_hangs_from_its_mount_facing_its_arc() -> void:
	assert_vector(_turret.global_position).is_equal_approx(Vector3(0.0, 3.0, -5.5), Vector3.ONE * 0.01)
	assert_vector(-_turret.global_basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.01)
	assert_int(_turret.mind.state).is_equal(RobotMind.State.IDLE)
	assert_float(_turret.get_health().health).is_equal(200.0)


func test_idle_turret_locks_on_in_about_0_8_seconds() -> void:
	await _place(IN_SIGHT)
	var frames := await _frames_until_attacking(2 * FRAMES_PER_SECOND)
	assert_int(frames).is_between(roundi(0.8 * FRAMES_PER_SECOND) - 6, roundi(0.8 * FRAMES_PER_SECOND) + 6)


func test_alert_turret_locks_on_in_about_0_4_seconds() -> void:
	Hearing.make_noise(_player, IN_SIGHT, 20.0, &"test")
	assert_int(_turret.mind.state).is_equal(RobotMind.State.INVESTIGATING)
	await _physics_frames(FRAMES_PER_SECOND)
	await _place(IN_SIGHT)
	var frames := await _frames_until_attacking(2 * FRAMES_PER_SECOND)
	assert_int(frames).is_between(roundi(0.4 * FRAMES_PER_SECOND) - 6, roundi(0.4 * FRAMES_PER_SECOND) + 6)


func test_quick_peek_isnt_shot_but_makes_it_investigate() -> void:
	await _place(IN_SIGHT)
	await _physics_frames(roundi(0.3 * FRAMES_PER_SECOND))
	assert_bool(_turret.mind.is_locking).is_true()
	await _place(OUT_OF_SIGHT)
	await _physics_frames(FRAMES_PER_SECOND)
	assert_int(_turret.mind.state).is_equal(RobotMind.State.INVESTIGATING)
	assert_int(_turret.shots_fired).is_equal(0)
	assert_float(_player.get_health().health).is_equal(100.0)
	assert_float(Vector2(_turret.mind.focus.x, _turret.mind.focus.z).distance_to(Vector2(IN_SIGHT.x, IN_SIGHT.z))) \
		.is_less(1.0)


func test_locked_turret_fires_and_hits_the_player() -> void:
	await _place(IN_SIGHT)
	await _physics_frames(5 * FRAMES_PER_SECOND)
	assert_int(_turret.shots_fired).is_greater(0)
	assert_float(_player.get_health().health).is_less(100.0)


func test_fire_walks_in_and_starts_wide_again_after_losing_sight() -> void:
	_make_player_tough()
	await _place(IN_SIGHT)
	await _frames_until_attacking(2 * FRAMES_PER_SECOND)
	var definition := _turret.definition
	assert_float(_turret.aim_spread()).is_greater(definition.initial_spread - 1.0)
	await _physics_frames(roundi((definition.settle_time + 0.2) * FRAMES_PER_SECOND))
	assert_float(_turret.aim_spread()).is_equal_approx(definition.spread, 0.01)
	await _place(OUT_OF_SIGHT)
	await _physics_frames(FRAMES_PER_SECOND)
	assert_float(_turret.aim_spread()).is_equal(definition.initial_spread)


func test_turret_vents_after_six_shots_in_a_row() -> void:
	_make_player_tough()
	var shots_at_vent := [-1]
	_turret.vent_started.connect(func() -> void: shots_at_vent[0] = _turret.shots_fired)
	await _place(IN_SIGHT)
	await _physics_frames(3 * FRAMES_PER_SECOND)
	assert_int(shots_at_vent[0]).is_equal(6)
	# It holds its fire while it vents, then fires again.
	await _physics_frames(3 * FRAMES_PER_SECOND)
	assert_int(_turret.shots_fired).is_greater(6)


func test_charged_shot_to_the_eye_destroys_it() -> void:
	_make_player_tough()
	await _place(UNDER_THE_TURRET)
	# Let it lock on and turn to the player, so its eye holds still for the shot.
	await _physics_frames(2 * FRAMES_PER_SECOND)
	_look_at(_turret.get_node("%Ring/Head/Hitboxes/Eye").global_position)
	Input.action_press(&"aim")
	Input.action_press(&"shoot")
	await _physics_frames(roundi(1.4 * FRAMES_PER_SECOND))
	Input.action_release(&"shoot")
	await _physics_frames(5)
	assert_bool(_turret.is_destroyed()).is_true()
	assert_float(_turret.get_health().health).is_equal(0.0)


func test_destroyed_turret_stays_as_wreckage() -> void:
	var destroyed := [0]
	_turret.destroyed.connect(func() -> void: destroyed[0] += 1)
	_turret.get_health().take_damage(500.0, IN_SIGHT)
	await _place(IN_SIGHT)
	await _physics_frames(3 * FRAMES_PER_SECOND)
	assert_int(destroyed[0]).is_equal(1)
	assert_bool(is_instance_valid(_turret) and _turret.is_inside_tree()).is_true()
	assert_int(_turret.mind.state).is_equal(RobotMind.State.DESTROYED)
	assert_int(_turret.collision_layer).is_equal(Robot.WORLD_LAYER)
	assert_bool(_turret.get_node("%Searchlight").visible).is_false()
	for hitbox in _turret.get_hitboxes():
		assert_bool(hitbox.is_active()).is_false()
	assert_int(_turret.shots_fired).is_equal(0)
	assert_float(_player.get_health().health).is_equal(100.0)


func test_wreckage_can_be_pried_open_for_its_salvage() -> void:
	_turret.get_health().take_damage(500.0, IN_SIGHT)
	await _place(BELOW_THE_TURRET)
	await _physics_frames(2 * FRAMES_PER_SECOND)
	var salvage := _turret.get_salvage()
	assert_object(salvage).is_not_null()
	_look_at(salvage.global_position + _turret.salvage_offset)
	await _physics_frames(3)
	assert_object(_player.interact_target).is_same(salvage)
	assert_str((_player.get_node("Hud") as Hud).prompt_text).is_equal("Hold E Pry open ceiling turret wreckage")
	Input.action_press(&"interact")
	await _physics_frames(roundi(1.6 * FRAMES_PER_SECOND))
	assert_bool(salvage.is_open).is_true()
	assert_object(_player.get_inventory_screen().loot).is_same(salvage)
	var parts := salvage.grid.items.map(func(item: Item) -> String: return item.definition.id)
	assert_array(parts).contains_exactly_in_any_order(["base:plasma_coil", "base:circuit_board"])


func test_combat_music_plays_only_while_it_attacks() -> void:
	_make_player_tough()
	var music := _player.get_node("CombatMusic") as CombatMusic
	await _place(IN_SIGHT)
	await _physics_frames(roundi(0.5 * FRAMES_PER_SECOND))
	# Locking on isn't combat yet.
	assert_bool(music.is_combat).is_false()
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(music.is_combat).is_true()
	assert_bool(music.playing).is_true()
	await _place(OUT_OF_SIGHT)
	await _physics_frames(2 * FRAMES_PER_SECOND)
	assert_int(_turret.mind.state).is_equal(RobotMind.State.SEARCHING)
	assert_bool(music.is_combat).is_true()
	await _physics_frames(4 * FRAMES_PER_SECOND)
	assert_bool(music.is_combat).is_false()


func test_unlit_player_is_only_seen_up_close() -> void:
	for light in _runner.scene().get_tree().get_nodes_in_group(LightLevel.GROUP):
		(light as Light3D).visible = false
	await _place(IN_SIGHT)
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(_turret.mind.sees_player).is_false()
	assert_int(_turret.mind.state).is_equal(RobotMind.State.IDLE)
	# Up close the dark doesn't hide the player, once its sweep comes round to them.
	await _place(UNDER_THE_TURRET)
	assert_int(await _frames_until_seen(6 * FRAMES_PER_SECOND)).is_less(6 * FRAMES_PER_SECOND)


func test_flashlight_shows_the_player_at_full_range() -> void:
	for light in _runner.scene().get_tree().get_nodes_in_group(LightLevel.GROUP):
		(light as Light3D).visible = false
	await _place(IN_SIGHT)
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(_turret.mind.sees_player).is_false()
	_player.set_flashlight(true)
	assert_int(await _frames_until_seen(6 * FRAMES_PER_SECOND)).is_less(6 * FRAMES_PER_SECOND)


## Counts physics frames until the turret attacks, up to limit; returns limit when it never does.
func _frames_until_attacking(limit: int) -> int:
	for frame in limit:
		await get_tree().physics_frame
		if _turret.mind.is_attacking():
			return frame + 1
	return limit


## Counts physics frames until the turret sees the player, up to limit; returns limit when it never does.
func _frames_until_seen(limit: int) -> int:
	for frame in limit:
		await get_tree().physics_frame
		if _turret.mind.sees_player:
			return frame + 1
	return limit


## Enough health to take a whole burst, so a test can watch the turret fire on.
func _make_player_tough() -> void:
	_player.get_health().max_health = 100000.0
	_player.get_health().reset()


## Points the player's view at a point.
func _look_at(point: Vector3) -> void:
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, point)
	_player.set_look(angles.x, angles.y)


## Flickering lamps would make the light level, and so the turret's sight, change from frame to frame.
func _steady_lamps() -> void:
	for lamp in _runner.scene().find_children("*", "CeilingLamp", true, false):
		lamp.set_process(false)


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0)
	_player.reset_physics_interpolation()
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
