class_name AimTrail
extends RefCounted
## Where a target was a moment ago, so a robot can aim with a lag: shots at a moving player land where they were and
## trail behind them, while a player who holds still gets hit. Kept free of nodes so it can be unit tested. The robot
## records the player's position every physics frame and shifts its aim point by offset(). The lag is game time, so
## it holds at any physics tick rate.

## Seconds closer than this count as equal, so frames that add up to the lag reach it despite rounding.
const EPSILON := 0.0001

var _lag := 0.0
var _clock := 0.0
var _positions: Array[Vector3] = []
## When each position was recorded, on _clock.
var _times: Array[float] = []


func _init(lag_seconds: float) -> void:
	_lag = maxf(lag_seconds, 0.0)


## Records where the target is this physics frame, delta seconds after the last record.
func record(position: Vector3, delta: float) -> void:
	_clock += delta
	_positions.append(position)
	_times.append(_clock)
	# Keep the newest record that is at least the lag old, and everything since.
	while _times.size() > 1 and _clock - _times[1] >= _lag - EPSILON:
		_times.pop_front()
		_positions.pop_front()


## How far the target has moved since the lag ago (or since the first record, if that is more recent), pointing back
## to where it was. Add it to a point on the target to aim where that point was.
func offset() -> Vector3:
	if _positions.is_empty():
		return Vector3.ZERO
	return _positions[0] - _positions[_positions.size() - 1]
