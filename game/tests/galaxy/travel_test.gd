extends GdUnitTestSuite
## Checks travelling between star systems through the game session, with travel turned off: a new game on the outer
## ring with 2 of 10 units of antimatter; antimatter ordered at the hub (filling every empty unit or nothing, paid
## at once), arriving a day later and collected at the hub; jumps that burn antimatter by
## distance, take a day, start only from the hub and arrive at the next hub, with the drive recharging for a day; each
## system keeping what is left in it, and its hub its prices; intel on a system in range; and easy wrecks turning up
## only when the player would otherwise be stranded. The ship starts each test at Praetor's hub, whose neighbours are
## Mori (7.2 ly, 8 units), Concordia, Vallum, Halden and Aquila (9.8 ly, 10 units); Centurion is out of range.

var _praetor: StarSystemDefinition
var _mori: StarSystemDefinition
var _aquila: StarSystemDefinition
var _centurion: StarSystemDefinition


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_praetor = _system("base:praetor")
	_mori = _system("base:mori")
	_aquila = _system("base:aquila")
	_centurion = _system("base:centurion")
	GameSession.arrive_in(_praetor)
	# Plenty of hydrogen, so flying to any wreck and back never gets in the way.
	GameSession.hydrogen = 99


func after_test() -> void:
	GameSession.travel_enabled = true
	GameSession.new_game()


func test_a_new_game_starts_on_the_outer_ring_with_a_little_antimatter_and_nothing_else_known() -> void:
	for _game in 10:
		GameSession.new_game()
		var start := GameSession.system.definition
		assert_float(start.map_position.length()).is_greater_equal(Galaxy.OUTER_RING)
		# Too little for any jump: the shortest burns 5.
		assert_int(GameSession.antimatter).is_equal(2)
		assert_int(GameSession.check_jump(GameSession.jump_targets()[0])).is_equal(
			GameSession.Jump.SHORT_OF_ANTIMATTER)
		assert_int(GameSession.order_units).is_equal(0)
		assert_bool(GameSession.drive_charged()).is_true()
		assert_array(GameSession.route).is_equal([start])
		assert_array(GameSession.revealed.keys()).is_equal([start.id])


func test_antimatter_is_paid_for_when_ordered_and_arrives_at_the_hub_a_day_later() -> void:
	GameSession.bitcoin = 10000
	var price := GameSession.trader.antimatter_price(8)
	assert_int(GameSession.order_antimatter()).is_equal(8)
	assert_int(GameSession.bitcoin).is_equal(10000 - price)
	assert_int(GameSession.order_day).is_equal(1)
	assert_int(GameSession.antimatter).is_equal(2)
	# One order at a time, and nothing to collect before it arrives.
	assert_int(GameSession.order_antimatter()).is_equal(0)
	assert_int(GameSession.collect_antimatter()).is_equal(0)
	_board_a_wreck()
	# Day 1: it has arrived, and waits at the hub until it is collected there.
	assert_bool(GameSession.order_arrived()).is_true()
	assert_int(GameSession.collect_antimatter()).is_equal(0)
	assert_bool(GameSession.fly_to_hub()).is_true()
	assert_int(GameSession.antimatter).is_equal(2)
	assert_int(GameSession.check_jump(_mori)).is_equal(GameSession.Jump.ORDER_PENDING)
	assert_int(GameSession.collect_antimatter()).is_equal(8)
	assert_int(GameSession.antimatter).is_equal(10)
	assert_int(GameSession.order_units).is_equal(0)


func test_an_order_fills_every_empty_unit_or_nothing() -> void:
	GameSession.bitcoin = 10000
	GameSession.antimatter = 6
	assert_int(GameSession.order_antimatter()).is_equal(4)
	# A wallet that can't pay for filling the tank orders nothing, not part of it.
	GameSession.new_game()
	GameSession.bitcoin = GameSession.trader.antimatter_price(8) - 1
	assert_int(GameSession.order_antimatter()).is_equal(0)
	assert_int(GameSession.order_units).is_equal(0)
	assert_int(GameSession.bitcoin).is_equal(GameSession.trader.antimatter_price(8) - 1)
	# The ₿500 a game starts with doesn't fill the tank, so the first system already needs runs.
	GameSession.new_game()
	assert_int(GameSession.order_antimatter()).is_equal(0)
	GameSession.new_game()
	GameSession.antimatter = GameSession.ANTIMATTER_TANK
	GameSession.bitcoin = 10000
	assert_int(GameSession.order_antimatter()).is_equal(0)
	assert_int(GameSession.bitcoin).is_equal(10000)


func test_antimatter_is_only_ordered_at_the_hub_and_arrives_a_day_later_whatever_the_day() -> void:
	GameSession.bitcoin = 10000
	assert_bool(GameSession.fly_to_wreck(GameSession.system.wrecks[0])).is_true()
	assert_int(GameSession.order_antimatter()).is_equal(0)
	assert_int(GameSession.bitcoin).is_equal(10000)
	GameSession.fly_to_hub()
	GameSession.day = 45
	GameSession.order_antimatter()
	assert_int(GameSession.order_day).is_equal(46)


