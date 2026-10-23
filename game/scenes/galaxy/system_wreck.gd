class_name SystemWreck
extends RefCounted
## A wreck in a star system, to fly to and board: its roll (layout, hidden level and the robots aboard), the place it
## lies at (null when it drifts in open space), and where it is on the system map. Node-free and silent.

var roll: WreckRoll
## The place it lies at, or null in open space.
var place: SystemPlace
## Where it is on the system map, in map units from the star.
var position := Vector2.ZERO


func _init(wreck_roll: WreckRoll, at_place: SystemPlace, map_position: Vector2) -> void:
	roll = wreck_roll
	place = at_place
	position = map_position


## Where it lies, e.g. "at the Long Fall" or "in open space".
func where() -> String:
	return "at %s" % place.display_name if place else "in open space"


## Its layout's name, e.g. "Hauler".
func title() -> String:
	return roll.definition.display_name
