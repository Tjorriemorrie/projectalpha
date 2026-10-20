class_name MovementRules
extends RefCounted
## The player controller's movement decisions, kept free of nodes and input so they can be unit tested.
## Input directions come from Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
## so forward is negative y.

enum State { IDLE, WALK, SPRINT, CROUCH_IDLE, CROUCH_WALK }

## Input shorter than this counts as standing still.
const MOVE_THRESHOLD := 0.1


## Sprint only counts while moving forward: forward diagonals count, strafing and backing up don't.
## Peeking and the weapon (aiming, the trigger, reloading) block it.
static func wants_sprint(input_dir: Vector2, sprint_held: bool, blocked: bool = false) -> bool:
	return sprint_held and not blocked and input_dir.y < -MOVE_THRESHOLD


## The toggled crouch flips on each toggle press, and sprinting clears it so the player doesn't drop
## back into a crouch when the sprint ends.
static func next_crouch_toggle(toggled: bool, toggle_pressed: bool, sprint_wanted: bool) -> bool:
	var next := not toggled if toggle_pressed else toggled
	return next and not sprint_wanted


## Crouch is wanted while held or toggled on, unless the player is trying to sprint.
static func wants_crouch(crouch_held: bool, crouch_toggled: bool, sprint_wanted: bool) -> bool:
	return (crouch_held or crouch_toggled) and not sprint_wanted


## A crouched body can't sprint, even when sprint is wanted (for example when there is no room to stand).
static func resolve_state(input_dir: Vector2, sprint_wanted: bool, crouched: bool) -> State:
	var moving := input_dir.length() > MOVE_THRESHOLD
	if crouched:
		return State.CROUCH_WALK if moving else State.CROUCH_IDLE
	if not moving:
		return State.IDLE
	return State.SPRINT if sprint_wanted else State.WALK


## Peeking and aiming down sights cap the speed at crouch speed, standing or crouched.
static func speed_for_state(state: State, walk_speed: float, sprint_speed: float, crouch_speed: float,
		slowed: bool = false) -> float:
	if slowed:
		return crouch_speed
	match state:
		State.SPRINT:
			return sprint_speed
		State.CROUCH_IDLE, State.CROUCH_WALK:
			return crouch_speed
		_:
			return walk_speed
