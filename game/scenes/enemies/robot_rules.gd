class_name RobotRules
extends RefCounted
## Robot decisions that need no state, kept free of nodes so they can be unit tested: what a robot can see, how
## wide it fires, and how a turret turns. Directions follow Godot's convention: forward is −Z.


## Whether point is within sight_range metres of eye and inside the view cone, sight_angle degrees across, around
## forward. Walls are the caller's business (a ray against world).
static func in_view(eye: Vector3, forward: Vector3, point: Vector3, sight_range: float, sight_angle: float) -> bool:
	var to_point := point - eye
	var distance := to_point.length()
	if distance > sight_range:
		return false
	if distance < 0.001:
		return true
	return forward.normalized().dot(to_point / distance) >= cos(deg_to_rad(sight_angle / 2.0))


## Metres within which a robot sees a part of the player: its full sight range when the part is lit, its dark sight
## range when not.
static func sight_range_for(definition: EnemyDefinition, lit: bool) -> float:
	return definition.sight_range if lit else minf(definition.dark_sight_range, definition.sight_range)


## Degrees from the aimed point that a shot lands within, after keeping the player in sight for aim_time seconds
## since locking on: wide at first, walking in to the definition's spread over its settle time.
static func aim_spread(definition: EnemyDefinition, aim_time: float) -> float:
	var settled := clampf(aim_time / maxf(definition.settle_time, 0.001), 0.0, 1.0)
	return lerpf(definition.initial_spread, definition.spread, settled)


## The yaw (x) and pitch (y), in radians, that turn forward (−Z of frame) from from towards target. Yaw is positive
## to the left, pitch positive upwards.
static func aim_angles(frame: Basis, from: Vector3, target: Vector3) -> Vector2:
	var local := frame.orthonormalized().inverse() * (target - from)
	return Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))


## A yaw in radians, kept within an arc arc_degrees across centred on forward.
static func clamp_to_arc(yaw: float, arc_degrees: float) -> float:
	var half := deg_to_rad(minf(arc_degrees, 360.0)) / 2.0
	return clampf(wrapf(yaw, -PI, PI), -half, half)


## An angle in radians turned towards target by at most max_step. With wraps on it turns the shorter way round;
## off, it never crosses behind (a turret whose arc is less than a full circle).
static func turn_towards(angle: float, target: float, max_step: float, wraps: bool = true) -> float:
	var difference := wrapf(target - angle, -PI, PI) if wraps else target - angle
	return angle + clampf(difference, -max_step, max_step)
