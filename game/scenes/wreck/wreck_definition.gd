class_name WreckDefinition
extends ContentDefinition
## A wreck layout in the content registry: a scene built by hand from kit sections (its root a Wreck, with the
## player in the airlock), the range of hidden difficulty levels it is rolled at, how many robots are expected aboard
## at each of them, and how many containers it holds. Its robots and loot are rolled onto its markers every run (see
## WreckRoll), so the same layout plays differently each time.

## Difficulty levels run from 1 to MAX_LEVEL. The player never sees one; they see what makes a wreck dangerous.
const MAX_LEVEL := 5
## The fewest robots a layout may expect at any level: enough that a wreck rolled the spread below it still holds
## WreckRoll.MIN_ROBOTS, so the scan's estimate never undersells a wreck.
const LEAST_EXPECTED_ROBOTS := WreckRoll.MIN_ROBOTS + WreckRoll.ROBOT_SPREAD

## The layout's scene, whose root is a Wreck. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var scene := ""
## The lowest (x) and highest (y) difficulty level it is rolled at, evenly.
@export var levels := Vector2i(1, 1)
## How many robots are expected aboard at each of its levels, lowest level first: what the system map shows. The
## wreck holds this many give or take one, and never fewer than two; each must be at least LEAST_EXPECTED_ROBOTS.
@export var expected_robots := PackedInt32Array([LEAST_EXPECTED_ROBOTS])
## How many containers it holds, each on a random loot marker.
@export var containers := 0


## The scene's res:// path, also when the inspector stored a uid://.
func get_scene_path() -> String:
	return ResourceUID.ensure_path(scene)


## How many robots are expected aboard at a level within its range.
func expected_robots_at(level: int) -> int:
	return expected_robots[clampi(level, levels.x, levels.y) - levels.x]


func get_problems() -> PackedStringArray:
	var problems := super()
	if scene.is_empty():
		problems.append("Wreck has no scene")
	elif not ResourceLoader.exists(get_scene_path()):
		problems.append("Wreck scene not found: scene=%s" % scene)
	if levels.x < 1 or levels.y > MAX_LEVEL or levels.x > levels.y:
		problems.append("Wreck levels out of range: levels=%s, max=%d" % [levels, MAX_LEVEL])
	elif expected_robots.size() != levels.y - levels.x + 1:
		problems.append("Wreck needs one expected robot count per level: levels=%s, expected_robots=%s" % [
			levels, expected_robots])
	for count in expected_robots:
		if count < LEAST_EXPECTED_ROBOTS:
			problems.append("Wreck expects too few robots, every level needs at least %d: expected_robots=%s" % [
				LEAST_EXPECTED_ROBOTS, expected_robots])
			break
	if containers < 0:
		problems.append("Wreck has a negative number of containers: containers=%d" % containers)
	return problems
