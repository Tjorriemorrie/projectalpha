class_name SystemConsole
extends StaticBody3D
## The cockpit console in front of the pilot seat: interact opens the system map, where the player inspects the
## system's wrecks and flies the ship to them or back to the hub, and its second tab, the star map, where the player
## jumps to other systems. Its screen shows the system the ship is in, and changes with a jump. It faces +Z, with its
## origin in the middle of its back on the floor.

## What the screen says, with the system's name.
@export var screen_format := "SYSTEM MAP\n%s"

@onready var _interactable: Interactable = %Interactable
@onready var _screen_text: Label3D = %ScreenText


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	GameSession.ship_moved.connect(_show_system)
	_show_system()
	Log.info("🚀 System console ready: console=%s, system=%s, position=%s" % [name, _system_name(), global_position])


func get_interactable() -> Interactable:
	return _interactable


## What the screen says, for tests: e.g. "SYSTEM MAP\nPRAETOR".
func screen_text() -> String:
	return _screen_text.text


## The screen names the system the ship is in.
func _show_system() -> void:
	_screen_text.text = screen_format % _system_name().to_upper()
	Log.info("🚀 System console shows the system: console=%s, system=%s" % [name, _system_name()])


func _system_name() -> String:
	return GameSession.system.definition.display_name if GameSession.system else "no system"


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 System console used with no player to open the map for: console=%s" % name)
		return
	Log.info("🚀 System console used, opening the system map: console=%s" % name)
	player.open_system_map()
