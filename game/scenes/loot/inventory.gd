class_name Inventory
extends RefCounted
## What the player carries: the weapon slot holding the gun in hand, a strip of pockets for things wanted at hand (a
## reload takes its thermal clips from there) and a backpack. Loot only ever moves into it by being dragged there (see
## InventoryScreen); nothing is sorted into it by itself.

var weapon: WeaponSlot
var pockets: ItemGrid
var backpack: ItemGrid


func _init(pocket_size: Vector2i = Vector2i(4, 1), backpack_size: Vector2i = Vector2i(6, 5),
		weapon_size: Vector2i = Vector2i(3, 2)) -> void:
	weapon = WeaponSlot.new(weapon_size)
	pockets = ItemGrid.new(pocket_size)
	backpack = ItemGrid.new(backpack_size)


## Its grids: the weapon slot, the pockets and the backpack.
func grids() -> Array[ItemGrid]:
	return [weapon, pockets, backpack]


## The gun in the weapon slot, or null when the player is unarmed.
func gun() -> Item:
	return weapon.gun()


## The grid holding an item, or null.
func grid_of(item: Item) -> ItemGrid:
	for grid in grids():
		if grid.has(item):
			return grid
	return null


## How many items of this kind it holds in all its grids.
func count(definition: ItemDefinition) -> int:
	return weapon.count(definition) + pockets.count(definition) + backpack.count(definition)


## Items in all its grids, the gun included.
func item_count() -> int:
	return weapon.items.size() + pockets.items.size() + backpack.items.size()


## Cells no item covers in the pockets and the backpack, where loot goes (the weapon slot only takes a gun).
func free_cells() -> int:
	return pockets.free_cells() + backpack.free_cells()


## Total value carried, the gun included, in bitcoin.
func value() -> int:
	return weapon.value() + pockets.value() + backpack.value()
