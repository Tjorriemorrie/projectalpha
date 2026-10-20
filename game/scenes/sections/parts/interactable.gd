class_name Interactable
extends Area3D
## Something the player uses by looking at it within reach and pressing interact. It lives on the interactable
## physics layer, where the player's look ray finds it; walls block that ray.

signal interacted

## What using it does, shown after the interact key (e.g. "Call elevator").
@export var prompt := "Use"


func interact() -> void:
	Log.info("🖐️ Interacted: target=%s/%s, prompt=%s" % [get_parent().name, name, prompt])
	interacted.emit()
