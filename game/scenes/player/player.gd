class_name Player
extends CharacterBody3D
## First-person player controller: walking, sprinting, crouching, mouse look, stepping onto low obstacles
## and riding elevators. MovementRules makes the decisions; this script applies them to the body and camera.

## Emitted when the movement state changes, so systems such as noise and footsteps can react to it.
signal movement_state_changed(previous: MovementRules.State, current: MovementRules.State)

## The camera stops this many degrees short of looking straight up or down.
const PITCH_LIMIT_DEGREES := 89.0
## Aspect ratio at which horizontal_fov applies; wider screens see more at the sides.
const REFERENCE_ASPECT := 16.0 / 9.0
## Smallest height change that counts as a step rather than floor unevenness.
const MIN_STEP_HEIGHT := 0.01
## Extra rise when testing a step, so obstacles exactly max_step_height tall still fit.
const STEP_CLEARANCE := 0.02
## How far ahead to look for floor when stepping up or down, so the body lands clear of the obstacle's edge
## (Jolt rounds collision shape edges slightly) even when this frame's motion is only a few millimetres.
const STEP_PROBE_DISTANCE := 0.05
## Seconds the camera takes to catch up with the body after stepping up or down.
const STEP_SMOOTHING_TIME := 0.12
## Seconds the head bob takes to fade in or out.
const BOB_FADE_TIME := 0.2

@export_group("Speeds")
@export var walk_speed: float = 1.5
@export var sprint_speed: float = 3.0
@export var crouch_speed: float = 1.0
## Seconds to reach the target speed.
@export var acceleration_time: float = 0.15
## Seconds to slide to a stop from walk speed; stopping from a sprint takes proportionally longer.
@export var deceleration_time: float = 0.2

@export_group("Body")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var stand_eye_height: float = 1.65
@export var crouch_eye_height: float = 0.85
## Seconds the camera takes to move between standing and crouched eye height.
@export var crouch_transition_time: float = 0.2
## Tallest obstacle the player steps onto without jumping.
@export var max_step_height: float = 0.35

@export_group("Camera")
## Degrees the view turns per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.1
## Horizontal field of view in degrees at 16:9.
@export var horizontal_fov: float = 90.0
## Turn off for players who get motion sick.
@export var head_bob_enabled: bool = true
## Metres the camera bobs up and down while walking.
@export var walk_bob_amplitude: float = 0.013
## Metres the camera bobs up and down while sprinting.
@export var sprint_bob_amplitude: float = 0.017
## Metres travelled per full bob cycle (two footsteps).
@export var bob_stride_length: float = 1.6

var movement_state: MovementRules.State = MovementRules.State.IDLE
var is_crouched: bool = false

var _crouch_toggled := false
var _stand_blocked := false
var _yaw := 0.0
var _pitch := 0.0
var _eye_height := 0.0
var _step_offset := 0.0
var _bob_phase := 0.0
var _bob_amplitude := 0.0
var _body_shape: CylinderShape3D

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	# Each player gets its own shape, because crouching changes its height.
	_body_shape = (_collision_shape.shape as CylinderShape3D).duplicate()
	_collision_shape.shape = _body_shape
	_apply_body_height(stand_height)
	_eye_height = stand_eye_height
	_yaw = rotation.y
	floor_snap_length = max_step_height
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_fov) / 2.0) / REFERENCE_ASPECT))
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_update_camera()
	_set_mouse_captured(true)
	Log.info("🏃 Player ready: position=%s, walk=%.1f, sprint=%.1f, crouch=%.1f m/s, max_step=%.2f m, fov=%.0f°" % [
		global_position, walk_speed, sprint_speed, crouch_speed, max_step_height, horizontal_fov])


