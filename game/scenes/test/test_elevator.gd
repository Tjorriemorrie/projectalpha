extends AnimatableBody3D
## Test-scene elevator: rides between its start height and travel_height above it, pausing at each end.
## Wrecks use the Elevator section (scenes/sections/elevator.tscn) instead.

@export var travel_height: float = 4.0
@export var speed: float = 1.5
@export var wait_time: float = 2.0

var _bottom_height := 0.0
var _going_up := true
var _wait_left := 0.0


func _ready() -> void:
	_bottom_height = position.y
	_wait_left = wait_time
	Log.info("🛗 Test elevator ready: bottom=%.2f m, travel=%.2f m, speed=%.1f m/s, wait=%.1f s" % [
		_bottom_height, travel_height, speed, wait_time])


func _physics_process(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
	else:
		var target := _bottom_height + (travel_height if _going_up else 0.0)
		position.y = move_toward(position.y, target, speed * delta)
		if is_equal_approx(position.y, target):
			_going_up = not _going_up
			_wait_left = wait_time
			Log.info("🛗 Test elevator arrived: height=%.2f m, next=%s" % [position.y, "up" if _going_up else "down"])
