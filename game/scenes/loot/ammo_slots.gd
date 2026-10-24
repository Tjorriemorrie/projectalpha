class_name AmmoSlots
extends ItemGrid
## The inventory's ammo slots, which take thermal clips only, fresh or spent (ItemDefinition.ammo). A reload takes
## its fresh clip from here, and the spent one comes back here first.


## Only ammunition goes in them.
func accepts(definition: ItemDefinition) -> bool:
	return definition.ammo
