extends GdUnitTestSuite
## Checks rolling a wreck without loading one: the robots aboard against the expected count, levels, what the scan
## says, putting robots and containers on markers (given as paths and mounts or spaces), the loot within the
## containers' budgets, the level-1 gun, and the same seed rolling the same wreck. Uses the base game's layouts, robots
## and containers.

const FLOOR := SectionMarker.Mount.FLOOR
const CEILING := SectionMarker.Mount.CEILING
const ROOM := SectionMarker.Space.ROOM
const TIGHT := SectionMarker.Space.TIGHT


func test_robots_aboard_are_the_expected_count_give_or_take_one() -> void:
	var hauler := _layout("base:hauler")
	var seen := {}
	for seed_value in 60:
		var roll := WreckRoll.new(hauler, 2, seed_value)
		assert_int(roll.expected_robots()).is_equal(4)
		assert_int(roll.robots).is_between(3, 5)
		seen[roll.robots] = true
	assert_array(seen.keys()).contains_exactly_in_any_order([3, 4, 5])


func test_the_same_seed_rolls_the_same_robots() -> void:
	var freighter := _layout("base:freighter")
	assert_int(WreckRoll.new(freighter, 3, 99).robots).is_equal(WreckRoll.new(freighter, 3, 99).robots)


func test_a_level_outside_the_layouts_range_is_clamped() -> void:
	var courier := _layout("base:courier")
	assert_int(WreckRoll.new(courier, 5, 1).level).is_equal(2)
	assert_int(WreckRoll.new(_layout("base:freighter"), 1, 1).level).is_equal(2)


func test_random_rolls_a_registered_layout_at_a_level_in_its_range() -> void:
	var layouts := ContentRegistry.get_all(WreckDefinition)
	var rng := _rng(4)
	var seen := {}
	for draw in 60:
		var roll := WreckRoll.random(layouts, rng)
		assert_int(roll.level).is_between(roll.definition.levels.x, roll.definition.levels.y)
		seen[roll.definition.id] = true
	assert_int(seen.size()).is_equal(3)
	assert_object(WreckRoll.random([], rng)).is_null()


func test_the_scan_says_about_how_many_robots_are_active() -> void:
	assert_str(WreckRoll.new(_layout("base:hauler"), 3, 1).robots_estimate()).is_equal("about 6 robots active")
	assert_str(WreckRoll.new(_layout("base:courier"), 1, 1).robots_estimate()).is_equal("about 1 robot active")
	var empty := WreckDefinition.new()
	empty.expected_robots = PackedInt32Array([0])
	assert_str(WreckRoll.new(empty, 1, 1).robots_estimate()).is_equal("no robots active")


func test_robots_go_on_markers_that_fit_their_kind() -> void:
	var roll := WreckRoll.new(_layout("base:hauler"), 3, 2)
	var markers := {}
	for index in 6:
		markers["Floor%d" % index] = FLOOR
		markers["Ceiling%d" % index] = CEILING
	var enemies := roll.roll_enemies(markers, _enemy_kinds(), roll.new_rng())
	assert_int(enemies.size()).is_equal(roll.robots)
	for path in enemies:
		assert_str(enemies[path]).is_equal("base:drone" if path.begins_with("Floor") else "base:turret")


func test_fewer_markers_take_fewer_robots() -> void:
	var roll := WreckRoll.new(_layout("base:freighter"), 3, 2)
	var enemies := roll.roll_enemies({"A": FLOOR, "B": CEILING}, _enemy_kinds(), roll.new_rng())
	assert_int(enemies.size()).is_equal(2)


func test_containers_go_on_markers_that_fit_them() -> void:
	var roll := WreckRoll.new(_layout("base:freighter"), 2, 3)
	var markers := {}
	for index in 10:
		markers["Room%d" % index] = ROOM
		markers["Vent%d" % index] = TIGHT
	var loot := roll.roll_loot(markers, _container_kinds(), null, roll.new_rng())
	assert_int(loot.size()).is_equal(9)
	for placement in loot:
		if placement.marker.begins_with("Vent"):
			assert_str(placement.container).is_equal("base:small_case")
	assert_array(Array(roll.problems)).is_empty()


