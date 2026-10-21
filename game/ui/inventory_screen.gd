class_name InventoryScreen
extends Control
## The inventory screen, part of the HUD, over the running game, which stays visible and slightly dimmed: the
## player's pockets and backpack as placards on the right half; on the left half an open container's grid and,
## except on the ship, the floor: the dropped items within the player's reach. The middle stays clear to watch for robots. Loot
## only ever moves by being dragged with the pointer (inventory_drag), turned (inventory_rotate) and mirrored
## (inventory_mirror) while dragged; nothing is sorted by itself. Pressing on an item selects it (a thick border),
## and the item under the pointer shows its item card: name, picture, value, size, value per cell and description.
## Dragging an item onto the floor, or releasing it outside every placard, drops it (it shows in the floor's grid);
## dragging one off the floor picks it up. The player turns those into items in the world (dropped_on_floor,
## taken_from_floor). The floor grows so it always has empty rows. The screen takes every mouse event itself (its
## placards let them through) and keeps the pointer's position from them, so a gamepad can drive the same pointer
## later. The player opens and closes it.

## Emitted when an item lands on the floor from another grid: the player drops it into the world.
signal dropped_on_floor(item: Item)
## Emitted when an item leaves the floor for another grid: the player takes it out of the world.
signal taken_from_floor(item: Item)

## Columns of the floor's grid, and the empty rows it always keeps below its lowest item: enough for any item,
## turned to lie flat.
const FLOOR_COLUMNS := 6
const FLOOR_SPARE_ROWS := 2
const DIM_COLOR := Color(0.02, 0.03, 0.045, 0.35)
const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_TEXT_COLOR := Color(0.721569, 0.768627, 0.815686)
const PLACARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.62)
const CARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.92)
const PLACARD_EDGE := Color(0.862745, 0.901961, 0.941176, 0.18)
const DRAG_OUTLINE := Color(0.62, 0.82, 1.0, 0.9)
const FONT_NAMES := ["Bahnschrift", "DIN Alternate", "Arial Narrow"]
## Fraction of the screen width between its centre and the inner edge of each column.
const CENTRE_GAP := 0.09
## Cell size as a fraction of the screen height, and its limits in pixels.
const CELL_FRACTION := 0.05
const MIN_CELL := 40.0
const MAX_CELL := 72.0
const FADE_TIME := 0.12
## The item card: its width, inner margin, the largest the picture is drawn, and how far it sits from the pointer.
const CARD_WIDTH := 260.0
const CARD_MARGIN := 12.0
const CARD_PICTURE := Vector2(236.0, 96.0)
const CARD_OFFSET := Vector2(22.0, 18.0)
const MOUSE_BUTTON_NAMES := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "Wheel", MOUSE_BUTTON_WHEEL_DOWN: "Wheel"}

@export var open_sound: AudioStream = preload("res://assets/audio/loot/inventory_open.wav")
@export var close_sound: AudioStream = preload("res://assets/audio/loot/inventory_close.wav")
@export var pick_sound: AudioStream = preload("res://assets/audio/loot/item_pick.wav")
@export var place_sound: AudioStream = preload("res://assets/audio/loot/item_place.wav")
@export var bump_sound: AudioStream = preload("res://assets/audio/loot/item_bump.wav")

var inventory: Inventory
## The container (or wreckage) being searched, or null.
var loot: Lootable
## The dropped items within reach, laid out in a grid that grows as things are dropped on it.
var floor_grid: ItemGrid
var is_open := false
## The item being dragged, out of every grid until it lands, or null.
var dragged: Item
## The selected item (pressed on last), or null.
var selected: Item
## The item under the pointer, whose card shows, or null.
var focused: Item
## Where the pointer is, in this control's pixels.
var pointer := Vector2.ZERO
## What the carried readout says, for tests: e.g. "CARRIED  100 CR   ·   30 FREE CELLS".
var carried_text := ""

