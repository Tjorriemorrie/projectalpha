class_name SystemMapView
extends Control
## The system map's orbital diagram, part of the SystemMapScreen: the star in the middle, its orbits, each place on its
## orbit as a glyph of its kind with its name (asteroid belts as dotted rings), the trader hub, the wrecks to board as
## chevrons with the robots the scan expects aboard, and the ship as a laser-blue ring with a slow transponder ping.
## The target on show (hovered, or else selected) gets the course plotted to it from the ship, with the hydrogen the
## flight burns, and on from there back to the hub; a course the tank can't fly is drawn in red. Targets are picked
## by index: a wreck's in the system's list, HUB or NONE. Another system, shown read-only from the star map, has no
## ship and no courses. It decides nothing; the screen tells it what to show.

## The ship's marker moved along its course, as a share of the way from 0 to 1.
signal flight_progressed(progress: float)

const NONE := -1
const HUB := -2
const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_TEXT_COLOR := Color(0.721569, 0.768627, 0.815686)
const LASER_COLOR := Color(0.62, 0.82, 1.0)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const BACKING_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.85)
## The map's own dark backdrop, so the ship behind the screen doesn't show through the orbits.
const SCOPE_COLOR := Color(0.016, 0.022, 0.032, 0.9)
const STAR_COLORS := {
	StarSystemDefinition.Star.RED_DWARF: Color(1.0, 0.52, 0.36), StarSystemDefinition.Star.YELLOW: Color(1.0, 0.86, 0.58),
	StarSystemDefinition.Star.WHITE: Color(0.9, 0.94, 1.0), StarSystemDefinition.Star.BINARY: Color(1.0, 0.86, 0.58),
	StarSystemDefinition.Star.NEUTRON: Color(0.75, 0.9, 1.0)}
## Pixels kept clear round the map's reach (see StarSystem.radius()).
const EDGE_MARGIN := 12.0
## How close the pointer must be to a target to pick it, in pixels.
const PICK_RADIUS := 14.0
## Seconds between transponder pings.
const PING_PERIOD := 2.4

var system: StarSystem
## Where the ship's marker is drawn, in map units: it flies along the course after a flight.
var ship_spot := Vector2.ZERO
## The target whose details and course show, and whether the tank can fly that course.
var shown := NONE
var selected := NONE
var course_ok := true
## Whether the ship and courses show: off for another system, shown read-only.
var show_ship := true
## The place under the pointer, whose note shows under its name, or -1.
var hovered_place := -1

var _font: Font
var _label_font: Font
var _ping := 0.0
var _flight: Tween
var _flying := false
var _flight_from := Vector2.ZERO


func setup(star_system: StarSystem, side: float, font: Font, label_font: Font, with_ship: bool = true) -> void:
	system = star_system
	show_ship = with_ship
	custom_minimum_size = Vector2(side, side)
	_font = font
	_label_font = label_font
	if _flight:
		_flight.kill()
	_flying = false
	ship_spot = GameSession.ship_position
	queue_redraw()


## Pixels per map unit, so the outer orbit fits the square.
func map_scale() -> float:
	if system == null:
		return 1.0
	return (minf(size.x, size.y) / 2.0 - EDGE_MARGIN) / system.radius()


## A spot on the map (map units from the star) in this control's pixels.
func to_pixels(spot: Vector2) -> Vector2:
	return size / 2.0 + spot * map_scale()


## Where a target is on the map, in map units; the ship's spot for NONE.
func target_spot(target: int) -> Vector2:
	if target == HUB:
		return system.hub_position
	if target >= 0 and target < system.wrecks.size():
		return system.wrecks[target].position
	return GameSession.ship_position


## The target nearest a point in this control's pixels, within PICK_RADIUS, or NONE.
func target_at(point: Vector2) -> int:
	if system == null:
		return NONE
	var best := NONE
	var best_distance := PICK_RADIUS
	var targets := range(system.wrecks.size())
	targets.append(HUB)
	for target: int in targets:
		var distance := to_pixels(target_spot(target)).distance_to(point)
		if distance <= best_distance:
			best = target
			best_distance = distance
	return best


## The place whose glyph is nearest a point in this control's pixels, within PICK_RADIUS, or -1.
func place_at(point: Vector2) -> int:
	if system == null:
		return -1
	for index in system.place_positions.size():
		if to_pixels(system.place_positions[index]).distance_to(point) <= PICK_RADIUS:
			return index
	return -1


