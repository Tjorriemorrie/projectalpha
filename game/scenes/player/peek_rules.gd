class_name PeekRules
extends RefCounted
## The free peek's decisions, kept free of nodes and input so they can be unit tested. Head offsets are in metres
## in the body's frame: x is right, y is up.

enum State { NONE, PEEK, AIM_OUT }

## A head closer to its normal position than this fraction of its range counts as centred.
const CENTRED_FRACTION := 0.1
## Stops a range of zero from dividing by zero.
const MIN_RANGE := 0.001


## How far out the head is, as a fraction of its range in each direction: the head's range is an ellipse that
## reaches side to either side, up above and down below, and this maps it onto the unit circle.
static func range_fraction(offset: Vector2, side: float, up: float, down: float) -> Vector2:
	var vertical := up if offset.y >= 0.0 else down
	return Vector2(offset.x / maxf(side, MIN_RANGE), offset.y / maxf(vertical, MIN_RANGE))


## Pulls a head offset back onto the edge of its range when it is outside, keeping its direction.
static func clamp_to_range(offset: Vector2, side: float, up: float, down: float) -> Vector2:
	var reach := range_fraction(offset, side, up, down).length()
	return offset / reach if reach > 1.0 else offset


static func is_centred(offset: Vector2, side: float, up: float, down: float) -> bool:
	return range_fraction(offset, side, up, down).length() < CENTRED_FRACTION


## Where the head goes when aiming out: the edge of the larger aim-out range, in the direction of the peek.
## Aiming out reaches no further down than peeking.
static func aim_out_offset(peek_offset: Vector2, side: float, up: float, down: float,
		aim_side: float, aim_up: float) -> Vector2:
	var direction := range_fraction(peek_offset, side, up, down).normalized()
	return Vector2(direction.x * aim_side, direction.y * (aim_up if direction.y >= 0.0 else down))


## Aim out is decided when aim is pressed: off-centre while peeking aims out until aim is released; otherwise aim
## stays plain aim down sights until released, even if the head moves off-centre meanwhile.
static func next_state(current: State, peek_held: bool, aim_held: bool, aim_pressed: bool, centred: bool) -> State:
	if not peek_held:
		return State.NONE
	if aim_held and (current == State.AIM_OUT or (aim_pressed and not centred)):
		return State.AIM_OUT
	return State.PEEK


## Degrees the view rolls towards a sideways lean: positive leans right. Grows with the lean and stops at
## max_tilt once the head is a full peek's side reach out, so aiming out further doesn't tilt it more.
static func tilt_degrees(offset_x: float, side: float, max_tilt: float) -> float:
	return clampf(offset_x / maxf(side, MIN_RANGE), -1.0, 1.0) * max_tilt
