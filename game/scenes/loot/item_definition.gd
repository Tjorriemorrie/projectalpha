class_name ItemDefinition
extends ContentDefinition
## An item in the content registry: how many of it stack in one slot, what it is worth, and its model, which only
## loads when the item lies in the world or its icon is rendered. Every item takes one square slot in a grid,
## whatever the shape of its model, and a slot holds a stack of one kind, up to its stack size. The model has its
## origin in the middle of its footprint on the floor.

## How many of it stack in one slot: small things stack high and bulky ones low; a gun takes a slot to itself.
@export_range(1, 99) var stack_size: int = 1
## What one is worth, in bitcoin.
@export var value: int = 0
## Whether it is ammunition (a thermal clip, fresh or spent), the only kind the ammo slots take.
@export var ammo := false
## Its name for more than one ("Hull plating"); empty adds an s to the display name.
@export var plural_name := ""
## A line or two about what it is and what it is good for, shown on its item card.
@export_multiline var description := ""
## The item's model, a .glb (or a scene). A res:// path, or a uid:// when picked in the inspector.
@export_file("*.glb", "*.tscn") var model := ""


## How many of it there are, in lower case: "servo motor" for one, "3 circuit boards" for more.
func name_for(quantity: int) -> String:
	if quantity == 1:
		return display_name.to_lower()
	var plural := plural_name if not plural_name.is_empty() else display_name + "s"
	return "%d %s" % [quantity, plural.to_lower()]


## The model's res:// path, also when the inspector stored a uid://.
func get_model_path() -> String:
	return ResourceUID.ensure_path(model)


func get_problems() -> PackedStringArray:
	var problems := super()
	if stack_size < 1:
		problems.append("Item stack size is below 1: stack_size=%d" % stack_size)
	if model.is_empty():
		problems.append("Item has no model")
	elif not ResourceLoader.exists(get_model_path()):
		problems.append("Item model not found: model=%s" % model)
	if value < 0:
		problems.append("Item value is negative: value=%d" % value)
	if description.strip_edges().is_empty():
		problems.append("Item has no description")
	return problems
