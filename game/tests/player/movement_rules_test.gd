extends GdUnitTestSuite
## Unit tests for the player's movement decisions.

const FORWARD := Vector2(0.0, -1.0)
const BACK := Vector2(0.0, 1.0)
const RIGHT := Vector2(1.0, 0.0)
const FORWARD_RIGHT := Vector2(0.7071, -0.7071)
const BACK_RIGHT := Vector2(0.7071, 0.7071)


func test_wants_sprint(input_dir: Vector2, sprint_held: bool, expected: bool, test_parameters := [
	[FORWARD, true, true],
	[FORWARD_RIGHT, true, true],
	[RIGHT, true, false],
	[BACK, true, false],
	[BACK_RIGHT, true, false],
	[Vector2.ZERO, true, false],
	[FORWARD, false, false],
]) -> void:
	assert_bool(MovementRules.wants_sprint(input_dir, sprint_held)).is_equal(expected)


func test_next_crouch_toggle(toggled: bool, toggle_pressed: bool, sprint_wanted: bool, expected: bool,
		test_parameters := [
	[false, true, false, true],
	[true, true, false, false],
	[true, false, false, true],
	[false, false, false, false],
	[true, false, true, false],
	[false, true, true, false],
]) -> void:
	assert_bool(MovementRules.next_crouch_toggle(toggled, toggle_pressed, sprint_wanted)).is_equal(expected)


func test_wants_crouch(crouch_held: bool, crouch_toggled: bool, sprint_wanted: bool, expected: bool,
		test_parameters := [
	[true, false, false, true],
	[false, true, false, true],
	[true, true, false, true],
	[false, false, false, false],
	[true, false, true, false],
	[false, true, true, false],
]) -> void:
	assert_bool(MovementRules.wants_crouch(crouch_held, crouch_toggled, sprint_wanted)).is_equal(expected)


func test_resolve_state(input_dir: Vector2, sprint_wanted: bool, crouched: bool, expected: MovementRules.State,
		test_parameters := [
	[Vector2.ZERO, false, false, MovementRules.State.IDLE],
	[Vector2.ZERO, true, false, MovementRules.State.IDLE],
	[FORWARD, false, false, MovementRules.State.WALK],
	[FORWARD, true, false, MovementRules.State.SPRINT],
	[Vector2.ZERO, false, true, MovementRules.State.CROUCH_IDLE],
	[RIGHT, false, true, MovementRules.State.CROUCH_WALK],
	[FORWARD, true, true, MovementRules.State.CROUCH_WALK],
]) -> void:
	assert_int(MovementRules.resolve_state(input_dir, sprint_wanted, crouched)).is_equal(expected)


func test_speed_for_state(state: MovementRules.State, expected: float, test_parameters := [
	[MovementRules.State.IDLE, 3.0],
	[MovementRules.State.WALK, 3.0],
	[MovementRules.State.SPRINT, 5.5],
	[MovementRules.State.CROUCH_IDLE, 1.5],
	[MovementRules.State.CROUCH_WALK, 1.5],
]) -> void:
	assert_float(MovementRules.speed_for_state(state, 3.0, 5.5, 1.5)).is_equal(expected)


func test_peeking_blocks_sprint() -> void:
	assert_bool(MovementRules.wants_sprint(FORWARD, true, true)).is_false()
	assert_bool(MovementRules.wants_sprint(FORWARD, true, false)).is_true()


func test_peeking_caps_speed_at_crouch_speed(state: MovementRules.State, test_parameters := [
	[MovementRules.State.WALK],
	[MovementRules.State.SPRINT],
	[MovementRules.State.CROUCH_WALK],
]) -> void:
	assert_float(MovementRules.speed_for_state(state, 1.5, 3.0, 1.0, true)).is_equal(1.0)
