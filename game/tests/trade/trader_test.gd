extends GdUnitTestSuite
## Unit tests for Trader, a hub's prices: selling pays an item's value and buying costs twice that, each varied a
## little and always the same way by the hub's seed; hydrogen's and antimatter's prices, how much hydrogen a wallet buys;
## intel's price; the offer for stacks, every item in them; and the shelf's order.

var _clip: ItemDefinition
var _coil: ItemDefinition
var _pistol: WeaponDefinition


func before_test() -> void:
	_clip = _definition(ItemDefinition.new(), "test:clip", 25)
	_coil = _definition(ItemDefinition.new(), "test:coil", 180)
	_pistol = _definition(WeaponDefinition.new(), "test:pistol", 200) as WeaponDefinition


func test_prices_are_the_value_and_twice_the_value_give_or_take_the_variance() -> void:
	var trader := Trader.new(7)
	for definition: ItemDefinition in [_clip, _coil, _pistol]:
		var factor := trader.price_factor(definition)
		assert_float(factor).is_between(1.0 - Trader.PRICE_VARIANCE, 1.0 + Trader.PRICE_VARIANCE)
		assert_int(trader.sell_price(definition)).is_equal(roundi(definition.value * factor))
		assert_int(trader.buy_price(definition)).is_equal(roundi(definition.value * 2.0 * factor))


func test_hydrogen_is_cheap_give_or_take_the_variance() -> void:
	for hub_seed in [1, 7, 42, 99]:
		var trader := Trader.new(hub_seed)
		var tank := trader.hydrogen_price(24)
		assert_int(tank).is_between(floori(24 * Trader.HYDROGEN_VALUE * (1.0 - Trader.PRICE_VARIANCE)),
			ceili(24 * Trader.HYDROGEN_VALUE * (1.0 + Trader.PRICE_VARIANCE)))
		assert_int(trader.hydrogen_price(24)).is_equal(tank)
		assert_int(trader.hydrogen_price(0)).is_equal(0)
		assert_int(trader.hydrogen_price(1)).is_greater_equal(1)


func test_the_wallet_buys_as_much_hydrogen_as_it_pays_for() -> void:
	var trader := Trader.new(7)
	assert_int(trader.affordable_hydrogen(10, 1000)).is_equal(10)
	assert_int(trader.affordable_hydrogen(10, 0)).is_equal(0)
	assert_int(trader.affordable_hydrogen(0, 1000)).is_equal(0)
	for bitcoin in [3, 12, 37, 50]:
		var units := trader.affordable_hydrogen(24, bitcoin)
		assert_int(trader.hydrogen_price(units)).is_less_equal(bitcoin)
		assert_int(trader.hydrogen_price(units + 1)).is_greater(bitcoin)


func test_a_full_tank_of_antimatter_costs_about_1000_give_or_take_the_variance() -> void:
	for hub_seed in [1, 7, 42, 99]:
		var trader := Trader.new(hub_seed)
		assert_int(trader.antimatter_price(10)).is_between(950, 1050)
		assert_int(trader.antimatter_price(0)).is_equal(0)
		assert_int(trader.antimatter_price(4)).is_less(trader.antimatter_price(10))


func test_intel_costs_about_200_at_every_hub() -> void:
	for hub_seed in [1, 7, 42, 99]:
		assert_int(Trader.new(hub_seed).intel_price()).is_between(190, 210)
	assert_int(Trader.new(5).intel_price()).is_equal(Trader.new(5).intel_price())



func test_a_hub_always_quotes_the_same_price() -> void:
	assert_int(Trader.new(42).buy_price(_coil)).is_equal(Trader.new(42).buy_price(_coil))
	assert_float(Trader.new(42).price_factor(_coil)).is_equal(Trader.new(42).price_factor(_coil))


func test_hubs_quote_slightly_different_prices() -> void:
	var factors := {}
	for seed_value in 20:
		factors[Trader.new(seed_value).price_factor(_coil)] = true
	assert_int(factors.size()).is_greater(10)


func test_nothing_is_free_to_buy() -> void:
	var junk := _definition(ItemDefinition.new(), "test:junk", 0)
	assert_int(Trader.new(1).buy_price(junk)).is_equal(1)
	assert_int(Trader.new(1).sell_price(junk)).is_equal(0)


func test_offers_the_sum_of_the_sell_prices_of_every_item_in_the_stacks() -> void:
	var trader := Trader.new(3)
	var items: Array[Item] = [Item.new(_clip, 2), Item.new(_clip), Item.new(_coil)]
	assert_int(trader.offer(items)).is_equal(3 * trader.sell_price(_clip) + trader.sell_price(_coil))
	assert_int(trader.offer([])).is_equal(0)


func test_the_shelf_puts_weapons_first_then_the_cheapest() -> void:
	var drive := _definition(ItemDefinition.new(), "test:drive", 25)
	var section := SectionDefinition.new()
	var shelf := Trader.shelf([_coil, section, drive, _clip, _pistol])
	assert_array(shelf).is_equal([_pistol, _clip, drive, _coil])


static func _definition(definition: ItemDefinition, id: String, value: int) -> ItemDefinition:
	definition.id = id
	definition.value = value
	return definition
