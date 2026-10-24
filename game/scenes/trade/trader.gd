class_name Trader
extends RefCounted
## A trader hub's prices. Selling pays an item's value and buying costs twice its value, each item varied a little by
## the hub (up to PRICE_VARIANCE either way, the same factor for selling and buying) from the hub's seed, so the same
## hub always quotes the same price and another hub a slightly different one. Stock is unlimited: the shelf is every
## item in the game, and hydrogen, cheap and always in stock, fills the ship's tank. Antimatter is never on the shelf:
## the hub procures it to order, which takes DELIVERY_DAYS (a tuning lever, fixed for now). Intel on a system in
## jump range shows its ships before the jump. The rates are a first guess, to be tuned once a full playthrough is
## possible.

## What selling pays and buying costs, as multiples of an item's value.
const SELL_RATE := 1.0
const BUY_RATE := 2.0
## The most a hub's price for an item differs from the base price, as a fraction of it.
const PRICE_VARIANCE := 0.05
## What a unit of hydrogen and of antimatter, and intel on a system, cost before the hub's variance. A full tank of
## antimatter costs about the loot of a courier run or two, so the first systems, where the player can only take on
## couriers, don't strand him.
const HYDROGEN_VALUE := 5.0
const ANTIMATTER_VALUE := 100.0
const INTEL_VALUE := 200.0
## Days the hub takes to procure antimatter: fixed for now, and a tuning lever (the design has it grow through the
## game, as the war makes antimatter scarcer).
const DELIVERY_DAYS := 1

## What the hub is called, shown on its screen.
var title := ""
## Seeds the hub's price variance.
var price_seed := 0


func _init(hub_seed: int = 0, hub_title: String = "Trader hub") -> void:
	price_seed = hub_seed
	title = hub_title


## How much this hub's prices for an item differ from the base prices: a factor between 1 - PRICE_VARIANCE and
## 1 + PRICE_VARIANCE, always the same for the same hub and item.
func price_factor(definition: ItemDefinition) -> float:
	return _factor(definition.id)


## What the hub pays for one of an item, in bitcoin.
func sell_price(definition: ItemDefinition) -> int:
	return roundi(definition.value * SELL_RATE * price_factor(definition))


## What one of an item costs at the hub, in bitcoin; never free.
func buy_price(definition: ItemDefinition) -> int:
	return maxi(roundi(definition.value * BUY_RATE * price_factor(definition)), 1)


## What units of hydrogen cost at the hub together, in bitcoin; nothing for none.
func hydrogen_price(units: int) -> int:
	return _fuel_price(units, HYDROGEN_VALUE, "hydrogen")


## The most hydrogen, up to units, that bitcoin buys at the hub.
func affordable_hydrogen(units: int, bitcoin: int) -> int:
	return _affordable(units, bitcoin, HYDROGEN_VALUE, "hydrogen")


## What units of antimatter cost at the hub together, in bitcoin; nothing for none.
func antimatter_price(units: int) -> int:
	return _fuel_price(units, ANTIMATTER_VALUE, "antimatter")


## What intel on a system costs at the hub, in bitcoin.
func intel_price() -> int:
	return maxi(roundi(INTEL_VALUE * _factor("intel")), 1)



## What the hub pays for all these stacks together, every item in them, in bitcoin.
func offer(items: Array[Item]) -> int:
	var total := 0
	for item in items:
		total += sell_price(item.definition) * item.quantity
	return total


## The hub's shelf from every registered item: weapons first, then the rest from the cheapest up, ties by ID.
static func shelf(definitions: Array) -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for definition in definitions:
		if definition is ItemDefinition:
			items.append(definition)
	items.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		if (a is WeaponDefinition) != (b is WeaponDefinition):
			return a is WeaponDefinition
		if a.value != b.value:
			return a.value < b.value
		return a.id < b.id)
	return items


## What units of a fuel cost together at the hub, never free; nothing for none.
func _fuel_price(units: int, value: float, key: String) -> int:
	if units <= 0:
		return 0
	return maxi(roundi(units * value * _factor(key)), 1)


## The most units of a fuel, up to units, that bitcoin buys at the hub.
func _affordable(units: int, bitcoin: int, value: float, key: String) -> int:
	var affordable := mini(units, floori(bitcoin / (value * _factor(key))) + 1)
	while affordable > 0 and _fuel_price(affordable, value, key) > bitcoin:
		affordable -= 1
	return maxi(affordable, 0)


## The hub's factor for a price, from its seed and what is priced: always the same for the same hub.
func _factor(key: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [price_seed, key]).hash()
	return 1.0 + rng.randf_range(-PRICE_VARIANCE, PRICE_VARIANCE)
