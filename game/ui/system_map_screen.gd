class_name SystemMapScreen
extends MapScreen
## The system map, the first of the cockpit console's map tabs (see MapScreen): the star system the ship is in as an
## orbital diagram (SystemMapView) on the left, and on the right the system, the hydrogen in the tank, what the
## pointer is on or was clicked last, a FLY button and a status line. A wreck shows what makes it dangerous, never a
## difficulty level: its type, where it lies, how many robots its scan expects and the gear it requires. Pointing at a
## wreck or the hub plots the course there and back to the hub, on the map and on the hydrogen gauge; clicking selects
## it, and FLY flies the ship there (docking with a wreck), unless the tank couldn't get it there and back to the hub.
## Flying takes no time in the game, but on the map the ship's marker flies the course for FLY_TIME_PER_UNIT a unit
## of hydrogen, and the gauge (and the ship's bar) burns a unit at each share of the way: a 3-unit flight burns one
## every third of it, while the thrusters roar for exactly as long. Away from the hub with too little hydrogen to reach any wreck and get back, the status line
## says to fly back to the hub to buy more, the only flight left. The flights go through the GameSession, which keeps
## the system, the ship and the tank. From the star map it can also show another known system (visited, or one with
## intel), read-only: its places, its hub and its wrecks with their details, but no ship, course or FLY. The player
## opens and closes it.

## The gauge shows a new amount while a flight burns its hydrogen, so the ship's bar can follow it.
signal hydrogen_shown(hydrogen: int)

const NONE := SystemMapView.NONE
const HUB := SystemMapView.HUB
## Seconds the ship's marker takes to fly a course on the map, per unit of hydrogen it burns, and at least.
const FLY_TIME_PER_UNIT := 0.5
const MIN_FLY_TIME := 1.0
## Seconds the thrusters' roar takes to swell in under the ignition and to die away on arrival, and how quiet it is
## before and after, in dB.
const ENGINE_FADE_IN := 0.4
const ENGINE_FADE_OUT := 0.15
const ENGINE_QUIET_DB := -40.0

## The thrusters, lasting as long as the flight on the map: the ignition, the roar looping until the ship arrives, and
## the stop as it does.
@export var ignite_sound: AudioStream = preload("res://assets/audio/ship/thruster_ignite.wav")
@export var engine_sound: AudioStream = preload("res://assets/audio/ship/thruster_loop.wav")
@export var stop_sound: AudioStream = preload("res://assets/audio/ship/thruster_stop.wav")

## What the readouts say, for tests: e.g. "18/24", "HAULER", "FLY  ·  4" and "MORI". The details are the label and
## value of each row, e.g. "WHERE at the Long Fall · ROBOTS about 4 active".
var hydrogen_text := ""
var target_text := ""
var details_text := ""
var fly_text := ""
var system_text := ""
## The target clicked last (a wreck's index in the system's list, HUB or NONE), and the one whose details show.
var selected := NONE
var shown := NONE

## Another known system shown read-only, or null while it shows the one the ship is in.
var _viewing: StarSystem
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
var _fly_hovered := false
## While a flight flies on the map: the hydrogen the tank held before it, what it burns, what the gauge shows (-1 when
## no flight is under way), and what the status line says on arrival.
var _burn_from := 0
var _burn := 0
var _shown_hydrogen := -1
var _arrival_text := ""
## The thrusters' looping roar, and their ignition and stop, apart from the screen's other sounds.
var _engine: AudioStreamPlayer
var _engine_shot: AudioStreamPlayer
var _engine_fade: Tween
var _engine_running := false


func _build() -> void:
	_centre_gap = 0.02
	_map = SystemMapView.new()
	_map.flight_progressed.connect(_on_flight_progressed)
	_engine = AudioStreamPlayer.new()
	_engine.name = "Engine"
	add_child(_engine)
	_engine_shot = AudioStreamPlayer.new()
	_engine_shot.name = "EngineShot"
	add_child(_engine_shot)
	_map_detail = _label("", 12, DIM_TEXT_COLOR, true)
	_left_column.add_child(_build_tabs())
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
	_fly_button = _new_button()
	target_body.add_child(_fly_button)
	_target_title = _label("", 11, DIM_TEXT_COLOR, true)
	_right_column.add_child(_sized(_placard("", _label("", 12, DIM_TEXT_COLOR, true), target_body, _target_title)))
	_build_status()


func _hints() -> Array:
	return [[&"inventory_drag", "Select"], [&"", "Click FLY to fly there"], [&"map_tab", "Star map"],
		[&"inventory", "Close"]]


func _tab() -> Tab:
	return Tab.SYSTEM


