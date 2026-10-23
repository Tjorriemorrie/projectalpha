class_name SystemMapScreen
extends MenuScreen
## The system map, part of the HUD (see MenuScreen), opened from the cockpit console: the star system the ship is in
## as an orbital diagram (SystemMapView) on the left, and on the right the system, the hydrogen in the tank, what the
## pointer is on or was clicked last, a FLY button and a status line. A wreck shows what makes it dangerous, never a
## difficulty level: its type, where it lies, how many robots its scan expects and the gear it requires. Pointing at a
## wreck or the hub plots the course there and back to the hub, on the map and on the hydrogen gauge; clicking selects
## it, and FLY flies the ship there (docking with a wreck), unless the tank couldn't get it there and back to the hub.
## Flying takes no time. The flights go through the GameSession, which keeps the system, the ship and the tank. The
## player opens and closes it.

## The map's side as a fraction of the screen height, and its limits in pixels.
const MAP_FRACTION := 0.72
const MIN_MAP := 320.0
const MAX_MAP := 760.0
## The width of the right column's placards, so it doesn't change with what they say.
const PANEL_WIDTH := 300.0
const NONE := SystemMapView.NONE
const HUB := SystemMapView.HUB

@export var fly_sound: AudioStream = preload("res://assets/audio/ship/thruster_burn.wav")

## What the readouts say, for tests: e.g. "18/24", "HAULER", "FLY  ·  4" and "Docked with the hauler at the Long
## Fall." The details are the label and value of each row, e.g. "WHERE at the Long Fall · ROBOTS about 4 active".
var hydrogen_text := ""
var target_text := ""
var details_text := ""
var fly_text := ""
var status_text := ""
## The target clicked last (a wreck's index in the system's list, HUB or NONE), and the one whose details show.
var selected := NONE
var shown := NONE

var _map: SystemMapView
var _map_detail: Label
var _system_name: Label
var _system_kind: Label
var _day: Label
var _gauge: FuelGauge
var _hydrogen: Label
var _gauge_note: Label
var _target_title: Label
var _target_where: Label
var _details: GridContainer
var _fly_button: PanelContainer
var _fly_style: StyleBoxFlat
var _fly_label: Label
var _fly_hovered := false
var _status: Label


func _build() -> void:
	_centre_gap = 0.02
	_map = SystemMapView.new()
	_map_detail = _label("", 12, DIM_TEXT_COLOR, true)
	_left_column.add_child(_placard("SYSTEM MAP", _map_detail, _map))
	var system_body := VBoxContainer.new()
	system_body.add_theme_constant_override("separation", 2)
	_system_name = _label("", 24, INK_COLOR, false)
	_system_kind = _label("", 12, DIM_TEXT_COLOR, false)
	system_body.add_child(_system_name)
	system_body.add_child(_system_kind)
	_day = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_sized(_placard("STAR SYSTEM", _day, system_body)))
	var fuel_body := VBoxContainer.new()
	fuel_body.add_theme_constant_override("separation", 6)
	_gauge = FuelGauge.new()
	_gauge.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 12.0)
	_gauge_note = _label("", 12, DIM_TEXT_COLOR, false)
	fuel_body.add_child(_gauge)
	fuel_body.add_child(_gauge_note)
	_hydrogen = _label("", 13, INK_COLOR, true)
	_right_column.add_child(_sized(_placard("HYDROGEN", _hydrogen, fuel_body)))
	var target_body := VBoxContainer.new()
	target_body.add_theme_constant_override("separation", 10)
	_target_where = _label("", 13, DIM_TEXT_COLOR, false)
	_target_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_where.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	target_body.add_child(_target_where)
	_details = GridContainer.new()
	_details.columns = 2
	_details.add_theme_constant_override("h_separation", 14)
	_details.add_theme_constant_override("v_separation", 6)
	target_body.add_child(_details)
	_fly_button = PanelContainer.new()
	_fly_style = StyleBoxFlat.new()
	_fly_style.set_border_width_all(1)
	_fly_style.set_corner_radius_all(2)
	_fly_style.content_margin_top = 6.0
	_fly_style.content_margin_bottom = 6.0
	_fly_button.add_theme_stylebox_override("panel", _fly_style)
	_fly_label = _label("", 13, INK_COLOR, true)
	_fly_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fly_button.add_child(_fly_label)
	target_body.add_child(_fly_button)
	_target_title = _label("", 11, DIM_TEXT_COLOR, true)
	_right_column.add_child(_sized(_placard("", _label("", 12, DIM_TEXT_COLOR, true), target_body, _target_title)))
	_status = _label("", 13, DIM_TEXT_COLOR, false)
	# It wraps within the column and keeps room for three lines, so a long message never moves the placards.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_right_column.add_child(_status)


