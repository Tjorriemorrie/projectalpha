class_name GridScreen
extends Control
## The base of the full-screen item screens in the HUD (the inventory and the trader hub): item grids on placards in
## two columns either side of the screen's centre, over the running game, which stays visible and slightly dimmed.
## Items only ever move by being dragged with the pointer (inventory_drag), turned (inventory_rotate) and mirrored
## (inventory_mirror) while dragged; nothing is sorted by itself. Pressing on an item selects it (a thick border), and
## the item under the pointer shows its item card beside the pointer. An item that can't land goes back where it came
## from. The screen takes every mouse event itself (its placards let them through) and keeps the pointer's position
## from them, so a gamepad can drive the same pointer later. Subclasses build the columns (_build), say which grids
## they show (_views) and what happens around the drags (the _on_* hooks); the player opens and closes them.

const DIM_COLOR := Color(0.02, 0.03, 0.045, 0.35)
const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_TEXT_COLOR := Color(0.721569, 0.768627, 0.815686)
const PLACARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.62)
const CARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.92)
const PLACARD_EDGE := Color(0.862745, 0.901961, 0.941176, 0.18)
const DRAG_OUTLINE := Color(0.62, 0.82, 1.0, 0.9)
const LASER_COLOR := Color(0.62, 0.82, 1.0)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const FONT_NAMES := ["Bahnschrift", "DIN Alternate", "Arial Narrow"]
## Fraction of the screen width between its centre and the inner edge of each column.
const CENTRE_GAP := 0.09
## Cell size as a fraction of the screen height, and its limits in pixels.
const CELL_FRACTION := 0.05
const MIN_CELL := 40.0
const MAX_CELL := 72.0
const FADE_TIME := 0.12
## Pixels between the key hints and the bottom of the screen, when the columns leave room for it.
const HINT_BOTTOM := 96.0
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

var is_open := false
## The item being dragged, out of every grid until it lands, or null.
var dragged: Item
## The selected item (pressed on last), or null.
var selected: Item
## The item under the pointer, whose card shows, or null.
var focused: Item
## Where the pointer is, in this control's pixels.
var pointer := Vector2.ZERO

var _cell_px := 52.0
## The columns left and right of the centre; subclasses fill them in _build().
var _left_column: VBoxContainer
var _right_column: VBoxContainer
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
	_left_column = VBoxContainer.new()
	_left_column.add_theme_constant_override("separation", 12)
	add_child(_left_column)
	_right_column = VBoxContainer.new()
	_right_column.add_theme_constant_override("separation", 12)
	add_child(_right_column)
	_build()
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


## Shows the screen: resets the selection, takes the pointer from the mouse, fades in and lays out. Subclasses set
## up their views first.
func _show_screen() -> void:
	_cell_px = _cell_size()
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


## Hides the screen; an item still being dragged goes back where it came from.
func _hide_screen() -> void:
	if dragged:
		_return_drag()
	select(null)
	for view in _views():
		view.clear_preview()
		view.set_hovered(null)
	focused = null
	is_open = false
	visible = false
	_play(close_sound)


## The cell size for the window's height now.
func _cell_size() -> float:
	return clampf(roundf(get_viewport_rect().size.y * CELL_FRACTION), MIN_CELL, MAX_CELL)


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
		return
	_refresh()
	accept_event()


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
	_overlay.queue_redraw()


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


## Places the left column's right edge and the right column's left edge either side of the screen's centre, their
## tops level and the taller column centred vertically; the key hints along the bottom, below the columns.
func _layout() -> void:
	if not is_open:
		return
	var screen := get_viewport_rect().size
	var gap := screen.x * CENTRE_GAP
	var left_size := _left_column.get_combined_minimum_size()
	var right_size := _right_column.get_combined_minimum_size()
	var tallest := maxf(left_size.y, right_size.y)
	var hint_size := _hint.get_combined_minimum_size()
	var hint_y := screen.y - hint_size.y - HINT_BOTTOM
	var top := maxf(minf((screen.y - tallest) / 2.0, hint_y - 12.0 - tallest), 16.0)
	if top + tallest + 12.0 > hint_y:
		hint_y = minf(top + tallest + 12.0, screen.y - hint_size.y - 8.0)
	_left_column.size = left_size
	_left_column.position = Vector2(screen.x / 2.0 - gap - left_size.x, top)
	_right_column.size = right_size
	_right_column.position = Vector2(screen.x / 2.0 + gap, top)
	_hint.size = hint_size
	_hint.position = Vector2((screen.x - hint_size.x) / 2.0, hint_y)


## The key hints along the bottom, from _hints(): each a key cap read from the Input Map with what it does, or plain
## text.
func _build_hint() -> void:
	for entry: Array in _hints():
		if entry[0] == &"":
			_hint.add_child(_label(entry[1], 13, DIM_TEXT_COLOR, false))
			continue
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


## A placard: a header with its label and a detail on the right, and the body (a grid's view) under it.
func _placard(title: String, detail: Label, body: Control, title_label: Label = null) -> PanelContainer:
	var panel := PanelContainer.new()
	# As wide as its body (or its header), not as wide as its column.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _placard_style())
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
	rows.add_child(body)
	return panel


func _placard_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PLACARD_COLOR
	style.border_color = PLACARD_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 12.0
	return style


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


## Whether the pointer is over a control, by its rectangle on the screen.
func _pointer_over(control: Control) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(get_global_transform() * pointer)


func _over_placard() -> bool:
	for placard in _left_column.get_children() + _right_column.get_children():
		if _pointer_over(placard as Control):
			return true
	return false


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


func _play(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()


## Builds the screen's placards into _left_column and _right_column.
func _build() -> void:
	pass


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
