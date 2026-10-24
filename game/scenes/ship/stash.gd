class_name Stash
extends StaticBody3D
## The ship's stash: a storage cabinet whose slots the GameSession keeps, so it survives every run and every death,
## and which grows so it never runs out of room. It is never pried open: interact opens it straight away in the
## inventory screen, in a container's place. Like a container it faces −Z, and its origin is the middle of its back on
## the floor.

@onready var _lootable: Lootable = %Lootable


func _ready() -> void:
	_lootable.bind("Stash", GameSession.stash)
	Log.info("🚀 Stash ready: stash=%s, grid=%s, items=%d, value=%d, position=%s" % [
		name, GameSession.stash.size, GameSession.stash.items.size(), GameSession.stash.value(), global_position])


func get_lootable() -> Lootable:
	return _lootable