func test_a_jump_burns_antimatter_by_distance_takes_a_day_and_arrives_at_the_next_hub() -> void:
	GameSession.antimatter = 10
	var days: Array[int] = []
	var on_day := func(day: int) -> void: days.append(day)
	GameSession.day_changed.connect(on_day)
	assert_int(GameSession.check_jump(_mori)).is_equal(GameSession.Jump.OK)
	assert_bool(GameSession.jump_to(_mori)).is_true()
	GameSession.day_changed.disconnect(on_day)
	assert_object(GameSession.system.definition).is_same(_mori)
	assert_int(GameSession.antimatter).is_equal(2)
	assert_int(GameSession.day).is_equal(1)
	assert_array(days).is_equal([1])
	assert_bool(GameSession.at_hub).is_true()
	assert_vector(GameSession.ship_position).is_equal(GameSession.system.hub_position)
	assert_str(GameSession.trader.title).is_equal("Mori Hanse")
	assert_object(GameSession.route.back()).is_same(_mori)
	assert_int(GameSession.system.wrecks.size()).is_between(StarSystem.MIN_WRECKS, StarSystem.MAX_WRECKS)


func test_a_jump_is_refused_out_of_range_short_of_antimatter_or_to_where_the_ship_is() -> void:
	GameSession.antimatter = 10
	assert_int(GameSession.check_jump(_centurion)).is_equal(GameSession.Jump.OUT_OF_RANGE)
	assert_int(GameSession.check_jump(_praetor)).is_equal(GameSession.Jump.HERE)
	GameSession.antimatter = 7
	assert_int(GameSession.check_jump(_mori)).is_equal(GameSession.Jump.SHORT_OF_ANTIMATTER)
	assert_bool(GameSession.jump_to(_mori)).is_false()
	assert_object(GameSession.system.definition).is_same(_praetor)
	assert_int(GameSession.antimatter).is_equal(7)
	assert_int(GameSession.day).is_equal(0)


func test_the_ship_jumps_only_from_the_hub_leaving_a_docked_wreck_behind() -> void:
	GameSession.antimatter = 10
	var wreck := GameSession.system.wrecks[0]
	GameSession.fly_to_wreck(wreck)
	assert_int(GameSession.check_jump(_mori)).is_equal(GameSession.Jump.AWAY_FROM_HUB)
	GameSession.fly_to_hub()
	var praetor := GameSession.system
	assert_bool(GameSession.jump_to(_mori)).is_true()
	assert_bool(praetor.wrecks.has(wreck)).is_true()


func test_after_a_jump_the_drive_recharges_until_a_ship_is_boarded() -> void:
	GameSession.antimatter = 10
	GameSession.jump_to(_mori)
	GameSession.antimatter = 10
	assert_int(GameSession.check_jump(_aquila)).is_equal(GameSession.Jump.RECHARGING)
	assert_int(GameSession.wait_days()).is_equal(1)
	_board_a_wreck()
	GameSession.fly_to_hub()
	assert_int(GameSession.check_jump(_aquila)).is_equal(GameSession.Jump.OK)


func test_a_jump_never_leaves_antimatter_on_order_behind() -> void:
	GameSession.antimatter = 8
	GameSession.bitcoin = 10000
	GameSession.order_antimatter()
	assert_int(GameSession.check_jump(_mori)).is_equal(GameSession.Jump.ORDER_PENDING)


func test_a_system_keeps_what_is_left_in_it_and_its_hub_its_prices() -> void:
	var praetor := GameSession.system
	var hub := GameSession.trader
	praetor.wrecks.resize(2)
	var left := praetor.wrecks.duplicate()
	GameSession.bitcoin = 100000
	GameSession.antimatter = 10
	GameSession.jump_to(_mori)
	GameSession.antimatter = 10
	_board_a_wreck()
	GameSession.fly_to_hub()
	assert_bool(GameSession.jump_to(_praetor)).is_true()
	assert_object(GameSession.system).is_same(praetor)
	assert_array(GameSession.system.wrecks).is_equal(left)
	assert_object(GameSession.trader).is_same(hub)
	assert_array(GameSession.route.slice(-3)).is_equal([_praetor, _mori, _praetor])
	assert_bool(GameSession.has_visited(_mori)).is_true()
	assert_bool(GameSession.has_visited(_aquila)).is_false()