## Opens the map on the GameSession's system, ship and tank, with nothing selected; or, given another known system
## (from the star map), on that one, read-only. switching opens it in place of the star map, quietly.
func open(viewing: StarSystem = null, switching: bool = false) -> void:
	_viewing = viewing if viewing and viewing != GameSession.system else null
	var system := _system()
	_map.setup(system, _map_side(), _font, _label_font, _viewing == null)
	_shown_hydrogen = -1
	_stop_engine(false)
	selected = NONE
	shown = NONE
	system_text = system.definition.display_name.to_upper() if system else ""
	_system_name.text = system.definition.display_name if system else "No system"
	_system_kind.text = system.definition.describe() if system else ""
	_day.text = "DAY %d" % GameSession.day
	if _viewing:
		_day.text = "LAST SEEN" if GameSession.has_visited(_viewing.definition) else "INTEL"
	_fly_button.visible = _viewing == null
	if not GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.connect(_update_fuel)
	if _viewing:
		_set_status("Viewing %s from the star map, as %s. Press %s to go back." % [
			_viewing.definition.display_name,
			"you left it" if GameSession.has_visited(_viewing.definition) else "the intel shows it",
			_binding_label(&"map_tab")], DIM_TEXT_COLOR)
	elif _is_low_on_hydrogen():
		_set_status(_low_hydrogen_text(), DANGER_COLOR)
	else:
		_set_status("", DIM_TEXT_COLOR)
	_update()
	_switching = switching
	_show_screen()
	_switching = false
	Log.info("🪐 System map opened: system=%s, viewing=%s, wrecks=%d, hydrogen=%d, at_hub=%s, docked=%s, switching=%s, map=%.0f px" % [
		system.definition.id if system else "none", _viewing != null, system.wrecks.size() if system else 0,
		GameSession.hydrogen, GameSession.at_hub, GameSession.docked.definition.id if GameSession.docked else "none",
		switching, _map_side()])


## Closes the map; switching closes it for the star map to open in its place, quietly.
func close(switching: bool = false) -> void:
	if not is_open:
		Log.info("🪐 System map not closed, it isn't open")
		return
	_switching = switching
	_hide_screen()
	_switching = false
	# The ship is there already; only its flight on the map is cut short.
	if _map.is_flying():
		_map.stop_flight()
		_end_flight(false)
	if GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.disconnect(_update_fuel)
	Log.info("🪐 System map closed: hydrogen=%d, at_hub=%s, docked=%s, switching=%s" % [
		GameSession.hydrogen, GameSession.at_hub, GameSession.docked.definition.id if GameSession.docked else "none",
		switching])


## Whether it shows another known system read-only, rather than the one the ship is in.
func is_viewing_elsewhere() -> bool:
	return _viewing != null


## Selects a target (a wreck's index in the system's list, HUB or NONE): its details show and its course is plotted.
func select(target: int) -> void:
	selected = target
	_update()
	Log.info("🪐 Target selected: target=%s" % _target_name(target))


## Flies the ship to the selected target. Returns whether it flew; when it can't, the status line says why.
func fly() -> bool:
	var target := selected
	if _viewing:
		_refuse("This is %s, seen from the star map. Jump there to fly to its wrecks." % _viewing.definition.display_name)
		Log.info("🪐 Not flown, the map shows another system: viewing=%s" % _viewing.definition.id)
		return false
	if GameSession.system == null or target == NONE:
		_refuse("Select a wreck or the hub on the map first.")
		Log.info("🪐 Nothing selected to fly to")
		return false
	if _is_here(target):
		_refuse("The ship is already there.")
		Log.info("🪐 Not flown, the ship is already there: target=%s" % _target_name(target))
		return false
	if is_flying():
		Log.info("🪐 Not flown, the ship is still flying: target=%s" % _target_name(target))
		return false
	var spot := _map.target_spot(target)
	var needed := GameSession.hydrogen_needed(spot) if target != HUB else GameSession.flight_cost(spot)
	if needed > GameSession.hydrogen:
		var where := "Refuel at the trader terminal." if GameSession.at_hub else "Fly back to the hub to buy more."
		_refuse("Not enough hydrogen: flying there and back to the hub takes %d, the tank holds %d. %s" % [
			needed, GameSession.hydrogen, where])
		Log.info("🪐 Not flown, not enough hydrogen: target=%s, needed=%d, hydrogen=%d" % [
			_target_name(target), needed, GameSession.hydrogen])
		return false
	var wreck: SystemWreck = GameSession.system.wrecks[target] if target != HUB else null
	var before := GameSession.hydrogen
	var flown := GameSession.fly_to_wreck(wreck) if wreck else GameSession.fly_to_hub()
	if not flown:
		_refuse("The ship couldn't fly there.")
		Log.warning("🪐 Flight refused by the session: target=%s" % _target_name(target))
		return false
	_burn_from = before
	_burn = before - GameSession.hydrogen
	_shown_hydrogen = before
	var duration := maxf(MIN_FLY_TIME, _burn * FLY_TIME_PER_UNIT)
	_start_engine()
	_map.fly_marker(duration)
	if wreck:
		_set_status("Flying to the %s %s..." % [wreck.title().to_lower(), wreck.where()], DIM_TEXT_COLOR)
		_arrival_text = "Docked with the %s %s. Board it through the airlock." % [wreck.title().to_lower(), wreck.where()]
	else:
		_set_status("Flying back to the hub...", DIM_TEXT_COLOR)
		_arrival_text = "Back at the hub. Trade and refuel at the trader terminal."
	_update()
	hydrogen_shown.emit(_shown_hydrogen)
	Log.info("🪐 Flying: target=%s, burn=%d, hydrogen=%d, duration=%.1f s" % [
		_target_name(target), _burn, GameSession.hydrogen, duration])
	return true


