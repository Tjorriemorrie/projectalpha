extends GdUnitTestSuite
## Checks the game session on its own, with travel turned off: a new game, handing the kit the player carries from one
## scene to the next (once, the gun keeping its loaded clip's heat), the summaries of an extraction and a death, clone
## numbers, the basic kit only for the first clone, the stash lasting through runs and deaths, the wallet (selling
## the crate, buying into the stash, and the crate going back to the stash, only at the hub), flying within the system
## on hydrogen (never further than the tank gets back to the hub), refuelling at the hub, the day counter, and the
## docked wreck: boarded, its roll handed to that wreck once, and gone from the system for good after the run.
## Most tests swap the new game's system for a hand-made one with known distances: the hub at the origin, the hauler
## 3 units east, the courier 4 units north of that and 5 from the hub, and the freighter 7 units west.

var _travelled: Array[String] = []
var _hauler: SystemWreck
var _courier: SystemWreck
var _freighter: SystemWreck


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_travelled.clear()
	GameSession.travelled.connect(_on_travelled)
	var system := StarSystem.new(ContentRegistry.get_definition("base:praetor") as StarSystemDefinition)
	system.hub_position = Vector2.ZERO
	_hauler = SystemWreck.new(WreckRoll.new(_layout("base:hauler"), 2, 7), system.definition.places[4],
		Vector2(3.0, 0.0))
	_courier = SystemWreck.new(WreckRoll.new(_layout("base:courier"), 1, 3), null, Vector2(3.0, 4.0))
	_freighter = SystemWreck.new(WreckRoll.new(_layout("base:freighter"), 3, 5), null, Vector2(-7.0, 0.0))
	system.wrecks.assign([_hauler, _courier, _freighter])
	GameSession.system = system
	GameSession.ship_position = Vector2.ZERO


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


func test_a_new_game_starts_on_day_0_with_a_full_tank_at_the_hub_of_a_star_system() -> void:
	GameSession.new_game()
	assert_int(GameSession.day).is_equal(0)
	assert_int(GameSession.hydrogen).is_equal(GameSession.HYDROGEN_TANK)
	assert_int(GameSession.HYDROGEN_TANK).is_equal(24)
	var system := GameSession.system
	assert_object(system).is_not_null()
	assert_bool(ContentRegistry.get_all(StarSystemDefinition).has(system.definition)).is_true()
	assert_int(system.wrecks.size()).is_between(StarSystem.MIN_WRECKS, StarSystem.MAX_WRECKS)
	assert_bool(GameSession.at_hub).is_true()
	assert_vector(GameSession.ship_position).is_equal(system.hub_position)
	assert_object(GameSession.docked).is_null()
	assert_str(GameSession.trader.title).is_equal(system.definition.hub_name())


func test_flying_to_a_wreck_burns_hydrogen_and_docks_with_it() -> void:
	var burns: Array[int] = []
	var on_burn := func(hydrogen: int) -> void: burns.append(hydrogen)
	GameSession.hydrogen_changed.connect(on_burn)
	var moves: Array[bool] = []
	var on_move := func() -> void: moves.append(true)
	GameSession.ship_moved.connect(on_move)
	assert_int(GameSession.flight_cost(_hauler.position)).is_equal(3)
	assert_int(GameSession.hydrogen_needed(_hauler.position)).is_equal(6)
	assert_bool(GameSession.fly_to_wreck(_hauler)).is_true()
	GameSession.hydrogen_changed.disconnect(on_burn)
	GameSession.ship_moved.disconnect(on_move)
	assert_int(GameSession.hydrogen).is_equal(21)
	assert_array(burns).is_equal([21])
	assert_array(moves).is_equal([true])
	assert_object(GameSession.docked).is_same(_hauler.roll)
	assert_bool(GameSession.at_hub).is_false()
	assert_vector(GameSession.ship_position).is_equal(_hauler.position)
	# Flying takes no time, and the wreck stays in the system until it is boarded.
	assert_int(GameSession.day).is_equal(0)
	assert_bool(GameSession.system.wrecks.has(_hauler)).is_true()


func test_a_flight_is_refused_when_the_tank_couldnt_get_back_to_the_hub() -> void:
	GameSession.hydrogen = 9
	# The courier is 5 there and 5 back.
	assert_bool(GameSession.fly_to_wreck(_courier)).is_false()
	assert_int(GameSession.hydrogen).is_equal(9)
	assert_bool(GameSession.at_hub).is_true()
	assert_object(GameSession.docked).is_null()
	GameSession.hydrogen = 10
	assert_bool(GameSession.fly_to_wreck(_courier)).is_true()
	assert_int(GameSession.hydrogen).is_equal(5)
	# What is left always gets the ship home.
	assert_bool(GameSession.fly_to_hub()).is_true()
	assert_int(GameSession.hydrogen).is_equal(0)
	assert_bool(GameSession.at_hub).is_true()
	assert_object(GameSession.docked).is_null()


func test_a_loop_through_the_wrecks_burns_less_than_flying_back_to_the_hub_between_them() -> void:
	GameSession.fly_to_wreck(_hauler)
	GameSession.fly_to_wreck(_courier)
	GameSession.fly_to_hub()
	var loop := GameSession.HYDROGEN_TANK - GameSession.hydrogen
	assert_int(loop).is_equal(3 + 4 + 5)
	GameSession.hydrogen = GameSession.HYDROGEN_TANK
	GameSession.fly_to_wreck(_hauler)
	GameSession.fly_to_hub()
	GameSession.fly_to_wreck(_courier)
	GameSession.fly_to_hub()
	assert_int(GameSession.HYDROGEN_TANK - GameSession.hydrogen).is_greater(loop)