func _hints() -> Array:
	return [[&"inventory_drag", "Select"], [&"", "Click FLY to fly there"], [&"inventory", "Close"]]


## Opens the map on the GameSession's system, ship and tank, with nothing selected.
func open() -> void:
	var system := GameSession.system
	var side := clampf(roundf(get_viewport_rect().size.y * MAP_FRACTION), MIN_MAP, MAX_MAP)
	_map.setup(system, side, _font, _label_font)
	selected = NONE
	shown = NONE
	_system_name.text = system.definition.display_name if system else "No system"
	_system_kind.text = system.definition.describe() if system else ""
	_day.text = "DAY %d" % GameSession.day
	if not GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.connect(_update_fuel)
	_set_status("", DIM_TEXT_COLOR)
	_update()
	_show_screen()
	Log.info("🪐 System map opened: system=%s, wrecks=%d, hydrogen=%d, at_hub=%s, docked=%s, map=%.0f px" % [
		system.definition.id if system else "none", system.wrecks.size() if system else 0, GameSession.hydrogen,
		GameSession.at_hub, GameSession.docked.definition.id if GameSession.docked else "none", side])


func close() -> void:
	if not is_open:
		Log.info("🪐 System map not closed, it isn't open")
		return
	_hide_screen()
	if GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.disconnect(_update_fuel)
	Log.info("🪐 System map closed: hydrogen=%d, at_hub=%s, docked=%s" % [
		GameSession.hydrogen, GameSession.at_hub, GameSession.docked.definition.id if GameSession.docked else "none"])


## Selects a target (a wreck's index in the system's list, HUB or NONE): its details show and its course is plotted.
func select(target: int) -> void:
	selected = target
	_update()
	Log.info("🪐 Target selected: target=%s" % _target_name(target))


## Flies the ship to the selected target. Returns whether it flew; when it can't, the status line says why.
func fly() -> bool:
	var target := selected
	if GameSession.system == null or target == NONE:
		_refuse("Select a wreck or the hub on the map first.")
		Log.info("🪐 Nothing selected to fly to")
		return false
	if _is_here(target):
		_refuse("The ship is already there.")
		Log.info("🪐 Not flown, the ship is already there: target=%s" % _target_name(target))
		return false
	var spot := _map.target_spot(target)
	var needed := GameSession.hydrogen_needed(spot) if target != HUB else GameSession.flight_cost(spot)
	if needed > GameSession.hydrogen:
		_refuse("Not enough hydrogen: flying there and back to the hub takes %d, the tank holds %d. Refuel at the hub." % [
			needed, GameSession.hydrogen])
		Log.info("🪐 Not flown, not enough hydrogen: target=%s, needed=%d, hydrogen=%d" % [
			_target_name(target), needed, GameSession.hydrogen])
		return false
	var wreck: SystemWreck = GameSession.system.wrecks[target] if target != HUB else null
	var flown := GameSession.fly_to_wreck(wreck) if wreck else GameSession.fly_to_hub()
	if not flown:
		_refuse("The ship couldn't fly there.")
		Log.warning("🪐 Flight refused by the session: target=%s" % _target_name(target))
		return false
	_play(fly_sound)
	_map.fly_marker()
	if wreck:
		_set_status("Docked with the %s %s. Board it through the airlock." % [wreck.title().to_lower(), wreck.where()],
			DIM_TEXT_COLOR)
	else:
		_set_status("Back at the hub. Trade and refuel at the trader terminal.", DIM_TEXT_COLOR)
	_update()
	Log.info("🪐 Flew: target=%s, hydrogen=%d" % [_target_name(target), GameSession.hydrogen])
	return true


