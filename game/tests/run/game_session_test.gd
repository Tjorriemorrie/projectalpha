extends GdUnitTestSuite
## Checks the game session on its own, with travel turned off: a new game, handing the kit the player carries from one
## scene to the next (once, the gun keeping its loaded clip's heat), the summaries of an extraction and a death, clone
## numbers, the basic kit only for the first clone, the stash lasting through runs and deaths, the wallet (selling
## the crate, buying into the stash, and the crate going back to the stash), and the docked wreck: rolled for a new
## game and after every run, boarded, and its roll handed to that wreck once.

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
	assert_bool(GameSession.basic_kit_next).is_true()
	assert_bool(GameSession.fade_in_next).is_true()
	assert_int(GameSession.bitcoin).is_equal(500)
	assert_array(GameSession.crate.items).is_empty()


func test_boarding_hands_the_kit_to_the_wreck_once() -> void:
	var carried := _kit(["base:thermal_clip", "base:gyroscope"])
	var gun := Item.new(_item("base:laser_pistol"))
	gun.clip_heat = 0.4
	carried.weapon.add(gun)
	GameSession.board(carried)
	assert_array(_travelled).is_equal([GameSession.docked.definition.get_scene_path()])
	assert_int(GameSession.runs).is_equal(1)
	var taken := GameSession.take_carried()
	assert_object(taken).is_same(carried)
	assert_float(taken.gun().clip_heat).is_equal_approx(0.4, 0.001)
	assert_object(GameSession.take_carried()).is_null()


func test_extracting_keeps_the_kit_and_sums_up_the_haul() -> void:
	var carried := _kit(["base:thermal_clip", "base:thermal_clip"])
	var wreck_scene := GameSession.docked.definition.get_scene_path()
	GameSession.board(carried)
	GameSession.take_carried()
	carried.backpack.add(Item.new(_item("base:plasma_coil")))
	carried.backpack.add(Item.new(_item("base:data_drive")))
	var summary := GameSession.extract(carried)
	assert_bool(summary.extracted).is_true()
	assert_int(summary.items).is_equal(4)
	assert_int(summary.value).is_equal(50 + 180 + 150)
	assert_int(summary.gained).is_equal(180 + 150)
	assert_int(summary.clone_number).is_equal(1)
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.EXTRACTED)
	assert_object(GameSession.last_run).is_same(summary)
	GameSession.continue_to_ship()
	assert_array(_travelled).is_equal([wreck_scene, GameSession.SHIP_SCENE])
	assert_object(GameSession.take_carried()).is_same(carried)


func test_dying_loses_the_kit_and_wakes_the_next_clone() -> void:
	var carried := _kit(["base:thermal_clip", "base:power_cell"])
	GameSession.board(carried)
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
	# The next clone wakes empty-handed, and arms from the stash.
	assert_bool(GameSession.basic_kit_next).is_false()


func test_every_death_counts_a_clone() -> void:
	for death in 3:
		GameSession.die(_kit([]))
	assert_int(GameSession.clone_number).is_equal(4)
	assert_int(GameSession.last_run.clone_number).is_equal(4)


func test_the_stash_lasts_through_runs_and_deaths() -> void:
	var gyroscope := Item.new(_item("base:gyroscope"))
	assert_bool(GameSession.stash.add(gyroscope)).is_true()
	GameSession.board(_kit([]))
	GameSession.die(_kit([]))
	GameSession.continue_to_ship()
	GameSession.board(_kit([]))
	GameSession.extract(_kit([]))
	assert_bool(GameSession.stash.has(gyroscope)).is_true()
	GameSession.new_game()
	assert_array(GameSession.stash.items).is_empty()


func test_the_wallet_lasts_through_deaths_and_a_new_game_resets_it() -> void:
	GameSession.bitcoin = 1234
	GameSession.die(_kit(["base:gyroscope"]))
	assert_int(GameSession.bitcoin).is_equal(1234)
	GameSession.new_game()
	assert_int(GameSession.bitcoin).is_equal(GameSession.STARTING_BITCOIN)
	assert_bool(GameSession.basic_kit_next).is_true()