var _cell_px := 52.0
var _pockets_view: ItemGridView
var _backpack_view: ItemGridView
var _loot_view: ItemGridView
var _floor_view: ItemGridView
var _player_column: VBoxContainer
var _loot_column: VBoxContainer
var _loot_placard: PanelContainer
var _loot_title: Label
var _loot_size: Label
var _floor_placard: PanelContainer
var _drop_hint: Label
var _backpack_size: Label
var _carried: Label
var _hint: HBoxContainer
var _overlay: Control
var _font: SystemFont
var _label_font: FontVariation
var _body_font: SystemFont
var _sound: AudioStreamPlayer
var _fade: Tween
## Where the dragged item came from, to put it back when it can't land.
var _drag_view: ItemGridView
var _drag_cell := Vector2i.ZERO
var _drag_orientation := 0
## Which of the dragged item's cells the pointer holds, by its index in the item's shape.
var _grab_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(FONT_NAMES)
	_font.font_weight = 600
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(FONT_NAMES)
	_label_font = FontVariation.new()
	_label_font.base_font = _font
	_label_font.spacing_glyph = 2
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pockets_view = ItemGridView.new()
	_backpack_view = ItemGridView.new()
	_loot_view = ItemGridView.new()
	_floor_view = ItemGridView.new()
	_loot_column = VBoxContainer.new()
	_loot_column.add_theme_constant_override("separation", 12)
	add_child(_loot_column)
	_loot_title = _label("", 11, DIM_TEXT_COLOR, true)
	_loot_size = _label("", 12, DIM_TEXT_COLOR, true)
	_loot_placard = _placard("", _loot_size, _loot_view, _loot_title)
	_loot_column.add_child(_loot_placard)
	_floor_placard = _placard("FLOOR", _label("Within reach", 12, DIM_TEXT_COLOR, false), _floor_view)
	_loot_column.add_child(_floor_placard)
	_player_column = VBoxContainer.new()
	_player_column.add_theme_constant_override("separation", 12)
	add_child(_player_column)
	_player_column.add_child(_placard("POCKETS", _label("Reloads take clips from here", 12, DIM_TEXT_COLOR, false),
		_pockets_view))
	_backpack_size = _label("", 12, DIM_TEXT_COLOR, true)
	_player_column.add_child(_placard("BACKPACK", _backpack_size, _backpack_view))
	_carried = _label("", 12, DIM_TEXT_COLOR, true)
	_player_column.add_child(_carried)
	_hint = HBoxContainer.new()
	_hint.add_theme_constant_override("separation", 18)
	add_child(_hint)
	_build_hint()
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	# Every mouse event comes to the screen itself, so nothing it holds may catch them first.
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	get_viewport().size_changed.connect(_layout)


## Opens the screen on what the player carries, the dropped items within reach (floor, FLOOR_COLUMNS wide; an empty
## one when none is given) and, when searching one, a container's grid. Without a floor (on the ship) the floor's
## placard is hidden and nothing can be dropped: an item released outside the placards goes back.
func open(carried: Inventory, container: Lootable = null, floor: ItemGrid = null, with_floor: bool = true) -> void:
	inventory = carried
	loot = container
	floor_grid = null
	if with_floor:
		floor_grid = floor if floor else ItemGrid.new(Vector2i(FLOOR_COLUMNS, FLOOR_SPARE_ROWS))
	_cell_px = clampf(roundf(get_viewport_rect().size.y * CELL_FRACTION), MIN_CELL, MAX_CELL)
	_pockets_view.setup(inventory.pockets, _cell_px)
	_backpack_view.setup(inventory.backpack, _cell_px)
	_floor_placard.visible = with_floor
	_drop_hint.visible = with_floor
	if floor_grid:
		_floor_view.setup(floor_grid, _cell_px)
		_keep_floor_room()
	_backpack_size.text = "%d × %d" % [inventory.backpack.size.x, inventory.backpack.size.y]
	_loot_placard.visible = loot != null
	if loot:
		_loot_view.setup(loot.grid, _cell_px)
		_loot_title.text = loot.title.to_upper()
		_loot_size.text = "%d × %d" % [loot.grid.size.x, loot.grid.size.y]
	for grid in _grids():
		if not grid.changed.is_connected(_update_carried):
			grid.changed.connect(_update_carried)
	_update_carried()
	select(null)
	pointer = get_local_mouse_position()
	is_open = true
	visible = true
	modulate.a = 0.0
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_play(open_sound)
	_layout()
	# Labels and containers settle their sizes during the frame; lay out again once they have.
	_layout.call_deferred()
	Log.info(("🎒 Inventory opened: loot=%s, floor=%s items, pockets=%d items, backpack=%d items, free=%d/%d, "
		+ "value=%d, cell=%.0f px") % [loot.title if loot else "none", floor_grid.items.size() if floor_grid else "no",
		inventory.pockets.items.size(), inventory.backpack.items.size(), inventory.pockets.free_cells(),
		inventory.backpack.free_cells(), inventory.value(), _cell_px])


