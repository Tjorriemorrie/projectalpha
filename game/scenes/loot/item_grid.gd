class_name ItemGrid
extends RefCounted
## A grid of square slots that holds stacks of items, such as the backpack, the pockets or a container. A slot is
## addressed by its cell (column, row going down) and holds one stack (an Item) of one kind, up to the kind's stack
## size; stacks of the same kind top each other up, and nothing else ever shares a slot. A grid may take only some
## kinds (accepts(): the weapon slot takes guns, the ammo slots thermal clips). A growing grid (the stash, the floor)
## keeps spare_rows empty rows below its last stack, growing and shrinking as stacks come and go, so it always has
## room. Nodes that change a grid log what they did; the grid itself only emits changed.

## Emitted whenever a stack is placed, removed or changes its quantity, or the grid grows or shrinks.
signal changed

## Not a cell: where there is no free slot.
const NO_CELL := Vector2i(-1, -1)

## Columns and rows.
var size: Vector2i
## The stacks it holds, in the order they were placed.
var items: Array[Item] = []
## Empty rows a growing grid keeps below its last stack; -1 for a grid of a fixed size.
var spare_rows := -1
## The fewest rows a growing grid shrinks to: the rows it was made with.
var min_rows := 1

var _occupant := {}


func _init(grid_size: Vector2i, spare: int = -1) -> void:
	size = grid_size
	spare_rows = spare
	min_rows = grid_size.y
	_fit_rows()


## Whether it keeps empty rows below its last stack, so it always has room.
func is_growing() -> bool:
	return spare_rows >= 0


## Whether a kind may go in it at all. Every grid takes every kind, but the weapon slot and the ammo slots.
func accepts(_definition: ItemDefinition) -> bool:
	return true


## Whether a stack of this kind can go into the slot at cell: the slot is in the grid and free (or holds ignore, the
## stack being moved), and the grid takes the kind.
func fits(definition: ItemDefinition, cell: Vector2i, ignore: Item = null) -> bool:
	if not has_cell(cell) or not accepts(definition):
		return false
	var occupant: Item = _occupant.get(cell)
	return occupant == null or occupant == ignore


## How many of a kind the slot at cell can still take: a whole stack in a free slot, what a stack of the same kind
## has room for, and none otherwise.
func room_at(definition: ItemDefinition, cell: Vector2i) -> int:
	if not has_cell(cell) or not accepts(definition):
		return 0
	var occupant: Item = _occupant.get(cell)
	if occupant == null:
		return definition.stack_size
	return occupant.room() if occupant.definition == definition else 0


## Puts a stack into the free slot at cell. A stack already in this grid moves. Returns whether it was placed.
func place(item: Item, cell: Vector2i) -> bool:
	if not fits(item.definition, cell, item):
		return false
	if _occupant.get(item.cell) == item:
		_occupant.erase(item.cell)
	item.cell = cell
	_occupant[cell] = item
	if not items.has(item):
		items.append(item)
		item.changed.connect(_on_item_changed)
	_fit_rows()
	changed.emit()
	return true


## Takes a stack out of the grid. Returns whether it was there.
func remove(item: Item) -> bool:
	if not items.has(item):
		return false
	if _occupant.get(item.cell) == item:
		_occupant.erase(item.cell)
	items.erase(item)
	item.changed.disconnect(_on_item_changed)
	_fit_rows()
	changed.emit()
	return true


func has(item: Item) -> bool:
	return items.has(item)


## The stack in the slot at cell, or null.
func item_at(cell: Vector2i) -> Item:
	return _occupant.get(cell)


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The first free slot in reading order, for a kind the grid takes; NO_CELL when there is none.
func first_free(definition: ItemDefinition) -> Vector2i:
	if not accepts(definition):
		return NO_CELL
	for row in size.y:
		for column in size.x:
			if not _occupant.has(Vector2i(column, row)):
				return Vector2i(column, row)
	return NO_CELL