func test_room_markers_roll_crates_twice_as_often_as_lockers() -> void:
	var counts := {}
	for seed_value in 200:
		var roll := WreckRoll.new(_layout("base:hauler"), 1, seed_value)
		for placement in roll.roll_loot({"A": ROOM, "B": ROOM, "C": ROOM}, _container_kinds(), null, roll.new_rng()):
			counts[placement.container] = counts.get(placement.container, 0) + 1
	assert_float(float(counts["base:supply_crate"]) / counts["base:locker"]).is_between(1.6, 2.4)
	assert_float(float(counts["base:small_case"]) / counts["base:locker"]).is_between(0.7, 1.3)


func test_every_container_holds_no_more_than_its_budget() -> void:
	for level in [2, 3]:
		for seed_value in 20:
			var roll := WreckRoll.new(_layout("base:hauler"), level, seed_value)
			var markers := {"A": ROOM, "B": ROOM, "C": ROOM, "D": ROOM, "E": TIGHT, "F": TIGHT}
			var total := 0
			for placement in roll.roll_loot(markers, _container_kinds(), null, roll.new_rng()):
				var kind := ContentRegistry.get_definition(placement.container) as ContainerDefinition
				var value := 0
				for id in placement.items:
					value += (ContentRegistry.get_definition(id) as ItemDefinition).value
				assert_int(value).is_less_equal(LootRoll.budget_for(kind.budget, level))
				total += value
			assert_int(roll.loot_value).is_equal(total)


func test_only_level_one_puts_the_gun_in_on_top_of_the_budget() -> void:
	var pistol := ContentRegistry.get_definition("base:laser_pistol") as ItemDefinition
	var markers := {"A": ROOM, "B": ROOM, "C": TIGHT}
	var easy := WreckRoll.new(_layout("base:courier"), 1, 8)
	var loot := easy.roll_loot(markers, _container_kinds(), pistol, easy.new_rng())
	var with_gun := loot.filter(func(placement: LootPlacement) -> bool:
		return placement.items.size() > 0 and placement.items[0] == "base:laser_pistol")
	assert_int(with_gun.size()).is_equal(1)
	var harder := WreckRoll.new(_layout("base:courier"), 2, 8)
	for placement in harder.roll_loot(markers, [_only_crates()], pistol, harder.new_rng()):
		assert_array(Array(placement.items)).not_contains(["base:laser_pistol"])


func test_unknown_items_in_a_loot_table_are_left_out_and_noted() -> void:
	var odd := ContainerDefinition.new()
	odd.id = "test:odd_crate"
	odd.grid_size = Vector2i(4, 3)
	odd.budget = 200
	odd.loot = {"base:thermal_clip": 1.0, "test:nothing": 5.0}
	var roll := WreckRoll.new(_layout("base:courier"), 2, 1)
	var loot := roll.roll_loot({"A": ROOM}, [odd], null, roll.new_rng())
	assert_int(loot.size()).is_equal(1)
	assert_array(Array(loot[0].items)).is_not_empty()
	assert_array(Array(loot[0].items)).not_contains(["test:nothing"])
	assert_int(roll.problems.size()).is_equal(1)


func test_the_same_seed_rolls_the_same_loot() -> void:
	var markers := {"A": ROOM, "B": ROOM, "C": TIGHT, "D": ROOM}
	var first := WreckRoll.new(_layout("base:courier"), 1, 21)
	var second := WreckRoll.new(_layout("base:courier"), 1, 21)
	var pistol := ContentRegistry.get_definition("base:laser_pistol") as ItemDefinition
	var a := first.roll_loot(markers, _container_kinds(), pistol, first.new_rng())
	var b := second.roll_loot(markers, _container_kinds(), pistol, second.new_rng())
	assert_int(a.size()).is_equal(b.size())
	for index in a.size():
		assert_str(a[index].marker).is_equal(b[index].marker)
		assert_str(a[index].container).is_equal(b[index].container)
		assert_array(Array(a[index].items)).is_equal(Array(b[index].items))


static func _layout(id: String) -> WreckDefinition:
	return ContentRegistry.get_definition(id) as WreckDefinition


static func _enemy_kinds() -> Array:
	return ContentRegistry.get_all(EnemyDefinition)


static func _container_kinds() -> Array:
	return ContentRegistry.get_all(ContainerDefinition)


static func _only_crates() -> ContainerDefinition:
	return ContentRegistry.get_definition("base:supply_crate") as ContainerDefinition


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
