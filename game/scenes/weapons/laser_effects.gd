class_name LaserEffects
extends RefCounted
## The look of a laser shot, shared by every weapon: a brief beam from the muzzle to where it hit, sparks and a
## flash at the impact and, on walls and floors, a scorch mark that stays for the rest of the run. The beam, sparks
## and flash are added under a parent as top-level nodes, so they stay where they are when the shooter moves, and
## free themselves. A scorch mark becomes part of the surface it hit, so it moves with doors and elevators.

## Seconds the beam takes to fade.
const BEAM_TIME := 0.08
const BEAM_RADIUS := 0.006
## How much brighter than its colour the beam is drawn, so the glow picks it up.
const BEAM_BRIGHTNESS := 1.4
const SPARK_COUNT := 14
const SPARK_LIFETIME := 0.35
const IMPACT_FLASH_TIME := 0.08
const IMPACT_FLASH_RANGE := 1.5
const IMPACT_FLASH_ENERGY := 1.5
## Metres across a scorch mark.
const SCORCH_SIZE := 0.14
## Most scorch marks kept at once; past this the oldest goes, so a long fight can't slow the game down.
const MAX_SCORCH_MARKS := 256
## Metres from the camera at which scorch marks start to fade out, and over how far, so distant marks cost nothing.
const SCORCH_FADE_BEGIN := 25.0
const SCORCH_FADE_LENGTH := 5.0

static var _scorch_texture: GradientTexture2D
## The scorch marks still in the world, oldest first.
static var _scorch_marks: Array[Decal] = []


static func beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEAM_RADIUS
	mesh.bottom_radius = BEAM_RADIUS
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := _glow_material(color * BEAM_BRIGHTNESS)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	parent.add_child(node)
	# A cylinder runs along its Y axis, so turn Y onto the beam and centre it between the two ends.
	node.global_transform = Transform3D(_y_along((to - from) / length), (from + to) / 2.0)
	_fade_and_free(node, material, BEAM_TIME)


## Sparks and a flash where a shot hit. When the shot hit a surface (a wall, floor or door; null for a hitbox), it
## leaves a scorch mark on it too.
static func impact(parent: Node, point: Vector3, normal: Vector3, color: Color, surface: Node3D) -> void:
	var up := normal.normalized() if not normal.is_zero_approx() else Vector3.UP
	var facing := _y_along(up)
	_add_sparks(parent, Transform3D(facing, point), color)
	_add_flash(parent, point + up * 0.05, color)
	if surface:
		_add_scorch(surface, Transform3D(facing, point))


## How many scorch marks are in the world now.
static func scorch_mark_count() -> int:
	_forget_freed_scorch_marks()
	return _scorch_marks.size()


static func _add_sparks(parent: Node, at: Transform3D, color: Color) -> void:
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.008, 0.008, 0.03)
	spark_mesh.material = _glow_material(color * BEAM_BRIGHTNESS)
	var sparks := CPUParticles3D.new()
	sparks.mesh = spark_mesh
	sparks.amount = SPARK_COUNT
	sparks.lifetime = SPARK_LIFETIME
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.0
	sparks.gravity = Vector3(0.0, -9.8, 0.0)
	sparks.particle_flag_align_y = true
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.top_level = true
	parent.add_child(sparks)
	sparks.global_transform = at
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


static func _add_flash(parent: Node, at: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = IMPACT_FLASH_ENERGY
	light.omni_range = IMPACT_FLASH_RANGE
	light.top_level = true
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, IMPACT_FLASH_TIME)
	tween.tween_callback(light.queue_free)


## A decal projects along its -Y, so at's Y axis must point out of the surface. The mark is a child of the surface,
## so it moves with it and goes when it goes (or when the level reloads). Beyond MAX_SCORCH_MARKS the oldest goes.
static func _add_scorch(surface: Node3D, at: Transform3D) -> void:
	var decal := Decal.new()
	decal.size = Vector3(SCORCH_SIZE, 0.1, SCORCH_SIZE)
	decal.texture_albedo = _get_scorch_texture()
	decal.modulate = Color(1.0, 1.0, 1.0, 0.9)
	# Leave the weapon in view alone when it is held against a scorched wall.
	decal.cull_mask &= ~WeaponViewmodel.VISUAL_LAYER
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = SCORCH_FADE_BEGIN
	decal.distance_fade_length = SCORCH_FADE_LENGTH
	surface.add_child(decal)
	# Turn each mark a different way round, so overlapping marks don't look stamped.
	decal.global_transform = at.rotated_local(Vector3.UP, randf() * TAU)
	_forget_freed_scorch_marks()
	_scorch_marks.append(decal)
	while _scorch_marks.size() > MAX_SCORCH_MARKS:
		_scorch_marks.pop_front().queue_free()


## Marks freed with their surface or the level are dropped from the list.
static func _forget_freed_scorch_marks() -> void:
	for i in range(_scorch_marks.size() - 1, -1, -1):
		if not is_instance_valid(_scorch_marks[i]):
			_scorch_marks.remove_at(i)


static func _get_scorch_texture() -> GradientTexture2D:
	if _scorch_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.02, 0.02, 0.025, 0.95))
		gradient.set_color(1, Color(0.05, 0.045, 0.04, 0.0))
		gradient.add_point(0.35, Color(0.03, 0.03, 0.03, 0.8))
		_scorch_texture = GradientTexture2D.new()
		_scorch_texture.gradient = gradient
		_scorch_texture.fill = GradientTexture2D.FILL_RADIAL
		_scorch_texture.fill_from = Vector2(0.5, 0.5)
		_scorch_texture.fill_to = Vector2(1.0, 0.5)
		_scorch_texture.width = 64
		_scorch_texture.height = 64
	return _scorch_texture


## A basis whose Y axis points along direction (a unit vector), turned any way round it.
static func _y_along(direction: Vector3) -> Basis:
	var reference := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := direction.cross(reference).normalized()
	return Basis(x, direction, x.cross(direction))


static func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	return material


static func _fade_and_free(node: Node3D, material: StandardMaterial3D, time: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_callback(node.queue_free)
