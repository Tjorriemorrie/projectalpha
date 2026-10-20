class_name ThermalClips
extends RefCounted
## The thermal clips the player carries, kept as counts until the grid inventory exists (007): the heat in the
## loaded clip (0 is fresh, 1 is saturated) and how many fresh and spent clips are carried. A spent clip is salvage,
## so it stays with the player instead of being dropped.

## Heat differences smaller than this count as equal, so twenty 5% shots exactly saturate a clip.
const EPSILON := 0.0001

var heat := 0.0
var fresh := 0
var spent := 0


func _init(fresh_clips: int = 0, loaded_heat: float = 0.0) -> void:
	fresh = fresh_clips
	heat = loaded_heat


## How much heat the loaded clip can still take.
func room() -> float:
	return maxf(1.0 - heat, 0.0)


## Whether the loaded clip can take a shot that puts this much heat into it.
func has_room_for(shot_heat: float) -> bool:
	return room() + EPSILON >= shot_heat


func add_heat(amount: float) -> void:
	heat = minf(heat + amount, 1.0)


## A reload needs a fresh clip to load, and swapping out an unused clip would only waste it.
func can_reload() -> bool:
	return fresh > 0 and heat > EPSILON


## Swaps the loaded clip for a fresh one. The old clip goes back as spent, however much heat it had left.
func swap() -> void:
	fresh -= 1
	spent += 1
	heat = 0.0