## Says something in the status line, such as where the ship arrived after a jump.
func say(text: String) -> void:
	_set_status(text, DIM_TEXT_COLOR)


## Where a target is on the screen, in this control's pixels: where the pointer goes to pick it.
func target_center(target: int) -> Vector2:
	var middle := _map.get_global_transform() * _map.to_pixels(_map.target_spot(target))
	return get_global_transform().affine_inverse() * middle


## The middle of the FLY button, in this control's pixels.
func fly_button_center() -> Vector2:
	return _center_of(_fly_button)


## Whether the map is still flying the ship's marker along its course.
func is_flying() -> bool:
	return _map.is_flying()


## Whether the thrusters' roar is playing: from a flight's start until the ship arrives on the map.
func is_engine_running() -> bool:
	return _engine_running


func _handle_map_input(event: InputEvent) -> bool:
	if not event.is_action_pressed("inventory_drag"):
		return false
	if _pointer_over(_fly_button):
		# A click on FLY while the ship is still flying does nothing.
		if not is_flying():
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


## The system on show: another known one from the star map, or else the one the ship is in.
func _system() -> StarSystem:
	return _viewing if _viewing else GameSession.system


## Shows the target under the pointer (or else the selected one): its details, its course on the map and the gauge,
## and what FLY would do. Another system, shown read-only, plots no course.
func _update() -> void:
	var system := _system()
	var on_map := _pointer_over(_map) if is_open else false
	var under := _map.target_at(_map_point()) if on_map else NONE
	shown = under if under != NONE else selected
	_map_detail.text = "%d WRECKS" % system.wrecks.size() if system else ""
	var needed := 0
	var burn := 0
	if system and not _viewing and shown != NONE and not _is_here(shown):
		var spot := _map.target_spot(shown)
		burn = GameSession.flight_cost(spot)
		needed = GameSession.hydrogen_needed(spot) if shown != HUB else burn
	var can_fly := needed <= GameSession.hydrogen
	_map.shown = shown
	_map.selected = selected
	_map.course_ok = can_fly
	_map.queue_redraw()
	if _shown_hydrogen >= 0:
		# A flight under way: what is still to burn, in the laser's blue.
		_gauge.set_state(GameSession.HYDROGEN_TANK, _shown_hydrogen, _shown_hydrogen - GameSession.hydrogen, 0)
	else:
		_gauge.set_state(GameSession.HYDROGEN_TANK, GameSession.hydrogen, burn, needed - burn)
	_show_fuel_note(burn, needed, can_fly)
	_show_target(shown)
	_show_fly_button(shown, burn, can_fly)


func _update_fuel(_hydrogen_left: int) -> void:
	_update()


func _show_fuel_note(burn: int, needed: int, can_fly: bool) -> void:
	var tank := _shown_hydrogen if _shown_hydrogen >= 0 else GameSession.hydrogen
	hydrogen_text = "%d/%d" % [tank, GameSession.HYDROGEN_TANK]
	_hydrogen.text = hydrogen_text
	if _shown_hydrogen >= 0:
		_gauge_note.text = "Burning hydrogen: %d to go" % (_shown_hydrogen - GameSession.hydrogen)
	elif _viewing:
		_gauge_note.text = "In the tank, for flights in the system the ship is in"
	elif burn == 0:
		_gauge_note.text = "Bought at the hub" if not GameSession.at_hub else "At the hub: refuel at the trader terminal"
	elif shown == HUB:
		_gauge_note.text = "%d to fly back to the hub" % burn
	elif can_fly:
		_gauge_note.text = "%d to fly there  ·  %d kept for the way back" % [burn, needed - burn]
	else:
		_gauge_note.text = "%d needed there and back, %d short%s" % [needed, needed - GameSession.hydrogen,
			"" if GameSession.at_hub else ": fly back to the hub"]
	_gauge_note.add_theme_color_override("font_color", DIM_TEXT_COLOR if can_fly or _shown_hydrogen >= 0 \
		else DANGER_COLOR)


