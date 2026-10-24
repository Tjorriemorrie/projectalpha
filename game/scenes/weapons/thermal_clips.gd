class_name ThermalClips
extends RefCounted
## The thermal clips the player carries: the heat in the gun's loaded clip (0 is fresh, 1 is saturated), and the
## clips in the player's inventory, which are items. The heat lives on the gun item, so it goes wherever the gun goes.
## A reload takes a fresh clip off a stack in the ammo slots when it starts, and the spent clip that comes out of the
## weapon when it ends goes onto a spent stack or a free slot in the ammo slots, else the pockets or the backpack; with
## no room anywhere it overflows, and the player drops it on the floor. A spent clip is salvage, so it stays with the
## player when it can.

## Emitted when a clip out of the gun (a spent one, or a fresh one put back) has no room anywhere in the inventory:
## the player drops it.
signal overflowed(clip: Item)

## Heat differences smaller than this count as equal, so twenty 5% shots exactly saturate a clip.
const EPSILON := 0.0001

## The loaded clip's heat, kept on the gun; always 0 with no gun.
var heat: float:
	get:
		return gun.clip_heat if gun else 0.0
	set(value):
		if gun:
			gun.clip_heat = value
## The gun whose loaded clip this is, or null when the player is unarmed.
var gun: Item
var inventory: Inventory
## The items a fresh and a spent clip are (from the weapon's definition).
var fresh_clip: ItemDefinition
var spent_clip: ItemDefinition
## Fresh clips in the ammo slots, the ones a reload can use.
var fresh: int:
	get:
		return inventory.ammo.count(fresh_clip) if _has_clips() else 0
## Fresh clips in the pockets and the backpack, which have to go into the ammo slots before a reload can use them.
var packed: int:
	get:
		return inventory.pockets.count(fresh_clip) + inventory.backpack.count(fresh_clip) if _has_clips() else 0
## Spent clips carried anywhere.
var spent: int:
	get:
		return inventory.count(spent_clip) if _has_clips() else 0

## Whether a reload under way has taken its fresh clip.
var _taken := false


func _init(carried: Inventory = null, fresh_item: ItemDefinition = null, spent_item: ItemDefinition = null,
		loaded: Item = null) -> void:
	inventory = carried
	fresh_clip = fresh_item
	spent_clip = spent_item
	gun = loaded


## How much heat the loaded clip can still take.
func room() -> float:
	return maxf(1.0 - heat, 0.0)


## Whether the loaded clip can take a shot that puts this much heat into it.
func has_room_for(shot_heat: float) -> bool:
	return room() + EPSILON >= shot_heat


func add_heat(amount: float) -> void:
	heat = minf(heat + amount, 1.0)


## A reload needs a fresh clip in the ammo slots to load, and swapping out an unused clip would only waste it.
func can_reload() -> bool:
	return fresh > 0 and heat > EPSILON


## Starts a swap: takes a fresh clip off the first stack of them in the ammo slots. Returns whether there was one.
func take_fresh() -> bool:
	if not _has_clips():
		return false
	var stack := inventory.ammo.first_of(fresh_clip)
	if stack == null:
		return false
	inventory.ammo.take(stack, 1)
	_taken = true
	return true


## Finishes a swap: the loaded clip comes out spent, however much heat it had left, and goes back into the inventory
## (see _stow()), and the fresh one take_fresh() took is loaded (taking one first if it wasn't called). With no fresh
## clip in the ammo slots nothing changes.
func swap() -> void:
	if not _taken and not take_fresh():
		return
	heat = 0.0
	_taken = false
	if spent_clip:
		_stow(Item.new(spent_clip))


## Calls off a swap under way: the fresh clip take_fresh() took goes back into the inventory, and the loaded clip
## stays as it was. Returns whether there was one.
func cancel_swap() -> bool:
	if not _taken:
		return false
	_taken = false
	if fresh_clip:
		_stow(Item.new(fresh_clip))
	return true


## Whether a swap is under way (its fresh clip taken).
func is_swapping() -> bool:
	return _taken


## A clip out of the gun goes onto a stack of its kind or into a free slot in the ammo slots, else onto a stack or
## into a free slot in the pockets or the backpack; with no room anywhere it overflows, and the player drops it.
func _stow(clip: Item) -> void:
	if inventory.ammo.add(clip):
		return
	if ItemGrid.stow(clip, [inventory.pockets, inventory.backpack]) > 0:
		return
	overflowed.emit(clip)


func _has_clips() -> bool:
	return inventory != null and fresh_clip != null
