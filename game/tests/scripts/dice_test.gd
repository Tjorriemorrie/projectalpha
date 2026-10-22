extends GdUnitTestSuite
## Checks the random picks everything rolled from a seed goes through: picking without repeats, and picking by weight.


func test_picks_up_to_count_without_repeats() -> void:
	var picked := Dice.pick(["a", "b", "c", "d", "e"], 3, _rng(1))
	assert_int(picked.size()).is_equal(3)
	for entry in picked:
		assert_int(picked.count(entry)).is_equal(1)
		assert_array(["a", "b", "c", "d", "e"]).contains([entry])


func test_picks_fewer_when_there_are_fewer() -> void:
	assert_array(Dice.pick(["a", "b"], 5, _rng(1))).contains_exactly_in_any_order(["a", "b"])
	assert_array(Dice.pick([], 2, _rng(1))).is_empty()


func test_the_same_seed_picks_the_same() -> void:
	var from := range(20)
	assert_array(Dice.pick(from, 6, _rng(9))).is_equal(Dice.pick(from, 6, _rng(9)))


func test_leaves_the_array_it_picks_from_alone() -> void:
	var from := [1, 2, 3]
	Dice.pick(from, 2, _rng(1))
	assert_array(from).is_equal([1, 2, 3])


func test_weighted_picks_follow_the_weights() -> void:
	var rng := _rng(3)
	var counts := [0, 0, 0]
	for draw in 3000:
		counts[Dice.weighted([1.0, 0.0, 2.0], rng)] += 1
	assert_int(counts[1]).is_equal(0)
	assert_float(float(counts[2]) / counts[0]).is_between(1.7, 2.3)


func test_weighted_finds_nothing_without_a_positive_weight() -> void:
	assert_int(Dice.weighted([], _rng(1))).is_equal(-1)
	assert_int(Dice.weighted([0.0, -1.0], _rng(1))).is_equal(-1)
	assert_int(Dice.weighted([0.0, 0.5], _rng(1))).is_equal(1)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
