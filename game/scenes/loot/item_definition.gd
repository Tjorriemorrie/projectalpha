class_name ItemDefinition
extends ContentDefinition
## An item in the content registry: the shape it takes up in a grid, what it is worth, and its model, which only
## loads when the item lies in the world or its icon is rendered. The model is built to the shape, CELL_SIZE metres
## a cell, with its origin in the middle of its footprint on the floor and its rows running along +Z, so seen from
## above it covers its cells.

## Metres a grid cell spans in item models.
const CELL_SIZE := 0.15

## The cells it takes up, as rows: "#" is a cell, "." a gap. ["###", ".#."] is a T. See ItemShape.
@export var shape := PackedStringArray(["#"])
## What it is worth, in credits.
@export var value: int = 0
## A line or two about what it is and what it is good for, shown on its item card.
@export_multiline var description := ""
## The item's model, a .glb (or a scene). A res:// path, or a uid:// when picked in the inspector.
@export_file("*.glb", "*.tscn") var model := ""

var _cells: Array[Vector2i] = []


## The cells of its shape in its first orientation, starting at (0, 0).
func get_cells() -> Array[Vector2i]:
	if _cells.is_empty():
		_cells = ItemShape.oriented(ItemShape.cells_from_rows(shape), 0)
	return _cells


## The model's res:// path, also when the inspector stored a uid://.
func get_model_path() -> String:
	return ResourceUID.ensure_path(model)


func get_problems() -> PackedStringArray:
	var problems := super()
	var cells := ItemShape.cells_from_rows(shape)
	if not ItemShape.is_one_piece(cells):
		problems.append("Item shape is empty or not one piece: shape=%s" % [shape])
	for row in shape:
		if not row.replace(ItemShape.CELL, "").replace(ItemShape.GAP, "").is_empty():
			problems.append("Item shape has characters other than # and .: shape=%s" % [shape])
			break
	if model.is_empty():
		problems.append("Item has no model")
	elif not ResourceLoader.exists(get_model_path()):
		problems.append("Item model not found: model=%s" % model)
	if value < 0:
		problems.append("Item value is negative: value=%d" % value)
	if description.strip_edges().is_empty():
		problems.append("Item has no description")
	return problems
