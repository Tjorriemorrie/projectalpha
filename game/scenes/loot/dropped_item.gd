class_name DroppedItem
extends RigidBody3D
## A stack the player dropped, lying in the world for the rest of the run as one object: its item's model, a collision
## box round the model, and an Interactable the player looks at to open the floor in the inventory screen, where the
## stack is dragged back into a slot. A stack dropped onto it on the floor joins it, and taking part of it leaves the
## rest lying there. It is on the item layer and collides only with the world and other items, so the player walks
## through it and shots and sight pass it. It clatters when it lands. Made in code with create().

## The group every dropped item is in, so the player can find the ones within reach.
const GROUP := &"dropped_items"
## The item layer (6), and what it collides with: world (1) and other items.
const LAYER := 1 << 5
const MASK := 0b1 | (1 << 5)
## The size of the collision box when the item has no model to measure.
const DEFAULT_SIZE := Vector3(0.15, 0.05, 0.15)
## Metres the pick-up area reaches past the item's box, so it is easy to look at.
const PICK_MARGIN := 0.04

## The stack lying here.
var item: Item

var _sound: AudioStreamPlayer3D
var _landed := false


## A dropped item for this stack, built from its definition: model, box and pick-up area. Place it, then add it.
static func create(dropped: Item, drop_sound: AudioStream) -> DroppedItem:
	var body := DroppedItem.new()
	body.item = dropped
	body.name = "Dropped_%s" % dropped.definition.id.get_slice(":", 1).to_pascal_case()
	body.collision_layer = LAYER
	body.collision_mask = MASK
	body.mass = 0.5 + 0.1 * dropped.quantity
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.add_to_group(GROUP)
	var model: Node3D = null
	if ResourceLoader.exists(dropped.definition.get_model_path()):
		model = (load(dropped.definition.get_model_path()) as PackedScene).instantiate() as Node3D
		body.add_child(model)
	var bounds := model_bounds(model)
	var area := Interactable.new()
	area.name = "PickUp"
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	body.add_child(area)
	var centre := bounds.get_center()
	body.add_child(_box(bounds.size * Vector3(0.95, 1.0, 0.95), centre))
	area.add_child(_box(bounds.size + Vector3.ONE * PICK_MARGIN, centre))
	body._sound = AudioStreamPlayer3D.new()
	body._sound.name = "DropSound"
	body._sound.stream = drop_sound
	body._sound.unit_size = 3.0
	body.add_child(body._sound)
	body.body_entered.connect(body._on_body_entered)
	return body


## What a model covers, from its meshes, in its own space; a small box when there is no model or mesh. Also frames
## an item's icon (see ItemIcons).
static func model_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	if model:
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box := _transform_in(mesh, model) * mesh.get_aabb()
			bounds = box if not found else bounds.merge(box)
			found = true
	if not found or bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		return AABB(Vector3(-DEFAULT_SIZE.x / 2.0, 0.0, -DEFAULT_SIZE.z / 2.0), DEFAULT_SIZE)
	bounds.size.y = maxf(bounds.size.y, 0.02)
	return bounds


func get_pick_up() -> Interactable:
	return get_node("PickUp") as Interactable


## More was dropped onto it on the floor: it clatters again.
func clatter() -> void:
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	Log.info("🎒 Dropped item topped up: item=%s, quantity=%d, position=%s" % [
		item.definition.id, item.quantity, global_position])


func _on_body_entered(_other: Node) -> void:
	if _landed:
		return
	_landed = true
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	Log.info("🎒 Dropped item landed: item=%s, quantity=%d, position=%s" % [
		item.definition.id, item.quantity, global_position])


static func _box(size: Vector3, centre: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = centre
	return collision


## A node's transform in the space of one of its ancestors, also before they are in the tree.
static func _transform_in(node: Node3D, ancestor: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current and current != ancestor:
		transform = current.transform * transform
		current = current.get_parent() as Node3D
	return transform
