class_name MapScreen
extends MenuScreen
## The base of the two map tabs the cockpit console opens, the system map (SystemMapScreen) and the star map
## (StarMapScreen), part of the HUD (see MenuScreen): the map on the left under a row of tab headers, placards in a
## column on the right with a status line under them, the two centred together. Q (map_tab, which the player reads) or
## a click on the other tab's header asks the HUD to switch tabs (tab_requested): it closes this one and opens the
## other in its place, quietly. Subclasses build the map and the column, say which tab they are, and handle the map's
## presses.

## Asks the HUD to show the other tab: on the system map, the system to show (null for the one the ship is in).
signal tab_requested(viewing: StarSystem)

enum Tab { SYSTEM, STAR }

## The map's side as a fraction of the screen height, and its limits in pixels.
const MAP_FRACTION := 0.72
const MIN_MAP := 320.0
const MAX_MAP := 760.0
## The width of the right column's placards, so it doesn't change with what they say.
const PANEL_WIDTH := 300.0
const TAB_NAMES := {Tab.SYSTEM: "SYSTEM MAP", Tab.STAR: "STAR MAP"}

## What the status line says, for tests: e.g. "Docked with the hauler at the Long Fall."
var status_text := ""

## Each tab's header, by Tab.
var _tab_headers := {}
var _status: Label


## Asks the HUD to switch to the other tab: the player calls it on Q (map_tab), which, like closing, is read as the
## action rather than through the screen's own input.
func switch_tab() -> void:
	_request_tab("key")


## The middle of a tab's header, in this control's pixels: where the pointer goes to switch to it.
func tab_header_center(tab: Tab) -> Vector2:
	return get_global_transform().affine_inverse() * (_tab_headers[tab] as Control).get_global_rect().get_center()


## Which tab this screen is.
func _tab() -> Tab:
	return Tab.SYSTEM


## The system the system map shows after a switch from this tab: null for the one the ship is in.
func _viewing_after_switch() -> StarSystem:
	return null


## A press on the map or the column (not a tab switch) while open. Returns whether the screen used it.
func _handle_map_input(_event: InputEvent) -> bool:
	return false


func _handle_input(event: InputEvent) -> bool:
	var other := Tab.STAR if _tab() == Tab.SYSTEM else Tab.SYSTEM
	if event.is_action_pressed("inventory_drag") and _pointer_over(_tab_headers[other]):
		_request_tab("header")
		return true
	return _handle_map_input(event)


func _request_tab(how: String) -> void:
	var viewing := _viewing_after_switch()
	Log.info("🪐 Map tab switch asked for: from=%s, how=%s, viewing=%s" % [
		TAB_NAMES[_tab()], how, viewing.definition.id if viewing else "here"])
	tab_requested.emit(viewing)


## The row of tab headers over the map, this one lit with the laser's blue underline, and the key that switches them.
func _build_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for tab: Tab in [Tab.SYSTEM, Tab.STAR]:
		var active := tab == _tab()
		var header := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(PLACARD_COLOR, 0.62 if active else 0.3)
		style.border_color = LASER_COLOR if active else Color(INK_COLOR, 0.12)
		style.border_width_bottom = 2 if active else 1
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		style.content_margin_top = 5.0
		style.content_margin_bottom = 5.0
		header.add_theme_stylebox_override("panel", style)
		header.add_child(_label(TAB_NAMES[tab], 12, INK_COLOR if active else DIM_TEXT_COLOR, true))
		row.add_child(header)
		_tab_headers[tab] = header
	var cap := PanelContainer.new()
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(PLACARD_COLOR, 0.55)
	cap_style.border_color = Color(INK_COLOR, 0.5)
	cap_style.set_border_width_all(1)
	cap_style.set_corner_radius_all(2)
	cap_style.content_margin_left = 6.0
	cap_style.content_margin_right = 6.0
	cap.add_theme_stylebox_override("panel", cap_style)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(_label(_binding_label(&"map_tab"), 11, DIM_TEXT_COLOR, false))
	row.add_child(cap)
	return row


## The status line under the column: it wraps within the column and keeps room for three lines, so a long message
## never moves the placards.
func _build_status() -> void:
	_status = _label("", 13, DIM_TEXT_COLOR, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_right_column.add_child(_status)


## A button in the column: a frame round a centred label, styled by _style_button().
func _new_button() -> PanelContainer:
	var button := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("panel", style)
	var label := _label("", 13, INK_COLOR, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(label)
	return button


## A button lights up in the laser's blue when it would do something, brighter under the pointer; otherwise it is
## dimmed, with a red edge when what it shows is refused.
func _style_button(button: PanelContainer, text: String, active: bool, hovered: bool, refused: bool) -> void:
	var style := button.get_theme_stylebox("panel") as StyleBoxFlat
	var label := button.get_child(0) as Label
	label.text = text
	style.border_color = LASER_COLOR if active else Color(DANGER_COLOR if refused else INK_COLOR, 0.3)
	style.bg_color = Color(LASER_COLOR, 0.28 if hovered else 0.12) if active else Color(PLACARD_COLOR, 0.4)
	label.add_theme_color_override("font_color", INK_COLOR if active else Color(DIM_TEXT_COLOR, 0.6))


## The middle of a control, in this control's pixels.
func _center_of(control: Control) -> Vector2:
	return get_global_transform().affine_inverse() * control.get_global_rect().get_center()


## The map's side in pixels, from the screen's height.
func _map_side() -> float:
	return clampf(roundf(get_viewport_rect().size.y * MAP_FRACTION), MIN_MAP, MAX_MAP)


## A placard as wide as the column.
func _sized(placard: PanelContainer) -> PanelContainer:
	placard.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	return placard


## A row of a placard's details: its name, small and spaced, beside its value.
func _add_detail_row(grid: GridContainer, row_name: String, value: String, color: Color = INK_COLOR) -> void:
	var name_label := _label(row_name, 10, DIM_TEXT_COLOR, true)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var value_label := _label(value, 15, color, false)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(name_label)
	grid.add_child(value_label)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refuse(message: String) -> void:
	_play(bump_sound)
	_set_status(message, DANGER_COLOR)


func _set_status(text: String, color: Color) -> void:
	status_text = text
	_status.text = text
	_status.add_theme_color_override("font_color", color)


## Centres the map and the column together, rather than each either side of the screen's centre.
func _layout() -> void:
	super()
	if not is_open:
		return
	var shift := (_left_column.size.x - _right_column.size.x) / 2.0
	_left_column.position.x += shift
	_right_column.position.x += shift
