extends GdUnitTestSuite
## Plays the security drone in the robot test level: patrolling, flying to noises (through an automatic door, and as
## close as it can get to one it can't reach), keeping its fighting distance, noticing a bump, and falling when
## destroyed. The turret is taken out so it can't interfere.
## Positions refer to the layout of res://scenes/test/robot_test.tscn: the drone's post is in the lit hall at
## (4, 0, -4); the hall spans x -2..6 and z -6..2, its door at (0, 0, 2) opens south into a corridor, and a vent in
## its east wall leads to a closet at (12, 0, 0) that only the player fits through.

const TEST_SCENE := "res://scenes/test/robot_test.tscn"
## Physics frames per second of game time at the runner's time factor.
const FRAMES_PER_SECOND := 60
const POST := Vector3(4.0, 0.0, -4.0)
## In the hall's south-west corner, by the door.
const BY_THE_DOOR := Vector3(-1.0, 0.0, 1.0)
## In the corridor south of the hall's door.
const IN_THE_CORRIDOR := Vector3(0.0, 0.0, 4.5)
const IN_THE_CLOSET := Vector3(12.0, 0.0, 0.0)

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _drone: Drone


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	_player.reload_on_death = false
	for robot in _wreck.robots:
		if robot is Drone:
			_drone = robot
		else:
			robot.queue_free()
	_drone.rng.seed = 3
	for lamp in _wreck.find_children("*", "CeilingLamp", true, false):
		lamp.set_process(false)
	await _physics_frames(2)


func test_drone_rises_from_its_post_to_hover() -> void:
	assert_vector(_drone.post).is_equal_approx(POST, Vector3.ONE * 0.01)
	assert_float(_drone.global_position.y).is_equal_approx(_drone.hover_height, 0.05)
	assert_float(_drone.get_health().health).is_equal(75.0)


func test_drone_patrols_around_its_post() -> void:
	_hide_player()
	var furthest := 0.0
	for second in 12:
		await _physics_frames(FRAMES_PER_SECOND)
		furthest = maxf(furthest, _flat_distance(_drone.global_position, POST))
	assert_float(furthest).is_greater(1.5)
	assert_float(furthest).is_less_equal(_drone.patrol_radius + 1.0)
	assert_int(_drone.mind.state).is_equal(RobotMind.State.IDLE)
	assert_float(_drone.global_position.y).is_equal_approx(_drone.hover_height, 0.1)


func test_drone_flies_to_a_noise() -> void:
	_hide_player()
	Hearing.make_noise(_player, BY_THE_DOOR, 20.0, &"test")
	assert_int(_drone.mind.state).is_equal(RobotMind.State.INVESTIGATING)
	var closest := await _closest_approach(BY_THE_DOOR, 8)
	assert_float(closest).is_less(1.0)


func test_drone_passes_an_automatic_door() -> void:
	_hide_player()
	Hearing.make_noise(_player, IN_THE_CORRIDOR, 20.0, &"test")
	var closest := await _closest_approach(IN_THE_CORRIDOR, 10)
	assert_float(closest).is_less(1.0)


func test_noise_it_cant_reach_draws_it_as_close_as_it_can_get() -> void:
	_hide_player()
	Hearing.make_noise(_player, IN_THE_CLOSET, 20.0, &"test")
	var furthest_east := -INF
	for second in 8:
		await _physics_frames(FRAMES_PER_SECOND)
		furthest_east = maxf(furthest_east, _drone.global_position.x)
	# It comes to the hall's east wall, where the vent is, but never into the vent.
	assert_float(furthest_east).is_greater(4.5)
	assert_float(furthest_east).is_less(6.0)


func test_drone_keeps_its_fighting_distance() -> void:
	_player.get_health().max_health = 100000.0
	_player.get_health().reset()
	await _place(BY_THE_DOOR)
	Hearing.make_noise(_player, BY_THE_DOOR, 20.0, &"test")
	await _physics_frames(4 * FRAMES_PER_SECOND)
	assert_bool(_drone.mind.is_attacking()).is_true()
	var closest := INF
	for frame in 4 * FRAMES_PER_SECOND:
		await get_tree().physics_frame
		closest = minf(closest, _flat_distance(_drone.global_position, _player.global_position))
	assert_float(closest).is_greater(_drone.fighting_distance.x - 1.0)
	assert_int(_drone.shots_fired).is_greater(0)
	assert_float(_player.get_health().health).is_less(100000.0)


func test_bumping_into_it_from_behind_alerts_it() -> void:
	# It faces north at its post; the player walks into its back.
	await _place(POST + Vector3(0.0, 0.0, 0.5))
	await _physics_frames(5)
	assert_int(_drone.mind.state).is_equal(RobotMind.State.INVESTIGATING)


func test_destroyed_drone_drops_to_the_floor_and_stays() -> void:
	_hide_player()
	_drone.get_health().take_damage(500.0, BY_THE_DOOR)
	await _physics_frames(3 * FRAMES_PER_SECOND)
	assert_bool(_drone.is_destroyed()).is_true()
	assert_bool(_drone.is_inside_tree()).is_true()
	# It rests on the floor: its body sits a little above it, and it didn't fall through.
	assert_float(_drone.global_position.y).is_between(0.0, 0.5)
	assert_int(_drone.collision_layer).is_equal(Robot.WORLD_LAYER)
	for hitbox in _drone.get_hitboxes():
		assert_bool(hitbox.is_active()).is_false()


## Puts the player where no robot can see them: their hitboxes are what robots look for.
func _hide_player() -> void:
	for hitbox in _player.get_hitboxes():
		hitbox.set_active(false)


## The closest the drone gets to target, flat, over seconds of game time.
func _closest_approach(target: Vector3, seconds: int) -> float:
	var closest := INF
	for frame in seconds * FRAMES_PER_SECOND:
		await get_tree().physics_frame
		closest = minf(closest, _flat_distance(_drone.global_position, target))
	return closest


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0)
	_player.reset_physics_interpolation()
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