## The ship's marker moved along its course: a unit of hydrogen burns at each share of the way, and on arrival the
## status line says where the ship is.
func _on_flight_progressed(progress: float) -> void:
	if _shown_hydrogen < 0:
		return
	if progress >= 1.0:
		_end_flight()
		return
	var shown_now := _burn_from - mini(floori(progress * _burn + 0.0001), _burn)
	if shown_now == _shown_hydrogen:
		return
	_shown_hydrogen = shown_now
	_update()
	hydrogen_shown.emit(_shown_hydrogen)


## The flight is over on the map: the thrusters stop (with the clamps' knock when the ship arrives rather than the map
## closing), the gauge and the bar show the tank as it is, and the status line where the ship arrived, or that it is
## too low on hydrogen to fly anywhere but the hub.
func _end_flight(arrived: bool = true) -> void:
	if _shown_hydrogen < 0:
		return
	_shown_hydrogen = -1
	_stop_engine(arrived)
	if _is_low_on_hydrogen():
		_set_status(_low_hydrogen_text(), DANGER_COLOR)
	else:
		_set_status(_arrival_text, DIM_TEXT_COLOR)
	_update()
	hydrogen_shown.emit(GameSession.hydrogen)
	Log.info("🪐 Flight over on the map: hydrogen=%d, at_hub=%s, docked=%s" % [
		GameSession.hydrogen, GameSession.at_hub, GameSession.docked.definition.id if GameSession.docked else "none"])


## Whether the ship, away from the hub with nothing docked, can't reach any wreck and get back: the hub is the only
## flight left.
func _is_low_on_hydrogen() -> bool:
	return not _viewing and GameSession.system != null and not GameSession.at_hub and GameSession.docked == null \
		and not GameSession.can_reach_a_wreck()


## The thrusters light: the ignition plays while the roar swells in, and the roar loops until _stop_engine().
func _start_engine() -> void:
	_engine_shot.stream = ignite_sound
	_engine_shot.play()
	if _engine_fade:
		_engine_fade.kill()
	_engine.stream = engine_sound
	_engine.volume_db = ENGINE_QUIET_DB
	_engine.play()
	_engine_running = true
	_engine_fade = create_tween()
	_engine_fade.tween_property(_engine, "volume_db", 0.0, ENGINE_FADE_IN)


## The roar dies away; on arrival the stop plays too.
func _stop_engine(arrived: bool) -> void:
	if not _engine_running:
		return
	_engine_running = false
	if _engine_fade:
		_engine_fade.kill()
	_engine_fade = create_tween()
	_engine_fade.tween_property(_engine, "volume_db", ENGINE_QUIET_DB, ENGINE_FADE_OUT)
	_engine_fade.tween_callback(_engine.stop)
	if arrived:
		_engine_shot.stream = stop_sound
		_engine_shot.play()


func _low_hydrogen_text() -> String:
	return "Low on hydrogen: no wreck is in reach with enough left to get back. Fly back to the hub to buy more."


## The target placard: a wreck's type, where it lies, its robots and the gear it requires; the hub's name and what it
## is for; or how to pick something.
func _show_target(target: int) -> void:
	_clear(_details)
	var rows: Array = []
	var system := _system()
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
		_add_detail_row(_details, row[0], row[1])
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
	_style_button(_fly_button, fly_text, active, _fly_hovered, target != NONE and not can_fly)


## Whether the ship is at a target already: docked with that wreck, or at the hub. Never in another system on show.
func _is_here(target: int) -> bool:
	if _viewing:
		return false
	if target == HUB:
		return GameSession.at_hub
	var system := GameSession.system
	return system != null and target >= 0 and target < system.wrecks.size() \
		and system.wrecks[target].roll == GameSession.docked


## The pointer in the map's own pixels.
func _map_point() -> Vector2:
	return _map.get_global_transform().affine_inverse() * (get_global_transform() * pointer)


func _target_name(target: int) -> String:
	if target == HUB:
		return "hub"
	var system := _system()
	if system and target >= 0 and target < system.wrecks.size():
		return "%s %s" % [system.wrecks[target].roll.definition.id, system.wrecks[target].where()]
	return "none"
