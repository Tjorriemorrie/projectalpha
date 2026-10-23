class_name FuelGauge
extends Control
## The ship's hydrogen tank as a row of segments, one per unit, like the heat gauge: full segments are the hydrogen in
## the tank. A planned flight shows on it: the segments it would burn in the laser's blue, and those it keeps for the
## way back to the hub outlined in blue. When the tank can't fly it, the units missing are outlined in red. Redraws only
## when something changes.

const SEGMENT_GAP := 2.0
const EMPTY_COLOR := Color(0.862745, 0.901961, 0.941176, 0.1)
const EMPTY_EDGE := Color(0.862745, 0.901961, 0.941176, 0.28)
const FULL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.8)
const BURN_COLOR := Color(0.62, 0.82, 1.0)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)

var segments := 24
var hydrogen := 0
## The planned flight's burn and the hydrogen it keeps for the way back to the hub; both 0 with no flight planned.
var burn := 0
var reserve := 0


func set_state(new_segments: int, new_hydrogen: int, new_burn: int, new_reserve: int) -> void:
	if new_segments == segments and new_hydrogen == hydrogen and new_burn == burn and new_reserve == reserve:
		return
	segments = new_segments
	hydrogen = new_hydrogen
	burn = new_burn
	reserve = new_reserve
	queue_redraw()


func _draw() -> void:
	var width := (size.x - SEGMENT_GAP * (segments - 1)) / segments
	var needed := burn + reserve
	var short := needed > hydrogen
	for i in segments:
		var rect := Rect2(i * (width + SEGMENT_GAP), 0.0, width, size.y)
		draw_rect(rect, EMPTY_COLOR)
		draw_rect(rect, EMPTY_EDGE, false, 1.0)
		if short:
			if i < hydrogen:
				draw_rect(rect, Color(FULL_COLOR, 0.45))
			elif i < needed:
				draw_rect(rect.grow(-0.5), DANGER_COLOR, false, 1.0)
			continue
		if i >= hydrogen:
			continue
		if i >= hydrogen - burn:
			draw_rect(rect, BURN_COLOR)
		elif i >= hydrogen - needed:
			draw_rect(rect, Color(FULL_COLOR, 0.35))
			draw_rect(rect.grow(-0.5), BURN_COLOR, false, 1.0)
		else:
			draw_rect(rect, FULL_COLOR)
