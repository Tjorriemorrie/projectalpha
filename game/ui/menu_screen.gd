class_name MenuScreen
extends Control
## The base of the full-screen screens in the HUD (the inventory and the trader hub, through GridScreen, and the system
## and star maps, through MapScreen): placards in two columns either side of the screen's centre, over the running
## game, which stays visible and slightly dimmed, with key hints along the bottom. The screen takes every mouse event
## itself (its placards let them through) and keeps the pointer's position from them, so a gamepad can drive the same
## pointer later. Subclasses build the columns (_build), handle presses (_handle_input) and say what happens as the
## pointer moves (_refresh); the player opens and closes them.

const DIM_COLOR := Color(0.02, 0.03, 0.045, 0.35)
const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_TEXT_COLOR := Color(0.721569, 0.768627, 0.815686)
const PLACARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.62)
const CARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.92)
const PLACARD_EDGE := Color(0.862745, 0.901961, 0.941176, 0.18)
const LASER_COLOR := Color(0.62, 0.82, 1.0)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const FONT_NAMES := ["Bahnschrift", "DIN Alternate", "Arial Narrow"]
## Fraction of the screen width between its centre and the inner edge of each column.
const CENTRE_GAP := 0.09
const FADE_TIME := 0.12
## Pixels between the key hints and the bottom of the screen, when the columns leave room for it.
const HINT_BOTTOM := 96.0
const MOUSE_BUTTON_NAMES := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "Wheel", MOUSE_BUTTON_WHEEL_DOWN: "Wheel"}

@export var open_sound: AudioStream = preload("res://assets/audio/loot/inventory_open.wav")
@export var close_sound: AudioStream = preload("res://assets/audio/loot/inventory_close.wav")
@export var bump_sound: AudioStream = preload("res://assets/audio/loot/item_bump.wav")

var is_open := false
## Where the pointer is, in this control's pixels.
var pointer := Vector2.ZERO
## Pixels at the top of the screen kept clear, for the ship's bar that stays over every screen at home.
var top_inset := 0.0

## Whether the screen is opening or closing to switch tabs with another (the map's): no fade and no sound.
var _switching := false

## The columns left and right of the centre; subclasses fill them in _build().
var _left_column: VBoxContainer
var _right_column: VBoxContainer
## Fraction of the screen width between its centre and each column.
var _centre_gap := CENTRE_GAP
var _hint: HBoxContainer
## Drawn over everything else, with _draw_overlay().
var _overlay: Control
var _font: SystemFont
var _label_font: FontVariation
var _body_font: SystemFont
var _sound: AudioStreamPlayer
var _fade: Tween


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


## Where the key hints are, in this control's pixels.
func hint_rect() -> Rect2:
	return Rect2(_hint.position, _hint.size)


## Shows the screen: takes the pointer from the mouse, fades in and lays out (switching tabs, it shows at once and
## quietly). Subclasses set up their contents first.
func _show_screen() -> void:
	pointer = get_local_mouse_position()
	is_open = true
	visible = true
	if _fade:
		_fade.kill()
	modulate.a = 1.0
	if not _switching:
		modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)
		_play(open_sound)
	_layout()
	# Labels and containers settle their sizes during the frame; lay out again once they have.
	_layout.call_deferred()


func _hide_screen() -> void:
	is_open = false
	visible = false
	if not _switching:
		_play(close_sound)


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouse:
		pointer = (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		_refresh()
		accept_event()
		return
	if not _handle_input(event):
		return
	_refresh()
	accept_event()


## Places the left column's right edge and the right column's left edge either side of the screen's centre, their
## tops level and the taller column centred vertically below top_inset; the key hints along the bottom, below the
## columns.
func _layout() -> void:
	if not is_open:
		return
	var screen := get_viewport_rect().size
	var gap := screen.x * _centre_gap
	var left_size := _left_column.get_combined_minimum_size()
	var right_size := _right_column.get_combined_minimum_size()
	var tallest := maxf(left_size.y, right_size.y)
	var hint_size := _hint.get_combined_minimum_size()
	var hint_y := screen.y - hint_size.y - HINT_BOTTOM
	var top := maxf(minf((screen.y + top_inset - tallest) / 2.0, hint_y - 12.0 - tallest), top_inset + 16.0)
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


## A placard: a header with its label and a detail on the right, and the body under it.
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


## Whether the pointer is over a control, by its rectangle on the screen.
func _pointer_over(control: Control) -> bool:
	return control.is_visible_in_tree() and control.get_global_rect().has_point(get_global_transform() * pointer)


func _over_placard() -> bool:
	for placard in _left_column.get_children() + _right_column.get_children():
		if _pointer_over(placard as Control):
			return true
	return false


func _play(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()


## Builds the screen's placards into _left_column and _right_column.
func _build() -> void:
	pass


## The key hints: [action, what it does], or [&"", plain text].
func _hints() -> Array:
	return [[&"inventory", "Close"]]


## A button or key event (not a pointer move) while open. Returns whether the screen used it.
func _handle_input(_event: InputEvent) -> bool:
	return false


## The pointer moved or something changed: update what is under the pointer and redraw the overlay.
func _refresh() -> void:
	_overlay.queue_redraw()


## Draws over everything else on the screen.
func _draw_overlay() -> void:
	pass
