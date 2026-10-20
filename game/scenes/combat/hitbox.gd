class_name Hitbox
extends Area3D
## A part of something that can be hit: the player's head, body, or the shoulder and arm that come out while aiming
## out of cover, a shooting target, and robots in 006. Shots cast rays against the hitbox physics layer and pass
## what they hit to take_hit(), which damages the Health the hitbox belongs to. Enemies can only hit the parts they
## can see, so a hitbox also offers sample points to check line of sight against.

enum Part { HEAD, BODY, ARM }

## How far towards the edge of the shape the outer sample points sit, so a ray grazing the very edge doesn't count.
const SAMPLE_INSET := 0.8

@export var part: Part = Part.BODY
## Damage through this part is multiplied by this, e.g. 2 for the player's head.
@export var damage_multiplier: float = 1.0
## What hits on this part damage.
@export var health: Health

@onready var _shape: CollisionShape3D = $CollisionShape3D


## Whether this part can be hit now; the arm is only out while aiming out of cover.
func is_active() -> bool:
	return not _shape.disabled


func set_active(active: bool) -> void:
	_shape.disabled = not active


## Damages the health this part belongs to with a hit from source_position, times the part's multiplier, and
## returns the damage dealt.
func take_hit(damage: float, source_position: Vector3) -> float:
	if health == null:
		Log.warning("🩸 Hit on a hitbox without health: hitbox=%s, part=%s, damage=%.1f, source=%s" % [
			get_path(), Part.keys()[part], damage, source_position])
		return 0.0
	var dealt := damage * damage_multiplier
	Log.info("🩸 Hitbox hit: hitbox=%s/%s, part=%s, damage=%.1f x %.2f = %.1f, source=%s" % [
		get_parent().name, name, Part.keys()[part], damage, damage_multiplier, dealt, source_position])
	health.take_damage(dealt, source_position, part)
	return dealt


## The centre of the shape and a point towards each of its six sides, in global space.
func sample_points() -> PackedVector3Array:
	var half := _half_extents() * SAMPLE_INSET
	var xform := _shape.global_transform
	var points := PackedVector3Array([xform.origin])
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		points.append(xform * (axis * half))
		points.append(xform * (-axis * half))
	return points


func _half_extents() -> Vector3:
	var shape := _shape.shape
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return Vector3(radius, radius, radius)
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return Vector3(cylinder.radius, cylinder.height / 2.0, cylinder.radius)
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size / 2.0
	Log.warning("🩸 Hitbox shape has no sample points: hitbox=%s, shape=%s" % [name, shape])
	return Vector3.ZERO