## Closes the screen; an item still being dragged goes back where it came from.
func close() -> void:
	if not is_open:
		return
	if dragged:
		_return_drag()
	select(null)
	for view in _views():
		view.clear_preview()
		view.set_hovered(null)
	focused = null
	is_open = false
	visible = false
	for grid in _grids():
		if grid.changed.is_connected(_update_carried):
			grid.changed.disconnect(_update_carried)
	_play(close_sound)
	Log.info("🎒 Inventory closed: loot=%s, floor=%s items, pockets=%d items, backpack=%d items, value=%d" % [
		loot.title if loot else "none", floor_grid.items.size() if floor_grid else "no", inventory.pockets.items.size(),
		inventory.backpack.items.size(), inventory.value()])
	loot = null
	floor_grid = null


## Moves the pointer, in this control's pixels: what the mouse does, and what a gamepad's stick will do.
func move_pointer(position: Vector2) -> void:
	pointer = position
	_refresh()


## The middle of a grid's cell, in this control's pixels: where the pointer goes to point at it.
func cell_center(grid: ItemGrid, cell: Vector2i) -> Vector2:
	var view := _view_of(grid)
	var middle := view.get_global_transform() * (view.cell_position(cell) + Vector2.ONE * view.cell_px / 2.0)
	return get_global_transform().affine_inverse() * middle


## Where the key hints are, in this control's pixels.
func hint_rect() -> Rect2:
	return Rect2(_hint.position, _hint.size)