func _unhandled_input(event: InputEvent) -> void:
	var mouse_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and mouse_captured:
		# screen_relative is raw pixel movement, unaffected by window scaling.
		var turn := (event as InputEventMouseMotion).screen_relative * deg_to_rad(mouse_sensitivity)
		var pitch_limit := deg_to_rad(PITCH_LIMIT_DEGREES)
		_yaw = wrapf(_yaw - turn.x, -PI, PI)
		_pitch = clampf(_pitch - turn.y, -pitch_limit, pitch_limit)
	elif event.is_action_pressed("pause") and mouse_captured:
		_set_mouse_captured(false)
	elif event is InputEventMouseButton and event.is_pressed() and not mouse_captured:
		_set_mouse_captured(true)


func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint_wanted := MovementRules.wants_sprint(input_dir, Input.is_action_pressed("sprint"))
	_crouch_toggled = MovementRules.next_crouch_toggle(
		_crouch_toggled, Input.is_action_just_pressed("crouch_toggle"), sprint_wanted)
	_update_crouch(MovementRules.wants_crouch(Input.is_action_pressed("crouch_hold"), _crouch_toggled, sprint_wanted))
	_set_movement_state(MovementRules.resolve_state(input_dir, sprint_wanted, is_crouched))
	_update_velocity(input_dir, delta)
	_try_step_up(delta)
	_move_and_follow_floor()


func _process(delta: float) -> void:
	var eye_target := crouch_eye_height if is_crouched else stand_eye_height
	var eye_speed := (stand_eye_height - crouch_eye_height) / crouch_transition_time
	_eye_height = move_toward(_eye_height, eye_target, eye_speed * delta)
	_step_offset = move_toward(_step_offset, 0.0, max_step_height / STEP_SMOOTHING_TIME * delta)
	_update_head_bob(delta)
	_update_camera()


func _update_crouch(wants_crouch: bool) -> void:
	if wants_crouch:
		_stand_blocked = false
		if not is_crouched:
			is_crouched = true
			_apply_body_height(crouch_height)
			Log.info("🏃 Crouched: toggled=%s, position=%s" % [_crouch_toggled, global_position])
	elif is_crouched:
		_try_stand_up()


func _try_stand_up() -> void:
	if test_move(global_transform, up_direction * (stand_height - crouch_height)):
		if not _stand_blocked:
			_stand_blocked = true
			Log.info("🏃 No room to stand up, staying crouched: position=%s" % global_position)
	else:
		is_crouched = false
		_stand_blocked = false
		_apply_body_height(stand_height)
		Log.info("🏃 Stood up: position=%s" % global_position)


func _set_movement_state(new_state: MovementRules.State) -> void:
	if new_state != movement_state:
		var previous := movement_state
		movement_state = new_state
		Log.info("🏃 Movement state changed: %s -> %s" % [
			MovementRules.State.keys()[previous], MovementRules.State.keys()[new_state]])
		movement_state_changed.emit(previous, new_state)


func _update_velocity(input_dir: Vector2, delta: float) -> void:
	var target_speed := MovementRules.speed_for_state(movement_state, walk_speed, sprint_speed, crouch_speed)
	var target := global_basis * Vector3(input_dir.x, 0.0, input_dir.y) * target_speed
	var moving := input_dir.length() > MovementRules.MOVE_THRESHOLD
	var rate := target_speed / acceleration_time if moving else walk_speed / deceleration_time
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta


## Lifts the body onto an obstacle no taller than max_step_height when one blocks this frame's move:
## rise as far as the ceiling allows, move forward at that height, then come back down onto the obstacle.
## Pressed against an obstacle, a frame's motion is only millimetres, so the body moves at least
## STEP_PROBE_DISTANCE forward to land on top of it. Runs every physics frame, so it only logs when it steps.
func _try_step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	var blocker := KinematicCollision3D.new()
	if not is_on_floor() or motion.is_zero_approx() or not test_move(global_transform, motion, blocker):
		return
	if blocker.get_normal().angle_to(up_direction) <= floor_max_angle:
		return

	var raised := global_transform
	var rise := up_direction * (max_step_height + STEP_CLEARANCE)
	var ceiling := KinematicCollision3D.new()
	if test_move(raised, rise, ceiling):
		rise = ceiling.get_travel()
	raised.origin += rise
	var forward := motion.normalized() * maxf(motion.length(), STEP_PROBE_DISTANCE)
	if test_move(raised, forward):
		return

	var ahead := raised.translated(forward)
	var landing := KinematicCollision3D.new()
	if not test_move(ahead, -rise, landing):
		return
	var landing_position := ahead.origin + landing.get_travel()
	var step_height := (landing_position - global_position).dot(up_direction)
	var too_steep := landing.get_normal().angle_to(up_direction) > floor_max_angle
	if step_height < MIN_STEP_HEIGHT or step_height > max_step_height + MIN_STEP_HEIGHT or too_steep:
		return

	global_position = landing_position
	_smooth_camera_step(step_height)
	Log.info("🏃 Stepped up: height=%.2f m, obstacle=%s, position=%s" % [
		step_height, (landing.get_collider() as Node).name, global_position])


