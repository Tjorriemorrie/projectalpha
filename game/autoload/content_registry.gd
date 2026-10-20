extends Node
## Registers every content definition by ID at startup, so systems look content up by ID instead of hard-coding
## it. Each folder in game/content/ is a pack; the base game is the pack "base" and loads exactly the way other
## packs will. Inside a pack, content is grouped by kind, and each piece of content has its own folder,
## content/<pack>/<kind>/<name>/, holding exactly one ContentDefinition, which registers as "<pack>:<name>".
## Autoloaded as ContentRegistry. It has no class_name, which would clash with the autoload's name.

const CONTENT_ROOT := "res://content"
const DEFINITION_EXTENSIONS: Array[String] = ["tres", "res"]

## The packs registered so far, in the order they loaded.
var packs := PackedStringArray()
## Everything that didn't register; empty when all content registered cleanly.
var errors := PackedStringArray()

var _definitions := {}


func _ready() -> void:
	load_content(CONTENT_ROOT)


## Registers every pack in root, a folder of pack folders. Problems are logged, kept in errors and skipped, so the
## rest of the content still loads.
func load_content(root: String) -> void:
	Log.info("📦 Loading content: root=%s" % root)
	var errors_before := errors.size()
	var pack_folders := _list_folders(root)
	if pack_folders.is_empty():
		_report("No content packs found: root=%s" % root)
	var registered := 0
	for pack in pack_folders:
		registered += _load_pack(root.path_join(pack), pack)

	var summary := "root=%s, packs=%d, definitions=%d, errors=%d, total_definitions=%d, kinds=%s" % [
		root, pack_folders.size(), registered, errors.size() - errors_before, _definitions.size(), _describe_kinds()]
	if errors.size() == errors_before:
		Log.info("📦 Content loaded: " + summary)
	else:
		Log.error("📦 Content loaded with problems: " + summary)


## The definition registered under id ("<pack>:<name>"), or null, after logging an error, when there is none.
func get_definition(id: String) -> ContentDefinition:
	if not _definitions.has(id):
		Log.error("📦 Unknown content ID: id=%s, registered=%d" % [id, _definitions.size()])
		return null
	return _definitions[id]


func has_definition(id: String) -> bool:
	return _definitions.has(id)


## Every registered definition of one kind (a ContentDefinition subclass, such as SectionDefinition), sorted by ID
## so the order is the same on every run.
func get_all(kind: Script) -> Array[ContentDefinition]:
	var ids := _definitions.keys()
	ids.sort()
	var found: Array[ContentDefinition] = []
	for id: String in ids:
		if is_instance_of(_definitions[id], kind):
			found.append(_definitions[id])
	return found


func _load_pack(pack_path: String, pack: String) -> int:
	var registered := 0
	for kind in _list_folders(pack_path):
		var kind_path := pack_path.path_join(kind)
		for content_name in _list_folders(kind_path):
			if _register(pack, content_name, kind_path.path_join(content_name)):
				registered += 1
	packs.append(pack)
	Log.info("📦 Loaded content pack: pack=%s, definitions=%d" % [pack, registered])
	return registered


func _register(pack: String, content_name: String, folder: String) -> bool:
	var id := "%s:%s" % [pack, content_name]
	var found: Array[ContentDefinition] = []
	for file in ResourceLoader.list_directory(folder):
		if file.get_extension() in DEFINITION_EXTENSIONS:
			var definition := load(folder.path_join(file)) as ContentDefinition
			if definition != null:
				found.append(definition)
	if found.is_empty():
		_report("Content folder has no definition: id=%s, folder=%s" % [id, folder])
		return false
	if found.size() > 1:
		var paths := PackedStringArray(found.map(func(definition: ContentDefinition) -> String:
			return definition.resource_path.get_file()))
		_report("Content folder has more than one definition: id=%s, folder=%s, definitions=%s" % [
			id, folder, ", ".join(paths)])
		return false

	var definition := found[0]
	if _definitions.has(id):
		_report("Duplicate content ID: id=%s, definition=%s, registered=%s" % [
			id, definition.resource_path, _definitions[id].resource_path])
		return false
	var problems := definition.get_problems()
	if not problems.is_empty():
		_report("Content definition has problems: id=%s, definition=%s, problems=%s" % [
			id, definition.resource_path, "; ".join(problems)])
		return false
	definition.id = id
	definition.pack = pack
	_definitions[id] = definition
	return true


func _report(problem: String) -> void:
	errors.append(problem)
	Log.error("📦 " + problem)


## How many definitions of each kind are registered, e.g. "SectionDefinition=10".
func _describe_kinds() -> String:
	var counts := {}
	for definition: ContentDefinition in _definitions.values():
		var script: Script = definition.get_script()
		var kind := script.get_global_name()
		if kind.is_empty():
			kind = script.resource_path.get_file().get_basename()
		counts[kind] = counts.get(kind, 0) + 1
	var kinds := counts.keys()
	kinds.sort()
	return ", ".join(PackedStringArray(kinds.map(func(kind: String) -> String: return "%s=%d" % [kind, counts[kind]])))


static func _list_folders(path: String) -> PackedStringArray:
	var folders := PackedStringArray()
	for entry in ResourceLoader.list_directory(path):
		if entry.ends_with("/"):
			folders.append(entry.trim_suffix("/"))
	folders.sort()
	return folders
