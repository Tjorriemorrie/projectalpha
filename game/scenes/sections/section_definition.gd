class_name SectionDefinition
extends ContentDefinition
## A wreck section in the content registry. Its scene is referenced by path and only loads when a wreck uses it.

## The section's scene, whose root is a Section. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var scene := ""


## The scene's res:// path, also when the inspector stored a uid://.
func get_scene_path() -> String:
	return ResourceUID.ensure_path(scene)


func get_problems() -> PackedStringArray:
	var problems := super()
	if scene.is_empty():
		problems.append("Section has no scene")
	elif not ResourceLoader.exists(get_scene_path()):
		problems.append("Section scene not found: scene=%s" % scene)
	return problems
