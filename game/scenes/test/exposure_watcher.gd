class_name ExposureWatcher
extends Node3D
## A debug stand-in for an enemy, for the test level until robots arrive in 006. Every physics frame it checks which
## parts of the player it can see from its eye: it draws a red line to every hitbox sample point in sight, glows red
## while it sees any part, and shows the parts it sees above itself. With fire_enabled on it also shoots: a red
## laser at a part it can see, every couple of seconds, with spread.

## Emitted when the watcher starts or stops seeing a part of the player.
signal seen_parts_changed(parts: Array[Hitbox.Part])

## Physics layers that block the watcher's sight: world (1).
const SIGHT_MASK := 0b1
## Physics layers its shots hit: world (1) stops them, hitbox (4) is what they damage.
const SHOT_MASK := 0b1001
## Metres a shot carries on past the point it aimed at, so a near miss can still hit what is behind it.
const SHOT_OVERREACH := 1.0
const SEEING_COLOR := Color(1.0, 0.12, 0.08)
const IDLE_COLOR := Color(0.55, 0.6, 0.65)

@export var player: Player
## Metres within which the watcher looks for the player.
@export var sight_range: float = 10.0

@export_group("Fire")
## Shoot at the player as well as watching. Off by default; tests that don't want it turn it off.
@export var fire_enabled: bool = false
## Seconds between shots while the watcher sees the player.
@export var fire_interval: float = 2.0
## Seconds from spotting the player to the first shot.
@export var first_shot_delay: float = 1.0
@export var damage: float = 10.0
## Degrees from the aimed point that shots land within.
@export var fire_spread: float = 1.5

## The parts of the player the watcher can see, in Hitbox.Part order.
var seen_parts: Array[Hitbox.Part] = []

var _lines := ImmediateMesh.new()
var _eye_material := StandardMaterial3D.new()
var _fire_timer := 0.0

@onready var _eye: MeshInstance3D = $Eye
@onready var _label: Label3D = $Label
@onready var _sight_lines: MeshInstance3D = $SightLines
@onready var _shot_sound: AudioStreamPlayer3D = $ShotSound


func _ready() -> void:
	_eye_material.emission_enabled = true
	_eye.material_override = _eye_material
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = SEEING_COLOR
	_sight_lines.mesh = _lines
	_sight_lines.material_override = line_material
	_show_seen_parts()
	_fire_timer = first_shot_delay
	Log.info("👁️ Watcher ready: watcher=%s, eye=%s, sight_range=%.1f m, player=%s, fire=%s" % [
		name, _eye.global_position, sight_range, player.name if player else "none", fire_enabled])


## Runs every physics frame, so it only logs when what the watcher sees changes.
func _physics_process(delta: float) -> void:
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
	_update_fire(delta, eye, points)
	if parts != seen_parts:
		seen_parts = parts
		_show_seen_parts()
		Log.info("👁️ Watcher sight changed: watcher=%s, parts=%s, points=%d, player_position=%s" % [
			name, _part_names(), points.size(), player.global_position if player else Vector3.ZERO])
		seen_parts_changed.emit(parts)


## Shoots every fire_interval while it sees part of the player, starting first_shot_delay after spotting them.
func _update_fire(delta: float, eye: Vector3, points: PackedVector3Array) -> void:
	if not fire_enabled or points.is_empty():
		_fire_timer = first_shot_delay
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_interval
	_fire(eye, points[randi() % points.size()])


## Fires a red laser at a point it sees, spread around it; what it hits first takes the damage.
func _fire(eye: Vector3, aim_point: Vector3) -> void:
	var view := Basis.looking_at(aim_point - eye)
	var direction := WeaponRules.shot_direction(view, fire_spread, randf(), randf())
	var end := eye + direction * (eye.distance_to(aim_point) + SHOT_OVERREACH)
	var query := PhysicsRayQueryParameters3D.create(eye, end, SHOT_MASK)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := "nothing"
	if not hit.is_empty():
		end = hit["position"]
		var hitbox := hit["collider"] as Hitbox
		target = Hitbox.Part.keys()[hitbox.part] if hitbox else (hit["collider"] as Node).name
		if hitbox:
			hitbox.take_hit(damage, eye)
		LaserEffects.impact(self, end, hit["normal"], SEEING_COLOR, null if hitbox else hit["collider"] as Node3D)
	LaserEffects.beam(self, eye, end, SEEING_COLOR)
	_shot_sound.play()
	Log.info("👁️ Watcher fired: watcher=%s, hit=%s, damage=%.1f, distance=%.1f m" % [
		name, target, damage, eye.distance_to(end)])


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
