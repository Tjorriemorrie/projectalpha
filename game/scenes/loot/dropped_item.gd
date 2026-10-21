class_name DroppedItem
extends RigidBody3D
## An item the player dropped, lying in the world for the rest of the run: its model, a collision box for each cell
## of its shape, and an Interactable the player looks at to open the floor in the inventory screen, where it is
## dragged back into a grid. It is on the item layer and collides only with the world and other items, so the player
## walks through it and shots and sight pass it. It clatters when it lands. Made in code with create().

## The group every dropped item is in, so the player can find the ones within reach.
const GROUP := &"dropped_items"
## The item layer (6), and what it collides with: world (1) and other items.
const LAYER := 1 << 5
const MASK := 0b1 | (1 << 5)
## Height of the collision boxes when the model has none to measure.
const DEFAULT_HEIGHT := 0.05
## Metres the pick-up area reaches past the item's boxes, so it is easy to look at.
const PICK_MARGIN := 0.04

var item: Item

var _sound: AudioStreamPlayer3D
var _landed := false


## A dropped item for this item, built from its definition: model, boxes and pick-up area. Place it, then add it.
static func create(dropped: Item, drop_sound: AudioStream) -> DroppedItem:
	var body := DroppedItem.new()
	body.item = dropped
	body.name = "Dropped_%s" % dropped.definition.id.get_slice(":", 1).to_pascal_case()
	body.collision_layer = LAYER
	body.collision_mask = MASK
	body.mass = 0.5 + 0.25 * dropped.definition.get_cells().size()
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.add_to_group(GROUP)
	var model: Node3D = null
	if ResourceLoader.exists(dropped.definition.get_model_path()):
		model = (load(dropped.definition.get_model_path()) as PackedScene).instantiate() as Node3D
		body.add_child(model)
	var height := _model_height(model)
	var area := Interactable.new()
	area.name = "PickUp"
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	body.add_child(area)
	var cells := dropped.definition.get_cells()
	var span := ItemShape.size_of(cells)
	var cell_size := ItemDefinition.CELL_SIZE
	for cell in cells:
		# The model's origin is the middle of its footprint, with rows running along +Z.
		var centre := Vector3((cell.x + 0.5 - span.x / 2.0) * cell_size, height / 2.0,
				(cell.y + 0.5 - span.y / 2.0) * cell_size)
		body.add_child(_box(Vector3(cell_size * 0.95, height, cell_size * 0.95), centre))
		area.add_child(_box(Vector3(cell_size + PICK_MARGIN, height + PICK_MARGIN, cell_size + PICK_MARGIN), centre))
	body._sound = AudioStreamPlayer3D.new()
	body._sound.name = "DropSound"
	body._sound.stream = drop_sound
	body._sound.unit_size = 3.0
	body.add_child(body._sound)
	body.body_entered.connect(body._on_body_entered)
	return body


func get_pick_up() -> Interactable:
	return get_node("PickUp") as Interactable


func _on_body_entered(_other: Node) -> void:
	if _landed:
		return
	_landed = true
	_sound.pitch_scale = randf_range(0.9, 1.1)
	_sound.play()
	Log.info("🎒 Dropped item landed: item=%s, position=%s" % [item.definition.id, global_position])


static func _box(size: Vector3, centre: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = centre
	return collision


## How tall the model stands, from its meshes.
static func _model_height(model: Node3D) -> float:
	if model == null:
		return DEFAULT_HEIGHT
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := mesh.transform * mesh.get_aabb()
		top = maxf(top, bounds.end.y)
	return maxf(top, 0.02)