## Where a target is on the screen, in this control's pixels: where the pointer goes to pick it.
func target_center(target: int) -> Vector2:
	var middle := _map.get_global_transform() * _map.to_pixels(_map.target_spot(target))
	return get_global_transform().affine_inverse() * middle


## The middle of the FLY button, in this control's pixels.
func fly_button_center() -> Vector2:
	return get_global_transform().affine_inverse() * _fly_button.get_global_rect().get_center()


## Whether the map is still flying the ship's marker along its course.
func is_flying() -> bool:
	return _map.is_flying()


func _handle_input(event: InputEvent) -> bool:
	if not event.is_action_pressed("inventory_drag"):
		return false
	if _pointer_over(_fly_button):
		fly()
	elif _pointer_over(_map):
		select(_map.target_at(_map_point()))
	return true


## What the pointer is on: the target and place under it on the map, and whether it is on the FLY button.
func _refresh() -> void:
	var on_map := _pointer_over(_map)
	var under := _map.target_at(_map_point()) if on_map else NONE
	var place := _map.place_at(_map_point()) if on_map and under == NONE else -1
	var over_fly := _pointer_over(_fly_button)
	var next := under if under != NONE else selected
	if next != shown or place != _map.hovered_place or over_fly != _fly_hovered:
		_map.hovered_place = place
		_fly_hovered = over_fly
		_update()
	super()


## Shows the target under the pointer (or else the selected one): its details, its course on the map and the gauge,
## and what FLY would do.
func _update() -> void:
	var system := GameSession.system
	var on_map := _pointer_over(_map) if is_open else false
	var under := _map.target_at(_map_point()) if on_map else NONE
	shown = under if under != NONE else selected
	_map_detail.text = "%d WRECKS" % system.wrecks.size() if system else ""
	var needed := 0
	var burn := 0
	if system and shown != NONE and not _is_here(shown):
		var spot := _map.target_spot(shown)
		burn = GameSession.flight_cost(spot)
		needed = GameSession.hydrogen_needed(spot) if shown != HUB else burn
	var can_fly := needed <= GameSession.hydrogen
	_map.shown = shown
	_map.selected = selected
	_map.course_ok = can_fly
	_map.queue_redraw()
	_gauge.set_state(GameSession.HYDROGEN_TANK, GameSession.hydrogen, burn, needed - burn)
	_show_fuel_note(burn, needed, can_fly)
	_show_target(shown)
	_show_fly_button(shown, burn, can_fly)


func _update_fuel(_hydrogen_left: int) -> void:
	_update()


func _show_fuel_note(burn: int, needed: int, can_fly: bool) -> void:
	hydrogen_text = "%d/%d" % [GameSession.hydrogen, GameSession.HYDROGEN_TANK]
	_hydrogen.text = hydrogen_text
	if burn == 0:
		_gauge_note.text = "Bought at the hub" if not GameSession.at_hub else "At the hub: refuel at the trader terminal"
	elif shown == HUB:
		_gauge_note.text = "%d to fly back to the hub" % burn
	elif can_fly:
		_gauge_note.text = "%d to fly there  ·  %d kept for the way back" % [burn, needed - burn]
	else:
		_gauge_note.text = "%d needed there and back, %d short" % [needed, needed - GameSession.hydrogen]
	_gauge_note.add_theme_color_override("font_color", DIM_TEXT_COLOR if can_fly else DANGER_COLOR)


