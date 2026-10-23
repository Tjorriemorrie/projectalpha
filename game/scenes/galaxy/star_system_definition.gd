class_name StarSystemDefinition
extends ContentDefinition
## A star system of the fixed galaxy (galaxy.md) in the content registry: its ID on the galaxy map, its star, who holds
## it, where it lies, and its places from the star outwards. art-source/galaxy/systems.py writes every system's
## definition from galaxy.md and galaxy.json, so change those and run it rather than editing definitions by hand. The
## ships to board in a system are rolled when it is revealed (see StarSystem), never stored here.

enum Star { RED_DWARF, YELLOW, WHITE, BINARY, NEUTRON }
enum Owner { HALDEN_MORI, MASSEY, CORVID, FREE, CONTESTED }

## Every system has two to eight places.
const MIN_PLACES := 2
const MAX_PLACES := 8
const STAR_NAMES := {
	Star.RED_DWARF: "Red dwarf", Star.YELLOW: "Yellow star", Star.WHITE: "White star", Star.BINARY: "Binary star",
	Star.NEUTRON: "Neutron star"}
const OWNER_NAMES := {
	Owner.HALDEN_MORI: "Halden-Mori space", Owner.MASSEY: "Massey space", Owner.CORVID: "Corvid space",
	Owner.FREE: "Free system", Owner.CONTESTED: "Contested"}

## Its ID on the galaxy map, e.g. "H2".
@export var map_id := ""
@export var star := Star.YELLOW
@export var owner := Owner.FREE
## Where it lies on the star map (012), in light years from the middle: x towards the east, y towards the north.
@export var map_position := Vector2.ZERO
## Its places, from the star outwards; a moon follows its planet.
@export var places: Array[SystemPlace] = []


## The name of its trader hub, which the Hanse runs in every system.
func hub_name() -> String:
	return "%s Hanse" % display_name


## Its star and who holds it, e.g. "Yellow star · Halden-Mori space".
func describe() -> String:
	return "%s · %s" % [STAR_NAMES[star], OWNER_NAMES[owner]]


func get_problems() -> PackedStringArray:
	var problems := super()
	if map_id.is_empty():
		problems.append("Star system has no map ID")
	if places.size() < MIN_PLACES or places.size() > MAX_PLACES:
		problems.append("Star system needs %d to %d places: places=%d" % [MIN_PLACES, MAX_PLACES, places.size()])
	for index in places.size():
		var place := places[index]
		if place == null or place.display_name.is_empty():
			problems.append("Star system place has no name: index=%d" % index)
		elif index == 0 and place.kind == SystemPlace.Kind.MOON:
			problems.append("Star system starts with a moon, which must follow its planet: place=%s" % place.display_name)
	return problems
