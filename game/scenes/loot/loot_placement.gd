class_name LootPlacement
extends Resource
## One entry of a wreck's loot list: the container that stands on a loot marker and exactly what is inside it, by
## content ID. Missions will fill markers from loot tables later; until then each wreck lists its own.

## The loot marker's path from the wreck, e.g. "Deck1/StoreRoom/LootSpotWest".
@export var marker := ""
## The container's content ID, e.g. "base:supply_crate".
@export var container := ""
## The items inside, by content ID, packed into its grid in this order.
@export var items := PackedStringArray()
