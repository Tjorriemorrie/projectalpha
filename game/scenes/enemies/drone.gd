class_name Drone
extends Robot
## A hovering security drone. Idle, it patrols points around its post, pausing at each. It flies to what it noticed
## and looks around there; while attacking it keeps its fighting distance from the player and strafes as it fires;
## it searches where it last saw them. It follows paths on the wreck's navigation mesh, asked for from the floor
## below it (so never from the top of a crate it hovers over), stays on its own deck and holds its hover height.
## It is placed on its post on the floor and rises to hover; its origin is the centre of its body. Destroyed, it drops
## and its wreckage lies on the floor.

## Metres from a path point at which it counts as there.
const ARRIVE_DISTANCE := 0.4
## Seconds between path updates while the destination moves.
const REPATH_TIME := 0.5
## Metres a destination must move before the path is asked for again early.
const REPATH_DISTANCE := 0.75
## Metres off its deck's floor a navigation point may be and still count as on its deck.
const DECK_TOLERANCE := 0.5
## Attempts at finding a patrol point before waiting for the next pause.
const PATROL_ATTEMPTS := 20
## Metres a patrol point must be from where it is, so each leg is worth flying.
const MIN_PATROL_LEG := 2.0
## How quickly it settles back to its hover height (per second).
const HOVER_STIFFNESS := 4.0
## Degrees it tilts at most to look at its focus.
const MAX_TILT := 35.0
## Size of the flat box the wreckage rests on, so the player can step over it.
const WRECKAGE_SIZE := Vector3(0.6, 0.28, 0.6)
## Degrees the wreckage lies tipped over.
const WRECKAGE_TIP := 25.0

@export_group("Flight")
## Metres above the floor the centre of the drone floats.
@export var hover_height: float = 1.5
@export var patrol_speed: float = 1.2
## Metres per second while investigating, attacking or searching.
@export var move_speed: float = 2.5
## Metres per second per second it speeds up and slows down by.
@export var acceleration: float = 4.0
## Degrees per second it turns.
@export var turn_speed: float = 150.0

@export_group("Patrol")
## Metres around its post that it patrols.
@export var patrol_radius: float = 12.0
## Seconds it pauses at each patrol point.
@export var patrol_pause: float = 2.0
## Degrees per second it turns while looking around a spot it investigates or searches.
@export var look_around_speed: float = 60.0

@export_group("Attack")
## Metres from the player it keeps while attacking (closest, furthest).
@export var fighting_distance := Vector2(6.0, 10.0)
## Seconds between changes of strafing direction (shortest, longest), and metres it strafes ahead at a time.
@export var strafe_time := Vector2(1.5, 3.0)
@export var strafe_distance: float = 2.0

## Where it was placed: the floor point it patrols around.
var post := Vector3.ZERO
## The floor height of its deck.
var floor_height := 0.0
## Where it is flying to on the floor, and whether it has one.
var destination := Vector3.ZERO
var has_destination := false
## Whether it got to its destination (or as close as the navigation lets it).
var arrived := false

var _path := PackedVector3Array()
var _path_index := 0
var _path_target := Vector3.INF
var _repath_left := 0.0
var _pause_left := 0.0
var _patrol_point := Vector3.ZERO
var _has_patrol_point := false
var _strafe_direction := 1.0
var _strafe_left := 0.0
var _yaw := 0.0
var _tilt := 0.0
var _landed := false

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _contact: Area3D = %Contact


func _ready_body() -> void:
	post = global_position
	floor_height = post.y
	global_position = post + Vector3.UP * hover_height
	_yaw = rotation.y
	_pause_left = patrol_pause
	_contact.body_entered.connect(_on_contact)
	_idle_sound.play()
	Log.info("🤖 Drone ready: robot=%s, post=%s, hover=%.1f m, patrol_radius=%.0f m, fighting_distance=%s" % [
		name, post, hover_height, patrol_radius, fighting_distance])


## Picks where to go for the state, follows the path there, holds its hover height and turns to look.
func _move(delta: float) -> void:
	var wanted := Vector3.ZERO
	var speed := patrol_speed if mind.state == RobotMind.State.IDLE else move_speed
	if not mind.is_locking and _choose_destination(delta):
		wanted = _follow_path(delta) * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wanted, acceleration * delta)
	velocity = Vector3(horizontal.x, (floor_height + hover_height - global_position.y) * HOVER_STIFFNESS, horizontal.z)
	move_and_slide()
	_turn(delta, horizontal)


func _is_at_focus() -> bool:
	return arrived or mind.sees_player


## Sets the destination for the state. Returns whether it has one; holding still (pausing on patrol, no navigation
## yet) has none.
func _choose_destination(delta: float) -> bool:
	match mind.state:
		RobotMind.State.IDLE:
			return _choose_patrol(delta)
		RobotMind.State.INVESTIGATING, RobotMind.State.SEARCHING:
			return _set_destination(mind.focus)
		RobotMind.State.ATTACKING:
			return _choose_fighting_position(delta)
	return false


## From patrol point to patrol point around its post, pausing at each.
func _choose_patrol(delta: float) -> bool:
	var at_patrol_point := arrived and _flat_distance(_path_target, _patrol_point) < ARRIVE_DISTANCE
	if _has_patrol_point and not at_patrol_point:
		return _set_destination(_patrol_point)
	_pause_left -= delta
	if _pause_left > 0.0:
		has_destination = false
		return false
	_pause_left = patrol_pause
	_has_patrol_point = _pick_patrol_point()
	return _has_patrol_point and _set_destination(_patrol_point)


