extends GdUnitTestSuite
## Unit tests for the wreck kit's joining rules and assembly checks.

const CORRIDOR := Socket.Kind.CORRIDOR
const VENT := Socket.Kind.VENT
const WALL := Socket.Kind.WALL
const NONE := Socket.Opening.NONE
const DOORWAY := Socket.Opening.DOORWAY
const VENT_MOUTH := Socket.Opening.VENT_MOUTH
## The edge between cell (0, 0) and cell (1, 0).
const EDGE := Vector3(2.0, 0.0, 0.0)


func test_openings_for(kind_a: Socket.Kind, accepts_a: bool, kind_b: Socket.Kind, accepts_b: bool, expected: Array,
		test_parameters := [
	[CORRIDOR, true, CORRIDOR, true, [NONE, NONE]],
	[VENT, true, VENT, true, [NONE, NONE]],
	[CORRIDOR, true, WALL, true, [NONE, DOORWAY]],
	[WALL, true, CORRIDOR, true, [DOORWAY, NONE]],
	[VENT, true, WALL, true, [NONE, VENT_MOUTH]],
	[WALL, false, VENT, true, [VENT_MOUTH, NONE]],
	[CORRIDOR, true, WALL, false, []],
	[CORRIDOR, true, VENT, true, []],
	[WALL, true, WALL, true, []],
]) -> void:
	var a := WreckAssembly.SocketInfo.new("a", EDGE, Vector3.RIGHT, kind_a, accepts_a)
	var b := WreckAssembly.SocketInfo.new("b", EDGE, Vector3.LEFT, kind_b, accepts_b)
	assert_array(WreckAssembly.openings_for(a, b)).is_equal(expected)


func test_joins_sockets_that_face_each_other() -> void:
	var plan := _plan([_socket("a", EDGE, Vector3.RIGHT, CORRIDOR), _socket("b", EDGE, Vector3.LEFT, WALL)])
	assert_array(plan.errors).is_empty()
	assert_int(plan.joins).is_equal(1)
	assert_array(Array(plan.partners)).is_equal([1, 0])
	assert_array(plan.openings).is_equal([NONE, DOORWAY])


func test_closes_walls_that_nothing_joins() -> void:
	var plan := _plan([_socket("wall", EDGE, Vector3.RIGHT, WALL)])
	assert_array(plan.errors).is_empty()
	assert_int(plan.closed_walls).is_equal(1)
	assert_array(Array(plan.partners)).is_equal([-1])


func test_reports_loose_ends(kind: Socket.Kind, required: bool, test_parameters := [
	[CORRIDOR, false],
	[VENT, false],
	[WALL, true],
]) -> void:
	var plan := _plan([_socket("end", EDGE, Vector3.RIGHT, kind, required)])
	assert_array(plan.errors).has_size(1)
	assert_str(plan.errors[0]).starts_with("Loose socket")


func test_reports_sockets_that_dont_face_each_other() -> void:
	var plan := _plan([_socket("a", EDGE, Vector3.RIGHT, CORRIDOR), _socket("b", EDGE, Vector3.RIGHT, CORRIDOR)])
	assert_int(plan.joins).is_equal(0)
	assert_bool(_has_error(plan, "don't face each other")).is_true()


func test_reports_kinds_that_cant_join() -> void:
	var plan := _plan([_socket("corridor", EDGE, Vector3.RIGHT, CORRIDOR), _socket("vent", EDGE, Vector3.LEFT, VENT)])
	assert_int(plan.joins).is_equal(0)
	assert_bool(_has_error(plan, "can't join")).is_true()


func test_reports_sockets_off_the_grid() -> void:
	var plan := _plan([_socket("wall", Vector3(1.0, 0.0, 0.0), Vector3.RIGHT, WALL)])
	assert_bool(_has_error(plan, "off the grid")).is_true()


func test_reports_overlapping_sections() -> void:
	var plan := WreckAssembly.plan([] as Array[WreckAssembly.SocketInfo], {
		"room": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
		"corridor": [Vector3i(1, 0, 0)],
	})
	assert_array(plan.errors).has_size(1)
	assert_str(plan.errors[0]).starts_with("Sections overlap")


func test_is_on_grid(position: Vector3, outward: Vector3, expected: bool, test_parameters := [
	[Vector3(2, 0, 0), Vector3.RIGHT, true],
	[Vector3(-2, 4, 8), Vector3.LEFT, true],
	[Vector3(4, 0, 6), Vector3.BACK, true],
	[Vector3(2, 0, 0), Vector3.FORWARD, false],
	[Vector3(0, 0, 0), Vector3.RIGHT, false],
	[Vector3(2, 0, 2), Vector3.RIGHT, false],
	[Vector3(2, 1, 0), Vector3.RIGHT, false],
]) -> void:
	assert_bool(WreckAssembly.is_on_grid(_socket("s", position, outward, WALL))).is_equal(expected)


func test_to_cell(position: Vector3, expected: Vector3i, test_parameters := [
	[Vector3(0, 0, 0), Vector3i(0, 0, 0)],
	[Vector3(4, 0, -8), Vector3i(1, 0, -2)],
	[Vector3(12, 4, 8), Vector3i(3, 1, 2)],
	[Vector3(12, 3.999, 8), Vector3i(3, 1, 2)],
]) -> void:
	assert_that(WreckAssembly.to_cell(position)).is_equal(expected)


func _socket(label: String, position: Vector3, outward: Vector3, kind: Socket.Kind,
		required := false) -> WreckAssembly.SocketInfo:
	return WreckAssembly.SocketInfo.new(label, position, outward, kind, true, required)


func _plan(sockets: Array) -> WreckAssembly.Plan:
	var typed: Array[WreckAssembly.SocketInfo] = []
	typed.assign(sockets)
	return WreckAssembly.plan(typed, {})


func _has_error(plan: WreckAssembly.Plan, text: String) -> bool:
	return Array(plan.errors).any(func(error: String) -> bool: return error.contains(text))
