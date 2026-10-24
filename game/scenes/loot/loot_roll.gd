class_name LootRoll
extends RefCounted
## Rolls what is inside a container from its loot table and its bitcoin budget, which the wreck's level scales.
## Items are drawn by weight from those whose value fits the budget left and that still fit in the container, until
## none does, so pricier items only turn up in bigger containers or at higher levels. Drawn items are packed into the
## container's slots as they are drawn, topping up stacks of their kind the way Lootable.fill() packs them later, so
## everything drawn fits. Node-free,
## so it doesn't log; the wreck that rolls logs the outcome.

## How much of a container's budget each level above 1 adds: ×1, ×1.5 and ×2 at levels 1, 2 and 3.
const LEVEL_STEP := 0.5


## A container's budget at a difficulty level.
static func budget_for(budget: int, level: int) -> int:
	return roundi(budget * (1.0 + LEVEL_STEP * (level - 1)))


## Draws items from a loot table (items and their weights, side by side) into grid, which may already hold something
## put in first, until no item fits the budget and the grid. Returns the drawn items in the order they were packed.
static func draw(items: Array[ItemDefinition], weights: Array[float], budget: int, grid: ItemGrid,
		rng: RandomNumberGenerator) -> Array[ItemDefinition]:
	var drawn: Array[ItemDefinition] = []
	var left := budget
	while true:
		var choices: Array[ItemDefinition] = []
		var choice_weights: Array[float] = []
		for index in items.size():
			var item := items[index]
			if weights[index] > 0.0 and item.value <= left and grid.room_for(item) > 0:
				choices.append(item)
				choice_weights.append(weights[index])
		if choices.is_empty():
			break
		var chosen := choices[Dice.weighted(choice_weights, rng)]
		grid.add_one(chosen)
		left -= chosen.value
		drawn.append(chosen)
	return drawn
