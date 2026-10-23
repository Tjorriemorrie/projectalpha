extends GdUnitTestSuite
## Unit tests for Galaxy, the cluster as the jump drive sees it, on the base game's 50 systems: distances in light
## years, the antimatter a jump burns (a unit per light year, rounded up), the systems within a jump (about five from
## any system, and never one 10 to 11 ly away), the outer ring, and where a new game starts.

var _systems: Array
var _praetor: StarSystemDefinition


func before_test() -> void:
	_systems = ContentRegistry.get_all(StarSystemDefinition)
	_praetor = _system("base:praetor")


func test_a_jump_burns_a_unit_of_antimatter_per_light_year_rounded_up() -> void:
	var mori := _system("base:mori")
	assert_float(Galaxy.distance(_praetor, mori)).is_equal_approx(7.2, 0.01)
	assert_int(Galaxy.antimatter_between(_praetor, mori)).is_equal(8)
	assert_int(Galaxy.antimatter_between(mori, _praetor)).is_equal(8)
	assert_int(Galaxy.antimatter_between(_praetor, _praetor)).is_equal(0)
	# Aquila is 9.8 ly away: a full tank reaches it.
	assert_int(Galaxy.antimatter_between(_praetor, _system("base:aquila"))).is_equal(10)


func test_the_systems_in_range_are_those_within_ten_light_years_nearest_first() -> void:
	var ids := Galaxy.in_range(_praetor, _systems).map(func(system: StarSystemDefinition) -> String: return system.id)
	assert_array(ids).is_equal(["base:mori", "base:concordia", "base:vallum", "base:halden", "base:aquila"])


func test_every_system_has_four_to_six_in_range_and_none_just_out_of_it() -> void:
	for system: StarSystemDefinition in _systems:
		assert_int(Galaxy.in_range(system, _systems).size()).override_failure_message(
			"%s has %d systems in range" % [system.id, Galaxy.in_range(system, _systems).size()]).is_between(4, 6)
		for other: StarSystemDefinition in _systems:
			var light_years := Galaxy.distance(system, other)
			assert_bool(light_years > Galaxy.JUMP_RANGE and light_years < 11.0).override_failure_message(
				"%s and %s are %.2f ly apart" % [system.id, other.id, light_years]).is_false()
			if other != system and light_years <= Galaxy.JUMP_RANGE:
				assert_int(Galaxy.antimatter_between(system, other)).is_between(1, GameSession.ANTIMATTER_TANK)


func test_the_outer_ring_holds_the_sixteen_systems_28_ly_or_more_from_the_middle() -> void:
	var ring := Galaxy.outer_ring(_systems)
	assert_int(ring.size()).is_equal(16)
	for system in ring:
		assert_float(system.map_position.length()).is_greater_equal(Galaxy.OUTER_RING)
	assert_bool(ring.has(_praetor)).is_false()


func test_a_new_game_starts_on_the_outer_ring_in_a_random_direction() -> void:
	var picked := {}
	for roll_seed in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = roll_seed
		var start := Galaxy.pick_start(_systems, rng)
		assert_float(start.map_position.length()).is_greater_equal(Galaxy.OUTER_RING)
		picked[start.id] = true
		# The same seed always picks the same start.
		var again := RandomNumberGenerator.new()
		again.seed = roll_seed
		assert_object(Galaxy.pick_start(_systems, again)).is_same(start)
	# Ostby, alone on the north of the ring, is picked as often as its stretch of the ring, not one time in sixteen.
	assert_int(picked.size()).is_greater_equal(10)
	assert_bool(picked.has("base:ostby")).is_true()


func test_with_no_system_on_the_ring_any_system_starts_and_with_none_nothing_does() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_object(Galaxy.pick_start([_praetor], rng)).is_same(_praetor)
	assert_object(Galaxy.pick_start([], rng)).is_null()


static func _system(id: String) -> StarSystemDefinition:
	return ContentRegistry.get_definition(id) as StarSystemDefinition
