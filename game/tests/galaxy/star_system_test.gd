extends GdUnitTestSuite
## Unit tests for StarSystem, a system as the map shows it: one orbit per place from the star outwards with each moon
## beside its planet, the hub beside the first habitable world, the same layout every time for the same system, six
## to eight wrecks rolled when it is revealed (at its places or in open space), wrecks leaving for good, and the
## hydrogen a flight burns.

var _praetor: StarSystemDefinition
var _layouts: Array


func before_test() -> void:
	_praetor = ContentRegistry.get_definition("base:praetor") as StarSystemDefinition
	_layouts = ContentRegistry.get_all(WreckDefinition)


func test_places_lie_on_their_orbits_and_moons_beside_their_planets() -> void:
	var system := StarSystem.new(_praetor)
	# Praetor I, Hearth, Calloway (Hearth's moon), Praetor IV, the Granary, Dray's Gate.
	assert_array(Array(system.place_orbits)).is_equal([1, 2, 2, 3, 4, 5])
	assert_int(system.orbit_count).is_equal(5)
	for index in [0, 1, 3, 4, 5]:
		assert_float(system.place_positions[index].length()).is_equal_approx(
			system.place_orbits[index] * StarSystem.ORBIT_SPACING, 0.001)
	# A moon lies just below its planet on the map, so their names don't overlap.
	assert_vector(system.place_positions[2] - system.place_positions[1]).is_equal_approx(
		Vector2(0.0, StarSystem.MOON_OFFSET), Vector2.ONE * 0.001)
	assert_float(system.radius()).is_greater(5.0)


func test_the_hub_lies_beside_the_first_habitable_world() -> void:
	var system := StarSystem.new(_praetor)
	assert_int(system.hub_place).is_equal(1)
	assert_vector(system.hub_position - system.place_positions[1]).is_equal_approx(
		Vector2(0.0, -StarSystem.HUB_OFFSET), Vector2.ONE * 0.001)
	# With no habitable world, it orbits the first place.
	var kr_207 := StarSystem.new(ContentRegistry.get_definition("base:kr_207") as StarSystemDefinition)
	assert_int(kr_207.hub_place).is_equal(0)


func test_a_system_looks_the_same_every_time() -> void:
	var first := StarSystem.new(_praetor)
	var second := StarSystem.new(_praetor)
	assert_array(Array(first.place_positions)).is_equal(Array(second.place_positions))
	assert_vector(first.hub_position).is_equal(second.hub_position)


func test_revealing_a_system_rolls_six_to_eight_wrecks_at_its_places_or_in_open_space() -> void:
	var counts := {}
	for roll_seed in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = roll_seed
		var system := StarSystem.reveal(_praetor, _layouts, rng)
		counts[system.wrecks.size()] = true
		assert_int(system.wrecks.size()).is_between(StarSystem.MIN_WRECKS, StarSystem.MAX_WRECKS)
		for wreck in system.wrecks:
			assert_bool(_layouts.has(wreck.roll.definition)).is_true()
			# On the map, at most a wreck crowded out to a far spot reaching into its margin.
			assert_float(wreck.position.length()).is_less(system.radius() + 0.8)
			if wreck.place:
				assert_bool(_praetor.places.has(wreck.place)).is_true()
				var spot := system.place_positions[_praetor.places.find(wreck.place)]
				if wreck.place.kind == SystemPlace.Kind.BELT:
					# Along the belt's ring.
					assert_float(wreck.position.length()).is_equal_approx(spot.length(), 0.001)
				else:
					assert_float(wreck.position.distance_to(spot)).is_less_equal(2.1)
	assert_array(counts.keys()).contains_exactly_in_any_order([6, 7, 8])


func test_wrecks_at_one_place_fan_out_clear_of_each_other_its_moon_and_the_hub() -> void:
	var system := StarSystem.new(_praetor)
	var hearth := _praetor.places[1]
	for i in 7:
		var wreck := SystemWreck.new(WreckRoll.new(_layouts[0], _layouts[0].levels.x, i), hearth,
			system._place_spot(1, RandomNumberGenerator.new()))
		system.wrecks.append(wreck)
	var taken: Array[Vector2] = [system.place_positions[1], system.place_positions[2], system.hub_position]
	for wreck in system.wrecks:
		for other in taken:
			assert_float(wreck.position.distance_to(other)).is_greater_equal(StarSystem.WRECK_OFFSET - 0.001)
		taken.append(wreck.position)


func test_a_wreck_once_removed_is_gone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var system := StarSystem.reveal(_praetor, _layouts, rng)
	var wreck := system.wrecks[0]
	assert_object(system.wreck_with(wreck.roll)).is_same(wreck)
	assert_bool(system.remove(wreck)).is_true()
	assert_bool(system.wrecks.has(wreck)).is_false()
	assert_object(system.wreck_with(wreck.roll)).is_null()
	assert_bool(system.remove(wreck)).is_false()


func test_a_flight_burns_a_unit_of_hydrogen_per_map_unit_rounded_up() -> void:
	assert_int(StarSystem.hydrogen_between(Vector2.ZERO, Vector2.ZERO)).is_equal(0)
	assert_int(StarSystem.hydrogen_between(Vector2.ZERO, Vector2(0.2, 0.0))).is_equal(1)
	assert_int(StarSystem.hydrogen_between(Vector2.ZERO, Vector2(3.0, 0.0))).is_equal(3)
	assert_int(StarSystem.hydrogen_between(Vector2.ZERO, Vector2(3.5, 0.0))).is_equal(4)
	assert_int(StarSystem.hydrogen_between(Vector2(3.0, 0.0), Vector2(3.0, 4.0))).is_equal(4)
	assert_int(StarSystem.hydrogen_between(Vector2(0.0, 0.0), Vector2(3.0, 4.0))).is_equal(5)
