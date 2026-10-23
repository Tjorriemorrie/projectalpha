class_name GridScreen
extends MenuScreen
## The base of the full-screen item screens in the HUD (the inventory and the trader hub): item grids on placards in
## two columns either side of the screen's centre (see MenuScreen). Items only ever move by being dragged with the
## pointer (inventory_drag), turned (inventory_rotate) and mirrored (inventory_mirror) while dragged; nothing is sorted
## by itself. Pressing on an item selects it (a thick border), and the item under the pointer shows its item card
## beside the pointer. An item that can't land goes back where it came from. Subclasses build the columns (_build), say
## which grids they show (_views) and what happens around the drags (the _on_* hooks); the player opens and closes them.

const DRAG_OUTLINE := Color(0.62, 0.82, 1.0, 0.9)
## Cell size as a fraction of the screen height, and its limits in pixels.
const CELL_FRACTION := 0.05
const MIN_CELL := 40.0
const MAX_CELL := 72.0
## The item card: its width, inner margin, the largest the picture is drawn, and how far it sits from the pointer.
const CARD_WIDTH := 260.0
const CARD_MARGIN := 12.0
const CARD_PICTURE := Vector2(236.0, 96.0)
const CARD_OFFSET := Vector2(22.0, 18.0)

@export var pick_sound: AudioStream = preload("res://assets/audio/loot/item_pick.wav")
@export var place_sound: AudioStream = preload("res://assets/audio/loot/item_place.wav")

## The item being dragged, out of every grid until it lands, or null.
var dragged: Item
## The selected item (pressed on last), or null.
var selected: Item
## The item under the pointer, whose card shows, or null.
var focused: Item

var _cell_px := 52.0
## Where the dragged item came from, to put it back when it can't land.
var _drag_view: ItemGridView
var _drag_cell := Vector2i.ZERO
var _drag_orientation := 0
## Which of the dragged item's cells the pointer holds, by its index in the item's shape.
var _grab_index := 0


## The middle of a grid's cell, in this control's pixels: where the pointer goes to point at it.
func cell_center(grid: ItemGrid, cell: Vector2i) -> Vector2:
	var view := _view_of(grid)
	var middle := view.get_global_transform() * (view.cell_position(cell) + Vector2.ONE * view.cell_px / 2.0)
	return get_global_transform().affine_inverse() * middle


## Selects an item (or nothing), shown with a thick border in its grid.
func select(item: Item) -> void:
	if item == selected:
		return
	selected = item
	for view in _views():
		view.set_selected(item)
	if item:
		Log.info("🎒 Item selected: item=%s" % item.definition.id)


## Picks up the item covering a cell of a grid to drag it, and selects it. Returns whether there was one.
func begin_drag(grid: ItemGrid, cell: Vector2i) -> bool:
	var view := _view_of(grid)
	var item := grid.item_at(cell) if view else null
	if item == null or dragged:
		return false
	select(item)
	dragged = item
	_drag_view = view
	_drag_cell = item.cell
	_drag_orientation = item.orientation
	_grab_index = maxi(item.shape().find(cell - item.cell), 0)
	view.set_cutout(item.cells())
	grid.remove(item)
	_play(pick_sound)
	Log.info("🎒 Item picked up: item=%s, from=%s, cell=%s, orientation=%d" % [
		item.definition.id, _grid_name(grid), item.cell, item.orientation])
	_refresh()
	return true


## Turns the dragged item a quarter turn clockwise, about the cell the pointer holds.
func rotate_drag() -> void:
	if dragged == null:
		return
	dragged.orientation = ItemShape.turned_clockwise(dragged.orientation)
	Log.info("🎒 Dragged item rotated: item=%s, orientation=%d" % [dragged.definition.id, dragged.orientation])
	_refresh()


## Mirrors the dragged item left to right as it is seen now.
func mirror_drag() -> void:
	if dragged == null:
		return
	dragged.orientation = ItemShape.mirrored(dragged.orientation)
	Log.info("🎒 Dragged item mirrored: item=%s, orientation=%d" % [dragged.definition.id, dragged.orientation])
	_refresh()


## Puts the dragged item down with the cell the pointer holds on cell of grid. When it doesn't fit there it goes back
## where it came from. Returns whether it landed.
func drop_drag(grid: ItemGrid, cell: Vector2i) -> bool:
	if dragged == null:
		return false
	var target := cell - _grab_offset()
	var item := dragged
	var from := _drag_view.grid
	if not grid.fits(item.definition, item.orientation, target):
		_play(bump_sound)
		Log.info("🎒 Item doesn't fit there, back where it was: item=%s, grid=%s, cell=%s, orientation=%d" % [
			item.definition.id, _grid_name(grid), target, item.orientation])
		_return_drag()
		return false
	grid.place(item, target, item.orientation)
	_end_drag()
	_play(place_sound)
	Log.info("🎒 Item moved: item=%s, from=%s, to=%s, cell=%s, orientation=%d" % [
		item.definition.id, _grid_name(from), _grid_name(grid), target, item.orientation])
	_on_moved(item, from, grid)
	return true


