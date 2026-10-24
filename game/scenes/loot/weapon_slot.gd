class_name WeaponSlot
extends ItemGrid
## The inventory's weapon slot: one slot holding the gun in the player's hand. Only a weapon goes in it, and a gun
## stacks alone, so it holds one gun at most.


func _init(slot_size: Vector2i = Vector2i.ONE) -> void:
	super(slot_size)


## Only a weapon goes in it.
func accepts(definition: ItemDefinition) -> bool:
	return definition is WeaponDefinition


## The gun it holds, or null when the player is unarmed.
func gun() -> Item:
	return items[0] if not items.is_empty() else null