## Selects an item (or nothing), shown with a thick border in its grid.
func select(item: Item) -> void:
	if item == selected:
		return
	selected = item
	for view in [_pockets_view, _backpack_view, _loot_view, _floor_view]:
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
	if grid == floor_grid and from != floor_grid:
		_keep_floor_room()
		dropped_on_floor.emit(item)
	elif from == floor_grid and grid != floor_grid:
		taken_from_floor.emit(item)
	return true


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


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouse:
		pointer = (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		_refresh()
		accept_event()
		return
	var at := _grid_at_pointer()
	if event.is_action_pressed("inventory_drag"):
		if at.size() != 2 or not begin_drag(at[0], at[1]):
			select(null)
	elif event.is_action_released("inventory_drag") and dragged:
		if at.size() == 2:
			drop_drag(at[0], at[1])
		elif _over_placard():
			_play(bump_sound)
			Log.info("🎒 Item released on a placard, back where it was: item=%s" % dragged.definition.id)
			_return_drag()
		else:
			drop_drag_outside()
	elif event.is_action_pressed("inventory_rotate"):
		rotate_drag()
	elif event.is_action_pressed("inventory_mirror"):
		mirror_drag()
	else:
		return
	_refresh()
	accept_event()


func _return_drag() -> void:
	var item := dragged
	var grid := _drag_view.grid
	_end_drag()
	if grid.place(item, _drag_cell, _drag_orientation):
		return
	# Nothing else lands in a grid while an item is dragged, so this shouldn't happen; if it does, it isn't lost.
	Log.warning("🎒 Item couldn't go back where it was, dropped on the floor: item=%s, grid=%s, cell=%s" % [
		item.definition.id, _grid_name(grid), _drag_cell])
	if grid == floor_grid:
		floor_grid.add(item)
		_keep_floor_room()
	elif floor_grid:
		_put_on_floor(item)
	elif not grid.add(item):
		Log.error("🎒 Item couldn't go back and there is no floor, it is lost: item=%s, grid=%s" % [
			item.definition.id, _grid_name(grid)])


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
	_overlay.queue_redraw()


## The dragged item under the pointer, held by the cell it was picked up by, or the card of the item under it.
func _draw_overlay() -> void:
	if dragged:
		var origin := pointer - (Vector2(_grab_offset()) + Vector2.ONE * 0.5) * _cell_px
		ItemGridView.draw_item(_overlay, dragged.definition, dragged.orientation, origin, _cell_px, DRAG_OUTLINE, 0.9)
		return
	if focused:
		_draw_card(focused.definition)


## The item card beside the pointer: name, picture, value, size and value per cell, and description. It stays on
## the screen, moving to the other side of the pointer near an edge.
func _draw_card(definition: ItemDefinition) -> void:
	var inner := CARD_WIDTH - 2.0 * CARD_MARGIN
	var cells := definition.get_cells()
	var span := ItemShape.size_of(cells)
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
	var stats := [["VALUE", "%d CR" % definition.value], ["SIZE", "%d %s" % [cells.size(),
		"CELL" if cells.size() == 1 else "CELLS"]], ["PER CELL", "%d CR" % roundi(float(definition.value) / cells.size())]]
	for i in stats.size():
		var x := left + inner / 3.0 * i
		_overlay.draw_string(_label_font, Vector2(x, y + 9.0), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			DIM_TEXT_COLOR)
		_overlay.draw_string(_font, Vector2(x, y + 28.0), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK_COLOR)
	y += 34.0 + 8.0
	_overlay.draw_line(Vector2(left, y - 4.0), Vector2(left + inner, y - 4.0), PLACARD_EDGE, 1.0)
	_overlay.draw_multiline_string(_body_font, Vector2(left, y + 13.0), definition.description,
		HORIZONTAL_ALIGNMENT_LEFT, inner, 13, -1, DIM_TEXT_COLOR)


## Places the container and the floor on the left half and the player's grids on the right half, either side of
## the screen's centre, their tops level and the taller column centred vertically; the hint along the bottom.
func _layout() -> void:
	if not is_open:
		return
	var screen := get_viewport_rect().size
	var gap := screen.x * CENTRE_GAP
	var loot_size := _loot_column.get_combined_minimum_size()
	var player_size := _player_column.get_combined_minimum_size()
	var top := maxf((screen.y - maxf(player_size.y, loot_size.y)) / 2.0, 16.0)
	_loot_column.size = loot_size
	_loot_column.position = Vector2(screen.x / 2.0 - gap - loot_size.x, top)
	_player_column.size = player_size
	_player_column.position = Vector2(screen.x / 2.0 + gap, top)
	var hint_size := _hint.get_combined_minimum_size()
	_hint.size = hint_size
	_hint.position = Vector2((screen.x - hint_size.x) / 2.0, screen.y - hint_size.y - 96.0)


func _update_carried() -> void:
	var free := inventory.free_cells()
	carried_text = "CARRIED  %d CR   ·   %d FREE %s" % [inventory.value(), free, "CELL" if free == 1 else "CELLS"]
	_carried.text = carried_text


## The key hints along the bottom, read from the Input Map once.
func _build_hint() -> void:
	for entry: Array in [[&"inventory_drag", "Drag"], [&"inventory_rotate", "Rotate"],
			[&"inventory_mirror", "Mirror"], [&"inventory", "Close"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 7)
		var cap := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0431373, 0.0588235, 0.0784314, 0.55)
		style.border_color = Color(INK_COLOR, 0.85)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		cap.add_theme_stylebox_override("panel", style)
		cap.add_child(_label(_binding_label(entry[0]), 12, INK_COLOR, false))
		pair.add_child(cap)
		pair.add_child(_label(entry[1], 13, DIM_TEXT_COLOR, false))
		_hint.add_child(pair)
	_drop_hint = _label("Drag onto the floor or outside to drop", 13, DIM_TEXT_COLOR, false)
	_hint.add_child(_drop_hint)


## A placard holding one grid: a header with its label and a detail on the right, and the grid under it.
func _placard(title: String, detail: Label, view: ItemGridView, title_label: Label = null) -> PanelContainer:
	var panel := PanelContainer.new()
	# As wide as its grid (or its header), not as wide as its column.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PLACARD_COLOR
	style.border_color = PLACARD_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	panel.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var label := title_label if title_label else _label(title, 11, DIM_TEXT_COLOR, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(detail)
	rows.add_child(header)
	rows.add_child(view)
	return panel


func _label(text: String, font_size: int, color: Color, spaced: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _label_font if spaced else _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## What to press for an action, from the Input Map: a key's name, or a mouse button's short name.
static func _binding_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			return MOUSE_BUTTON_NAMES.get(button.button_index, "Mouse %d" % button.button_index)
	return "?"


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


func _over_placard() -> bool:
	var at := get_global_transform() * pointer
	for placard in _loot_column.get_children() + _player_column.get_children():
		var control := placard as Control
		if control.is_visible_in_tree() and control.get_global_rect().has_point(at):
			return true
	return false


func _grab_offset() -> Vector2i:
	return dragged.shape()[_grab_index] if dragged else Vector2i.ZERO


func _views() -> Array[ItemGridView]:
	var views: Array[ItemGridView] = [_pockets_view, _backpack_view]
	if loot:
		views.append(_loot_view)
	if floor_grid:
		views.append(_floor_view)
	return views


func _grids() -> Array[ItemGrid]:
	var grids: Array[ItemGrid] = [inventory.pockets, inventory.backpack]
	if loot:
		grids.append(loot.grid)
	if floor_grid:
		grids.append(floor_grid)
	return grids


func _view_of(grid: ItemGrid) -> ItemGridView:
	for view in _views():
		if view.grid == grid:
			return view
	return null


func _grid_name(grid: ItemGrid) -> String:
	if inventory and grid == inventory.pockets:
		return "pockets"
	if inventory and grid == inventory.backpack:
		return "backpack"
	if loot and grid == loot.grid:
		return loot.title
	if floor_grid and grid == floor_grid:
		return "floor"
	return "grid"


func _play(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()
