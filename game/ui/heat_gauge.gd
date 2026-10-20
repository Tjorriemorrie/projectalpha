class_name HeatGauge
extends Control
## The loaded thermal clip as a row of segments, one per uncharged shot: hot segments are the heat already in the
## clip, cool ones the shots left. While a shot charges, the segments it would heat blink in the laser's colour, so
## the player sees what the shot will cost before letting go. During a reload the row fills with its progress.
## Redraws only when something changes (and while blinking).

const SEGMENT_GAP := 2.0
const COOL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.16)
const COOL_EDGE := Color(0.862745, 0.901961, 0.941176, 0.3)
## Older heat glows darker, the newest brightest.
const HOT_OLD := Color(0.62, 0.2, 0.05)
const HOT_NEW := Color(1.0, 0.45, 0.12)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const CHARGE_COLOR := Color(0.62, 0.82, 1.0)
const RELOAD_COLOR := Color(0.862745, 0.901961, 0.941176, 0.8)
## Blinks per second of the charge preview.
const BLINK_RATE := 3.0

var segments := 20
var heat := 0.0
## The heat the shot being charged would put into the clip; 0 when not charging.
var charge_heat := 0.0
var low := false
var reload_progress := -1.0

var _blink := 0.0


func set_state(new_heat: float, new_charge_heat: float, new_low: bool, new_reload_progress: float) -> void:
	if is_equal_approx(new_heat, heat) and is_equal_approx(new_charge_heat, charge_heat) and new_low == low \
			and is_equal_approx(new_reload_progress, reload_progress):
		return
	if charge_heat <= 0.0 and new_charge_heat > 0.0:
		_blink = 0.0
	heat = new_heat
	charge_heat = new_charge_heat
	low = new_low
	reload_progress = new_reload_progress
	queue_redraw()


func _process(delta: float) -> void:
	if charge_heat > 0.0:
		_blink += delta
		queue_redraw()


func _draw() -> void:
	var width := (size.x - SEGMENT_GAP * (segments - 1)) / segments
	var hot := heat * segments
	var charged := (heat + charge_heat) * segments
	var blink := 0.55 + 0.45 * cos(_blink * TAU * BLINK_RATE)
	for i in segments:
		var rect := Rect2(i * (width + SEGMENT_GAP), 0.0, width, size.y)
		if reload_progress >= 0.0:
			draw_rect(rect, RELOAD_COLOR if i < reload_progress * segments else COOL_COLOR)
			continue
		draw_rect(rect, COOL_COLOR)
		draw_rect(rect, DANGER_COLOR if low else COOL_EDGE, false, 1.0)
		var hot_fill := clampf(hot - i, 0.0, 1.0)
		if hot_fill > 0.0:
			var age := float(i) / maxf(hot - 1.0, 1.0)
			draw_rect(Rect2(rect.position, Vector2(width * hot_fill, size.y)), HOT_OLD.lerp(HOT_NEW, age))
		var charge_fill := clampf(charged - i, 0.0, 1.0) - hot_fill
		if charge_fill > 0.0:
			var start := rect.position + Vector2(width * hot_fill, 0.0)
			draw_rect(Rect2(start, Vector2(width * charge_fill, size.y)), Color(CHARGE_COLOR, blink))
