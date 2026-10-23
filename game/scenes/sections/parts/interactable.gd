class_name Interactable
extends Area3D
## Something the player uses by looking at it within reach and pressing interact, or by holding interact on it for
## hold_time seconds (prying a container open). It lives on the interactable physics layer, where the player's look
## ray finds it; walls block that ray.

signal interacted
## Emitted when the player starts or stops holding interact on it, for one with a hold_time.
signal held_changed(held: bool)

## The interactable physics layer, which the player's look ray finds.
const LAYER := 3

## What using it does, shown after the interact key (e.g. "Call elevator").
@export var prompt := "Use"
## Seconds the player has to hold interact to use it; 0 uses it on the press.
@export var hold_time := 0.0


## Switches it on or off: one that is off leaves the interactable layer, so the look ray passes it by and the player
## sees no prompt.
func set_enabled(enabled: bool) -> void:
	set_collision_layer_value(LAYER, enabled)
	Log.info("🖐️ Interactable %s: target=%s/%s, prompt=%s" % [
		"enabled" if enabled else "disabled", get_parent().name, name, prompt])


func is_enabled() -> bool:
	return get_collision_layer_value(LAYER)


func interact() -> void:
	Log.info("🖐️ Interacted: target=%s/%s, prompt=%s" % [get_parent().name, name, prompt])
	interacted.emit()


## The player started (or stopped) holding interact on it; interact() follows when the hold is full.
func set_held(held: bool) -> void:
	Log.info("🖐️ Hold %s: target=%s/%s, prompt=%s, hold_time=%.1f s" % [
		"started" if held else "stopped", get_parent().name, name, prompt, hold_time])
	held_changed.emit(held)
