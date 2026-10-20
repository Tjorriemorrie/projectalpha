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


func test_next_state(current: PeekRules.State, peek_held: bool, aim_held: bool, aim_pressed: bool, centred: bool,
		expected: PeekRules.State, test_parameters := [
	[NONE, false, false, false, true, NONE],
	[NONE, true, false, false, true, PEEK],
	[PEEK, true, false, false, false, PEEK],
	# Aim pressed off-centre while peeking aims out, and stays out while aim is held.
	[PEEK, true, true, true, false, AIM_OUT],
	[AIM_OUT, true, true, false, false, AIM_OUT],
	[AIM_OUT, true, false, false, false, PEEK],
	[AIM_OUT, false, true, false, false, NONE],
	# Aim pressed while centred, or held from before the peek moved, stays plain aim down sights.
	[PEEK, true, true, true, true, PEEK],
	[PEEK, true, true, false, false, PEEK],
	# Aim without peek is plain aim down sights.
	[NONE, false, true, true, false, NONE],
]) -> void:
	assert_int(PeekRules.next_state(current, peek_held, aim_held, aim_pressed, centred)).is_equal(expected)


func test_tilt_degrees(offset_x: float, expected: float, test_parameters := [
	[0.0, 0.0],
	[0.2, 4.0],
	[0.4, 8.0],
	[-0.4, -8.0],
	# Aiming out further than a full peek doesn't tilt more.
	[0.6, 8.0],
]) -> void:
	assert_float(PeekRules.tilt_degrees(offset_x, SIDE, 8.0)).is_equal_approx(expected, 0.0001)
