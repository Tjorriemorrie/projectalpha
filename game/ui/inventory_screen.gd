class_name InventoryScreen
extends GridScreen
## The inventory screen, part of the HUD (see GridScreen): the player's weapon and ammo slots, pockets and backpack as
## placards on the right half; on the left half the slots of an open container (or the ship's stash) and, except on
## the ship, the floor: the stacks dropped within the player's reach. The middle stays clear to watch for robots. The
## gun in the weapon slot is the one in hand, and only a gun goes there; only thermal clips go in the ammo slots. The
## item card shows name, picture, value, stack, what the slot is worth and description. A quick move sends a stack
## from the player to the open container (or the stash), else to the floor, and from there to the player
## (Inventory.stow_order()). Dragging a stack onto the floor, or releasing it outside every placard, drops it (it
## shows on the floor); dragging it off the floor picks it up. The floor grows to keep a spare row. After every move
## the screen tells the player what changed on the floor (dropped_on_floor, floor_topped_up, taken_from_floor), and
## the player keeps the objects in the world in step. The player opens and closes it.

## Emitted when a stack lands on the floor as a stack of its own: the player drops it into the world.
signal dropped_on_floor(item: Item)
## Emitted when more lands on a stack already on the floor: the player makes it clatter.
signal floor_topped_up(item: Item)
## Emitted when a stack has left the floor altogether: the player takes it out of the world.
signal taken_from_floor(item: Item)

## Columns of the floor's slots, and the empty rows it always keeps below its last stack.
const FLOOR_COLUMNS := 6
const FLOOR_SPARE_ROWS := 1
## The most rows of the floor, and of the stash, that show before they scroll.
const FLOOR_ROWS_SHOWN := 2
const LOOT_ROWS_SHOWN := 4

var inventory: Inventory
## The container (or wreckage, or the ship's stash) being searched, or null.
var loot: Lootable
## The stacks dropped within reach, laid out in slots that grow as things are dropped there.
var floor_grid: ItemGrid
## What the carried readout says, for tests: e.g. "CARRIED  ₿250   ·   8 FREE SLOTS".
var carried_text := ""

var _weapon_view: ItemGridView
var _ammo_view: ItemGridView
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
## The stacks lying on the floor in the world, and how many each held, as of the last move.
var _on_floor := {}


## Empty floor slots, FLOOR_COLUMNS wide, that grow to keep FLOOR_SPARE_ROWS empty rows.
static func make_floor() -> ItemGrid:
	return ItemGrid.new(Vector2i(FLOOR_COLUMNS, 1), FLOOR_SPARE_ROWS)


func _build() -> void:
	_weapon_view = _make_view()
	_ammo_view = _make_view()
	_pockets_view = _make_view()
	_backpack_view = _make_view()
	_loot_view = _make_view(LOOT_ROWS_SHOWN)
	_floor_view = _make_view(FLOOR_ROWS_SHOWN)
	_loot_title = _label("", 11, DIM_TEXT_COLOR, true)
	_loot_size = _label("", 12, DIM_TEXT_COLOR, true)
	_loot_placard = _placard("", _loot_size, _loot_view, _loot_title)
	_left_column.add_child(_loot_placard)
	_floor_placard = _placard("FLOOR", _label("Within reach", 12, DIM_TEXT_COLOR, false), _floor_view)
	_left_column.add_child(_floor_placard)
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 12)
	_weapon_name = _label("", 12, DIM_TEXT_COLOR, false)
	hand.add_child(_placard("WEAPON", _weapon_name, _weapon_view))
	hand.add_child(_placard("AMMO", _label("Reloads take clips from here", 12, DIM_TEXT_COLOR, false), _ammo_view))
	_right_column.add_child(hand)
	_right_column.add_child(_placard("POCKETS", _label("For things at hand", 12, DIM_TEXT_COLOR, false),
		_pockets_view))
	_backpack_size = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_placard("BACKPACK", _backpack_size, _backpack_view))
	_carried = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_carried)


