class_name WeaponSlot
extends ItemGrid
## The inventory's weapon slot: a small grid that holds one gun, the one in the player's hand. Anything that isn't a
## weapon never fits, and neither does a second gun; the gun it holds can still be moved about inside it.


## Whether a weapon fits there: only a weapon, only while the slot holds no other item, and only where the grid has
## room for its shape.
func fits(definition: ItemDefinition, orientation: int, cell: Vector2i, ignore: Item = null) -> bool:
	if not definition is WeaponDefinition:
		return false
	for item in items:
		if item != ignore:
			return false
	return super(definition, orientation, cell, ignore)


## The gun it holds, or null when the player is unarmed.
func gun() -> Item:
	return items[0] if not items.is_empty() else null
