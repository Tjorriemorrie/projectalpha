class_name ContainerDefinition
extends ContentDefinition
## A loot container in the content registry: its scene (body, model, lid and sounds), which only loads when a wreck
## places it, and the size of the grid that holds its loot. Its size hints at the haul before the player spends time
## prying it open.

## The container's scene, whose root is a LootContainer. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var scene := ""
## Columns and rows of its grid.
@export var grid_size := Vector2i(4, 3)
## Small enough for a tight loot marker (in a vent or a dead end). Every container fits a room's markers.
@export var fits_tight := false


## The scene's res:// path, also when the inspector stored a uid://.
func get_scene_path() -> String:
	return ResourceUID.ensure_path(scene)


func get_problems() -> PackedStringArray:
	var problems := super()
	if scene.is_empty():
		problems.append("Container has no scene")
	elif not ResourceLoader.exists(get_scene_path()):
		problems.append("Container scene not found: scene=%s" % scene)
	if grid_size.x <= 0 or grid_size.y <= 0:
		problems.append("Container grid is empty: grid_size=%s" % grid_size)
	return problems
