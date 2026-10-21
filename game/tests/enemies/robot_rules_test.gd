extends GdUnitTestSuite
## Unit tests for RobotRules: the view cone and range, the sight range in the dark, how fire walks in, and how a
## turret aims and turns.

const TOLERANCE := 0.001

var _definition: EnemyDefinition


func before_test() -> void:
	_definition = EnemyDefinition.new()
	_definition.sight_range = 15.0
	_definition.sight_angle = 90.0
	_definition.dark_sight_range = 5.0


func test_in_view(point: Vector3, expected: bool, test_parameters := [
	# Straight ahead within range, and just out of it.
	[Vector3(0.0, 0.0, -14.0), true],
	[Vector3(0.0, 0.0, -16.0), false],
	# 40° off to the side is inside a 90° cone, 50° isn't.
	[Vector3(-sin(deg_to_rad(40.0)), 0.0, -cos(deg_to_rad(40.0))) * 5.0, true],
	[Vector3(sin(deg_to_rad(50.0)), 0.0, -cos(deg_to_rad(50.0))) * 5.0, false],
	# Behind.
	[Vector3(0.0, 0.0, 3.0), false],
]) -> void:
	assert_bool(RobotRules.in_view(Vector3.ZERO, Vector3.FORWARD, point, 15.0, 90.0)).is_equal(expected)


func test_sight_range_in_the_dark() -> void:
	assert_float(RobotRules.sight_range_for(_definition, true)).is_equal(15.0)
	assert_float(RobotRules.sight_range_for(_definition, false)).is_equal(5.0)


func test_fire_walks_in(aim_time: float, expected: float, test_parameters := [
	# Wide right after locking on, tightening over the settle time, then holding.
	[0.0, 12.0],
	[1.0, 8.0],
	[2.0, 4.0],
	[5.0, 4.0],
]) -> void:
	_definition.initial_spread = 12.0
	_definition.spread = 4.0
	_definition.settle_time = 2.0
	assert_float(RobotRules.aim_spread(_definition, aim_time)).is_equal_approx(expected, TOLERANCE)


func test_aim_angles(target: Vector3, yaw_degrees: float, pitch_degrees: float, test_parameters := [
	[Vector3(0.0, 0.0, -5.0), 0.0, 0.0],
	# Positive yaw turns left, positive pitch looks up.
	[Vector3(-5.0, 0.0, 0.0), 90.0, 0.0],
	[Vector3(5.0, 0.0, 0.0), -90.0, 0.0],
	[Vector3(0.0, -5.0, -5.0), 0.0, -45.0],
]) -> void:
	var angles := RobotRules.aim_angles(Basis.IDENTITY, Vector3.ZERO, target)
	assert_float(rad_to_deg(angles.x)).is_equal_approx(yaw_degrees, TOLERANCE)
	assert_float(rad_to_deg(angles.y)).is_equal_approx(pitch_degrees, TOLERANCE)


func test_aim_angles_follow_the_frame() -> void:
	# A turret turned to face east (+X) aims straight ahead at a target in the east.
	var facing_east := Basis(Vector3.UP, deg_to_rad(-90.0))
	var angles := RobotRules.aim_angles(facing_east, Vector3.ZERO, Vector3(5.0, 0.0, 0.0))
	assert_float(angles.x).is_equal_approx(0.0, TOLERANCE)


func test_arc_keeps_the_yaw_inside(yaw_degrees: float, arc: float, expected: float, test_parameters := [
	[30.0, 180.0, 30.0],
	[120.0, 180.0, 90.0],
	[-120.0, 180.0, -90.0],
	[170.0, 360.0, 170.0],
]) -> void:
	assert_float(rad_to_deg(RobotRules.clamp_to_arc(deg_to_rad(yaw_degrees), arc))).is_equal_approx(
		expected, TOLERANCE)


func test_turning_is_limited_per_step() -> void:
	var step := deg_to_rad(10.0)
	assert_float(rad_to_deg(RobotRules.turn_towards(0.0, deg_to_rad(45.0), step))).is_equal_approx(10.0, TOLERANCE)
	assert_float(rad_to_deg(RobotRules.turn_towards(0.0, deg_to_rad(5.0), step))).is_equal_approx(5.0, TOLERANCE)


func test_turning_the_short_way_round_or_not() -> void:
	var from := deg_to_rad(170.0)
	var to := deg_to_rad(-170.0)
	var step := deg_to_rad(10.0)
	# Wrapping crosses behind (170° on to 180°); a turret with a limited arc turns back the long way instead.
	assert_float(rad_to_deg(RobotRules.turn_towards(from, to, step))).is_equal_approx(180.0, TOLERANCE)
	assert_float(rad_to_deg(RobotRules.turn_towards(from, to, step, false))).is_equal_approx(160.0, TOLERANCE)
