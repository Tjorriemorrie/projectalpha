class_name WeaponRules
extends RefCounted
## A weapon's decisions, kept free of nodes and input so they can be unit tested: what a charge costs and does,
## how far a charge can grow, and where a shot goes. Charges run from 0 (a quick click) to 1 (a full charge).

## max_charge() returns this when the clip can't take even an uncharged shot.
const SATURATED := -1.0


static func shot_heat(definition: WeaponDefinition, charge: float) -> float:
	return lerpf(definition.shot_heat, definition.full_charge_heat, charge)


static func shot_damage(definition: WeaponDefinition, charge: float) -> float:
	return definition.damage * lerpf(1.0, definition.full_charge_damage_multiplier, charge)


## Metres the shot carries as noise.
static func shot_loudness(definition: WeaponDefinition, charge: float) -> float:
	return lerpf(definition.shot_loudness, definition.full_charge_loudness, charge)


## Degrees the shot kicks the view up.
static func shot_kick(definition: WeaponDefinition, charge: float) -> float:
	return lerpf(definition.kick, definition.full_charge_kick, charge)


## How far the trigger has charged after being held for held_time seconds, before the clip's limit.
static func charge_for_hold(definition: WeaponDefinition, held_time: float) -> float:
	return clampf((held_time - definition.charge_delay) / maxf(definition.charge_time, 0.001), 0.0, 1.0)


## The biggest charge the loaded clip has room for: a charge stops growing when its shot would saturate the clip.
## SATURATED when there is no room for even an uncharged shot.
static func max_charge(definition: WeaponDefinition, clips: ThermalClips) -> float:
	if not clips.has_room_for(definition.shot_heat):
		return SATURATED
	var span := definition.full_charge_heat - definition.shot_heat
	if span <= 0.0:
		return 1.0
	return clampf((clips.room() - definition.shot_heat) / span, 0.0, 1.0)


## Degrees from the centre dot that the next shot lands within: tighter while aiming down sights, wider after
## quick follow-up shots (bloom).
static func spread(definition: WeaponDefinition, aiming: bool, bloom: float) -> float:
	return (definition.aim_spread if aiming else definition.hip_spread) + bloom


## The direction of a shot that lands within spread_degrees of the view's forward (-z of view), spread evenly over
## the disc. random_radius and random_angle are random numbers from 0 to 1.
static func shot_direction(view: Basis, spread_degrees: float, random_radius: float, random_angle: float) -> Vector3:
	var off_centre := deg_to_rad(spread_degrees) * sqrt(random_radius)
	var around := random_angle * TAU
	var local := Vector3(sin(off_centre) * cos(around), sin(off_centre) * sin(around), -cos(off_centre))
	return (view * local).normalized()
