extends GdUnitTestSuite
## Checks when an automatic sliding door opens: for someone walking at it (early enough to be open when they get
## there) or standing right in front of it, from either side, but not for someone walking past along its wall, as
## down the middle of a corridor past a side door; once open, anyone near keeps it open. A stand-in for the player
## (a body on the player layer, the player's size) moves by its velocity each physics frame. The door's origin is
## the bottom centre of the doorway, its local Z the wall's normal.

const DOOR_SCENE := "res://scenes/sections/parts/sliding_door.tscn"
## The player's collision layer (2), radius and height.
const PLAYER_LAYER := 1 << 1
const RADIUS := 0.3
const HEIGHT := 1.8
const WALK := 1.5

var _door: SlidingDoor
var _walker: CharacterBody3D


func before_test() -> void:
	_door = auto_free((load(DOOR_SCENE) as PackedScene).instantiate()) as SlidingDoor
	add_child(_door)
	_walker = auto_free(CharacterBody3D.new())
	_walker.collision_layer = PLAYER_LAYER
	_walker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT / 2.0
	_walker.add_child(shape)
	add_child(_walker)
	# Far from the door, so it starts shut.
	_walker.global_position = Vector3(0.0, 0.0, 10.0)
	await _physics_frames(2)


func test_walking_past_along_the_wall_leaves_it_shut() -> void:
	# Down the middle of a 2 m corridor: a metre from the wall, from well before the doorway to well after it.
	_walker.global_position = Vector3(-3.0, 0.0, 1.0)
	_walker.velocity = Vector3(WALK, 0.0, 0.0)
	var opened := await _walk_until(func() -> bool: return _walker.global_position.x > 3.0)
	assert_bool(opened).is_false()
	assert_bool(_door.is_closed()).is_true()


func test_walking_at_it_opens_it_in_time() -> void:
	_walker.global_position = Vector3(0.0, 0.0, 3.0)
	_walker.velocity = Vector3(0.0, 0.0, -WALK)
	await _walk_until(func() -> bool: return _walker.global_position.z < RADIUS + 0.1)
	assert_bool(_door.is_fully_open()).is_true()


func test_walking_at_it_from_the_other_side_opens_it_too() -> void:
	_walker.global_position = Vector3(0.3, 0.0, -3.0)
	_walker.velocity = Vector3(0.0, 0.0, WALK)
	await _walk_until(func() -> bool: return _walker.global_position.z > -RADIUS - 0.1)
	assert_bool(_door.is_fully_open()).is_true()


func test_walking_at_the_wall_beside_it_at_a_slant_opens_it() -> void:
	# Heading for the doorway at 45°, as round a corner into it.
	_walker.global_position = Vector3(-1.4, 0.0, 1.4)
	_walker.velocity = Vector3(WALK, 0.0, -WALK) / sqrt(2.0)
	await _walk_until(func() -> bool: return _walker.global_position.z < 0.5)
	assert_bool(_door.open_requested).is_true()


func test_standing_right_in_front_opens_it() -> void:
	_walker.global_position = Vector3(0.2, 0.0, 0.5)
	_walker.velocity = Vector3.ZERO
	await _physics_frames(5)
	assert_bool(_door.open_requested).is_true()


func test_standing_further_out_doesnt_open_it_but_keeps_it_open() -> void:
	_walker.global_position = Vector3(0.0, 0.0, 1.2)
	_walker.velocity = Vector3.ZERO
	await _physics_frames(60)
	assert_bool(_door.is_closed()).is_true()
	_door.open()
	# Well past the close delay, someone still near holds it open.
	await _physics_frames(roundi((_door.close_delay + 1.0) * 60))
	assert_bool(_door.open_requested).is_true()
	_walker.global_position = Vector3(0.0, 0.0, 6.0)
	await _physics_frames(roundi((_door.close_delay + 1.0) * 60))
	assert_bool(_door.open_requested).is_false()


func test_wants_through_reads_distance_and_heading() -> void:
	_walker.global_position = Vector3(0.0, 0.0, 1.0)
	_walker.velocity = Vector3(WALK, 0.0, 0.0)
	assert_bool(_door.wants_through(_walker)).is_false()
	_walker.velocity = Vector3(0.0, 0.0, -WALK)
	assert_bool(_door.wants_through(_walker)).is_true()
	# Walking away from it never opens it.
	_walker.velocity = Vector3(0.0, 0.0, WALK)
	assert_bool(_door.wants_through(_walker)).is_false()
	_walker.global_position = Vector3(0.0, 0.0, -0.4)
	_walker.velocity = Vector3.ZERO
	assert_bool(_door.wants_through(_walker)).is_true()


## Moves the walker by its velocity every physics frame until done says so (or 10 s pass). Returns whether the door
## was asked to open on the way.
func _walk_until(done: Callable) -> bool:
	var opened := false
	for frame in 600:
		await get_tree().physics_frame
		_walker.global_position += _walker.velocity / 60.0
		opened = opened or _door.open_requested
		if done.call():
			break
	return opened


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
