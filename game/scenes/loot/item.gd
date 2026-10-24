class_name Item
extends RefCounted
## A stack of items in one slot of a grid: what kind (its definition), how many (from 1 up to the kind's stack size)
## and the slot it sits in, by its cell. It doesn't know which grid holds it. A gun, which stacks alone, also keeps the
## heat of its loaded clip, which goes wherever the gun goes.

## Emitted when its quantity changes, so the grid holding it can redraw.
signal changed

var definition: ItemDefinition
## How many there are in the stack.
var quantity := 1:
	set(value):
		if value == quantity:
			return
		quantity = value
		changed.emit()
## The cell (column, row) of the slot it sits in.
var cell := Vector2i.ZERO
## For a gun, the heat in its loaded clip, from 0 (fresh) to 1 (saturated). A new gun comes with a fresh clip.
var clip_heat := 0.0


func _init(item_definition: ItemDefinition, count: int = 1, at: Vector2i = Vector2i.ZERO) -> void:
	definition = item_definition
	quantity = count
	cell = at


## How many more of its kind fit on it.
func room() -> int:
	return maxi(definition.stack_size - quantity, 0)


## What the stack is worth, in bitcoin.
func value() -> int:
	return definition.value * quantity


## What it is, with how many: "servo motor", "3 circuit boards".
func label() -> String:
	return definition.name_for(quantity)


func _to_string() -> String:
	return "%s×%d@%s" % [definition.id if definition else "?", quantity, cell]
