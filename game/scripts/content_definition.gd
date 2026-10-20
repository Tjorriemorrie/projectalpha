class_name ContentDefinition
extends Resource
## The base of every piece of content (sections now; items, weapons and enemies later). A definition is a small
## resource that describes its content and points at the files it uses. It lives in its own folder,
## content/<pack>/<kind>/<name>/, and the ContentRegistry registers it under the ID "<pack>:<name>".
## Subclass it for each kind of content; the registry picks up new kinds with no changes.

## The name shown to the player, e.g. "Small room".
@export var display_name := ""

## "<pack>:<name>", filled in by the registry from where the definition lives.
var id := ""
## The pack the definition came from, filled in by the registry.
var pack := ""


## Everything wrong with this definition that would stop it from being used, such as a missing file. The
## registry skips definitions with problems. Subclasses add their own checks; this must stay cheap, so it checks
## that files exist without loading them.
func get_problems() -> PackedStringArray:
	return PackedStringArray()
