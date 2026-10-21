class_name Inventory
extends RefCounted
## What the player carries: a strip of pockets for things wanted at hand (a reload takes its thermal clips from
## there) and a backpack. Loot only ever moves into it by being dragged there (see InventoryScreen); nothing is
## sorted into it by itself.

var pockets: ItemGrid
var backpack: ItemGrid


func _init(pocket_size: Vector2i = Vector2i(4, 1), backpack_size: Vector2i = Vector2i(6, 5)) -> void:
	pockets = ItemGrid.new(pocket_size)
	backpack = ItemGrid.new(backpack_size)


## The grid holding an item, or null.
func grid_of(item: Item) -> ItemGrid:
	for grid: ItemGrid in [pockets, backpack]:
		if grid.has(item):
			return grid
	return null


## How many items of this kind it holds in both grids.
func count(definition: ItemDefinition) -> int:
	return pockets.count(definition) + backpack.count(definition)


## Items in both grids.
func item_count() -> int:
	return pockets.items.size() + backpack.items.size()


## Cells no item covers in both grids.
func free_cells() -> int:
	return pockets.free_cells() + backpack.free_cells()


## Total value carried, in credits.
func value() -> int:
	return pockets.value() + backpack.value()
