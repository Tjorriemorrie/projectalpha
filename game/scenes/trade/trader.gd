class_name Trader
extends RefCounted
## A trader hub's prices. Selling pays an item's value and buying costs twice its value, each item varied a little by
## the hub (up to PRICE_VARIANCE either way, the same factor for selling and buying) from the hub's seed, so the same
## hub always quotes the same price and another hub a slightly different one. Stock is unlimited: the shelf is every
## item in the game. The rates are a first guess, to be tuned once a full playthrough is possible.

## What selling pays and buying costs, as multiples of an item's value.
const SELL_RATE := 1.0
const BUY_RATE := 2.0
## The most a hub's price for an item differs from the base price, as a fraction of it.
const PRICE_VARIANCE := 0.05

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
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [price_seed, definition.id]).hash()
	return 1.0 + rng.randf_range(-PRICE_VARIANCE, PRICE_VARIANCE)


## What the hub pays for one of an item, in bitcoin.
func sell_price(definition: ItemDefinition) -> int:
	return roundi(definition.value * SELL_RATE * price_factor(definition))


## What one of an item costs at the hub, in bitcoin; never free.
func buy_price(definition: ItemDefinition) -> int:
	return maxi(roundi(definition.value * BUY_RATE * price_factor(definition)), 1)


## What the hub pays for all these items together, in bitcoin.
func offer(items: Array[Item]) -> int:
	var total := 0
	for item in items:
		total += sell_price(item.definition)
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
