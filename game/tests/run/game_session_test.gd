extends GdUnitTestSuite
## Checks the game session on its own, with travel turned off: a new game, handing the kit the player carries from one
## scene to the next (once), the summaries of an extraction and a death, clone numbers, and the stash lasting through
## runs and deaths.

var _travelled: Array[String] = []


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_travelled.clear()
	GameSession.travelled.connect(_on_travelled)


func after_test() -> void:
	GameSession.travelled.disconnect(_on_travelled)
	GameSession.travel_enabled = true
	GameSession.new_game()


func test_a_new_game_wakes_the_first_clone_with_an_empty_stash() -> void:
	assert_int(GameSession.clone_number).is_equal(1)
	assert_int(GameSession.runs).is_equal(0)
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.NEW_CLONE)
	assert_vector(Vector2(GameSession.stash.size)).is_equal(Vector2(10, 8))
	assert_array(GameSession.stash.items).is_empty()
	assert_object(GameSession.take_carried()).is_null()
	assert_bool(GameSession.fade_in_next).is_true()


func test_boarding_hands_the_kit_to_the_wreck_once() -> void:
	var carried := _kit(["base:thermal_clip", "base:gyroscope"])
	GameSession.board(carried, 0.4)
	assert_array(_travelled).is_equal([GameSession.WRECK_SCENE])
	assert_int(GameSession.runs).is_equal(1)
	assert_object(GameSession.take_carried()).is_same(carried)
	assert_float(GameSession.carried_heat).is_equal_approx(0.4, 0.001)
	assert_object(GameSession.take_carried()).is_null()


func test_extracting_keeps_the_kit_and_sums_up_the_haul() -> void:
	var carried := _kit(["base:thermal_clip", "base:thermal_clip"])
	GameSession.board(carried, 0.0)
	GameSession.take_carried()
	carried.backpack.add(Item.new(_item("base:plasma_coil")))
	carried.backpack.add(Item.new(_item("base:data_drive")))
	var summary := GameSession.extract(carried, 0.7)
	assert_bool(summary.extracted).is_true()
	assert_int(summary.items).is_equal(4)
	assert_int(summary.value).is_equal(50 + 180 + 150)
	assert_int(summary.gained).is_equal(180 + 150)
	assert_int(summary.clone_number).is_equal(1)
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.EXTRACTED)
	assert_object(GameSession.last_run).is_same(summary)
	GameSession.continue_to_ship()
	assert_array(_travelled).is_equal([GameSession.WRECK_SCENE, GameSession.SHIP_SCENE])
	assert_object(GameSession.take_carried()).is_same(carried)
	assert_float(GameSession.carried_heat).is_equal_approx(0.7, 0.001)


func test_dying_loses_the_kit_and_wakes_the_next_clone() -> void:
	var carried := _kit(["base:thermal_clip", "base:power_cell"])
	GameSession.board(carried, 0.2)
	GameSession.take_carried()
	var summary := GameSession.die(carried)
	assert_bool(summary.extracted).is_false()
	assert_int(summary.items).is_equal(2)
	assert_int(summary.value).is_equal(25 + 120)
	assert_int(summary.clone_number).is_equal(2)
	assert_int(GameSession.clone_number).is_equal(2)
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.NEW_CLONE)
	GameSession.continue_to_ship()
	assert_object(GameSession.take_carried()).is_null()
	assert_float(GameSession.carried_heat).is_equal(0.0)


func test_every_death_counts_a_clone() -> void:
	for death in 3:
		GameSession.die(_kit([]))
	assert_int(GameSession.clone_number).is_equal(4)
	assert_int(GameSession.last_run.clone_number).is_equal(4)


func test_the_stash_lasts_through_runs_and_deaths() -> void:
	var gyroscope := Item.new(_item("base:gyroscope"))
	assert_bool(GameSession.stash.add(gyroscope)).is_true()
	GameSession.board(_kit([]), 0.0)
	GameSession.die(_kit([]))
	GameSession.continue_to_ship()
	GameSession.board(_kit([]), 0.0)
	GameSession.extract(_kit([]), 0.0)
	assert_bool(GameSession.stash.has(gyroscope)).is_true()
	GameSession.new_game()
	assert_array(GameSession.stash.items).is_empty()


func test_travel_arrives_fading_in() -> void:
	GameSession.fade_in_next = false
	GameSession.board(_kit([]), 0.0)
	assert_bool(GameSession.fade_in_next).is_true()


func _on_travelled(scene_path: String) -> void:
	_travelled.append(scene_path)


## A carried inventory with these items, in the pockets first.
static func _kit(ids: Array) -> Inventory:
	var carried := Inventory.new()
	for id: String in ids:
		var item := Item.new(_item(id))
		if not carried.pockets.add(item):
			carried.backpack.add(item)
	return carried


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition
