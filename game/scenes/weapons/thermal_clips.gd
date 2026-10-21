class_name ThermalClips
extends RefCounted
## The thermal clips the player carries: the heat in the loaded clip (0 is fresh, 1 is saturated), and the clips in
## the player's inventory, which are items. A reload takes a fresh clip from the pockets when it starts and keeps its
## cell for the spent clip that comes out of the weapon when it ends, so a reload never needs room. A spent clip is
## salvage, so it stays with the player instead of being dropped.

## Heat differences smaller than this count as equal, so twenty 5% shots exactly saturate a clip.
const EPSILON := 0.0001
const NO_CELL := Vector2i(-1, -1)

var heat := 0.0
var inventory: Inventory
## The items a fresh and a spent clip are (from the weapon's definition).
var fresh_clip: ItemDefinition
var spent_clip: ItemDefinition
## Fresh clips in the pockets, the ones a reload can use.
var fresh: int:
	get:
		return inventory.pockets.count(fresh_clip) if _has_clips() else 0
## Fresh clips in the backpack, which have to go into the pockets before a reload can use them.
var packed: int:
	get:
		return inventory.backpack.count(fresh_clip) if _has_clips() else 0
## Spent clips carried anywhere.
var spent: int:
	get:
		return inventory.count(spent_clip) if _has_clips() else 0

## The pocket cell a reload under way took its fresh clip from, kept free for the spent clip.
var _swap_cell := NO_CELL


func _init(carried: Inventory = null, fresh_item: ItemDefinition = null, spent_item: ItemDefinition = null,
		loaded_heat: float = 0.0) -> void:
	inventory = carried
	fresh_clip = fresh_item
	spent_clip = spent_item
	heat = loaded_heat


## How much heat the loaded clip can still take.
func room() -> float:
	return maxf(1.0 - heat, 0.0)


## Whether the loaded clip can take a shot that puts this much heat into it.
func has_room_for(shot_heat: float) -> bool:
	return room() + EPSILON >= shot_heat


func add_heat(amount: float) -> void:
	heat = minf(heat + amount, 1.0)


## A reload needs a fresh clip in the pockets to load, and swapping out an unused clip would only waste it.
func can_reload() -> bool:
	return fresh > 0 and heat > EPSILON


## Starts a swap: takes the first fresh clip from the pockets and reserves its cell for the spent one. Returns
## the cell, or NO_CELL when there is no fresh clip in the pockets.
func take_fresh() -> Vector2i:
	if not _has_clips():
		return NO_CELL
	var clip := inventory.pockets.first_of(fresh_clip)
	if clip == null:
		return NO_CELL
	var cell := clip.cell
	inventory.pockets.remove(clip)
	inventory.pockets.reserve(cell)
	_swap_cell = cell
	return cell


## Finishes a swap: the loaded clip comes out spent, however much heat it had left, into the cell take_fresh()
## reserved (taking a fresh clip first if it wasn't called), and the fresh one is loaded. With no fresh clip in the
## pockets nothing changes.
func swap() -> void:
	if _swap_cell == NO_CELL and take_fresh() == NO_CELL:
		return
	heat = 0.0
	# Nothing can take a reserved cell, so the spent clip always fits there.
	inventory.pockets.release(_swap_cell)
	if spent_clip:
		inventory.pockets.place(Item.new(spent_clip), _swap_cell, 0)
	_swap_cell = NO_CELL


## Whether a swap is under way (a fresh clip taken, its cell reserved).
func is_swapping() -> bool:
	return _swap_cell != NO_CELL


func _has_clips() -> bool:
	return inventory != null and fresh_clip != null
