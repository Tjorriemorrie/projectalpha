class_name HitMarkers
extends Control
## Red arcs round the centre of the screen pointing to where recent hits came from. They keep pointing at the source
## as the player turns, and fade out. Straight ahead is the top of the ring, behind is the bottom.

const RADIUS := 120.0
## Half the width of a marker, in radians (22°).
const HALF_WIDTH := 0.384
const WIDTH := 4.0
const LIFETIME := 1.4
const MAX_MARKERS := 4
const COLOR := Color(1.0, 0.12, 0.08)

## Each marker is [source_position: Vector3, age: float].
var _markers: Array = []


func add(source_position: Vector3) -> void:
	_markers.append([source_position, 0.0])
	if _markers.size() > MAX_MARKERS:
		_markers.pop_front()
	queue_redraw()


func clear() -> void:
	_markers.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _markers.is_empty():
		return
	for marker in _markers:
		marker[1] += delta
	_markers = _markers.filter(func(marker: Array) -> bool: return marker[1] < LIFETIME)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var centre := size / 2.0
	for marker in _markers:
		var local: Vector3 = camera.global_basis.inverse() * ((marker[0] as Vector3) - camera.global_position)
		# 0 is straight ahead (the top of the screen), growing clockwise; draw angles start at the right.
		var angle := atan2(local.x, -local.z) - PI / 2.0
		var alpha := 1.0 - (marker[1] as float) / LIFETIME
		draw_arc(centre, RADIUS, angle - HALF_WIDTH, angle + HALF_WIDTH, 16, Color(COLOR, alpha * alpha), WIDTH, true)
