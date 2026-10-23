class_name Galaxy
extends RefCounted
## The fixed cluster of star systems (galaxy.md) as the star map and the jump drive see it: how far apart two systems
## lie, which lie within a jump of each other, what a jump burns, and where a new game starts. Systems are
## StarSystemDefinitions, placed by their map_position in light years. Node-free and silent; the GameSession logs.

## The farthest a jump reaches, in light years: all that a full antimatter tank holds. No two systems lie 10 to 11 ly
## apart, so a system is clearly in range or clearly not.
const JUMP_RANGE := 10.0
## Antimatter a jump burns per light year, rounded up; any jump burns at least one.
const ANTIMATTER_PER_LY := 1.0
## Systems at least this far from the middle, in light years, are on the outer ring, where a new game starts.
const OUTER_RING := 28.0


## How far apart two systems lie, in light years.
static func distance(from: StarSystemDefinition, to: StarSystemDefinition) -> float:
	return from.map_position.distance_to(to.map_position)


## Antimatter a jump between two systems burns: none to stay put, otherwise a unit per light year, rounded up.
static func antimatter_between(from: StarSystemDefinition, to: StarSystemDefinition) -> int:
	var light_years := distance(from, to)
	if light_years < 0.01:
		return 0
	return maxi(1, ceili(light_years * ANTIMATTER_PER_LY - 0.0001))


## The systems a jump from a system can reach (within JUMP_RANGE, itself left out), nearest first.
static func in_range(from: StarSystemDefinition, systems: Array) -> Array[StarSystemDefinition]:
	var reachable: Array[StarSystemDefinition] = []
	for system in systems:
		if system is StarSystemDefinition and system != from and distance(from, system) <= JUMP_RANGE:
			reachable.append(system)
	reachable.sort_custom(func(a: StarSystemDefinition, b: StarSystemDefinition) -> bool:
		return distance(from, a) < distance(from, b))
	return reachable


## The systems on the outer ring, OUTER_RING or more from the middle.
static func outer_ring(systems: Array) -> Array[StarSystemDefinition]:
	var ring: Array[StarSystemDefinition] = []
	for system in systems:
		if system is StarSystemDefinition and system.map_position.length() >= OUTER_RING:
			ring.append(system)
	return ring


## Where a new game starts: the outer ring's system nearest a random direction from the middle, so that a long stretch
## of the ring with many systems on it (the cheap rival's west edge) isn't favoured. Any system when none lies on the
## ring; null when there are none.
static func pick_start(systems: Array, rng: RandomNumberGenerator) -> StarSystemDefinition:
	var ring := outer_ring(systems)
	if ring.is_empty():
		var any: Array[StarSystemDefinition] = []
		for system in systems:
			if system is StarSystemDefinition:
				any.append(system)
		return any[rng.randi_range(0, any.size() - 1)] if not any.is_empty() else null
	var direction := rng.randf() * TAU
	var best: StarSystemDefinition = null
	var best_gap := INF
	for system in ring:
		var gap := absf(angle_difference(direction, system.map_position.angle()))
		if gap < best_gap:
			best = system
			best_gap = gap
	return best
