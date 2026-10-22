class_name ContainerDefinition
extends ContentDefinition
## A loot container in the content registry: its scene (body, model, lid and sounds), which only loads when a wreck
## places it, the size of the grid that holds its loot, and how its loot is rolled: its loot table (item IDs and their
## weights) and its bitcoin budget at level 1, which the wreck's level scales (see LootRoll). Bigger containers get
## bigger budgets, so their size hints at the haul before the player spends time prying one open.

## The container's scene, whose root is a LootContainer. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var scene := ""
## Columns and rows of its grid.
@export var grid_size := Vector2i(4, 3)
## Small enough for a tight loot marker (in a vent or a dead end). Every container fits a room's markers.
@export var fits_tight := false
## How often it is rolled for a loot marker it fits, against the other containers that fit there.
@export var weight := 1.0
## Bitcoin worth of loot it holds at level 1; each level above adds half of it again (see LootRoll).
@export var budget := 0
## Its loot table: item IDs and how often each is drawn against the others. IDs are looked up when loot is rolled.
@export var loot: Dictionary[String, float] = {}


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
	if weight < 0.0:
		problems.append("Container weight is negative: weight=%s" % weight)
	if budget < 0:
		problems.append("Container budget is negative: budget=%d" % budget)
	for id in loot:
		if loot[id] < 0.0:
			problems.append("Container loot weight is negative: item=%s, weight=%s" % [id, loot[id]])
	return problems