## Shows the screen: sizes the cells for the window and resets the selection. Subclasses set up their views first.
func _show_screen() -> void:
	_cell_px = _cell_size()
	select(null)
	super()


## Hides the screen; an item still being dragged goes back where it came from.
func _hide_screen() -> void:
	if dragged:
		_return_drag()
	select(null)
	for view in _views():
		view.clear_preview()
		view.set_hovered(null)
	focused = null
	super()


## The cell size for the window's height now.
func _cell_size() -> float:
	return clampf(roundf(get_viewport_rect().size.y * CELL_FRACTION), MIN_CELL, MAX_CELL)


func _handle_input(event: InputEvent) -> bool:
	var at := _grid_at_pointer()
	if event.is_action_pressed("inventory_drag"):
		if at.size() == 2 and begin_drag(at[0], at[1]):
			pass
		elif not _on_pressed():
			select(null)
	elif event.is_action_released("inventory_drag") and dragged:
		if at.size() == 2:
			drop_drag(at[0], at[1])
		elif _over_placard():
			_play(bump_sound)
			Log.info("🎒 Item released on a placard, back where it was: item=%s" % dragged.definition.id)
			_return_drag()
		else:
			_on_released_outside()
	elif event.is_action_pressed("inventory_rotate"):
		rotate_drag()
	elif event.is_action_pressed("inventory_mirror"):
		mirror_drag()
	else:
		return false
	return true


## Puts the dragged item back where it came from.
func _return_drag() -> void:
	var item := dragged
	var grid := _drag_view.grid
	_end_drag()
	if grid.place(item, _drag_cell, _drag_orientation):
		return
	# Nothing else lands in a grid while an item is dragged, so this shouldn't happen; if it does, it isn't lost.
	Log.warning("🎒 Item couldn't go back where it was: item=%s, grid=%s, cell=%s" % [
		item.definition.id, _grid_name(grid), _drag_cell])
	_on_return_failed(item, grid)


func _end_drag() -> void:
	dragged = null
	if _drag_view:
		_drag_view.set_cutout([])
	for view in _views():
		view.clear_preview()
	_overlay.queue_redraw()


## Updates where the dragged item would land, the item under the pointer and the overlay. Runs on every pointer
## move.
func _refresh() -> void:
	var at := _grid_at_pointer()
	for view in _views():
		if dragged and at.size() == 2 and view.grid == at[0]:
			var target: Vector2i = at[1] - _grab_offset()
			var cells: Array[Vector2i] = []
			for offset in dragged.shape():
				cells.append(target + offset)
			view.set_preview(cells, view.grid.fits(dragged.definition, dragged.orientation, target))
		else:
			view.clear_preview()
	var hovered: Item = null
	if dragged == null and at.size() == 2:
		hovered = (at[0] as ItemGrid).item_at(at[1])
	if hovered != focused:
		focused = hovered
		for view in _views():
			view.set_hovered(hovered if hovered and view.grid.has(hovered) else null)
	_on_refreshed()
	super()


## The dragged item under the pointer, held by the cell it was picked up by, or the card of what is under it.
func _draw_overlay() -> void:
	if dragged:
		var origin := pointer - (Vector2(_grab_offset()) + Vector2.ONE * 0.5) * _cell_px
		ItemGridView.draw_item(_overlay, dragged.definition, dragged.orientation, origin, _cell_px, DRAG_OUTLINE, 0.9)
		return
	var definition := _card_definition()
	if definition:
		_draw_card(definition, _card_stats(definition))


