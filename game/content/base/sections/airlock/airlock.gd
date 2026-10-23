class_name Airlock
extends Section
## The airlock a ship docks at: an inner doorway into the rest of the wreck (its socket must be joined) and an outer
## door to whatever is docked outside, with a sign above it. Holding interact on the outer door cycles the airlock:
## on a wreck the player returns to their ship (extracts), on the ship they board the wreck. Cycling is loud: while
## interact is held the airlock pumps and hisses, and every noise_interval seconds it is a noise robots hear. When
## the hold completes it emits cycled, and the level decides what that means.

## Emitted when interact has been held on the outer door for cycle_time seconds.
signal cycled

## What cycling does here, shown after the interact key.
@export var prompt := "Return to ship"
## What the sign above the outer door says is docked outside.
@export var sign_text := "SHIP DOCKED"
## Seconds interact must be held on the outer door.
@export var cycle_time := 3.0
## Metres the cycling carries as noise, as far as a sprinting step, when the hold starts and every noise_interval
## seconds while it is held.
@export var cycle_loudness := 10.0
@export var noise_interval := 1.0

var _since_noise := 0.0

@onready var _outer_door: Interactable = %OuterDoor
@onready var _cycle_sound: AudioStreamPlayer3D = %CycleSound
@onready var _sign: Label3D = %Sign


func _ready() -> void:
	_outer_door.held_changed.connect(_on_held_changed)
	_outer_door.interacted.connect(_on_cycled)
	set_physics_process(false)
	_apply()
	Log.info("🚪 Airlock ready: airlock=%s, prompt=%s, cycle_time=%.1f s, loudness=%.0f m" % [
		name, prompt, cycle_time, cycle_loudness])


## Sets what cycling does here: the ship's airlock boards the wreck, a wreck's returns to the ship.
func set_purpose(cycle_prompt: String, docked_sign: String, time: float) -> void:
	prompt = cycle_prompt
	sign_text = docked_sign
	cycle_time = time
	_apply()
	Log.info("🚪 Airlock purpose set: airlock=%s, prompt=%s, sign=%s, cycle_time=%.1f s" % [
		name, prompt, sign_text, cycle_time])


## Opens or shuts the outer door to cycling: on the ship it is shut while nothing is docked outside.
func set_usable(usable: bool) -> void:
	_outer_door.set_enabled(usable)
	Log.info("🚪 Airlock %s: airlock=%s, sign=%s" % ["usable" if usable else "shut", name, sign_text])


func get_outer_door() -> Interactable:
	return _outer_door


func _apply() -> void:
	_outer_door.prompt = prompt
	_outer_door.hold_time = cycle_time
	_sign.text = sign_text


## Runs only while interact is held on the outer door, so it only logs (through Hearing) the noises it makes.
func _physics_process(delta: float) -> void:
	_since_noise += delta
	if _since_noise >= noise_interval:
		_since_noise -= noise_interval
		_make_noise()


func _on_held_changed(held: bool) -> void:
	set_physics_process(held)
	if held:
		_cycle_sound.play()
		_since_noise = 0.0
		_make_noise()
	else:
		_cycle_sound.stop()
	Log.info("🚪 Airlock cycling %s: airlock=%s, prompt=%s" % ["started" if held else "stopped", name, prompt])


func _on_cycled() -> void:
	set_physics_process(false)
	_cycle_sound.stop()
	Log.info("🚪 Airlock cycled: airlock=%s, prompt=%s, position=%s" % [name, prompt, _outer_door.global_position])
	cycled.emit()


func _make_noise() -> void:
	Hearing.make_noise(self, _outer_door.global_position, cycle_loudness, &"airlock")