## Flies the ship's marker along its course to where the ship is now, over duration seconds, easing in and out;
## flight_progressed tells how far along it is.
func fly_marker(duration: float) -> void:
	if _flight:
		_flight.kill()
	_flying = true
	_flight_from = ship_spot
	_flight = create_tween()
	_flight.tween_method(_move_marker, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flight.tween_callback(func() -> void: _flying = false)


## Puts the ship's marker where the ship is at once, cutting a flight short.
func stop_flight() -> void:
	if _flight:
		_flight.kill()
	_flying = false
	ship_spot = GameSession.ship_position
	queue_redraw()


func is_flying() -> bool:
	return _flying


func _move_marker(progress: float) -> void:
	ship_spot = _flight_from.lerp(GameSession.ship_position, progress)
	queue_redraw()
	flight_progressed.emit(progress)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_ping = fmod(_ping + delta, PING_PERIOD)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SCOPE_COLOR)
	if system == null:
		return
	var centre := size / 2.0
	var scale := map_scale()
	draw_line(Vector2(centre.x, 8.0), Vector2(centre.x, size.y - 8.0), Color(INK_COLOR, 0.04), 1.0)
	draw_line(Vector2(8.0, centre.y), Vector2(size.x - 8.0, centre.y), Color(INK_COLOR, 0.04), 1.0)
	var belts := {}
	for index in system.definition.places.size():
		if system.definition.places[index].kind == SystemPlace.Kind.BELT:
			belts[system.place_orbits[index]] = true
	for orbit in range(1, system.orbit_count + 1):
		var radius := orbit * StarSystem.ORBIT_SPACING * scale
		if belts.has(orbit):
			_draw_belt(centre, radius)
		else:
			draw_arc(centre, radius, 0.0, TAU, 128, Color(INK_COLOR, 0.1), 1.0, true)
	_draw_star(centre)
	for index in system.definition.places.size():
		_draw_place(index)
	_draw_hub()
	for index in system.wrecks.size():
		_draw_wreck(index)
	if show_ship and shown != NONE and not _flying:
		_draw_course(shown)
	if show_ship:
		_draw_ship()
	if selected != NONE:
		_draw_reticle(to_pixels(target_spot(selected)), LASER_COLOR)
	if shown != NONE and shown != selected:
		draw_arc(to_pixels(target_spot(shown)), 12.0, 0.0, TAU, 24, Color(INK_COLOR, 0.5), 1.0, true)


func _draw_belt(centre: Vector2, radius: float) -> void:
	var dots := maxi(48, roundi(radius * 0.6))
	for i in dots:
		var spot := centre + Vector2.from_angle(TAU * i / dots) * radius
		draw_rect(Rect2(spot - Vector2.ONE, Vector2.ONE * 2.0), Color(INK_COLOR, 0.3))


func _draw_star(centre: Vector2) -> void:
	var star := system.definition.star
	var color: Color = STAR_COLORS[star]
	draw_circle(centre, 20.0, Color(color, 0.05))
	draw_circle(centre, 12.0, Color(color, 0.12))
	match star:
		StarSystemDefinition.Star.BINARY:
			draw_circle(centre + Vector2(-4.0, 0.0), 4.5, color)
			draw_circle(centre + Vector2(5.0, 1.0), 3.5, STAR_COLORS[StarSystemDefinition.Star.WHITE])
		StarSystemDefinition.Star.NEUTRON:
			draw_line(centre + Vector2(-16.0, 10.0), centre + Vector2(16.0, -10.0), Color(color, 0.45), 1.0, true)
			draw_circle(centre, 3.0, color)
		StarSystemDefinition.Star.RED_DWARF:
			draw_circle(centre, 4.5, color)
		_:
			draw_circle(centre, 6.0, color)


