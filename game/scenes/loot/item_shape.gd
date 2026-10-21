class_name ItemShape
extends RefCounted
## The cells an item takes up in a grid, and its eight orientations. A shape is written as rows of text, "#" for a
## cell and "." for a gap (["###", ".#."] is a T), so it reads in the inspector and in a mod's .tres. Cells are
## Vector2i(column, row), with rows going down as on screen. Orientations 0 to 3 turn the shape a quarter turn
## clockwise each; 4 to 7 mirror it left to right first and then turn it the same way. An oriented shape always
## starts at cell (0, 0), and keeps its cells in the order they were given, so a cell can be followed through a turn.

const ORIENTATIONS := 8
const CELL := "#"
const GAP := "."


## The cells of a shape written as rows, in reading order. Characters other than "#" are gaps.
static func cells_from_rows(rows: PackedStringArray) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in rows.size():
		for column in rows[row].length():
			if rows[row][column] == CELL:
				cells.append(Vector2i(column, row))
	return cells


## The shape in an orientation, moved to start at cell (0, 0). Cell i of the result is cell i of the shape.
static func oriented(cells: Array[Vector2i], orientation: int) -> Array[Vector2i]:
	var turned: Array[Vector2i] = []
	for cell in cells:
		turned.append(orient_offset(cell, orientation))
	return _normalised(turned)


## Where one cell goes in an orientation, before the shape is moved back to start at (0, 0).
static func orient_offset(cell: Vector2i, orientation: int) -> Vector2i:
	var result := Vector2i(-cell.x, cell.y) if orientation >= 4 else cell
	for turn in orientation % 4:
		# A quarter turn clockwise on screen, where rows go down.
		result = Vector2i(-result.y, result.x)
	return result


## The columns and rows a shape spans.
static func size_of(cells: Array[Vector2i]) -> Vector2i:
	var size := Vector2i.ZERO
	for cell in cells:
		size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
	return size


## The orientation after turning one in a quarter turn clockwise.
static func turned_clockwise(orientation: int) -> int:
	return (orientation / 4) * 4 + (orientation % 4 + 1) % 4


## The orientation after mirroring one left to right as it is seen now. Mirroring a turned shape turns it back the
## other way, so the quarter turns count backwards.
static func mirrored(orientation: int) -> int:
	return (1 - orientation / 4) * 4 + (4 - orientation % 4) % 4


## The orientations that give different shapes, smallest first: a square has one, a bar two, a T four, an L eight.
static func distinct_orientations(cells: Array[Vector2i]) -> Array[int]:
	var seen := {}
	var distinct: Array[int] = []
	for orientation in ORIENTATIONS:
		var shape := oriented(cells, orientation)
		shape.sort_custom(_reading_order)
		if not seen.has(shape):
			seen[shape] = true
			distinct.append(orientation)
	return distinct


## Whether every cell of a shape touches another along an edge, so it is one piece.
static func is_one_piece(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var remaining := {}
	for cell in cells:
		remaining[cell] = true
	var stack: Array[Vector2i] = [cells[0]]
	remaining.erase(cells[0])
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if remaining.has(cell + step):
				remaining.erase(cell + step)
				stack.append(cell + step)
	return remaining.is_empty()


static func _normalised(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells
	var corner := cells[0]
	for cell in cells:
		corner = Vector2i(mini(corner.x, cell.x), mini(corner.y, cell.y))
	var moved: Array[Vector2i] = []
	for cell in cells:
		moved.append(cell - corner)
	return moved


static func _reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