func test_selling_the_crate_pays_the_hubs_offer() -> void:
	var gyroscope := _item("base:gyroscope")
	var drive := _item("base:data_drive")
	GameSession.crate.add(Item.new(gyroscope))
	GameSession.crate.add(Item.new(drive))
	var offer := GameSession.trader.sell_price(gyroscope) + GameSession.trader.sell_price(drive)
	var changes: Array[int] = []
	var on_change := func(amount: int) -> void: changes.append(amount)
	GameSession.bitcoin_changed.connect(on_change)
	assert_int(GameSession.sell_crate()).is_equal(offer)
	GameSession.bitcoin_changed.disconnect(on_change)
	assert_int(GameSession.bitcoin).is_equal(500 + offer)
	assert_array(changes).is_equal([500 + offer])
	assert_array(GameSession.crate.items).is_empty()
	assert_int(GameSession.sell_crate()).is_equal(0)


func test_buying_puts_one_in_the_stash_and_takes_the_price() -> void:
	var clip := _item("base:thermal_clip")
	var price := GameSession.trader.buy_price(clip)
	var item := GameSession.buy(clip)
	assert_object(item).is_not_null()
	assert_object(GameSession.stash.item_at(Vector2i(0, 0))).is_same(item)
	assert_int(GameSession.bitcoin).is_equal(500 - price)
	# A bought gun comes with a fresh clip loaded.
	GameSession.bitcoin = 10000
	var pistol := GameSession.buy(_item("base:laser_pistol"))
	assert_float(pistol.clip_heat).is_equal(0.0)


func test_buying_is_refused_when_the_wallet_is_short() -> void:
	GameSession.bitcoin = 10
	assert_object(GameSession.buy(_item("base:laser_pistol"))).is_null()
	assert_int(GameSession.bitcoin).is_equal(10)
	assert_array(GameSession.stash.items).is_empty()


func test_buying_is_refused_when_the_stash_is_full() -> void:
	var drive := _item("base:data_drive")
	for i in GameSession.STASH_SIZE.x * GameSession.STASH_SIZE.y:
		GameSession.stash.add(Item.new(drive))
	GameSession.bitcoin = 10000
	assert_object(GameSession.buy(_item("base:thermal_clip"))).is_null()
	assert_int(GameSession.bitcoin).is_equal(10000)


func test_whats_left_in_the_crate_goes_back_to_the_stash() -> void:
	var gyroscope := Item.new(_item("base:gyroscope"))
	GameSession.crate.add(gyroscope)
	assert_int(GameSession.return_crate()).is_equal(0)
	assert_bool(GameSession.stash.has(gyroscope)).is_true()
	assert_array(GameSession.crate.items).is_empty()


func test_what_doesnt_fit_in_the_stash_waits_in_the_crate() -> void:
	var drive := _item("base:data_drive")
	for i in GameSession.STASH_SIZE.x * GameSession.STASH_SIZE.y:
		GameSession.stash.add(Item.new(drive))
	var gyroscope := Item.new(_item("base:gyroscope"))
	GameSession.crate.add(gyroscope)
	assert_int(GameSession.return_crate()).is_equal(1)
	assert_bool(GameSession.crate.has(gyroscope)).is_true()


func test_a_new_game_docks_a_registered_wreck_at_a_level_in_its_range() -> void:
	var docked := GameSession.docked
	assert_object(docked).is_not_null()
	assert_bool(ContentRegistry.get_all(WreckDefinition).has(docked.definition)).is_true()
	assert_int(docked.level).is_between(docked.definition.levels.x, docked.definition.levels.y)


func test_boarding_hands_the_docked_wrecks_roll_to_that_wreck_once() -> void:
	var docked := GameSession.docked
	GameSession.board(_kit([]))
	assert_object(GameSession.take_boarding(docked.definition)).is_same(docked)
	assert_object(GameSession.take_boarding(docked.definition)).is_null()


func test_another_layout_gets_no_roll() -> void:
	var hauler := ContentRegistry.get_definition("base:hauler") as WreckDefinition
	var courier := ContentRegistry.get_definition("base:courier") as WreckDefinition
	GameSession.docked = WreckRoll.new(hauler, 1, 3)
	GameSession.board(_kit([]))
	assert_object(GameSession.take_boarding(courier)).is_null()
	assert_object(GameSession.take_boarding(hauler)).is_null()


func test_every_run_ends_with_a_new_wreck_docked() -> void:
	var first := GameSession.docked
	GameSession.board(_kit([]))
	GameSession.extract(_kit([]))
	var second := GameSession.docked
	assert_object(second).is_not_same(first)
	GameSession.board(_kit([]))
	GameSession.die(_kit([]))
	assert_object(GameSession.docked).is_not_same(second)
	assert_object(GameSession.docked).is_not_null()


func test_travel_arrives_fading_in() -> void:
	GameSession.fade_in_next = false
	GameSession.board(_kit([]))
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
