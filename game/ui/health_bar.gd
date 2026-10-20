class_name HealthBar
extends Control
## A thin bar of how much health is left, which turns red when one more body hit could kill.

const TRACK_COLOR := Color(0.862745, 0.901961, 0.941176, 0.16)
const FILL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.9)
const CRITICAL_COLOR := Color(1.0, 0.12, 0.08)

var fraction := 1.0
var critical := false


func set_state(new_fraction: float, new_critical: bool) -> void:
	if is_equal_approx(new_fraction, fraction) and new_critical == critical:
		return
	fraction = clampf(new_fraction, 0.0, 1.0)
	critical = new_critical
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TRACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fraction, size.y)), CRITICAL_COLOR if critical else FILL_COLOR)
