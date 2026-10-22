class_name InventoryScreen
extends GridScreen
## The inventory screen, part of the HUD (see GridScreen): the player's weapon slot, pockets and backpack as placards
## on the right half; on the left half an open container's grid and, except on the ship, the floor: the dropped items
## within the player's reach. The middle stays clear to watch for robots. The gun in the weapon slot is the one in
## hand, and only a gun fits there. The item card shows name, picture, value, size, value per cell and description.
## Dragging an item onto the floor, or releasing it outside every placard, drops it (it shows in the floor's grid);
## dragging one off the floor picks it up. The player turns those into items in the world (dropped_on_floor,
## taken_from_floor). The floor grows so it always has empty rows. The player opens and closes it.

## Emitted when an item lands on the floor from another grid: the player drops it into the world.
signal dropped_on_floor(item: Item)
## Emitted when an item leaves the floor for another grid: the player takes it out of the world.
signal taken_from_floor(item: Item)

## Columns of the floor's grid, and the empty rows it always keeps below its lowest item: enough for any item,
## turned to lie flat.
const FLOOR_COLUMNS := 6
const FLOOR_SPARE_ROWS := 2

var inventory: Inventory
## The container (or wreckage) being searched, or null.
var loot: Lootable
## The dropped items within reach, laid out in a grid that grows as things are dropped on it.
var floor_grid: ItemGrid
## What the carried readout says, for tests: e.g. "CARRIED  ₿100   ·   30 FREE CELLS".
var carried_text := ""

var _weapon_view: ItemGridView
var _pockets_view: ItemGridView
var _backpack_view: ItemGridView
var _loot_view: ItemGridView
var _floor_view: ItemGridView
var _loot_placard: PanelContainer
var _loot_title: Label
var _loot_size: Label
var _floor_placard: PanelContainer
var _drop_hint: Label
var _weapon_name: Label
var _backpack_size: Label
var _carried: Label


func _build() -> void:
	_weapon_view = ItemGridView.new()
	_pockets_view = ItemGridView.new()
	_backpack_view = ItemGridView.new()
	_loot_view = ItemGridView.new()
	_floor_view = ItemGridView.new()
	_loot_title = _label("", 11, DIM_TEXT_COLOR, true)
	_loot_size = _label("", 12, DIM_TEXT_COLOR, true)
	_loot_placard = _placard("", _loot_size, _loot_view, _loot_title)
	_left_column.add_child(_loot_placard)
	_floor_placard = _placard("FLOOR", _label("Within reach", 12, DIM_TEXT_COLOR, false), _floor_view)
	_left_column.add_child(_floor_placard)
	_weapon_name = _label("", 12, DIM_TEXT_COLOR, false)
	_right_column.add_child(_placard("WEAPON", _weapon_name, _weapon_view))
	_right_column.add_child(_placard("POCKETS", _label("Reloads take clips from here", 12, DIM_TEXT_COLOR, false),
		_pockets_view))
	_backpack_size = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_placard("BACKPACK", _backpack_size, _backpack_view))
	_carried = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_carried)


func _build_hint() -> void:
	super()
	_drop_hint = _label("Drag onto the floor or outside to drop", 13, DIM_TEXT_COLOR, false)
	_hint.add_child(_drop_hint)


## Opens the screen on what the player carries, the dropped items within reach (floor, FLOOR_COLUMNS wide; an empty
## one when none is given) and, when searching one, a container's grid. Without a floor (on the ship) the floor's
## placard is hidden and nothing can be dropped: an item released outside the placards goes back.
func open(carried: Inventory, container: Lootable = null, floor: ItemGrid = null, with_floor: bool = true) -> void:
	inventory = carried
	loot = container
	floor_grid = null
	if with_floor:
		floor_grid = floor if floor else ItemGrid.new(Vector2i(FLOOR_COLUMNS, FLOOR_SPARE_ROWS))
	var cell_px := _cell_size()
	_weapon_view.setup(inventory.weapon, cell_px)
	_pockets_view.setup(inventory.pockets, cell_px)
	_backpack_view.setup(inventory.backpack, cell_px)
	_floor_placard.visible = with_floor
	_drop_hint.visible = with_floor
	if floor_grid:
		_floor_view.setup(floor_grid, cell_px)
		_keep_floor_room()
	_backpack_size.text = "%d × %d" % [inventory.backpack.size.x, inventory.backpack.size.y]
	_loot_placard.visible = loot != null
	if loot:
		_loot_view.setup(loot.grid, cell_px)
		_loot_title.text = loot.title.to_upper()
		_loot_size.text = "%d × %d" % [loot.grid.size.x, loot.grid.size.y]
	for grid in _grids():
		if not grid.changed.is_connected(_update_carried):
			grid.changed.connect(_update_carried)
	_update_carried()
	_show_screen()
	Log.info(("🎒 Inventory opened: loot=%s, floor=%s items, gun=%s, pockets=%d items, backpack=%d items, "
		+ "free=%d/%d, value=%d, cell=%.0f px") % [loot.title if loot else "none",
		floor_grid.items.size() if floor_grid else "no", inventory.gun().definition.id if inventory.gun() else "none",
		inventory.pockets.items.size(), inventory.backpack.items.size(), inventory.pockets.free_cells(),
		inventory.backpack.free_cells(), inventory.value(), _cell_px])