## Closes in when the player is too far or out of sight, backs off when they are too close, and strafes in between.
func _choose_fighting_position(delta: float) -> bool:
	var to_player := mind.focus - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var away := -to_player.normalized() if distance > 0.01 else global_basis.z
	if seen_points.is_empty() or distance > fighting_distance.y:
		return _set_destination(mind.focus)
	if distance < fighting_distance.x:
		return _set_destination(global_position + away * (fighting_distance.x - distance + 1.0))
	_strafe_left -= delta
	if _strafe_left <= 0.0 or (arrived and has_destination):
		_strafe_direction = -_strafe_direction
		_strafe_left = rng.randf_range(strafe_time.x, strafe_time.y)
	var side := away.cross(Vector3.UP).normalized() * _strafe_direction
	return _set_destination(global_position + side * strafe_distance)


## Flies to the navigation point nearest target on its own deck. Returns false when there is none (no navigation
## yet, or nothing on this deck near it).
func _set_destination(target: Vector3) -> bool:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		has_destination = false
		return false
	var point := NavigationServer3D.map_get_closest_point(map, Vector3(target.x, floor_height, target.z))
	if absf(point.y - floor_height) > DECK_TOLERANCE:
		has_destination = false
		return false
	destination = point
	has_destination = true
	return true


## The direction to fly in along the path to the destination, flat; zero once there.
func _follow_path(delta: float) -> Vector3:
	var map := get_world_3d().navigation_map
	var from := Vector3(global_position.x, floor_height, global_position.z)
	_repath_left -= delta
	if _repath_left <= 0.0 or destination.distance_to(_path_target) > REPATH_DISTANCE:
		_path = NavigationServer3D.map_get_path(map, from, destination, true)
		_path_index = 1
		_path_target = destination
		_repath_left = REPATH_TIME
		arrived = false
	while _path_index < _path.size() and _flat_distance(from, _path[_path_index]) < ARRIVE_DISTANCE:
		_path_index += 1
	if _path_index >= _path.size():
		arrived = true
		return Vector3.ZERO
	var direction := _path[_path_index] - from
	direction.y = 0.0
	return direction.normalized()


## A random point on its own deck within its patrol radius that it can get to.
func _pick_patrol_point() -> bool:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var from := Vector3(global_position.x, floor_height, global_position.z)
	for attempt in PATROL_ATTEMPTS:
		var point := NavigationServer3D.map_get_random_point(map, 1, false)
		if absf(point.y - floor_height) > DECK_TOLERANCE or _flat_distance(point, post) > patrol_radius \
				or _flat_distance(point, from) < MIN_PATROL_LEG:
			continue
		var path := NavigationServer3D.map_get_path(map, from, point, true)
		if path.is_empty() or path[path.size() - 1].distance_to(point) > ARRIVE_DISTANCE:
			continue
		_patrol_point = point
		Log.info("🤖 Patrolling: robot=%s, to=%s, distance=%.1f m, attempts=%d" % [
			name, point, _flat_distance(point, from), attempt + 1])
		return true
	Log.warning("🤖 No patrol point found: robot=%s, post=%s, radius=%.0f m, attempts=%d" % [
		name, post, patrol_radius, PATROL_ATTEMPTS])
	return false


## Faces the player while locking on or attacking, looks around at a spot it investigates or searches, and otherwise
## faces where it flies. It tilts to look at its focus.
func _turn(delta: float, horizontal: Vector3) -> void:
	var looking := mind.is_locking or mind.is_attacking() or mind.sees_player
	var target_yaw := _yaw
	var target_tilt := 0.0
	if looking:
		var angles := RobotRules.aim_angles(Basis.IDENTITY, get_eye_position(), mind.focus)
		target_yaw = angles.x
		target_tilt = clampf(angles.y, -deg_to_rad(MAX_TILT), deg_to_rad(MAX_TILT))
	elif horizontal.length() > 0.2:
		target_yaw = atan2(-horizontal.x, -horizontal.z)
	elif mind.state == RobotMind.State.INVESTIGATING or mind.state == RobotMind.State.SEARCHING:
		target_yaw = _yaw + deg_to_rad(look_around_speed) * delta
	var step := deg_to_rad(turn_speed) * delta
	_yaw = wrapf(RobotRules.turn_towards(_yaw, target_yaw, step), -PI, PI)
	_tilt = move_toward(_tilt, target_tilt, step)
	rotation = Vector3(_tilt, _yaw, 0.0)


func _on_contact(body: Node3D) -> void:
	if body is Player and not is_destroyed():
		feel_contact(body.global_position + Vector3.UP)


## It drops out of the air; its flat wreckage box lets the player step over it.
func _destroy_body() -> void:
	_contact.set_deferred(&"monitoring", false)
	collision_mask = WORLD_LAYER
	# It flies in floating mode; falling, it needs a floor to land on.
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	velocity = Vector3.ZERO
	Log.info("🤖 Drone falling: robot=%s, height=%.1f m above the floor" % [name, global_position.y - floor_height])


func _update_wreckage(delta: float) -> void:
	if _landed:
		return
	velocity += get_gravity() * delta
	move_and_slide()
	if not is_on_floor():
		return
	_landed = true
	var box := BoxShape3D.new()
	box.size = WRECKAGE_SIZE
	_shape.shape = box
	rotation = Vector3(0.0, _yaw, 0.0)
	# The body rests where it landed; the box sits on the floor under it.
	_shape.position = Vector3.UP * (WRECKAGE_SIZE.y / 2.0 - (global_position.y - floor_height))
	_model.rotation.z = deg_to_rad(WRECKAGE_TIP)
	_crash()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
