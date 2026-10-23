class_name StarMapView
extends Control
## The star map's chart, part of the StarMapScreen: the whole cluster on the dark scope, north (towards the core worlds)
## up and deep space down, with a scale bar. Each faction's territory is a faint tinted halo round its systems (the
## colours of galaxy-map.svg), every system a small star glyph in its star's colour (filled once visited, a ring until
## then), the route so far a faint trail, and the ship the laser-blue ring with its slow ping round the system it is
## in. Round the ship a dashed circle marks the jump range, with a lane to each system in range and the antimatter
## that jump burns, red when the tank can't fly it. Names show for the systems that matter from here (in range,
## visited, known, and the one on show or selected); every known system carries how many ships it holds. The system on
## show (hovered, or else selected) is ringed and its lane drawn bright; the selected one gets corner brackets. It
## decides nothing; the screen tells it what to show.

const INK_COLOR := SystemMapView.INK_COLOR
const DIM_TEXT_COLOR := SystemMapView.DIM_TEXT_COLOR
const LASER_COLOR := SystemMapView.LASER_COLOR
const DANGER_COLOR := SystemMapView.DANGER_COLOR
const BACKING_COLOR := SystemMapView.BACKING_COLOR
const SCOPE_COLOR := SystemMapView.SCOPE_COLOR
const OWNER_COLORS := {
	StarSystemDefinition.Owner.HALDEN_MORI: Color(0.878, 0.345, 0.298),
	StarSystemDefinition.Owner.MASSEY: Color(0.91, 0.663, 0.235),
	StarSystemDefinition.Owner.CORVID: Color(0.718, 0.639, 0.918),
	StarSystemDefinition.Owner.FREE: Color(0.486, 0.788, 0.424),
	StarSystemDefinition.Owner.CONTESTED: Color(0.286, 0.737, 0.839)}
## How far a territory's halo reaches round each of its systems, in light years, and how strongly it tints.
const HALO_RADIUS := 4.6
const HALO_ALPHA := 0.055
## Light years kept clear round the furthest systems, for their names, and pixels round the chart.
const REACH_MARGIN := 3.2
const EDGE_MARGIN := 10.0
## The widest the chart gets against its height, however wide the cluster is.
const MAX_ASPECT := 1.4
## How close the pointer must be to a system to pick it, in pixels.
const PICK_RADIUS := 11.0
const PING_PERIOD := 2.4
## How long the scale bar is, in light years.
const SCALE_BAR := 10.0

var systems: Array[StarSystemDefinition] = []
## The system the ship is in, and those a jump from it reaches.
var current: StarSystemDefinition
var in_range: Array[StarSystemDefinition] = []
## The system whose details show (hovered, or else selected) and the selected one; null for none.
var shown: StarSystemDefinition
var selected: StarSystemDefinition

## Half the cluster's width and height in light years, with room for names.
var _reach := Vector2.ONE
var _font: Font
var _label_font: Font
var _ping := 0.0


## Lays the chart out for every system, height pixels tall and as wide as the cluster's shape asks, up to max_width.
func setup(all_systems: Array, height: float, max_width: float, font: Font, label_font: Font) -> void:
	systems.clear()
	for system in all_systems:
		if system is StarSystemDefinition:
			systems.append(system)
	_font = font
	_label_font = label_font
	_reach = Vector2.ONE
	for system in systems:
		_reach = Vector2(maxf(_reach.x, absf(system.map_position.x)), maxf(_reach.y, absf(system.map_position.y)))
	_reach += Vector2.ONE * REACH_MARGIN
	var width := minf(height * minf(_reach.x / _reach.y, MAX_ASPECT), max_width)
	custom_minimum_size = Vector2(maxf(width, height * 0.8), height)
	refresh()


## Reads where the ship is and what it can reach from the GameSession again.
func refresh() -> void:
	current = GameSession.system.definition if GameSession.system else null
	in_range = GameSession.jump_targets()
	queue_redraw()


## Pixels per light year, so the whole cluster fits.
func map_scale() -> float:
	return minf((size.x / 2.0 - EDGE_MARGIN) / _reach.x, (size.y / 2.0 - EDGE_MARGIN) / _reach.y)


## Where a system is on the chart, in this control's pixels (north up).
func to_pixels(system: StarSystemDefinition) -> Vector2:
	return size / 2.0 + Vector2(system.map_position.x, -system.map_position.y) * map_scale()


## The system nearest a point in this control's pixels, within PICK_RADIUS, or null.
func system_at(point: Vector2) -> StarSystemDefinition:
	var best: StarSystemDefinition = null
	var best_distance := PICK_RADIUS
	for system in systems:
		var distance := to_pixels(system).distance_to(point)
		if distance <= best_distance:
			best = system
			best_distance = distance
	return best


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_ping = fmod(_ping + delta, PING_PERIOD)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SCOPE_COLOR)
	if systems.is_empty():
		return
	_draw_frame()
	_draw_halos()
	_draw_trail()
	if current:
		_draw_range()
	for system in systems:
		_draw_system(system)
	if current:
		_draw_ship()
	if selected:
		_draw_reticle(to_pixels(selected))
	if shown and shown != selected:
		draw_arc(to_pixels(shown), 9.0, 0.0, TAU, 24, Color(INK_COLOR, 0.55), 1.0, true)