## Closes the screen; an item still being dragged goes back where it came from.
func close() -> void:
	if not is_open:
		Log.info("🎒 Inventory screen not closed, it isn't open")
		return
	_hide_screen()
	for grid in _grids():
		if grid.changed.is_connected(_update_carried):
			grid.changed.disconnect(_update_carried)
	Log.info("🎒 Inventory closed: loot=%s, floor=%s items, gun=%s, pockets=%d items, backpack=%d items, value=%d" % [
		loot.title if loot else "none", floor_grid.items.size() if floor_grid else "no",
		inventory.gun().definition.id if inventory.gun() else "none", inventory.pockets.items.size(),
		inventory.backpack.items.size(), inventory.value()])
	loot = null
	floor_grid = null


## Drops the dragged item: it lands on the floor and shows in the floor's grid. An item dragged off the floor and
## released outside goes back where it was, since it is on the floor already, and so does any item where there is
## no floor (on the ship).
func drop_drag_outside() -> void:
	if dragged == null:
		return
	if floor_grid == null:
		_play(bump_sound)
		Log.info("🎒 Item released outside with no floor to drop it on, back where it was: item=%s" % [
			dragged.definition.id])
		_return_drag()
		return
	if _drag_view.grid == floor_grid:
		Log.info("🎒 Floor item released outside, back where it was: item=%s" % dragged.definition.id)
		_return_drag()
		return
	var item := dragged
	_end_drag()
	_put_on_floor(item)
	Log.info("🎒 Item dragged out of the inventory, dropped on the floor: item=%s, floor_cell=%s, floor_items=%d" % [
		item.definition.id, item.cell, floor_grid.items.size()])


func _on_released_outside() -> void:
	drop_drag_outside()


func _on_moved(item: Item, from: ItemGrid, to: ItemGrid) -> void:
	if to == floor_grid and from != floor_grid:
		_keep_floor_room()
		dropped_on_floor.emit(item)
	elif from == floor_grid and to != floor_grid:
		taken_from_floor.emit(item)


## An item that can't go back where it came from lands on the floor, so it isn't lost.
func _on_return_failed(item: Item, grid: ItemGrid) -> void:
	if grid == floor_grid:
		floor_grid.add(item)
		_keep_floor_room()
	elif floor_grid:
		_put_on_floor(item)
	else:
		super(item, grid)


## Lays an item on the floor's first free spot (the floor keeps room for any item) and drops it into the world.
func _put_on_floor(item: Item) -> void:
	if not floor_grid.add(item):
		floor_grid.grow_to(floor_grid.size.y + ItemShape.size_of(item.definition.get_cells()).y)
		floor_grid.add(item)
	_keep_floor_room()
	_play(place_sound)
	dropped_on_floor.emit(item)


## Grows the floor so it keeps FLOOR_SPARE_ROWS empty rows below its lowest item, and fits its placard to it.
func _keep_floor_room() -> void:
	var rows := floor_grid.size.y
	floor_grid.grow_to(floor_grid.rows_used() + FLOOR_SPARE_ROWS)
	_floor_view.fit_size()
	if floor_grid.size.y != rows:
		Log.info("🎒 Floor grew: rows=%d->%d, items=%d" % [rows, floor_grid.size.y, floor_grid.items.size()])
		_layout.call_deferred()


func _update_carried() -> void:
	var free := inventory.free_cells()
	carried_text = "CARRIED  %s   ·   %d FREE %s" % [Bitcoin.format(inventory.value()), free,
		"CELL" if free == 1 else "CELLS"]
	_carried.text = carried_text
	var gun := inventory.gun()
	_weapon_name.text = gun.definition.display_name if gun else "Unarmed"


func _views() -> Array[ItemGridView]:
	var views: Array[ItemGridView] = [_weapon_view, _pockets_view, _backpack_view]
	if loot:
		views.append(_loot_view)
	if floor_grid:
		views.append(_floor_view)
	return views


func _grid_name(grid: ItemGrid) -> String:
	if inventory and grid == inventory.weapon:
		return "weapon"
	if inventory and grid == inventory.pockets:
		return "pockets"
	if inventory and grid == inventory.backpack:
		return "backpack"
	if loot and grid == loot.grid:
		return loot.title
	if floor_grid and grid == floor_grid:
		return "floor"
	return "grid"
