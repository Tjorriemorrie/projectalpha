class_name Hitbox
extends Area3D
## A part of the player that enemies can hit: the head, the body, or the shoulder and arm that come out while
## aiming out of cover. Enemies can only hit the parts they can see, so a hitbox offers sample points to check
## line of sight against. Hitboxes sit on the hitbox physics layer and are moved by the player.

enum Part { HEAD, BODY, ARM }

## How far towards the edge of the shape the outer sample points sit, so a ray grazing the very edge doesn't count.
const SAMPLE_INSET := 0.8

@export var part: Part = Part.BODY

@onready var _shape: CollisionShape3D = $CollisionShape3D


## Whether this part can be hit now; the arm is only out while aiming out of cover.
func is_active() -> bool:
	return not _shape.disabled


func set_active(active: bool) -> void:
	_shape.disabled = not active


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
	Log.warning("🏃 Hitbox shape has no sample points: hitbox=%s, shape=%s" % [name, shape])
	return Vector3.ZERO
