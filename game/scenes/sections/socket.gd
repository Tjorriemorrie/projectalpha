@tool
class_name Socket
extends Marker3D
## A connection point at the centre of a section's cell edge, at floor level, facing out of the section along
## its local -Z. Corridor and vent sockets are open ends that must join another section. A wall socket is a
## wall the wreck can open up: a doorway when a corridor joins it, a vent mouth when a vent joins it, and solid
## otherwise. Wall sockets build their own wall, solid until joined, so sections show complete in the editor.

enum Kind { CORRIDOR, VENT, WALL }
## What a wall socket builds. Corridor and vent sockets are always NONE.
enum Opening { NONE, DOORWAY, VENT_MOUTH }

const DOORWAY_SIZE := Vector2(1.2, 2.2)
const VENT_SIZE := Vector2(1.2, 1.2)
const WALL_THICKNESS := 0.2
const FLOOR_THICKNESS := 0.2
const TRIM_WIDTH := 0.08
const TRIM_DEPTH := 0.03
const SLIDING_DOOR_SCENE := preload("res://scenes/sections/parts/sliding_door.tscn")
const WALL_MATERIAL := preload("res://scenes/sections/materials/wall.tres")
const FLOOR_MATERIAL := preload("res://scenes/sections/materials/floor.tres")
const TRIM_MATERIAL := preload("res://scenes/sections/materials/trim.tres")

@export var kind: Kind = Kind.WALL:
	set(value):
		kind = value
		_rebuild_if_ready()

@export_group("Wall")
## Whether a corridor may join this wall. Corridor side walls only take vents.
@export var accepts_corridor := true
## A wall that must be joined, such as the elevator's doors or the airlock's inner door.
@export var required := false
@export var wall_width := 4.0:
	set(value):
		wall_width = value
		_rebuild_if_ready()
@export var wall_height := 3.0:
	set(value):
		wall_height = value
		_rebuild_if_ready()
## Distance from the socket back to the wall's outer face. A vent joining an inset wall gets a duct across
## the gap, as on corridor side walls.
@export var wall_inset := 0.0:
	set(value):
		wall_inset = value
		_rebuild_if_ready()
## Whether the door in this wall opens by itself when the player comes near. The elevator drives its own doors.
@export var automatic_door := true

var opening: Opening = Opening.NONE
var partner: Socket
## The door built into a doorway, or null.
var door: SlidingDoor

var _wall: CSGCombiner3D


func _ready() -> void:
	_build()


## The direction this socket faces, out of its section.
func get_outward() -> Vector3:
	return -global_basis.z


## Called by the wreck when another section's socket joins this one, with what this socket should build.
func join(joined: Socket, new_opening: Opening) -> void:
	partner = joined
	opening = new_opening
	_build()


func _rebuild_if_ready() -> void:
	if is_node_ready():
		_build()


func _build() -> void:
	if _wall:
		remove_child(_wall)
		_wall.queue_free()
		_wall = null
	if door:
		remove_child(door)
		door.queue_free()
		door = null
	if kind != Kind.WALL:
		return

	_wall = CSGCombiner3D.new()
	_wall.name = "Wall"
	_wall.use_collision = true
	add_child(_wall, false, Node.INTERNAL_MODE_BACK)
	var front := wall_inset
	var back := wall_inset + WALL_THICKNESS
	var half_width := wall_width / 2.0
	if opening == Opening.NONE:
		_add_box(Vector3(-half_width, 0.0, front), Vector3(half_width, wall_height, back), WALL_MATERIAL)
		return

	var hole := DOORWAY_SIZE if opening == Opening.DOORWAY else VENT_SIZE
	var hole_half := hole.x / 2.0
	_add_box(Vector3(-half_width, 0.0, front), Vector3(-hole_half, wall_height, back), WALL_MATERIAL)
	_add_box(Vector3(hole_half, 0.0, front), Vector3(half_width, wall_height, back), WALL_MATERIAL)
	_add_box(Vector3(-hole_half, hole.y, front), Vector3(hole_half, wall_height, back), WALL_MATERIAL)
	# Frame the hole on the section's side, and for doorways on the far side too.
	_add_frame(hole, back, back + TRIM_DEPTH)
	if opening == Opening.DOORWAY:
		_add_frame(hole, front - TRIM_DEPTH, front)
		_add_door(front + WALL_THICKNESS / 2.0)
	elif wall_inset > 0.0:
		_add_duct(hole, front)


## A duct from the socket back to the wall, the same size as a vent section's duct, so the joining vent lines up.
func _add_duct(hole: Vector2, length: float) -> void:
	var inner := hole.x / 2.0
	var outer := inner + WALL_THICKNESS
	_add_box(Vector3(-outer, -FLOOR_THICKNESS, 0.0), Vector3(outer, 0.0, length), FLOOR_MATERIAL)
	_add_box(Vector3(-outer, 0.0, 0.0), Vector3(-inner, hole.y, length), WALL_MATERIAL)
	_add_box(Vector3(inner, 0.0, 0.0), Vector3(outer, hole.y, length), WALL_MATERIAL)
	_add_box(Vector3(-outer, hole.y, 0.0), Vector3(outer, hole.y + WALL_THICKNESS, length), WALL_MATERIAL)


func _add_frame(hole: Vector2, from_z: float, to_z: float) -> void:
	var hole_half := hole.x / 2.0
	var top := hole.y + TRIM_WIDTH
	_add_box(Vector3(-hole_half - TRIM_WIDTH, 0.0, from_z), Vector3(-hole_half, top, to_z), TRIM_MATERIAL)
	_add_box(Vector3(hole_half, 0.0, from_z), Vector3(hole_half + TRIM_WIDTH, top, to_z), TRIM_MATERIAL)
	_add_box(Vector3(-hole_half, hole.y, from_z), Vector3(hole_half, top, to_z), TRIM_MATERIAL)


func _add_door(z: float) -> void:
	door = SLIDING_DOOR_SCENE.instantiate() as SlidingDoor
	door.name = "Door"
	door.automatic = automatic_door
	door.position = Vector3(0.0, 0.0, z)
	add_child(door, false, Node.INTERNAL_MODE_BACK)


func _add_box(from: Vector3, to: Vector3, material: Material) -> void:
	var box := CSGBox3D.new()
	box.position = (from + to) / 2.0
	box.size = (to - from).abs()
	box.material = material
	_wall.add_child(box)