## Puts as many of a stack as there is room for onto the stacks of its kind here, in reading order, taking them off
## it. Returns how many moved.
func top_up(item: Item) -> int:
	if not accepts(item.definition):
		return 0
	var moved := 0
	for stack in in_reading_order():
		if item.quantity <= 0:
			break
		if stack == item or stack.definition != item.definition:
			continue
		var amount := mini(stack.room(), item.quantity)
		if amount <= 0:
			continue
		stack.quantity += amount
		item.quantity -= amount
		moved += amount
	return moved


## Puts a stack in: it tops up the stacks of its kind first, and what is left goes into the first free slot. Returns
## whether all of it went in; what didn't stays on the item.
func add(item: Item) -> bool:
	if not accepts(item.definition):
		return false
	top_up(item)
	if item.quantity <= 0:
		return true
	var cell := first_free(item.definition)
	return cell != NO_CELL and place(item, cell)


## Adds one of a kind: onto the first stack of it with room, else into the first free slot. Returns the stack it
## went onto, or null when there is no room.
func add_one(definition: ItemDefinition) -> Item:
	if not accepts(definition):
		return null
	for stack in in_reading_order():
		if stack.definition == definition and stack.room() > 0:
			stack.quantity += 1
			return stack
	var item := Item.new(definition)
	return item if place(item, first_free(definition)) else null


## How many more of a kind it can take: the room on its stacks of that kind and whole stacks in its free slots. A
## growing grid always has room for more.
func room_for(definition: ItemDefinition) -> int:
	if not accepts(definition):
		return 0
	var room := free_slots() * definition.stack_size
	for stack in items:
		if stack.definition == definition:
			room += stack.room()
	return room


## Takes amount off a stack here into a stack of its own; taking all of it takes the stack itself out. Returns the
## stack taken, or null when the stack isn't here or amount is none.
func take(item: Item, amount: int) -> Item:
	amount = mini(amount, item.quantity)
	if amount <= 0 or not has(item):
		return null
	if amount == item.quantity:
		remove(item)
		return item
	item.quantity -= amount
	var taken := Item.new(item.definition, amount)
	taken.clip_heat = item.clip_heat
	return taken


## How many items of this kind it holds, in all its stacks.
func count(definition: ItemDefinition) -> int:
	var total := 0
	for item in items:
		if item.definition == definition:
			total += item.quantity
	return total


## The first stack of this kind in reading order, or null.
func first_of(definition: ItemDefinition) -> Item:
	for item in in_reading_order():
		if item.definition == definition:
			return item
	return null


## Its stacks in reading order of their slots: along each row, then down.
func in_reading_order() -> Array[Item]:
	var ordered := items.duplicate()
	ordered.sort_custom(func(a: Item, b: Item) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return ordered


## Slots no stack takes.
func free_slots() -> int:
	return size.x * size.y - _occupant.size()


## How many items it holds, counting every one in every stack.
func item_count() -> int:
	var total := 0
	for item in items:
		total += item.quantity
	return total


## Rows down to the lowest stack; 0 when it is empty.
func rows_used() -> int:
	var rows := 0
	for item in items:
		rows = maxi(rows, item.cell.y + 1)
	return rows


## Total value of the stacks it holds, in bitcoin.
func value() -> int:
	var total := 0
	for item in items:
		total += item.value()
	return total


## Moves a stack into these grids, in order: it tops up their stacks of its kind first, and what is left goes into
## the first free slot among them. from is the grid holding it now, if any, which it leaves once it has all gone, or
## when it goes into a free slot whole. Returns how many moved; what didn't stays on the item.
static func stow(item: Item, grids: Array[ItemGrid], from: ItemGrid = null) -> int:
	var moved := 0
	for grid in grids:
		moved += grid.top_up(item)
	if item.quantity > 0:
		for grid in grids:
			var cell := grid.first_free(item.definition)
			if cell == NO_CELL:
				continue
			if from:
				from.remove(item)
			grid.place(item, cell)
			moved += item.quantity
			return moved
	if item.quantity <= 0 and from:
		from.remove(item)
	return moved


## A growing grid keeps spare_rows empty rows below its last stack, and never fewer rows than min_rows.
func _fit_rows() -> void:
	if spare_rows < 0:
		return
	size.y = maxi(min_rows, rows_used() + spare_rows)


func _on_item_changed() -> void:
	changed.emit()
