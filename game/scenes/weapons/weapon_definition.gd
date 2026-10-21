class_name WeaponDefinition
extends ContentDefinition
## A weapon in the content registry: its numbers, and its viewmodel scene (model, muzzle and sounds), which only
## loads when the weapon is equipped. Laser weapons heat up as they fire, and a thermal clip soaks up the heat;
## heats are fractions of one clip (0.05 is 5%). Holding the trigger charges a shot: a charge of 0 is a quick click,
## 1 is a full charge, and a part charge scales between the two.

## The viewmodel scene, whose root is a WeaponViewmodel. A res:// path, or a uid:// when picked in the inspector.
@export_file("*.tscn") var viewmodel := ""

@export_group("Clips")
## The item, by content ID, that a reload loads from the pockets: a fresh thermal clip.
@export var clip_item := ""
## The item, by content ID, that the loaded clip becomes when a reload takes it out: a spent thermal clip.
@export var spent_clip_item := ""

@export_group("Shots")
## Damage of an uncharged shot, before the multiplier of the part it hits.
@export var damage: float = 25.0
## Metres a shot reaches.
@export var shot_range: float = 100.0
## Seconds between shots: the fire rate cap.
@export var fire_interval: float = 1.0 / 3.0
## Metres an uncharged shot carries as noise, so enemies hear it, and a fully charged one.
@export var shot_loudness: float = 20.0
@export var full_charge_loudness: float = 30.0

@export_group("Heat and charge")
## Heat an uncharged shot puts into the clip.
@export var shot_heat: float = 0.05
## Heat a fully charged shot puts into the clip.
@export var full_charge_heat: float = 0.15
## Damage of a fully charged shot, as a multiple of an uncharged one.
@export var full_charge_damage_multiplier: float = 4.0
## Seconds the trigger must be held before the shot starts charging, so a quick click stays uncharged.
@export var charge_delay: float = 0.15
## Seconds from the start of the charge to a full charge.
@export var charge_time: float = 1.0

@export_group("Kick and spread")
## Degrees an uncharged shot kicks the view up.
@export var kick: float = 0.5
## Degrees a fully charged shot kicks the view up.
@export var full_charge_kick: float = 3.0
## Seconds the view takes to settle after a full kick.
@export var kick_recovery_time: float = 0.3
## Degrees from the centre dot that hip-fire shots land within.
@export var hip_spread: float = 5.0
## Degrees from the centre dot that shots land within while aiming down sights.
@export var aim_spread: float = 1.0
## Degrees each shot adds to the spread, so quick follow-up shots are less accurate than steady ones.
@export var bloom_per_shot: float = 1.0
## Degrees per second the extra spread settles back.
@export var bloom_recovery: float = 2.0
## Most degrees the extra spread can add.
@export var max_bloom: float = 3.0

@export_group("Handling")
## How much aiming down sights zooms in.
@export var aim_zoom: float = 1.3
## Seconds a reload takes; the clips are swapped at the end.
@export var reload_time: float = 3.0
## Seconds to raise the weapon after a sprint before it can fire.
@export var raise_time: float = 0.25


## The viewmodel scene's res:// path, also when the inspector stored a uid://.
func get_viewmodel_path() -> String:
	return ResourceUID.ensure_path(viewmodel)


func get_problems() -> PackedStringArray:
	var problems := super()
	if viewmodel.is_empty():
		problems.append("Weapon has no viewmodel")
	elif not ResourceLoader.exists(get_viewmodel_path()):
		problems.append("Weapon viewmodel not found: viewmodel=%s" % viewmodel)
	if clip_item.is_empty() or spent_clip_item.is_empty():
		problems.append("Weapon has no clip items: clip_item=%s, spent_clip_item=%s" % [clip_item, spent_clip_item])
	if shot_heat <= 0.0 or full_charge_heat < shot_heat or full_charge_heat > 1.0:
		problems.append("Weapon heats are out of range: shot_heat=%.3f, full_charge_heat=%.3f" % [
			shot_heat, full_charge_heat])
	return problems