## Moves the body, keeps it on the floor when it walks off an obstacle, and smooths the camera on the way down.
func _move_and_follow_floor() -> void:
	var was_on_floor := is_on_floor()
	var height_before := global_position.dot(up_direction)
	move_and_slide()
	if was_on_floor and not is_on_floor() and velocity.dot(up_direction) <= 0.0:
		_snap_down_off_edge()
	var drop := height_before - global_position.dot(up_direction)
	var on_moving_platform := not get_platform_velocity().is_zero_approx()
	if was_on_floor and is_on_floor() and drop > MIN_STEP_HEIGHT and not on_moving_platform:
		_smooth_camera_step(-drop)
		Log.info("🏃 Stepped down: height=%.2f m, position=%s" % [drop, global_position])


## Godot's floor snap fails while the body still touches the edge it just walked off, because the downward
## test hits that edge first. Look for floor a little further along the direction of travel instead, and
## drop onto it when it is no deeper than a step. Deeper drops are left to gravity.
func _snap_down_off_edge() -> void:
	var travel_direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var probe := global_transform.translated(travel_direction * STEP_PROBE_DISTANCE)
	var landing := KinematicCollision3D.new()
	if test_move(probe, -up_direction * (max_step_height + STEP_CLEARANCE), landing) \
			and landing.get_normal().angle_to(up_direction) <= floor_max_angle:
		global_position += up_direction * landing.get_travel().dot(up_direction)
		apply_floor_snap()


## Keeps the camera where it was when the body moves up or down a step, then lets it catch up smoothly.
func _smooth_camera_step(height_change: float) -> void:
	_step_offset = clampf(_step_offset - height_change, -max_step_height, max_step_height)
	reset_physics_interpolation()


func _update_head_bob(delta: float) -> void:
	var target_amplitude := 0.0
	if head_bob_enabled and movement_state == MovementRules.State.WALK:
		target_amplitude = walk_bob_amplitude
	elif head_bob_enabled and movement_state == MovementRules.State.SPRINT:
		target_amplitude = sprint_bob_amplitude
	_bob_amplitude = move_toward(_bob_amplitude, target_amplitude, sprint_bob_amplitude / BOB_FADE_TIME * delta)
	var speed := Vector2(velocity.x, velocity.z).length()
	_bob_phase = fmod(_bob_phase + speed * delta / bob_stride_length * TAU, TAU)


## Places the camera at eye height on the physics-interpolated body, so movement looks smooth on high
## refresh rate screens, while the look direction comes straight from the latest mouse input.
func _update_camera() -> void:
	var look := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var bob := Basis(Vector3.UP, _yaw) * Vector3(
		sin(_bob_phase) * _bob_amplitude * 0.5, sin(_bob_phase * 2.0) * _bob_amplitude, 0.0)
	var feet := get_global_transform_interpolated().origin
	_camera.global_transform = Transform3D(look, feet + up_direction * (_eye_height + _step_offset) + bob)


func _apply_body_height(height: float) -> void:
	_body_shape.height = height
	_collision_shape.position.y = height / 2.0


func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	Log.info("🏃 Mouse %s" % ("captured" if captured else "released"))