func test_a_wreck_no_longer_in_the_system_cant_be_flown_to() -> void:
	GameSession.system.remove(_freighter)
	assert_bool(GameSession.fly_to_wreck(_freighter)).is_false()
	assert_int(GameSession.hydrogen).is_equal(GameSession.HYDROGEN_TANK)


func test_refuelling_at_the_hub_fills_the_tank_for_bitcoin() -> void:
	GameSession.hydrogen = 10
	var price := GameSession.trader.hydrogen_price(14)
	assert_int(GameSession.refuel()).is_equal(14)
	assert_int(GameSession.hydrogen).is_equal(GameSession.HYDROGEN_TANK)
	assert_int(GameSession.bitcoin).is_equal(500 - price)
	assert_int(price).is_between(66, 74)
	assert_int(GameSession.refuel()).is_equal(0)


func test_refuelling_buys_what_the_wallet_pays_for() -> void:
	GameSession.hydrogen = 0
	GameSession.bitcoin = 12
	var units := GameSession.refuel()
	assert_int(units).is_equal(2)
	assert_int(GameSession.hydrogen).is_equal(2)
	assert_int(GameSession.bitcoin).is_equal(12 - GameSession.trader.hydrogen_price(2))
	GameSession.bitcoin = 0
	assert_int(GameSession.refuel()).is_equal(0)


func test_refuelling_trading_and_buying_only_happen_at_the_hub() -> void:
	GameSession.fly_to_wreck(_hauler)
	GameSession.hydrogen = 10
	assert_int(GameSession.refuel()).is_equal(0)
	assert_int(GameSession.hydrogen).is_equal(10)
	var gyroscope := Item.new(_item("base:gyroscope"))
	GameSession.crate.add(gyroscope)
	assert_int(GameSession.sell_crate()).is_equal(0)
	assert_bool(GameSession.crate.has(gyroscope)).is_true()
	assert_object(GameSession.buy(_item("base:thermal_clip"))).is_null()
	assert_int(GameSession.bitcoin).is_equal(500)


func test_boarding_takes_a_day_and_the_wreck_is_gone_for_good_whether_the_android_extracts_or_dies() -> void:
	GameSession.fly_to_wreck(_hauler)
	GameSession.board(_kit([]))
	assert_int(GameSession.day).is_equal(1)
	assert_bool(GameSession.system.wrecks.has(_hauler)).is_false()
	assert_object(GameSession.docked).is_null()
	GameSession.extract(_kit([]))
	assert_object(GameSession.docked).is_null()
	assert_bool(GameSession.system.wrecks.has(_hauler)).is_false()
	# The ship stays where the wreck was, with nothing docked.
	assert_vector(GameSession.ship_position).is_equal(_hauler.position)
	assert_bool(GameSession.at_hub).is_false()
	GameSession.fly_to_wreck(_courier)
	GameSession.board(_kit([]))
	GameSession.die(_kit([]))
	assert_int(GameSession.day).is_equal(2)
	assert_array(GameSession.system.wrecks).is_equal([_freighter])
	assert_object(GameSession.docked).is_null()


func test_days_only_pass_by_boarding() -> void:
	GameSession.fly_to_wreck(_hauler)
	GameSession.fly_to_hub()
	GameSession.refuel()
	GameSession.sell_crate()
	assert_int(GameSession.day).is_equal(0)


func test_boarding_hands_the_kit_to_the_wreck_once() -> void:
	var carried := _kit(["base:thermal_clip", "base:gyroscope"])
	var gun := Item.new(_item("base:laser_pistol"))
	gun.clip_heat = 0.4
	carried.weapon.add(gun)
	GameSession.fly_to_wreck(_hauler)
	GameSession.board(carried)
	assert_array(_travelled).is_equal([_hauler.roll.definition.get_scene_path()])
	assert_int(GameSession.runs).is_equal(1)
	var taken := GameSession.take_carried()
	assert_object(taken).is_same(carried)
	assert_float(taken.gun().clip_heat).is_equal_approx(0.4, 0.001)
	assert_object(GameSession.take_carried()).is_null()


func test_extracting_keeps_the_kit_and_sums_up_the_haul() -> void:
	var carried := _kit(["base:thermal_clip", "base:thermal_clip"])
	var wreck_scene := _hauler.roll.definition.get_scene_path()
	GameSession.fly_to_wreck(_hauler)
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
	GameSession.fly_to_wreck(_hauler)
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
	GameSession.fly_to_wreck(_hauler)
	GameSession.board(_kit([]))
	GameSession.die(_kit([]))
	GameSession.continue_to_ship()
	GameSession.fly_to_wreck(_courier)
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


func test_boarding_with_nothing_docked_does_nothing() -> void:
	GameSession.board(_kit([]))
	assert_array(_travelled).is_empty()
	assert_int(GameSession.day).is_equal(0)
	assert_int(GameSession.runs).is_equal(0)


func test_boarding_hands_the_docked_wrecks_roll_to_that_wreck_once() -> void:
	GameSession.fly_to_wreck(_courier)
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


func test_travel_arrives_fading_in() -> void:
	GameSession.fade_in_next = false
	GameSession.fly_to_wreck(_hauler)
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


static func _layout(id: String) -> WreckDefinition:
	return ContentRegistry.get_definition(id) as WreckDefinition
