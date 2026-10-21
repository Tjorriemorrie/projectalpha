class_name RobotHeat
extends RefCounted
## A robot's laser heat, kept free of nodes so it can be unit tested. Every shot adds the definition's shot heat
## (0 is cold, 1 is full), and the heat cools off once the robot has held its fire for the cool delay. At full heat
## the robot has to vent: it can't fire until the vent is over, and the heat drains as it vents.

## Heat differences smaller than this count as equal, so six shots of a sixth exactly fill the heat.
const EPSILON := 0.0001

var heat := 0.0
var is_venting := false

var _vent_left := 0.0
var _since_shot := INF


func can_fire() -> bool:
	return not is_venting


## Adds the heat of a shot, and returns whether it filled the heat so the robot now vents.
func add_shot(definition: EnemyDefinition) -> bool:
	heat = minf(heat + definition.shot_heat, 1.0)
	_since_shot = 0.0
	if heat + EPSILON < 1.0:
		return false
	heat = 1.0
	is_venting = true
	_vent_left = definition.vent_time
	return true


## Cools the heat, or drains it while venting. Returns whether a vent finished this frame.
func update(delta: float, definition: EnemyDefinition) -> bool:
	if is_venting:
		_vent_left -= delta
		heat = clampf(_vent_left / maxf(definition.vent_time, 0.001), 0.0, 1.0)
		if _vent_left > 0.0:
			return false
		is_venting = false
		heat = 0.0
		return true
	_since_shot += delta
	if _since_shot >= definition.cool_delay:
		heat = maxf(heat - definition.cool_rate * delta, 0.0)
	return false
