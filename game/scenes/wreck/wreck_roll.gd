class_name WreckRoll
extends RefCounted
## A wreck rolled for a run: its layout, its hidden difficulty level and the seed its robots and loot are rolled
## from. How many robots are aboard (the expected count for the level, give or take one) comes from the seed when the
## roll is made, so a wreck rolled ahead holds what was shown. The wreck fills its markers from it with
## roll_enemies() and roll_loot(), the same way every time for the same seed and layout. Node-free, so it doesn't
## log: problems go into problems, and the wreck logs the outcome.

## How far the robots aboard can be off the expected count, either way: a scan of a security network is never sure.
const ROBOT_SPREAD := 1
## Every wreck holds at least this many robots, so none is an empty walk-through.
const MIN_ROBOTS := 2

var definition: WreckDefinition
## The hidden difficulty level, within the layout's range.
var level := 1
var roll_seed := 0
## How many robots are aboard: the expected count give or take ROBOT_SPREAD, never below MIN_ROBOTS.
var robots := 0
## What roll_loot() left out: unknown items in loot tables, a gun that fit no container.
var problems := PackedStringArray()
## What roll_loot() put in the containers, in bitcoin.
var loot_value := 0


func _init(layout: WreckDefinition, wreck_level: int, wreck_seed: int) -> void:
	definition = layout
	level = clampi(wreck_level, layout.levels.x, layout.levels.y)
	roll_seed = wreck_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	robots = maxi(MIN_ROBOTS, expected_robots() + rng.randi_range(-ROBOT_SPREAD, ROBOT_SPREAD))


## A random layout from those given, at a random level in its range, with a random seed; null when there are none.
static func random(layouts: Array, rng: RandomNumberGenerator) -> WreckRoll:
	if layouts.is_empty():
		return null
	return at_random_level(layouts[rng.randi_range(0, layouts.size() - 1)], rng)


## A layout at a random level in its range, with a random seed.
static func at_random_level(layout: WreckDefinition, rng: RandomNumberGenerator) -> WreckRoll:
	return WreckRoll.new(layout, rng.randi_range(layout.levels.x, layout.levels.y), rng.randi())


## How many robots the scan expects aboard: what the system map and the airlock show.
func expected_robots() -> int:
	return definition.expected_robots_at(level)


## What the scan says about the robots, e.g. "about 4 robots active". A layout always expects several (see
## WreckDefinition.LEAST_EXPECTED_ROBOTS).
func robots_estimate() -> String:
	return "about %d robots active" % expected_robots()


## The generator the markers are filled from: the same sequence every time for the same seed.
func new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed + 1
	return rng


## Puts the robots on random markers. markers maps each enemy marker's path to its mount (SectionMarker.Mount), and
## kinds are the enemy kinds there are. Returns marker path to enemy ID, for as many robots as are aboard (fewer when
## too few markers fit a kind), each of a random kind whose mount fits its marker.
func roll_enemies(markers: Dictionary, kinds: Array, rng: RandomNumberGenerator) -> Dictionary[String, String]:
	var fitting := markers.keys().filter(func(path: String) -> bool:
		return not _kinds_for_mount(kinds, markers[path]).is_empty())
	var enemies: Dictionary[String, String] = {}
	for path: String in Dice.pick(fitting, robots, rng):
		var fits := _kinds_for_mount(kinds, markers[path])
		enemies[path] = (fits[rng.randi_range(0, fits.size() - 1)] as EnemyDefinition).id
	return enemies


## Puts the layout's containers on random loot markers and rolls what is inside. markers maps each loot marker's path
## to its space (SectionMarker.Space), kinds are the container kinds there are, and gun (or null) goes into a random
## container first at level 1, on top of the budgets. Returns one placement per container (fewer when there are too
## few markers), each of a kind that fits its marker, picked by the kinds' weights.
func roll_loot(markers: Dictionary, kinds: Array, gun: ItemDefinition,
		rng: RandomNumberGenerator) -> Array[LootPlacement]:
	problems.clear()
	loot_value = 0
	var placements: Array[LootPlacement] = []
	var chosen: Array[ContainerDefinition] = []
	var grids: Array[ItemGrid] = []
	for path: String in Dice.pick(markers.keys(), definition.containers, rng):
		var fits := kinds.filter(func(kind: ContainerDefinition) -> bool:
			return markers[path] == SectionMarker.Space.ROOM or kind.fits_tight)
		var index := Dice.weighted(fits.map(func(kind: ContainerDefinition) -> float: return kind.weight), rng)
		if index < 0:
			problems.append("No container fits the loot marker: marker=%s" % path)
			continue
		var kind: ContainerDefinition = fits[index]
		var placement := LootPlacement.new()
		placement.marker = path
		placement.container = kind.id
		placements.append(placement)
		chosen.append(kind)
		grids.append(ItemGrid.new(kind.grid_size))
	if level == 1 and gun != null:
		_put_gun(gun, placements, grids, rng)
	var tables := {}
	for index in placements.size():
		var kind := chosen[index]
		if not tables.has(kind):
			tables[kind] = _table(kind)
		var table: Array = tables[kind]
		var drawn := LootRoll.draw(table[0], table[1], LootRoll.budget_for(kind.budget, level), grids[index], rng)
		for item in drawn:
			placements[index].items.append(item.id)
		loot_value += grids[index].value()
	return placements


## The level-1 gun goes into a random container it fits.
func _put_gun(gun: ItemDefinition, placements: Array[LootPlacement], grids: Array[ItemGrid],
		rng: RandomNumberGenerator) -> void:
	var takers := range(grids.size()).filter(func(index: int) -> bool: return grids[index].find_space(gun) != null)
	if takers.is_empty():
		problems.append("The level-1 gun fits no container: gun=%s, containers=%d" % [gun.id, grids.size()])
		return
	var index: int = takers[rng.randi_range(0, takers.size() - 1)]
	grids[index].add(Item.new(gun))
	placements[index].items.append(gun.id)


## A container's loot table as [items, weights], with unknown item IDs left out (and noted in problems).
func _table(kind: ContainerDefinition) -> Array:
	var items: Array[ItemDefinition] = []
	var weights: Array[float] = []
	for id: String in kind.loot:
		var item: ItemDefinition = null
		if ContentRegistry.has_definition(id):
			item = ContentRegistry.get_definition(id) as ItemDefinition
		if item == null:
			problems.append("Not a registered item in a loot table: container=%s, item=%s" % [kind.id, id])
			continue
		items.append(item)
		weights.append(kind.loot[id])
	return [items, weights]


static func _kinds_for_mount(kinds: Array, mount: int) -> Array:
	return kinds.filter(func(kind: EnemyDefinition) -> bool: return kind.mount == mount)
