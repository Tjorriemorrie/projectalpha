class_name Item
extends RefCounted
## One item the player can carry: what it is (its definition), and how it lies in the grid that holds it, its
## orientation (see ItemShape) and the cell its shape starts at. It doesn't know which grid holds it.

var definition: ItemDefinition
var orientation := 0
var cell := Vector2i.ZERO


func _init(item_definition: ItemDefinition, item_orientation: int = 0, at: Vector2i = Vector2i.ZERO) -> void:
	definition = item_definition
	orientation = item_orientation
	cell = at


## Its shape in its orientation, starting at (0, 0).
func shape() -> Array[Vector2i]:
	return ItemShape.oriented(definition.get_cells(), orientation)


## The grid cells it covers where it lies.
func cells() -> Array[Vector2i]:
	var covered: Array[Vector2i] = []
	for offset in shape():
		covered.append(cell + offset)
	return covered


## The columns and rows it spans in its orientation.
func size() -> Vector2i:
	return ItemShape.size_of(shape())


func _to_string() -> String:
	return "%s@%s/%d" % [definition.id if definition else "?", cell, orientation]
