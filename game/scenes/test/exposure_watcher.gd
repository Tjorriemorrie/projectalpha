class_name ExposureWatcher
extends Node3D
## A debug stand-in for an enemy, for the test level until robots arrive in 006. Every physics frame it checks which
## parts of the player it can see from its eye: it draws a red line to every hitbox sample point in sight, glows red
## while it sees any part, and shows the parts it sees above itself.

## Emitted when the watcher starts or stops seeing a part of the player.
signal seen_parts_changed(parts: Array[Hitbox.Part])

## Physics layers that block the watcher's sight: world (1).
const SIGHT_MASK := 0b1
const SEEING_COLOR := Color(1.0, 0.12, 0.08)
const IDLE_COLOR := Color(0.55, 0.6, 0.65)

@export var player: Player
## Metres within which the watcher looks for the player.
@export var sight_range: float = 10.0

## The parts of the player the watcher can see, in Hitbox.Part order.
var seen_parts: Array[Hitbox.Part] = []

var _lines := ImmediateMesh.new()
var _eye_material := StandardMaterial3D.new()

@onready var _eye: MeshInstance3D = $Eye
@onready var _label: Label3D = $Label
@onready var _sight_lines: MeshInstance3D = $SightLines


func _ready() -> void:
	_eye_material.emission_enabled = true
	_eye.material_override = _eye_material
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = SEEING_COLOR
	_sight_lines.mesh = _lines
	_sight_lines.material_override = line_material
	_show_seen_parts()
	Log.info("👁️ Watcher ready: watcher=%s, eye=%s, sight_range=%.1f m, player=%s" % [
		name, _eye.global_position, sight_range, player.name if player else "none"])


## Runs every physics frame, so it only logs when what the watcher sees changes.
func _physics_process(_delta: float) -> void:
	var eye := _eye.global_position
	var points := PackedVector3Array()
	var parts: Array[Hitbox.Part] = []
	if player and eye.distance_to(player.global_position) <= sight_range:
		var space := get_world_3d().direct_space_state
		for hitbox in player.get_hitboxes():
			if not hitbox.is_active():
				continue
			for point in hitbox.sample_points():
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)).is_empty():
					points.append(point)
					if not parts.has(hitbox.part):
						parts.append(hitbox.part)
	parts.sort()
	_draw_sight_lines(eye, points)
	if parts != seen_parts:
		seen_parts = parts
		_show_seen_parts()
		Log.info("👁️ Watcher sight changed: watcher=%s, parts=%s, points=%d, player_position=%s" % [
			name, _part_names(), points.size(), player.global_position if player else Vector3.ZERO])
		seen_parts_changed.emit(parts)


## Draws the lines in global space: SightLines is top level, so its transform stays at the origin.
func _draw_sight_lines(eye: Vector3, points: PackedVector3Array) -> void:
	_lines.clear_surfaces()
	if points.is_empty():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in points:
		_lines.surface_add_vertex(eye)
		_lines.surface_add_vertex(point)
	_lines.surface_end()


func _show_seen_parts() -> void:
	var color := SEEING_COLOR if not seen_parts.is_empty() else IDLE_COLOR
	_eye_material.albedo_color = color
	_eye_material.emission = color
	_label.modulate = color
	_label.text = "%s\nsees: %s" % [name, _part_names()]


func _part_names() -> String:
	var names := PackedStringArray()
	for part in seen_parts:
		names.append(String(Hitbox.Part.keys()[part]).to_lower())
	return ", ".join(names) if not names.is_empty() else "nothing"
