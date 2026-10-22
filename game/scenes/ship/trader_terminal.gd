class_name TraderTerminal
extends StaticBody3D
## The ship's trader terminal, beside the stash: the comms link to the system's trader hub. Nobody docks to trade on
## the rim; the hub's drones carry the cargo both ways, so the player trades from here without leaving the ship.
## Interact opens the hub's screen. Like the cockpit console it faces +Z, with its origin in the middle of its back on
## the floor. Its screen shows the hub it is linked to.

@onready var _interactable: Interactable = %Interactable
@onready var _screen_text: Label3D = %ScreenText


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_screen_text.text = "TRADER LINK\n%s" % GameSession.trader.title.to_upper()
	Log.info("🚀 Trader terminal ready: terminal=%s, hub=%s, position=%s" % [
		name, GameSession.trader.title, global_position])


func get_interactable() -> Interactable:
	return _interactable


func _on_interacted() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🚀 Trader terminal used with no player to open the hub for: terminal=%s" % name)
		return
	Log.info("🚀 Trader terminal used, opening the hub: terminal=%s, hub=%s" % [name, GameSession.trader.title])
	player.open_trader()
