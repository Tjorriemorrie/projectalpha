class_name SystemConsole
extends StaticBody3D
## The cockpit console in front of the pilot seat: interact opens the system map, where the player inspects the
## system's wrecks and flies the ship to them or back to the hub. Its screen shows the system the ship is in. It faces
## +Z, with its origin in the middle of its back on the floor.

## What the screen says, with the system's name.
@export var screen_format := "SYSTEM MAP\n%s"

@onready var _interactable: Interactable = %Interactable
@onready var _screen_text: Label3D = %ScreenText


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	var system_name := GameSession.system.definition.display_name if GameSession.system else "no system"
	_screen_text.text = screen_format % system_name.to_upper()
	Log.info("🚀 System console ready: console=%s, system=%s, position=%s" % [name, system_name, global_position])


func get_interactable() -> Interactable:
	return _interactable


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 System console used with no player to open the map for: console=%s" % name)
		return
	Log.info("🚀 System console used, opening the system map: console=%s" % name)
	player.open_system_map()
