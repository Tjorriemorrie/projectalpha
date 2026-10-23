class_name TraderTerminal
extends StaticBody3D
## The ship's trader terminal, beside the stash: the comms link to the system's trader hub. Nobody docks to trade on
## the rim; the hub's drones carry the cargo both ways, so the player trades from here without leaving the ship, but
## only while the ship is at the hub: away from it the link is out of range and the terminal can't be used. Interact
## opens the hub's screen. Like the cockpit console it faces +Z, with its origin in the middle of its back on the
## floor. Its screen shows the hub it is linked to, or that it is out of range.

## What the screen says: the hub's name, or that it is out of range.
@export var linked_text := "TRADER LINK\n%s"
@export var out_of_range_text := "TRADER LINK\nOUT OF RANGE"

@onready var _interactable: Interactable = %Interactable
@onready var _screen_text: Label3D = %ScreenText


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	GameSession.ship_moved.connect(_show_link)
	_show_link()
	Log.info("🚀 Trader terminal ready: terminal=%s, hub=%s, in_range=%s, position=%s" % [
		name, GameSession.trader.title, GameSession.at_hub, global_position])


func get_interactable() -> Interactable:
	return _interactable


## Links up with the hub while the ship is there; elsewhere the screen says it is out of range and the terminal is off.
func _show_link() -> void:
	var in_range := GameSession.at_hub
	_screen_text.text = linked_text % GameSession.trader.title.to_upper() if in_range else out_of_range_text
	_interactable.set_enabled(in_range)
	Log.info("🚀 Trader link %s: terminal=%s, hub=%s" % [
		"up" if in_range else "out of range", name, GameSession.trader.title])


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 Trader terminal used with no player to open the hub for: terminal=%s" % name)
		return
	Log.info("🚀 Trader terminal used, opening the hub: terminal=%s, hub=%s" % [name, GameSession.trader.title])
	player.open_trader()