## A place's glyph by its kind, its name beside it, and under the name its note while the pointer is on it.
func _draw_place(index: int) -> void:
	var place := system.definition.places[index]
	var at := to_pixels(system.place_positions[index])
	var ink := Color(INK_COLOR, 0.85 if place.habitable else 0.55)
	match place.kind:
		SystemPlace.Kind.PLANET:
			draw_circle(at, 4.5, ink)
		SystemPlace.Kind.MOON:
			draw_circle(at, 2.5, ink)
		SystemPlace.Kind.BELT:
			draw_rect(Rect2(at - Vector2.ONE * 2.5, Vector2.ONE * 5.0), ink)
		SystemPlace.Kind.STATION:
			draw_rect(Rect2(at - Vector2.ONE * 3.5, Vector2.ONE * 7.0), ink, false, 1.0)
		SystemPlace.Kind.BATTLEFIELD:
			for offset: Vector2 in [Vector2(-4.0, -2.0), Vector2(3.0, -4.0), Vector2(1.0, 3.5)]:
				draw_line(at + offset - Vector2(2.0, 2.0), at + offset + Vector2(2.0, 2.0), ink, 1.0)
				draw_line(at + offset + Vector2(-2.0, 2.0), at + offset + Vector2(2.0, -2.0), ink, 1.0)
		SystemPlace.Kind.ANOMALY:
			for i in 8:
				draw_arc(at, 8.0, TAU * i / 8.0, TAU * (i + 0.5) / 8.0, 4, ink, 1.0, true)
	if place.habitable:
		draw_arc(at, 7.5 if place.kind == SystemPlace.Kind.PLANET else 5.5, 0.0, TAU, 24, Color(INK_COLOR, 0.45), 1.0,
			true)
	var label_at := _name_spot(system.place_positions[index], place.display_name, 11)
	draw_string(_font, label_at, place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	if index == hovered_place:
		var note := "%s · %s" % [place.kind_name(), place.note]
		var note_size := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var note_at := Vector2(minf(label_at.x, size.x - note_size.x - 4.0), label_at.y + 16.0)
		draw_rect(Rect2(note_at + Vector2(-3.0, -12.0), note_size + Vector2(6.0, 4.0)), BACKING_COLOR)
		draw_string(_font, note_at, note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM_TEXT_COLOR)


func _draw_hub() -> void:
	var at := to_pixels(system.hub_position)
	var diamond := PackedVector2Array([at + Vector2(0.0, -6.0), at + Vector2(6.0, 0.0), at + Vector2(0.0, 6.0),
		at + Vector2(-6.0, 0.0)])
	draw_colored_polygon(diamond, Color(INK_COLOR, 0.9))
	draw_string(_label_font, _name_spot(system.hub_position, "HUB", 10, _label_font), "HUB", HORIZONTAL_ALIGNMENT_LEFT, -1,
		10, INK_COLOR)


## Where a name goes beside its glyph: on its right, or on its left where the map says so, so it stays on the map.
func _name_spot(spot: Vector2, text: String, font_size: int, font: Font = null) -> Vector2:
	var at := to_pixels(spot)
	if not system.name_on_left(spot):
		return at + Vector2(10.0, 4.0)
	var width := (font if font else _font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return at + Vector2(-10.0 - width, 4.0)


## A wreck's chevron, with how many robots the scan expects aboard beside it.
func _draw_wreck(index: int) -> void:
	var wreck := system.wrecks[index]
	var at := to_pixels(wreck.position)
	var chevron := PackedVector2Array([at + Vector2(0.0, -6.0), at + Vector2(5.5, 5.0), at + Vector2(0.0, 2.0),
		at + Vector2(-5.5, 5.0)])
	draw_colored_polygon(chevron, Color(INK_COLOR, 0.3 if index != shown else 0.6))
	chevron.append(chevron[0])
	draw_polyline(chevron, INK_COLOR, 1.0, true)
	draw_string(_font, at + Vector2(8.0, -3.0), "%d" % wreck.roll.expected_robots(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		DIM_TEXT_COLOR)


## The course from the ship to a target with the hydrogen it burns, and on from a wreck back to the hub.
func _draw_course(target: int) -> void:
	var to := target_spot(target)
	if StarSystem.hydrogen_between(GameSession.ship_position, to) == 0:
		return
	var color := LASER_COLOR if course_ok else DANGER_COLOR
	_draw_leg(GameSession.ship_position, to, color, 1.5)
	if target != HUB:
		_draw_leg(to, system.hub_position, Color(color, 0.4), 1.0)


func _draw_leg(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var start := to_pixels(from)
	var end := to_pixels(to)
	var length := start.distance_to(end)
	if length < 1.0:
		return
	var direction := (end - start) / length
	var at := 10.0
	while at < length - 10.0:
		draw_line(start + direction * at, start + direction * minf(at + 6.0, length - 10.0), color, width, true)
		at += 10.0
	var text := "%d" % StarSystem.hydrogen_between(from, to)
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var middle := (start + end) / 2.0
	draw_rect(Rect2(middle - text_size / 2.0 - Vector2(4.0, 1.0), text_size + Vector2(8.0, 2.0)), BACKING_COLOR)
	draw_rect(Rect2(middle - text_size / 2.0 - Vector2(4.0, 1.0), text_size + Vector2(8.0, 2.0)), color, false, 1.0)
	draw_string(_font, middle + Vector2(-text_size.x / 2.0, text_size.y / 2.0 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, color)


## The ship: a laser-blue ring round where it is (a dot too, where nothing else marks the spot), and a slow ping.
func _draw_ship() -> void:
	var at := to_pixels(ship_spot)
	draw_arc(at, 11.0, 0.0, TAU, 32, LASER_COLOR, 1.5, true)
	if _flying or (not GameSession.at_hub and GameSession.docked == null):
		draw_circle(at, 3.0, LASER_COLOR)
	var ping := _ping / PING_PERIOD
	draw_arc(at, 11.0 + ping * 16.0, 0.0, TAU, 40, Color(LASER_COLOR, 0.5 * (1.0 - ping)), 1.0, true)


## Corner brackets round the selected target.
func _draw_reticle(at: Vector2, color: Color) -> void:
	var reach := 14.0
	var arm := 5.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip := at + corner * reach
		draw_line(tip, tip - Vector2(corner.x * arm, 0.0), color, 1.5)
		draw_line(tip, tip - Vector2(0.0, corner.y * arm), color, 1.5)
