class_name LootContainer
extends StaticBody3D
## A loot container standing on a loot marker: a supply crate, a locker or a small case. A container scene's root is
## this body, on the world layer (so a crate is cover), with %Lootable, the area the player pries open, and %Model,
## whose Lid node (the locker's door) has its origin on the hinge and swings open by open_rotation when the
## container is pried open. Like the robots, a container faces −Z, the way its marker faces; its origin is the middle
## of its back on the floor, so it stands flush against the wall its marker is on. The wreck sets its definition,
## places it and fills it.

## Set by whoever places the container, before it enters the tree.
@export var definition: ContainerDefinition
## Degrees the lid turns about its hinge to open, in the model's axes.
@export var open_rotation := Vector3(-100.0, 0.0, 0.0)
## Seconds the lid takes to swing open.
@export var open_time := 0.45

@onready var _lootable: Lootable = %Lootable
@onready var _model: Node3D = %Model

var _lid: Node3D


func _ready() -> void:
	_lid = _model.find_child("Lid", true, false) as Node3D
	_lootable.opened.connect(_on_opened)
	if definition == null:
		Log.error("🎒 Container has no definition, so it holds nothing: container=%s, scene=%s" % [
			name, scene_file_path])
		_lootable.setup("Container", Vector2i.ONE)
		return
	_lootable.setup(definition.display_name, definition.grid_size)
	Log.info("🎒 Container ready: container=%s, kind=%s, grid=%s, position=%s, lid=%s" % [
		name, definition.id, definition.grid_size, global_position, _lid != null])


## Packs items into it in the order given. Returns the ones that didn't fit.
func fill(items: Array[ItemDefinition]) -> Array[ItemDefinition]:
	return _lootable.fill(items)


func get_lootable() -> Lootable:
	return _lootable


## The corners of its collision box on the floor, in world space, for cutting it out of the drones' navigation.
func get_footprint() -> PackedVector3Array:
	var box := _body_box()
	var half := box.size / 2.0
	var corners := PackedVector3Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var local := Vector3(half.x * corner.x, -half.y, half.z * corner.y)
		corners.append(global_transform * (_body_shape().transform * local))
	return corners


## How tall its collision box stands.
func get_height() -> float:
	return _body_box().size.y


func _body_shape() -> CollisionShape3D:
	return get_node("CollisionShape3D") as CollisionShape3D


func _body_box() -> BoxShape3D:
	return _body_shape().shape as BoxShape3D


func _on_opened() -> void:
	if _lid == null:
		Log.warning("🎒 Container opened without a lid to swing: container=%s" % name)
		return
	var target := _lid.rotation + open_rotation * (PI / 180.0)
	var tween := create_tween()
	tween.tween_property(_lid, "rotation", target, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Log.info("🎒 Container lid swinging open: container=%s, rotation=%s°, time=%.2f s" % [
		name, open_rotation, open_time])