func _build_hint() -> void:
	super()
	_drop_hint = _label("Drag onto the floor or outside to drop", 13, DIM_TEXT_COLOR, false)
	_hint.add_child(_drop_hint)


## Opens the screen on what the player carries, the stacks dropped within reach (floor, from make_floor(); an empty
## one when none is given) and, when searching one, a container's slots. Without a floor (on the ship) the floor's
## placard is hidden and nothing can be dropped: a stack released outside the placards goes back.
func open(carried: Inventory, container: Lootable = null, floor: ItemGrid = null, with_floor: bool = true) -> void:
	inventory = carried
	loot = container
	floor_grid = null
	if with_floor:
		floor_grid = floor if floor else make_floor()
	var cell_px := _cell_size()
	_weapon_view.setup(inventory.weapon, cell_px)
	_ammo_view.setup(inventory.ammo, cell_px)
	_pockets_view.setup(inventory.pockets, cell_px)
	_backpack_view.setup(inventory.backpack, cell_px)
	_floor_placard.visible = with_floor
	_drop_hint.visible = with_floor
	_on_floor.clear()
	if floor_grid:
		_floor_view.setup(floor_grid, cell_px)
		for item in floor_grid.items:
			_on_floor[item] = item.quantity
	_backpack_size.text = _slots_text(inventory.backpack)
	_loot_placard.visible = loot != null
	if loot:
		_loot_view.setup(loot.grid, cell_px)
		_loot_title.text = loot.title.to_upper()
	for grid in _grids():
		if not grid.changed.is_connected(_update_carried):
			grid.changed.connect(_update_carried)
	_update_carried()
	_show_screen()
	Log.info(("🎒 Inventory opened: loot=%s, floor=%s stacks, gun=%s, ammo=%d, pockets=%d stacks, "
		+ "backpack=%d stacks, free_slots=%d, value=%d, slot=%.0f px") % [loot.title if loot else "none",
		floor_grid.items.size() if floor_grid else "no", inventory.gun().definition.id if inventory.gun() else "none",
		inventory.ammo.item_count(), inventory.pockets.items.size(), inventory.backpack.items.size(),
		inventory.free_slots(), inventory.value(), _cell_px])


## Closes the screen; a stack still in hand goes back where it came from.
func close() -> void:
	if not is_open:
		Log.info("🎒 Inventory screen not closed, it isn't open")
		return
	_hide_screen()
	for grid in _grids():
		if grid.changed.is_connected(_update_carried):
			grid.changed.disconnect(_update_carried)
	Log.info("🎒 Inventory closed: loot=%s, floor=%s stacks, gun=%s, ammo=%d, pockets=%d stacks, backpack=%d stacks, value=%d" % [
		loot.title if loot else "none", floor_grid.items.size() if floor_grid else "no",
		inventory.gun().definition.id if inventory.gun() else "none", inventory.ammo.item_count(),
		inventory.pockets.items.size(), inventory.backpack.items.size(), inventory.value()])
	loot = null
	floor_grid = null
	_on_floor.clear()


## Drops the stack in hand: it lands on the floor (topping up a stack of its kind there) and shows there. A stack
## taken off the floor and released outside goes back where it was, since it is on the floor already, and so does any
## stack where there is no floor (on the ship).
func drop_drag_outside() -> void:
	if dragged == null:
		return
	if floor_grid == null:
		_play(bump_sound)
		Log.info("🎒 Stack released outside with no floor to drop it on, back where it was: item=%s" % [
			dragged.definition.id])
		_return_drag()
		_on_moved()
		return
	if _drag_view.grid == floor_grid:
		Log.info("🎒 Floor stack released outside, back where it was: item=%s" % dragged.definition.id)
		_return_drag()
		_on_moved()
		return
	var item := dragged
	var quantity := item.quantity
	_end_drag()
	put_on_floor(item)
	Log.info("🎒 Stack dragged out of the inventory, dropped on the floor: item=%s, quantity=%d, floor_stacks=%d" % [
		item.definition.id, quantity, floor_grid.items.size()])