## The item card beside the pointer: name, picture, three stats (label, value, colour) and description. It stays on
## the screen, moving to the other side of the pointer near an edge.
func _draw_card(definition: ItemDefinition, stats: Array) -> void:
	var inner := CARD_WIDTH - 2.0 * CARD_MARGIN
	var span := ItemShape.size_of(definition.get_cells())
	var picture_px := minf(CARD_PICTURE.x / span.x, CARD_PICTURE.y / span.y)
	var picture := Vector2(span) * picture_px
	var description_size := _body_font.get_multiline_string_size(definition.description, HORIZONTAL_ALIGNMENT_LEFT,
		inner, 13)
	var height := CARD_MARGIN + 22.0 + 8.0 + picture.y + 12.0 + 34.0 + 8.0 + description_size.y + CARD_MARGIN
	var position := pointer + CARD_OFFSET
	var screen := _overlay.size
	if position.x + CARD_WIDTH > screen.x:
		position.x = pointer.x - CARD_OFFSET.x - CARD_WIDTH
	if position.y + height > screen.y:
		position.y = screen.y - height
	position = position.clamp(Vector2.ZERO, (screen - Vector2(CARD_WIDTH, height)).max(Vector2.ZERO))
	var box := Rect2(position, Vector2(CARD_WIDTH, height))
	_overlay.draw_rect(box, CARD_COLOR)
	_overlay.draw_rect(box, PLACARD_EDGE, false, 1.0)
	var y := position.y + CARD_MARGIN
	var left := position.x + CARD_MARGIN
	_overlay.draw_string(_font, Vector2(left, y + 17.0), definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, inner,
		18, INK_COLOR)
	y += 22.0 + 8.0
	var picture_origin := Vector2(left + (inner - picture.x) / 2.0, y)
	_overlay.draw_rect(Rect2(left, y, inner, picture.y), Color(INK_COLOR, 0.04))
	ItemGridView.draw_item(_overlay, definition, 0, picture_origin, picture_px, Color(INK_COLOR, 0.3))
	y += picture.y + 12.0
	for i in stats.size():
		var x := left + inner / 3.0 * i
		var color: Color = stats[i][2] if stats[i].size() > 2 else INK_COLOR
		_overlay.draw_string(_label_font, Vector2(x, y + 9.0), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			DIM_TEXT_COLOR)
		_overlay.draw_string(_font, Vector2(x, y + 28.0), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	y += 34.0 + 8.0
	_overlay.draw_line(Vector2(left, y - 4.0), Vector2(left + inner, y - 4.0), PLACARD_EDGE, 1.0)
	_overlay.draw_multiline_string(_body_font, Vector2(left, y + 13.0), definition.description,
		HORIZONTAL_ALIGNMENT_LEFT, inner, 13, -1, DIM_TEXT_COLOR)


## The grid and cell under the pointer, as [grid, cell], or [] when it isn't over a grid's cells.
func _grid_at_pointer() -> Array:
	var at := get_global_transform() * pointer
	for view in _views():
		if not view.is_visible_in_tree():
			continue
		var cell := view.cell_at(view.get_global_transform().affine_inverse() * at)
		if view.grid.has_cell(cell):
			return [view.grid, cell]
	return []


func _grab_offset() -> Vector2i:
	return dragged.shape()[_grab_index] if dragged else Vector2i.ZERO


func _grids() -> Array[ItemGrid]:
	var grids: Array[ItemGrid] = []
	for view in _views():
		grids.append(view.grid)
	return grids


func _view_of(grid: ItemGrid) -> ItemGridView:
	for view in _views():
		if view.grid == grid:
			return view
	return null


## The key hints: [action, what it does], or [&"", plain text].
func _hints() -> Array:
	return [[&"inventory_drag", "Drag"], [&"inventory_rotate", "Rotate"], [&"inventory_mirror", "Mirror"],
		[&"inventory", "Close"]]


## The views of the grids the screen shows now.
func _views() -> Array[ItemGridView]:
	return []


## A grid's name for the log.
func _grid_name(_grid: ItemGrid) -> String:
	return "grid"


## An item landed in a grid after being dragged from another (or the same) grid.
func _on_moved(_item: Item, _from: ItemGrid, _to: ItemGrid) -> void:
	pass


## The drag button was pressed where there is no item to drag. Returns whether the screen used the press (a button);
## otherwise the selection clears.
func _on_pressed() -> bool:
	return false


## The dragged item was released outside every placard: it goes back where it came from.
func _on_released_outside() -> void:
	_play(bump_sound)
	Log.info("🎒 Item released outside, back where it was: item=%s" % dragged.definition.id)
	_return_drag()


## The dragged item couldn't go back where it came from: it goes to the first spot it fits there.
func _on_return_failed(item: Item, grid: ItemGrid) -> void:
	if not grid.add(item):
		Log.error("🎒 Item couldn't go back, it is lost: item=%s, grid=%s" % [item.definition.id, _grid_name(grid)])


## The pointer moved, after the grids updated what is under it.
func _on_refreshed() -> void:
	pass


## The item whose card shows: the one under the pointer.
func _card_definition() -> ItemDefinition:
	return focused.definition if focused else null


## The card's three stats: [label, value] or [label, value, colour].
func _card_stats(definition: ItemDefinition) -> Array:
	var cells := definition.get_cells().size()
	return [["VALUE", Bitcoin.format(definition.value)], ["SIZE", "%d %s" % [cells, "CELL" if cells == 1 else "CELLS"]],
		["PER CELL", Bitcoin.format(roundi(float(definition.value) / cells))]]
