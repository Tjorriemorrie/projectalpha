class_name StarSystem
extends RefCounted
## A star system as the system map shows it: its definition, where its places and its trader hub lie, and the wrecks
## still there to board. Places sit on orbits round the star, one orbit per place from the star outwards, a moon just
## below its planet and the hub just above the world it orbits (as the map is drawn, y down), so their names never
## overlap; the angles are seeded from the system's ID, so a system looks the same in every playthrough. Its wrecks are
## rolled when it is revealed (reveal()), spread over its places (or in open space) and fanned out on the side of each
## place away from its name, and from then on they only leave: a wreck once boarded is gone, whether the android
## extracted or died. Flights cost hydrogen by distance on the map (hydrogen_between()). Node-free and silent; the
## GameSession logs what changes.

## How many wrecks a system holds when it is revealed.
const MIN_WRECKS := 6
const MAX_WRECKS := 8
## Map units from one orbit to the next.
const ORBIT_SPACING := 1.0
## The least angle, in radians, between the places of two orbits, where the layout can keep it.
const ORBIT_ANGLE_GAP := 0.7
## Hydrogen a flight burns per map unit, rounded up; any flight burns at least one.
const HYDROGEN_PER_UNIT := 1.0
## How far a moon lies below its planet, the hub above the world it orbits, and a wreck from its place, in map units.
const MOON_OFFSET := 0.45
const HUB_OFFSET := 0.5
const WRECK_OFFSET := 0.5
## The spots round a place that its wrecks take in turn, in map units from it (y down): on the side away from its
## name, which is drawn on its right (mirrored for a name on the left), and clear of a moon below and the hub above.
## Wrecks past the last spot take the spots again, further out.
const FAN_SPOTS: Array[Vector2] = [Vector2(-WRECK_OFFSET, 0.0), Vector2(-0.82, 0.48), Vector2(-0.82, -0.48),
	Vector2(-1.3, 0.0), Vector2(-1.6, 0.48), Vector2(-1.6, -0.48)]
## Map units between wrecks along an asteroid belt's ring.
const BELT_GAP := 0.6
## How likely a wreck is to drift in open space rather than lie at a place, and how clear of everything else it keeps.
const OPEN_SPACE_CHANCE := 0.25
const OPEN_SPACE_CLEARANCE := 0.6
## A place further east than this fraction of the map's radius has its name on its left, so it stays on the map.
const NAME_FLIP := 0.25

var definition: StarSystemDefinition
## Each place's spot on the map in map units from the star, in the definition's order. A belt's spot is on its ring.
var place_positions := PackedVector2Array()
## Each place's orbit, from 1 at the star outwards; a moon shares its planet's.
var place_orbits := PackedInt32Array()
var orbit_count := 0
## The place the hub orbits: the first habitable world, or else the first place.
var hub_place := 0
var hub_position := Vector2.ZERO
## The wrecks still there to board.
var wrecks: Array[SystemWreck] = []


## Lays the system out from its definition, with no wrecks yet.
func _init(system: StarSystemDefinition) -> void:
	definition = system
	var rng := RandomNumberGenerator.new()
	rng.seed = system.map_id.hash()
	var planet := Vector2.ZERO
	var angles: Array[float] = []
	for index in system.places.size():
		var place := system.places[index]
		if place.kind == SystemPlace.Kind.MOON and orbit_count > 0:
			place_orbits.append(orbit_count)
			place_positions.append(planet + Vector2.DOWN * MOON_OFFSET)
			continue
		orbit_count += 1
		var angle := _spread_angle(angles, rng)
		angles.append(angle)
		planet = Vector2.from_angle(angle) * orbit_count * ORBIT_SPACING
		place_orbits.append(orbit_count)
		place_positions.append(planet)
	hub_place = 0
	for index in system.places.size():
		if system.places[index].habitable:
			hub_place = index
			break
	if not place_positions.is_empty():
		hub_position = place_positions[hub_place] + Vector2.UP * HUB_OFFSET


## A system revealed: laid out, with MIN_WRECKS to MAX_WRECKS wrecks rolled from the layouts given, each at a random
## place or in open space.
static func reveal(system: StarSystemDefinition, layouts: Array, rng: RandomNumberGenerator) -> StarSystem:
	var revealed := StarSystem.new(system)
	revealed.add_wrecks(layouts, rng.randi_range(MIN_WRECKS, MAX_WRECKS), rng)
	return revealed


