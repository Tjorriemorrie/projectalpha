class_name Dice
extends RefCounted
## Random picks from a given RandomNumberGenerator, so whatever is rolled from a seed comes out the same every time.
## Node-free and silent; whoever rolls logs the outcome.


## Up to count entries of an array, picked at random without repeats, in the order picked.
static func pick(from: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var pool := from.duplicate()
	var picked := []
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## The index of an entry picked at random, each as likely as its weight against the others; -1 when no weight is
## above zero. Negative weights count as zero.
static func weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight: float in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	var last := -1
	for index in weights.size():
		if weights[index] <= 0.0:
			continue
		last = index
		roll -= weights[index]
		if roll < 0.0:
			return index
	return last
