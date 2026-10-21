class_name ItemGrid
extends RefCounted
## A grid of cells that holds items, such as the backpack, the pockets or a container. Each item covers the cells
## of its shape in its orientation; items never overlap or stick out of the grid. A cell can be reserved so nothing
## is put there: a reload keeps the cell of the clip it took free for the spent clip. Nodes that change a grid log
## what they did; the grid itself only emits changed.

## Emitted whenever an item is placed or removed, a cell is reserved or released, or the grid grows.
signal changed

## Where an item would go: the cell its shape starts at, and its orientation.
class Spot:
	var cell: Vector2i
	var orientation: int

	func _init(at: Vector2i, item_orientation: int) -> void:
		cell = at
		orientation = item_orientation


## Columns and rows.
var size: Vector2i
## The items it holds, in the order they were placed.
var items: Array[Item] = []

var _occupant := {}
var _reserved := {}


func _init(grid_size: Vector2i) -> void:
	size = grid_size


## Whether an item of this kind fits with its shape starting at cell, in this orientation: every cell inside the
## grid, free and not reserved. ignore is an item that doesn't count as in the way (the one being moved).
func fits(definition: ItemDefinition, orientation: int, cell: Vector2i, ignore: Item = null) -> bool:
	for offset in ItemShape.oriented(definition.get_cells(), orientation):
		var covered := cell + offset
		if not has_cell(covered) or _reserved.has(covered):
			return false
		var occupant: Item = _occupant.get(covered)
		if occupant != null and occupant != ignore:
			return false
	return true


## Puts an item into the grid with its shape starting at cell, in this orientation, if it fits there. An item that
## is already in this grid moves. Returns whether it was placed.
func place(item: Item, cell: Vector2i, orientation: int) -> bool:
	if not fits(item.definition, orientation, cell, item):
		return false
	_release_cells(item)
	item.cell = cell
	item.orientation = orientation
	for covered in item.cells():
		_occupant[covered] = item
	if not items.has(item):
		items.append(item)
	changed.emit()
	return true


## Takes an item out of the grid. Returns whether it was there.
func remove(item: Item) -> bool:
	if not items.has(item):
		return false
	_release_cells(item)
	items.erase(item)
	changed.emit()
	return true


func has(item: Item) -> bool:
	return items.has(item)


## The first spot an item of this kind fits, or null: the first free cell in reading order in its own orientation,
## then in each other orientation in turn, so items keep the way they come when they can.
func find_space(definition: ItemDefinition) -> Spot:
	for orientation in ItemShape.distinct_orientations(definition.get_cells()):
		for row in size.y:
			for column in size.x:
				if fits(definition, orientation, Vector2i(column, row)):
					return Spot.new(Vector2i(column, row), orientation)
	return null


## Puts an item into the first spot it fits (see find_space). Returns whether there was room.
func add(item: Item) -> bool:
	var spot := find_space(item.definition)
	if spot == null:
		return false
	return place(item, spot.cell, spot.orientation)


## The item covering a cell, or null.
func item_at(cell: Vector2i) -> Item:
	return _occupant.get(cell)


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## How many items of this kind it holds.
func count(definition: ItemDefinition) -> int:
	return items.filter(func(item: Item) -> bool: return item.definition == definition).size()


## The first item of this kind in reading order of where it starts, or null.
func first_of(definition: ItemDefinition) -> Item:
	var found: Item = null
	for item in items:
		if item.definition != definition:
			continue
		if found == null or item.cell.y < found.cell.y or (item.cell.y == found.cell.y and item.cell.x < found.cell.x):
			found = item
	return found


## Cells no item covers and nothing reserved.
func free_cells() -> int:
	return size.x * size.y - _occupant.size() - _reserved.size()


## Keeps a free cell free until it is released. Returns whether it could be reserved.
func reserve(cell: Vector2i) -> bool:
	if not has_cell(cell) or _occupant.has(cell) or _reserved.has(cell):
		return false
	_reserved[cell] = true
	changed.emit()
	return true


func release(cell: Vector2i) -> void:
	if _reserved.erase(cell):
		changed.emit()


func is_reserved(cell: Vector2i) -> bool:
	return _reserved.has(cell)


## Rows down to the bottom of the lowest item; 0 when it is empty.
func rows_used() -> int:
	var rows := 0
	for item in items:
		rows = maxi(rows, item.cell.y + item.size().y)
	return rows


## Makes it this many rows deep when it is shallower (the floor grows to keep room free). Never shrinks.
func grow_to(rows: int) -> void:
	if rows <= size.y:
		return
	size.y = rows
	changed.emit()


## Total value of the items it holds, in credits.
func value() -> int:
	var total := 0
	for item in items:
		total += item.definition.value
	return total


func _release_cells(item: Item) -> void:
	for covered in item.cells():
		if _occupant.get(covered) == item:
			_occupant.erase(covered)