## Which way the core worlds lie and where deep space begins, faint at the chart's top and bottom, and a scale bar.
func _draw_frame() -> void:
	var core := "CORE WORLDS"
	var deep := "DEEP SPACE"
	var faint := Color(DIM_TEXT_COLOR, 0.45)
	var core_width := _label_font.get_string_size(core, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var deep_width := _label_font.get_string_size(deep, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_label_font, Vector2((size.x - core_width) / 2.0, 16.0), core, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, faint)
	draw_string(_label_font, Vector2((size.x - deep_width) / 2.0, size.y - 9.0), deep, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		faint)
	var bar := SCALE_BAR * map_scale()
	var start := Vector2(14.0, size.y - 14.0)
	draw_line(start, start + Vector2(bar, 0.0), faint, 1.0)
	draw_line(start + Vector2(0.0, -3.0), start + Vector2(0.0, 3.0), faint, 1.0)
	draw_line(start + Vector2(bar, -3.0), start + Vector2(bar, 3.0), faint, 1.0)
	draw_string(_label_font, start + Vector2(bar + 6.0, 3.0), "%d LY" % SCALE_BAR, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		faint)


## A soft tint round every system in its owner's colour, so each territory reads as one region.
func _draw_halos() -> void:
	var radius := HALO_RADIUS * map_scale()
	for system in systems:
		var color: Color = OWNER_COLORS.get(system.owner, INK_COLOR)
		draw_circle(to_pixels(system), radius, Color(color, HALO_ALPHA))
		draw_circle(to_pixels(system), radius * 0.6, Color(color, HALO_ALPHA * 0.6))


## The route so far, from the start system to the one the ship is in.
func _draw_trail() -> void:
	var route := GameSession.route
	for index in range(1, route.size()):
		if route[index - 1] == route[index]:
			continue
		draw_line(to_pixels(route[index - 1]), to_pixels(route[index]), Color(LASER_COLOR, 0.28), 2.0, true)


## The jump range round the ship as a dashed circle, and a lane to every system in range with the antimatter the jump
## burns: bright for the one on show, red where the tank can't fly it.
func _draw_range() -> void:
	var centre := to_pixels(current)
	var radius := Galaxy.JUMP_RANGE * map_scale()
	var dashes := 72
	for i in dashes:
		var from := TAU * i / dashes
		draw_arc(centre, radius, from, from + TAU / dashes * 0.5, 3, Color(LASER_COLOR, 0.32), 1.0, true)
	for target in in_range:
		var cost := GameSession.jump_cost(target)
		var fits := cost <= GameSession.antimatter
		var bright := target == shown or target == selected
		var color := LASER_COLOR if fits else DANGER_COLOR
		_draw_lane(centre, to_pixels(target), Color(color, 0.95 if bright else 0.3), "%d" % cost, bright)


func _draw_lane(start: Vector2, end: Vector2, color: Color, text: String, boxed: bool) -> void:
	var length := start.distance_to(end)
	if length < 1.0:
		return
	var direction := (end - start) / length
	var at := 11.0
	while at < length - 9.0:
		draw_line(start + direction * at, start + direction * minf(at + 5.0, length - 9.0), color, 1.5 if boxed else 1.0,
			true)
		at += 9.0
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var middle := start + (end - start) * 0.55
	var box := Rect2(middle - text_size / 2.0 - Vector2(3.0, 1.0), text_size + Vector2(6.0, 2.0))
	draw_rect(box, BACKING_COLOR)
	if boxed:
		draw_rect(box, color, false, 1.0)
	draw_string(_font, middle + Vector2(-text_size.x / 2.0, text_size.y / 2.0 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, color)


## A system's glyph in its star's colour, filled once visited; its name where it matters from here, and how many
## ships it holds once known.
func _draw_system(system: StarSystemDefinition) -> void:
	var at := to_pixels(system)
	var color: Color = SystemMapView.STAR_COLORS.get(system.star, INK_COLOR)
	var visited := GameSession.has_visited(system)
	if visited:
		draw_circle(at, 3.0, color)
	else:
		draw_arc(at, 2.6, 0.0, TAU, 12, Color(color, 0.8), 1.0, true)
	var known := GameSession.known_system(system)
	var named := system == current or system == shown or system == selected or visited or known != null \
		or in_range.has(system)
	if not named:
		return
	var lit := system == current or system == shown or system == selected
	var ink := INK_COLOR if lit else Color(DIM_TEXT_COLOR, 0.85 if in_range.has(system) else 0.6)
	var count := "  %d" % known.wrecks.size() if known else ""
	var spot := _name_spot(at, system.display_name + count)
	draw_string(_font, spot, system.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	if known:
		var after := _font.get_string_size(system.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, spot + Vector2(after, 0.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LASER_COLOR)


## Where a name goes beside its glyph: on its right, clear of the ship's ring, or on its left near the chart's east
## edge.
func _name_spot(at: Vector2, text: String) -> Vector2:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	if at.x + 11.0 + width > size.x - 4.0:
		return at + Vector2(-11.0 - width, 4.0)
	return at + Vector2(11.0, 4.0)


## The ship: a laser-blue ring round the system it is in, with a slow ping.
func _draw_ship() -> void:
	var at := to_pixels(current)
	draw_arc(at, 8.0, 0.0, TAU, 32, LASER_COLOR, 1.5, true)
	var ping := _ping / PING_PERIOD
	draw_arc(at, 8.0 + ping * 14.0, 0.0, TAU, 40, Color(LASER_COLOR, 0.5 * (1.0 - ping)), 1.0, true)


## Corner brackets round the selected system.
func _draw_reticle(at: Vector2) -> void:
	var reach := 11.0
	var arm := 4.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip := at + corner * reach
		draw_line(tip, tip - Vector2(corner.x * arm, 0.0), LASER_COLOR, 1.5)
		draw_line(tip, tip - Vector2(0.0, corner.y * arm), LASER_COLOR, 1.5)
