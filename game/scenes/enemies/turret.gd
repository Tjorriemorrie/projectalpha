class_name Turret
extends Robot
## A turret hanging from the ceiling. It never moves: its %Ring turns within its arc and its %Head tilts, carrying
## the eye. Idle, it sweeps its arc; otherwise it turns to its focus (a noise, the player it tracks, or where it last
## saw them). Its servos whir while it turns. Destroyed, its head slumps on the mount. Its origin is where it hangs
## from the ceiling, and the middle of its arc is its forward (−Z). Out of reach up there, its body is on no physics
## layer while it works, so it never holds a door open; its wreckage joins the world layer like any robot's.

## Degrees from its focus within which it counts as turned to it.
const FOCUS_TOLERANCE := 5.0
## Degrees the head droops when destroyed, and seconds it takes.
const SLUMP_PITCH := -75.0
const SLUMP_TIME := 0.5
## Turn rate, as a share of turn_speed, at which the servo whir is at full volume.
const SERVO_FULL := 0.5

@export_group("Turning")
## Degrees across the arc the ring can turn within, centred on the turret's forward. 360 turns all the way round.
@export var arc: float = 180.0
## Degrees per second the ring and head turn while tracking or turning to a noise.
@export var turn_speed: float = 120.0
## Degrees per second it sweeps while idle, and seconds it pauses at each end of the sweep.
@export var sweep_speed: float = 30.0
@export var sweep_pause: float = 1.0
## Degrees the head tilts while sweeping (negative is down), and the most it can tilt down and up.
@export var sweep_pitch: float = -20.0
@export var max_pitch_down: float = 80.0
@export var max_pitch_up: float = 15.0

## Radians the ring is turned from forward (positive to the left) and the head tilted (positive up).
var yaw := 0.0
var pitch := 0.0

var _sweep_direction := 1.0
var _sweep_pause_left := 0.0
var _servo_volume_db := 0.0

@onready var _ring: Node3D = %Ring
@onready var _head: Node3D = %Head


func _ready_body() -> void:
	# The model's turning parts ride on the pivots, keeping where they are, so turning a pivot turns its part.
	_model.get_node("Ring").reparent(_ring)
	_model.get_node("Head").reparent(_head)
	pitch = deg_to_rad(sweep_pitch)
	_servo_volume_db = _idle_sound.volume_db
	_apply_pose()
	Log.info("🤖 Turret ready: robot=%s, arc=%.0f°, turn_speed=%.0f°/s, sweep_speed=%.0f°/s, facing=%s" % [
		name, arc, turn_speed, sweep_speed, -global_basis.z])


## Sweeps while idle, otherwise turns to its focus, no faster than its turn speed and never out of its arc.
func _move(delta: float) -> void:
	var target: Vector2
	var speed := turn_speed
	if mind.state == RobotMind.State.IDLE and not mind.is_locking:
		target = _sweep_target(delta)
		speed = sweep_speed
	else:
		target = focus_angles()
	var step := deg_to_rad(speed) * delta
	var next_yaw := RobotRules.turn_towards(yaw, target.x, step, arc >= 360.0)
	var next_pitch := move_toward(pitch, target.y, step)
	var turned := absf(next_yaw - yaw) + absf(next_pitch - pitch)
	yaw = next_yaw
	pitch = next_pitch
	_apply_pose()
	_update_servo(turned / maxf(deg_to_rad(turn_speed) * delta, 0.0001))


## The yaw and pitch that point the head at the mind's focus, kept within the arc and the head's tilt.
func focus_angles() -> Vector2:
	var angles := RobotRules.aim_angles(global_basis, _head.global_position, mind.focus)
	return Vector2(RobotRules.clamp_to_arc(angles.x, arc),
		clampf(angles.y, -deg_to_rad(max_pitch_down), deg_to_rad(max_pitch_up)))


func _is_at_focus() -> bool:
	var target := focus_angles()
	var tolerance := deg_to_rad(FOCUS_TOLERANCE)
	return absf(wrapf(target.x - yaw, -PI, PI)) <= tolerance and absf(target.y - pitch) <= tolerance


## Back and forth across the arc (all the way round for a full circle), pausing at each end.
func _sweep_target(delta: float) -> Vector2:
	var sweep_pitch_radians := deg_to_rad(sweep_pitch)
	if arc >= 360.0:
		return Vector2(yaw + _sweep_direction * PI / 2.0, sweep_pitch_radians)
	var end := deg_to_rad(arc) / 2.0 * _sweep_direction
	if absf(yaw - end) > 0.001:
		return Vector2(end, sweep_pitch_radians)
	_sweep_pause_left -= delta
	if _sweep_pause_left <= 0.0:
		_sweep_direction = -_sweep_direction
		_sweep_pause_left = sweep_pause
	return Vector2(yaw, sweep_pitch_radians)


func _apply_pose() -> void:
	_ring.rotation.y = yaw
	_head.rotation.x = pitch


## The servos whir louder the faster the turret turns, and fall silent while it holds still.
func _update_servo(turn_share: float) -> void:
	var volume := clampf(turn_share / SERVO_FULL, 0.0, 1.0)
	if volume <= 0.01:
		if _idle_sound.playing:
			_idle_sound.stop()
		return
	_idle_sound.volume_db = _servo_volume_db + linear_to_db(volume)
	if not _idle_sound.playing:
		_idle_sound.play()


## The head slumps on the mount, and comes to rest with a clunk.
func _destroy_body() -> void:
	var tween := create_tween()
	tween.tween_property(_head, "rotation:x", deg_to_rad(SLUMP_PITCH), SLUMP_TIME) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_crash)
	Log.info("🤖 Turret slumping: robot=%s, yaw=%.0f°, pitch=%.0f°" % [name, rad_to_deg(yaw), rad_to_deg(pitch)])