func test_intel_reveals_a_system_in_range_whose_ships_are_there_on_arrival() -> void:
	GameSession.bitcoin = 1000
	var price := GameSession.trader.intel_price()
	assert_int(GameSession.check_intel(_mori)).is_equal(GameSession.Intel.OK)
	assert_object(GameSession.known_system(_mori)).is_null()
	var mori := GameSession.buy_intel(_mori)
	assert_object(mori).is_not_null()
	assert_int(GameSession.bitcoin).is_equal(1000 - price)
	assert_int(mori.wrecks.size()).is_between(StarSystem.MIN_WRECKS, StarSystem.MAX_WRECKS)
	assert_object(GameSession.known_system(_mori)).is_same(mori)
	assert_int(GameSession.check_intel(_mori)).is_equal(GameSession.Intel.KNOWN)
	assert_bool(GameSession.has_visited(_mori)).is_false()
	var ships := mori.wrecks.duplicate()
	GameSession.antimatter = 10
	GameSession.jump_to(_mori)
	assert_object(GameSession.system).is_same(mori)
	assert_array(GameSession.system.wrecks).is_equal(ships)


func test_intel_is_refused_out_of_range_away_from_the_hub_and_when_the_wallet_is_short() -> void:
	GameSession.bitcoin = 1000
	assert_int(GameSession.check_intel(_centurion)).is_equal(GameSession.Intel.OUT_OF_RANGE)
	assert_int(GameSession.check_intel(_praetor)).is_equal(GameSession.Intel.KNOWN)
	GameSession.fly_to_wreck(GameSession.system.wrecks[0])
	assert_int(GameSession.check_intel(_mori)).is_equal(GameSession.Intel.AWAY_FROM_HUB)
	assert_object(GameSession.buy_intel(_mori)).is_null()
	GameSession.fly_to_hub()
	GameSession.bitcoin = 10
	assert_int(GameSession.check_intel(_mori)).is_equal(GameSession.Intel.SHORT_OF_BITCOIN)
	assert_object(GameSession.buy_intel(_mori)).is_null()
	assert_object(GameSession.known_system(_mori)).is_null()


func test_easy_wrecks_turn_up_to_wait_out_a_delivery_when_too_few_are_left() -> void:
	var praetor := GameSession.system
	praetor.wrecks.clear()
	GameSession.bitcoin = 100000
	GameSession.order_antimatter()
	# A day to wait and no wreck left: one turns up, an easy one.
	assert_int(praetor.wrecks.size()).is_equal(Trader.DELIVERY_DAYS)
	assert_int(praetor.wrecks[0].roll.level).is_equal(GameSession.EASY_LEVEL)


func test_easy_wrecks_turn_up_when_the_player_cant_afford_the_antimatter_and_few_are_left() -> void:
	var praetor := GameSession.system
	praetor.wrecks.resize(2)
	GameSession.bitcoin = 0
	_board_a_wreck()
	# One left after the run, and nothing to pay for antimatter with: three or four wrecks again.
	assert_int(praetor.wrecks.size()).is_between(3, 4)
	for wreck in praetor.wrecks.slice(1):
		assert_int(wreck.roll.level).is_equal(1)


func test_no_wrecks_turn_up_for_a_player_who_can_afford_the_antimatter_but_hasnt_ordered_it() -> void:
	var praetor := GameSession.system
	praetor.wrecks.resize(1)
	GameSession.bitcoin = 100000
	_board_a_wreck()
	assert_array(praetor.wrecks).is_empty()
	# Ordering starts the wait, and the wait brings enough to fill it.
	GameSession.fly_to_hub()
	GameSession.order_antimatter()
	assert_int(praetor.wrecks.size()).is_equal(Trader.DELIVERY_DAYS)


func test_loot_on_the_ship_counts_towards_affording_the_antimatter() -> void:
	var praetor := GameSession.system
	praetor.wrecks.resize(2)
	GameSession.bitcoin = 0
	var drive := ContentRegistry.get_definition("base:data_drive") as ItemDefinition
	for _i in 30:
		GameSession.stash.add(Item.new(drive))
	assert_int(GameSession.ship_worth()).is_greater(GameSession.trader.antimatter_price(8))
	_board_a_wreck()
	assert_int(praetor.wrecks.size()).is_equal(1)


func test_an_empty_system_gets_a_wreck_to_wait_out_the_drives_recharge() -> void:
	var praetor := GameSession.system
	praetor.wrecks.clear()
	GameSession.bitcoin = 100000
	GameSession.antimatter = 10
	GameSession.jump_to(_mori)
	GameSession.antimatter = 10
	_board_a_wreck()
	GameSession.fly_to_hub()
	GameSession.jump_to(_praetor)
	# Back with 2 units left, the drive recharging and money for more: one easy wreck to fill the day.
	assert_object(GameSession.system).is_same(praetor)
	assert_int(praetor.wrecks.size()).is_equal(1)
	assert_int(praetor.wrecks[0].roll.level).is_equal(GameSession.EASY_LEVEL)


## Flies to the system's first wreck and boards it; the android dies, and the player comes back to the ship, where
## the ship waits where the wreck was. Takes a day.
func _board_a_wreck() -> void:
	assert_bool(GameSession.fly_to_wreck(GameSession.system.wrecks[0])).is_true()
	GameSession.board(Inventory.new())
	GameSession.die(null)
	GameSession.continue_to_ship()


static func _system(id: String) -> StarSystemDefinition:
	return ContentRegistry.get_definition(id) as StarSystemDefinition
