extends GdUnitTestSuite
## Unit tests for the free peek's decisions. Offsets are in metres: x right, y up.

const SIDE := 0.4
const UP := 0.35
const DOWN := 0.15
const AIM_SIDE := 0.6
const AIM_UP := 0.5
const NONE := PeekRules.State.NONE
const PEEK := PeekRules.State.PEEK
const AIM_OUT := PeekRules.State.AIM_OUT


func test_clamp_to_range(offset: Vector2, expected: Vector2, test_parameters := [
	[Vector2(0.1, 0.1), Vector2(0.1, 0.1)],
	[Vector2(1.0, 0.0), Vector2(SIDE, 0.0)],
	[Vector2(-1.0, 0.0), Vector2(-SIDE, 0.0)],
	[Vector2(0.0, 1.0), Vector2(0.0, UP)],
	[Vector2(0.0, -1.0), Vector2(0.0, -DOWN)],
	# A diagonal lands on the edge of the ellipse, not in the corner of a box.
	[Vector2(SIDE, UP), Vector2(SIDE, UP) / sqrt(2.0)],
]) -> void:
	assert_vector(PeekRules.clamp_to_range(offset, SIDE, UP, DOWN)).is_equal_approx(expected, Vector2.ONE * 0.0001)


func test_is_centred(offset: Vector2, expected: bool, test_parameters := [
	[Vector2.ZERO, true],
	[Vector2(0.03, 0.0), true],
	[Vector2(0.05, 0.0), false],
	[Vector2(0.0, -0.02), false],
]) -> void:
	assert_bool(PeekRules.is_centred(offset, SIDE, UP, DOWN)).is_equal(expected)


func test_aim_out_offset(peek: Vector2, expected: Vector2, test_parameters := [
	[Vector2(0.1, 0.0), Vector2(AIM_SIDE, 0.0)],
	[Vector2(-0.4, 0.0), Vector2(-AIM_SIDE, 0.0)],
	[Vector2(0.0, 0.2), Vector2(0.0, AIM_UP)],
	# Aiming out reaches no further down than peeking.
	[Vector2(0.0, -0.1), Vector2(0.0, -DOWN)],
	[Vector2(SIDE, UP), Vector2(AIM_SIDE, AIM_UP) / sqrt(2.0)],
]) -> void:
	assert_vector(PeekRules.aim_out_offset(peek, SIDE, UP, DOWN, AIM_SIDE, AIM_UP)) \
			.is_equal_approx(expected, Vector2.ONE * 0.0001)


func test_next_state(current: PeekRules.State, peek_held: bool, aim_held: bool, centred: bool,
		expected: PeekRules.State, test_parameters := [
	[NONE, false, false, true, NONE],
	[NONE, true, false, true, PEEK],
	[PEEK, true, false, false, PEEK],
	# Peek and aim held with the head off-centre aim out, whichever was pressed first, and stay out while both are.
	[PEEK, true, true, false, AIM_OUT],
	[NONE, true, true, false, AIM_OUT],
	[AIM_OUT, true, true, false, AIM_OUT],
	[AIM_OUT, true, true, true, AIM_OUT],
	[AIM_OUT, true, false, false, PEEK],
	[AIM_OUT, false, true, false, NONE],
	# With the head still centred there is no direction to lean out in yet, so it stays a peek.
	[PEEK, true, true, true, PEEK],
	[NONE, true, true, true, PEEK],
	# Aim without peek is plain aim down sights.
	[NONE, false, true, false, NONE],
]) -> void:
	assert_int(PeekRules.next_state(current, peek_held, aim_held, centred)).is_equal(expected)


func test_tilt_degrees(offset_x: float, expected: float, test_parameters := [
	[0.0, 0.0],
	[0.2, 4.0],
	[0.4, 8.0],
	[-0.4, -8.0],
	# Aiming out further than a full peek doesn't tilt more.
	[0.6, 8.0],
]) -> void:
	assert_float(PeekRules.tilt_degrees(offset_x, SIDE, 8.0)).is_equal_approx(expected, 0.0001)
