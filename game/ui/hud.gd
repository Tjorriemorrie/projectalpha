class_name Hud
extends CanvasLayer
## The player's heads-up display: a centre dot that shows where the player is looking, and under it the prompt
## for the interactable they are looking at, styled like an equipment placard ("[E]  Call elevator").

## Seconds the prompt takes to fade in.
const FADE_TIME := 0.12

var prompt_text := ""

var _fade: Tween

@onready var _prompt: Control = $Root/Prompt
@onready var _key: Label = $Root/Prompt/KeyCap/Key
@onready var _action: Label = $Root/Prompt/Action


func _ready() -> void:
	_prompt.visible = false


## Shows the key and what it does, or hides the prompt when action is empty.
func set_prompt(key: String, action: String) -> void:
	prompt_text = "" if action.is_empty() else "%s %s" % [key, action]
	if _fade:
		_fade.kill()
	if action.is_empty():
		_prompt.visible = false
		return
	var was_visible := _prompt.visible
	_key.text = key
	_action.text = action
	_prompt.visible = true
	if not was_visible:
		_prompt.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_prompt, "modulate:a", 1.0, FADE_TIME)
