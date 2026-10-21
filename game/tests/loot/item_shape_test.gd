extends GdUnitTestSuite
## Unit tests for ItemShape: reading shapes from rows, the eight orientations, and how turning and mirroring an
## orientation step through them.

const T := ["###", ".#."]
const L := ["#.", "#.", "##"]
const S := [".##", "##."]


func test_reads_cells_from_rows() -> void:
	assert_array(ItemShape.cells_from_rows(PackedStringArray(T))).contains_exactly(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)])


func test_quarter_turn_clockwise() -> void:
	# The T's stem points down; a quarter turn clockwise points it left.
	assert_array(_rows(T, 1)).contains_exactly([".#", "##", ".#"])
	assert_array(_rows(T, 2)).contains_exactly([".#.", "###"])
	assert_array(_rows(T, 3)).contains_exactly(["#.", "##", "#."])


func test_mirroring_turns_an_l_into_a_j() -> void:
	assert_array(_rows(L, 4)).contains_exactly([".#", ".#", "##"])


func test_oriented_shapes_start_at_the_origin() -> void:
	for orientation in ItemShape.ORIENTATIONS:
		var cells := ItemShape.oriented(_cells(S), orientation)
		var corner := Vector2i(100, 100)
		for cell in cells:
			corner = Vector2i(mini(corner.x, cell.x), mini(corner.y, cell.y))
		assert_vector(Vector2(corner)).is_equal(Vector2.ZERO)


func test_distinct_orientations(rows: Array, expected: int, test_parameters := [
	[["##", "##"], 1],
	[["###"], 2],
	[[".##", "##."], 4],
	[["###", ".#."], 4],
	[["#.", "#.", "##"], 8],
]) -> void:
	assert_int(ItemShape.distinct_orientations(_cells(rows)).size()).is_equal(expected)


func test_turning_steps_through_the_orientations_as_seen() -> void:
	for orientation in ItemShape.ORIENTATIONS:
		var turned := ItemShape.oriented(_cells(L), ItemShape.turned_clockwise(orientation))
		var expected := ItemShape.oriented(ItemShape.oriented(_cells(L), orientation), 1)
		assert_array(_sorted(turned)).is_equal(_sorted(expected))


func test_mirroring_mirrors_the_shape_as_seen() -> void:
	for orientation in ItemShape.ORIENTATIONS:
		var mirrored := ItemShape.oriented(_cells(L), ItemShape.mirrored(orientation))
		var expected := ItemShape.oriented(ItemShape.oriented(_cells(L), orientation), 4)
		assert_array(_sorted(mirrored)).is_equal(_sorted(expected))
		assert_int(ItemShape.mirrored(ItemShape.mirrored(orientation))).is_equal(orientation)


func test_four_turns_come_back() -> void:
	for orientation in ItemShape.ORIENTATIONS:
		var turned := orientation
		for turn in 4:
			turned = ItemShape.turned_clockwise(turned)
		assert_int(turned).is_equal(orientation)


func test_size_of() -> void:
	assert_vector(Vector2(ItemShape.size_of(_cells(L)))).is_equal(Vector2(2, 3))
	assert_vector(Vector2(ItemShape.size_of(ItemShape.oriented(_cells(L), 1)))).is_equal(Vector2(3, 2))


func test_one_piece() -> void:
	assert_bool(ItemShape.is_one_piece(_cells(T))).is_true()
	assert_bool(ItemShape.is_one_piece(_cells(["#.", ".#"]))).is_false()
	assert_bool(ItemShape.is_one_piece(_cells(["..."]))).is_false()


static func _cells(rows: Array) -> Array[Vector2i]:
	return ItemShape.cells_from_rows(PackedStringArray(rows))


## The shape in an orientation, written back as rows.
static func _rows(rows: Array, orientation: int) -> Array[String]:
	var cells := ItemShape.oriented(_cells(rows), orientation)
	var size := ItemShape.size_of(cells)
	var written: Array[String] = []
	for row in size.y:
		var line := ""
		for column in size.x:
			line += ItemShape.CELL if cells.has(Vector2i(column, row)) else ItemShape.GAP
		written.append(line)
	return written


static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy := cells.duplicate()
	copy.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return copy
