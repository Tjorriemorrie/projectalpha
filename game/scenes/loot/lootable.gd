class_name Lootable
extends Interactable
## Loot the player pries open by holding interact on it, then searches: a container, or a destroyed robot's
## wreckage. It holds the loot in an ItemGrid. Prying makes a scrape while it is held and a clunk when it gives,
## and the opening is a noise robots hear. Once open it stays open, and interact searches it straight away: the
## player opens the inventory screen with it. Its area should be a little bigger than the body it sits on, so the
## player's look ray finds it before the body.

## Emitted once, when it is pried open.
signal opened

## Seconds of holding interact to pry it open.
@export var pry_time := 1.5
## Metres the opening carries as noise, about as far as a walking step.
@export var pry_loudness := 4.0
@export var pry_sound: AudioStream = preload("res://assets/audio/loot/pry.wav")
@export var open_sound: AudioStream = preload("res://assets/audio/loot/pry_open.wav")

## What it is, shown in its prompts and above its grid (e.g. "Supply crate").
var title := ""
var grid: ItemGrid
var is_open := false

var _pry_player: AudioStreamPlayer3D
var _open_player: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false
	_pry_player = _add_sound(pry_sound, "PrySound")
	_open_player = _add_sound(open_sound, "OpenSound")
	held_changed.connect(_on_held_changed)
	_update_prompt()


## Names it and gives it an empty grid of this size.
func setup(loot_title: String, grid_size: Vector2i) -> void:
	title = loot_title
	grid = ItemGrid.new(grid_size)
	_update_prompt()


## Packs items into its grid in the order given, each in the first spot it fits. Returns the ones that didn't fit.
func fill(items: Array[ItemDefinition]) -> Array[ItemDefinition]:
	var left_out: Array[ItemDefinition] = []
	for definition in items:
		if not grid.add(Item.new(definition)):
			left_out.append(definition)
	Log.info("🎒 Loot packed: loot=%s, title=%s, items=%d, packed=%d, left_out=%d, free_cells=%d, value=%d" % [
		_path(), title, items.size(), items.size() - left_out.size(), left_out.size(), grid.free_cells(),
		grid.value()])
	return left_out


## Pries it open the first time; after that it is already open. Either way the player searches it next.
func interact() -> void:
	if not is_open:
		_open()
	super()


func _open() -> void:
	is_open = true
	hold_time = 0.0
	_pry_player.stop()
	_open_player.play()
	_update_prompt()
	Log.info("🎒 Pried open: loot=%s, title=%s, items=%d, value=%d, position=%s" % [
		_path(), title, grid.items.size() if grid else 0, grid.value() if grid else 0, global_position])
	Hearing.make_noise(self, global_position, pry_loudness, &"pry")
	opened.emit()


func _update_prompt() -> void:
	var what := title.to_lower() if not title.is_empty() else "container"
	prompt = ("Search %s" if is_open else "Pry open %s") % what
	hold_time = 0.0 if is_open else pry_time


func _on_held_changed(held: bool) -> void:
	if held and not is_open:
		_pry_player.play()
	else:
		_pry_player.stop()


func _add_sound(stream: AudioStream, sound_name: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = sound_name
	player.stream = stream
	player.unit_size = 4.0
	player.bus = &"Master"
	add_child(player)
	return player


func _path() -> String:
	return "%s/%s" % [get_parent().name, name] if get_parent() else String(name)
