class_name EnemyDefinition
extends ContentDefinition
## An enemy in the content registry: its scene (body, model, hitboxes, searchlight and sounds), which only loads
## when the enemy is placed, and the numbers of the robot brain it shares with every robot: health, sight, lock-on,
## fire, heat and how long it stays alert. How each kind moves (the turret's arc, the drone's speeds) is exported on
## its scene's root instead.

## The robot's scene, whose root is a Robot. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var scene := ""
## The marker it is placed on: drone posts on the floor, turret mounts on the ceiling.
@export var mount: SectionMarker.Mount = SectionMarker.Mount.FLOOR

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Sight")
## Metres within which it sees a lit part of the player.
@export var sight_range: float = 15.0
## Degrees across its view cone.
@export var sight_angle: float = 120.0
## Metres within which it sees a part of the player in the dark.
@export var dark_sight_range: float = 5.0
## Seconds it keeps seeing the player after the last sample point went out of sight, so a point flickering at the
## edge of cover doesn't drop the lock.
@export var sight_memory: float = 0.25

@export_group("Lock-on")
## Seconds to lock on when it spots the player while idle.
@export var idle_lock_time: float = 0.8
## Seconds to lock on when it is already investigating, attacking or searching.
@export var alert_lock_time: float = 0.4

@export_group("Fire")
## Damage of a hit, before the multiplier of the part it lands on. 10 takes ten body hits to kill the player, who
## has to get through many fights in a run.
@export var damage: float = 10.0
## Seconds between shots.
@export var fire_interval: float = 1.0
## Degrees from the aimed point that shots land within right after locking on: the first shots are wide.
@export var initial_spread: float = 10.0
## Degrees they land within once it has kept the player in sight for settle_time: its fire walks in.
@export var spread: float = 3.0
## Seconds of keeping the player in sight for the spread to tighten from initial_spread to spread.
@export var settle_time: float = 2.0
## Seconds behind the player it aims: it fires at where they were, so shots at a moving player trail behind them
## while a still one gets hit.
@export var aim_lag: float = 0.3
## Metres a shot reaches.
@export var shot_range: float = 50.0
## Degrees between where it faces and its target within which it fires, so it has to turn to aim.
@export var aim_tolerance: float = 10.0

@export_group("Heat")
## Heat a shot adds; at 1 it has to vent.
@export var shot_heat: float = 0.1
## Seconds after a shot before the heat starts cooling off.
@export var cool_delay: float = 0.5
## Heat per second that cools off when it isn't firing.
@export var cool_rate: float = 0.1
## Seconds a vent takes; it can't fire meanwhile.
@export var vent_time: float = 2.0

@export_group("Attention")
## Seconds it watches the spot of a noise, a hit or a glimpse once it got there, before going back to idle.
@export var investigate_time: float = 5.0
## Seconds it searches where it last saw the player once it got there, before going back to idle.
@export var search_time: float = 6.0

@export_group("Noise")
## Metres its shots carry, so other robots come to the fight.
@export var shot_loudness: float = 20.0
## Metres the crash of its wreckage carries when it is destroyed.
@export var crash_loudness: float = 15.0

@export_group("Salvage")
## Columns and rows of the grid its wreckage holds its salvage in.
@export var salvage_grid := Vector2i(3, 3)
## The parts the player can pry out of its wreckage, by content ID, packed into the grid in this order.
@export var salvage := PackedStringArray()


## The scene's res:// path, also when the inspector stored a uid://.
func get_scene_path() -> String:
	return ResourceUID.ensure_path(scene)


## Seconds to lock on, given whether the robot was idle when it spotted the player.
func lock_time(idle: bool) -> float:
	return idle_lock_time if idle else alert_lock_time


func get_problems() -> PackedStringArray:
	var problems := super()
	if scene.is_empty():
		problems.append("Enemy has no scene")
	elif not ResourceLoader.exists(get_scene_path()):
		problems.append("Enemy scene not found: scene=%s" % scene)
	if max_health <= 0.0 or shot_heat <= 0.0 or fire_interval <= 0.0:
		problems.append("Enemy numbers are out of range: max_health=%.1f, shot_heat=%.3f, fire_interval=%.3f" % [
			max_health, shot_heat, fire_interval])
	return problems