## Hydrogen a flight between two spots on the map burns: none to stay put, otherwise a unit per map unit, rounded up.
static func hydrogen_between(from: Vector2, to: Vector2) -> int:
	var distance := from.distance_to(to)
	if distance < 0.01:
		return 0
	return maxi(1, ceili(distance * HYDROGEN_PER_UNIT - 0.0001))


## How far out the map reaches from the star, in map units: the outer orbit, or a moon or the hub beyond it, with room
## for the first wrecks fanned out round a place.
func radius() -> float:
	var reach := (orbit_count + 0.6) * ORBIT_SPACING
	for spot in place_positions:
		reach = maxf(reach, spot.length() + FAN_SPOTS[1].length() + 0.1)
	return maxf(reach, hub_position.length() + 0.3)


## Whether a spot's name goes on its left on the map rather than its right: far enough east that it would run off.
func name_on_left(spot: Vector2) -> bool:
	return spot.x > NAME_FLIP * radius()


## Rolls count wrecks (random layouts at random levels) and puts each at a random place, a place that already holds
## wrecks less likely, or in open space.
func add_wrecks(layouts: Array, count: int, rng: RandomNumberGenerator) -> void:
	for _i in count:
		var roll := WreckRoll.random(layouts, rng)
		if roll == null:
			return
		var place_index := -1
		if definition.places.size() > 0 and rng.randf() >= OPEN_SPACE_CHANCE:
			var weights := definition.places.map(func(place: SystemPlace) -> float:
				return 1.0 / (1.0 + 2.0 * _wrecks_at(place)))
			place_index = Dice.weighted(weights, rng)
		var place: SystemPlace = definition.places[place_index] if place_index >= 0 else null
		var position := _place_spot(place_index, rng) if place else _open_space_spot(rng)
		wrecks.append(SystemWreck.new(roll, place, position))


## The wreck whose roll this is, or null.
func wreck_with(roll: WreckRoll) -> SystemWreck:
	for wreck in wrecks:
		if wreck.roll == roll:
			return wreck
	return null


## Takes a wreck off the map for good. Returns whether it was there.
func remove(wreck: SystemWreck) -> bool:
	var index := wrecks.find(wreck)
	if index < 0:
		return false
	wrecks.remove_at(index)
	return true


## A spot for another wreck at a place: along an asteroid belt's ring, either side of its spot in turn, or in the next
## free spot of the fan on the side of anything else away from its name.
func _place_spot(index: int, rng: RandomNumberGenerator) -> Vector2:
	var spot := place_positions[index]
	var already := _wrecks_at(definition.places[index])
	if definition.places[index].kind == SystemPlace.Kind.BELT:
		var side := 1.0 if (already + rng.randi_range(0, 1)) % 2 == 0 else -1.0
		var step := BELT_GAP / maxf(spot.length(), BELT_GAP)
		return spot.rotated(side * (already / 2 + 1) * step)
	var offset := FAN_SPOTS[already % FAN_SPOTS.size()] + Vector2(-1.5 * (already / FAN_SPOTS.size()), 0.0)
	if name_on_left(spot):
		offset.x = -offset.x
	return spot + offset


## A random angle for the next orbit's place, at least ORBIT_ANGLE_GAP from every one taken where it can be, so names on
## neighbouring orbits don't run into each other; otherwise the clearest of a few tries.
static func _spread_angle(taken: Array[float], rng: RandomNumberGenerator) -> float:
	var best := 0.0
	var best_gap := -1.0
	for _attempt in 24:
		var angle := rng.randf() * TAU
		var gap := PI
		for other in taken:
			gap = minf(gap, absf(angle_difference(angle, other)))
		if gap >= ORBIT_ANGLE_GAP:
			return angle
		if gap > best_gap:
			best = angle
			best_gap = gap
	return best


func _wrecks_at(place: SystemPlace) -> int:
	return wrecks.filter(func(wreck: SystemWreck) -> bool: return wreck.place == place).size()


## A spot in open space between the orbits, kept clear of the places, the hub and the other wrecks where it can be.
func _open_space_spot(rng: RandomNumberGenerator) -> Vector2:
	var spot := Vector2.ZERO
	for _attempt in 12:
		var distance := rng.randf_range(0.6, maxf(orbit_count, 1) + 0.3) * ORBIT_SPACING
		spot = Vector2.from_angle(rng.randf() * TAU) * distance
		if _is_clear(spot):
			return spot
	return spot


func _is_clear(spot: Vector2) -> bool:
	var taken: Array[Vector2] = [hub_position]
	taken.append_array(place_positions)
	for wreck in wrecks:
		taken.append(wreck.position)
	for other in taken:
		if other.distance_to(spot) < OPEN_SPACE_CLEARANCE:
			return false
	return true
