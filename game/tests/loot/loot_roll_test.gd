extends GdUnitTestSuite
## Checks rolling a container's loot: the budget the level scales, drawing by weight within the budget and the grid,
## and the same seed drawing the same. Uses the base game's items: thermal clip ₿25 (1 cell), circuit board ₿60
## (2 cells), gyroscope ₿160 (2×2) and plasma coil ₿180 (a T of 4 cells).


func test_the_level_scales_the_budget_by_half_a_budget_a_level() -> void:
	assert_int(LootRoll.budget_for(100, 1)).is_equal(100)
	assert_int(LootRoll.budget_for(100, 2)).is_equal(150)
	assert_int(LootRoll.budget_for(100, 3)).is_equal(200)
	assert_int(LootRoll.budget_for(350, 2)).is_equal(525)


func test_draws_within_the_budget_until_nothing_fits_it() -> void:
	for seed_value in 20:
		var grid := ItemGrid.new(Vector2i(6, 6))
		var drawn := LootRoll.draw(_items(["base:thermal_clip", "base:circuit_board"]), [1.0, 1.0], 200, grid,
				_rng(seed_value))
		var value := _value(drawn)
		assert_int(value).is_less_equal(200)
		# Whatever is left is less than the cheapest item.
		assert_int(200 - value).is_less(25)
		assert_int(grid.value()).is_equal(value)


func test_never_draws_what_costs_more_than_the_budget() -> void:
	var drawn := LootRoll.draw(_items(["base:plasma_coil"]), [1.0], 150, ItemGrid.new(Vector2i(4, 4)), _rng(1))
	assert_array(drawn).is_empty()


func test_stops_when_the_grid_is_full() -> void:
	var grid := ItemGrid.new(Vector2i(2, 1))
	var drawn := LootRoll.draw(_items(["base:thermal_clip"]), [1.0], 1000, grid, _rng(1))
	assert_int(drawn.size()).is_equal(2)
	assert_int(grid.free_cells()).is_equal(0)


func test_draws_only_what_still_fits() -> void:
	# A 2×2 gyroscope can't fit beside a clip in a 2×2 grid, so only clips come out.
	var grid := ItemGrid.new(Vector2i(2, 2))
	grid.add(Item.new(_items(["base:thermal_clip"])[0]))
	var drawn := LootRoll.draw(_items(["base:gyroscope", "base:thermal_clip"]), [100.0, 1.0], 1000, grid, _rng(1))
	assert_int(drawn.size()).is_equal(3)
	for item in drawn:
		assert_str(item.id).is_equal("base:thermal_clip")


func test_never_draws_an_item_without_weight() -> void:
	for seed_value in 10:
		var drawn := LootRoll.draw(_items(["base:thermal_clip", "base:circuit_board"]), [0.0, 1.0], 300,
				ItemGrid.new(Vector2i(6, 6)), _rng(seed_value))
		for item in drawn:
			assert_str(item.id).is_equal("base:circuit_board")


func test_the_same_seed_draws_the_same() -> void:
	var items := _items(["base:thermal_clip", "base:circuit_board", "base:gyroscope", "base:plasma_coil"])
	var weights: Array[float] = [3.0, 2.0, 1.0, 1.0]
	var first := LootRoll.draw(items, weights, 500, ItemGrid.new(Vector2i(4, 5)), _rng(7))
	var second := LootRoll.draw(items, weights, 500, ItemGrid.new(Vector2i(4, 5)), _rng(7))
	assert_array(second).is_equal(first)


static func _items(ids: Array) -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for id: String in ids:
		items.append(ContentRegistry.get_definition(id) as ItemDefinition)
	return items


static func _value(items: Array[ItemDefinition]) -> int:
	var value := 0
	for item in items:
		value += item.value
	return value


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
