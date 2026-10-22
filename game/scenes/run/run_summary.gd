class_name RunSummary
extends RefCounted
## How a run ended, for the summary placard on the black screen: extracted with a haul (what was carried out and
## what the run gained), or died and lost everything that was carried, with the next clone waking up.

## Whether the player got out alive.
var extracted := false
## Items carried out, or lost.
var items := 0
## Their value in bitcoin.
var value := 0
## Extracted only: the value carried out minus the value carried in when boarding.
var gained := 0
## The clone that made it back, or after a death the one that wakes up next.
var clone_number := 1


static func make_extracted(carried_items: int, carried_value: int, value_in: int, clone: int) -> RunSummary:
	var summary := RunSummary.new()
	summary.extracted = true
	summary.items = carried_items
	summary.value = carried_value
	summary.gained = carried_value - value_in
	summary.clone_number = clone
	return summary


static func make_died(carried_items: int, carried_value: int, next_clone: int) -> RunSummary:
	var summary := RunSummary.new()
	summary.extracted = false
	summary.items = carried_items
	summary.value = carried_value
	summary.clone_number = next_clone
	return summary


func _to_string() -> String:
	if extracted:
		return "extracted(items=%d, value=%d, gained=%d, clone=%d)" % [items, value, gained, clone_number]
	return "died(items=%d, value=%d, next_clone=%d)" % [items, value, clone_number]