## Lays a stack on the floor, topping up a stack of its kind there or taking the first free slot (the floor always
## has one), and drops it into the world. Returns whether there is a floor to lay it on.
func put_on_floor(item: Item) -> bool:
	if floor_grid == null:
		Log.warning("🎒 No floor to put a stack on: item=%s, quantity=%d" % [item.definition.id, item.quantity])
		return false
	floor_grid.add(item)
	_play(place_sound)
	_on_moved()
	Log.info("🎒 Stack put on the floor: item=%s, floor_stacks=%d" % [item.definition.id, floor_grid.items.size()])
	return true


func _on_released_outside() -> void:
	drop_drag_outside()


func _on_moved() -> void:
	_sync_floor()


## A stack that can't go back where it came from lands on the floor, or else in the open container (the stash on the
## ship), so it isn't lost.
func _on_return_failed(item: Item, grid: ItemGrid) -> void:
	if floor_grid and grid != floor_grid and put_on_floor(item):
		return
	if loot and grid != loot.grid and loot.grid.add(item):
		Log.info("🎒 Stack went into the open container instead: item=%s, loot=%s" % [item.definition.id, loot.title])
		return
	super(item, grid)


## From the player a quick move goes to the open container (or the stash), else to the floor; from either of those
## it goes to the player.
func _quick_targets(item: Item, from: ItemGrid) -> Array[ItemGrid]:
	var targets: Array[ItemGrid] = []
	if not inventory.grids().has(from):
		return inventory.stow_order(item.definition)
	if loot:
		targets.append(loot.grid)
	elif floor_grid:
		targets.append(floor_grid)
	return targets


## Tells the player what changed on the floor since the last move: stacks that landed there as their own, stacks
## that grew, and stacks that left it altogether.
func _sync_floor() -> void:
	if floor_grid == null:
		return
	var now := {}
	for item in floor_grid.items:
		now[item] = item.quantity
	for item: Item in _on_floor:
		if not now.has(item):
			taken_from_floor.emit(item)
	for item: Item in now:
		if not _on_floor.has(item):
			dropped_on_floor.emit(item)
		elif now[item] > _on_floor[item]:
			floor_topped_up.emit(item)
	_on_floor = now


func _update_carried() -> void:
	var free := inventory.free_slots()
	carried_text = "CARRIED  %s   ·   %d FREE %s" % [Bitcoin.format(inventory.value()), free,
		"SLOT" if free == 1 else "SLOTS"]
	_carried.text = carried_text
	var gun := inventory.gun()
	_weapon_name.text = gun.definition.display_name if gun else "Unarmed"
	if loot:
		var stacks := loot.grid.items.size()
		_loot_size.text = "%d %s" % [stacks, "STACK" if stacks == 1 else "STACKS"] if loot.grid.is_growing() \
			else _slots_text(loot.grid)


func _slots_text(grid: ItemGrid) -> String:
	return "%d SLOTS" % (grid.size.x * grid.size.y)


func _views() -> Array[ItemGridView]:
	var views: Array[ItemGridView] = [_weapon_view, _ammo_view, _pockets_view, _backpack_view]
	if loot:
		views.append(_loot_view)
	if floor_grid:
		views.append(_floor_view)
	return views


func _grid_name(grid: ItemGrid) -> String:
	if inventory and grid == inventory.weapon:
		return "weapon"
	if inventory and grid == inventory.ammo:
		return "ammo"
	if inventory and grid == inventory.pockets:
		return "pockets"
	if inventory and grid == inventory.backpack:
		return "backpack"
	if loot and grid == loot.grid:
		return loot.title
	if floor_grid and grid == floor_grid:
		return "floor"
	return "grid"
