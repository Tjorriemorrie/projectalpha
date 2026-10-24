class_name Inventory
extends RefCounted
## What the player carries, in four sets of slots: the weapon slot holding the gun in hand, the ammo slots for thermal
## clips (a reload takes its clip from there), the pockets for things wanted at hand, and the backpack. Loot moves into
## it by being dragged there, or by a quick move (see GridScreen), which goes where stow_order() says.

var weapon: WeaponSlot
var ammo: AmmoSlots
var pockets: ItemGrid
var backpack: ItemGrid


func _init(ammo_size: Vector2i = Vector2i(2, 1), pocket_size: Vector2i = Vector2i(2, 1),
		backpack_size: Vector2i = Vector2i(6, 1)) -> void:
	weapon = WeaponSlot.new()
	ammo = AmmoSlots.new(ammo_size)
	pockets = ItemGrid.new(pocket_size)
	backpack = ItemGrid.new(backpack_size)


## Its grids: the weapon slot, the ammo slots, the pockets and the backpack.
func grids() -> Array[ItemGrid]:
	return [weapon, ammo, pockets, backpack]


## Where a stack moved to the player goes, in order: a clip to the ammo slots and a gun to the weapon slot first,
## then anything to the backpack and then the pockets.
func stow_order(definition: ItemDefinition) -> Array[ItemGrid]:
	var order: Array[ItemGrid] = []
	if definition.ammo:
		order.append(ammo)
	if definition is WeaponDefinition:
		order.append(weapon)
	order.append_array([backpack, pockets])
	return order


## The haul a run brought home, which unloading after it puts in the stash: the stacks in the pockets and the
## backpack. The gun in hand and the clips in the ammo slots stay.
func haul() -> Array[Item]:
	var stacks: Array[Item] = pockets.in_reading_order()
	stacks.append_array(backpack.in_reading_order())
	return stacks


## The gun in the weapon slot, or null when the player is unarmed.
func gun() -> Item:
	return weapon.gun()


## The grid holding a stack, or null.
func grid_of(item: Item) -> ItemGrid:
	for grid in grids():
		if grid.has(item):
			return grid
	return null


## How many items of this kind it holds in all its grids.
func count(definition: ItemDefinition) -> int:
	var total := 0
	for grid in grids():
		total += grid.count(definition)
	return total


## Items in all its grids, every one in every stack, the gun included.
func item_count() -> int:
	var total := 0
	for grid in grids():
		total += grid.item_count()
	return total


## Free slots in the pockets and the backpack, where loot goes (the weapon and ammo slots take only guns and clips).
func free_slots() -> int:
	return pockets.free_slots() + backpack.free_slots()


## Total value carried, the gun included, in bitcoin.
func value() -> int:
	var total := 0
	for grid in grids():
		total += grid.value()
	return total