## The target placard: a wreck's type, where it lies, its robots and the gear it requires; the hub's name and what it
## is for; or how to pick something.
func _show_target(target: int) -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var rows: Array = []
	var system := GameSession.system
	if target == NONE or system == null:
		target_text = "NOTHING SELECTED"
		_target_where.text = "Point at a wreck or the hub on the map to see what is there, and click to select it."
	elif target == HUB:
		target_text = system.definition.hub_name().to_upper()
		var world: SystemPlace = system.definition.places[system.hub_place] \
			if not system.definition.places.is_empty() else null
		_target_where.text = "The Hanse's trader hub%s." % (" orbiting %s" % world.display_name if world else "")
		rows = [["TRADE", "Sell loot, buy gear"], ["FUEL", "Hydrogen, always in stock"]]
	else:
		var wreck := system.wrecks[target]
		target_text = wreck.title().to_upper()
		var place_kind := " · %s" % wreck.place.kind_name() if wreck.place else ""
		_target_where.text = "%s %s%s" % [wreck.title(), wreck.where(), place_kind]
		rows = [["ROBOTS", _robots_text(wreck)], ["REQUIRES", "No special gear"]]
	_target_title.text = target_text
	var lines: Array[String] = []
	for row: Array in rows:
		var name_label := _label(row[0], 10, DIM_TEXT_COLOR, true)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value_label := _label(row[1], 15, INK_COLOR, false)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_details.add_child(name_label)
		_details.add_child(value_label)
		lines.append("%s %s" % row)
	details_text = " · ".join(lines)


## What the scan says about a wreck's robots, starting with a capital: "About 4 robots active".
func _robots_text(wreck: SystemWreck) -> String:
	var estimate := wreck.roll.robots_estimate()
	return estimate.left(1).to_upper() + estimate.substr(1)


## FLY lights up in the laser's blue when the ship can fly to what shows, brighter under the pointer; it says why not
## when it can't.
func _show_fly_button(target: int, burn: int, can_fly: bool) -> void:
	var active := false
	if target == NONE:
		fly_text = "FLY"
	elif _is_here(target):
		fly_text = "DOCKED" if target != HUB else "AT THE HUB"
	elif not can_fly:
		fly_text = "NOT ENOUGH HYDROGEN"
	else:
		fly_text = "FLY  ·  %d" % burn
		active = true
	_fly_label.text = fly_text
	_fly_style.border_color = LASER_COLOR if active else Color(DANGER_COLOR if target != NONE and not can_fly else INK_COLOR, 0.3)
	_fly_style.bg_color = Color(LASER_COLOR, 0.28 if _fly_hovered else 0.12) if active else Color(PLACARD_COLOR, 0.4)
	_fly_label.add_theme_color_override("font_color", INK_COLOR if active else Color(DIM_TEXT_COLOR, 0.6))


## Whether the ship is at a target already: docked with that wreck, or at the hub.
func _is_here(target: int) -> bool:
	if target == HUB:
		return GameSession.at_hub
	var system := GameSession.system
	return system != null and target >= 0 and target < system.wrecks.size() \
		and system.wrecks[target].roll == GameSession.docked


func _refuse(message: String) -> void:
	_play(bump_sound)
	_set_status(message, DANGER_COLOR)


func _set_status(text: String, color: Color) -> void:
	status_text = text
	_status.text = text
	_status.add_theme_color_override("font_color", color)


## The pointer in the map's own pixels.
func _map_point() -> Vector2:
	return _map.get_global_transform().affine_inverse() * (get_global_transform() * pointer)


func _target_name(target: int) -> String:
	if target == HUB:
		return "hub"
	var system := GameSession.system
	if system and target >= 0 and target < system.wrecks.size():
		return "%s %s" % [system.wrecks[target].roll.definition.id, system.wrecks[target].where()]
	return "none"


## A placard as wide as the column.
func _sized(placard: PanelContainer) -> PanelContainer:
	placard.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	return placard


## Centres the map and the column together, rather than each either side of the screen's centre.
func _layout() -> void:
	super()
	if not is_open:
		return
	var shift := (_left_column.size.x - _right_column.size.x) / 2.0
	_left_column.position.x += shift
	_right_column.position.x += shift
