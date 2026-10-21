class_name LightLevel
extends RefCounted
## How much light reaches a point, so enemies can see a lit player from further away than one in the dark. Lights
## that count join the sight_lights group: ceiling and emergency lamps, the pistol's muzzle flash, robot searchlights.
## The estimate mirrors how Godot attenuates omni and spot lights (distance, range and the spot cone), weighted by
## how bright the light's colour looks, and a ray against world stops it, as a shadow would.

const GROUP := &"sight_lights"
## Light at or above this counts as lit: about what reaches the floor at the edge of a ceiling lamp's pool.
const LIT_THRESHOLD := 0.15
## Physics layers that cast the shadows: world (1).
const SHADOW_MASK := 0b1
## Metres a directional light (a sun) is checked for, towards the light.
const DIRECTIONAL_REACH := 100.0


## Whether the light reaching point from the lights in the scene tree counts as lit.
static func is_lit(space: PhysicsDirectSpaceState3D, tree: SceneTree, point: Vector3) -> bool:
	return light_at(space, tree, point) >= LIT_THRESHOLD


## The light reaching point from every visible light in the sight_lights group, with shadows. It stops adding up
## once the point counts as lit, so a well lit room costs few rays.
static func light_at(space: PhysicsDirectSpaceState3D, tree: SceneTree, point: Vector3) -> float:
	var total := 0.0
	for node: Node in tree.get_nodes_in_group(GROUP):
		var light := node as Light3D
		if light == null or not light.is_visible_in_tree():
			continue
		var amount := light_from(light, point)
		if amount <= 0.0 or not _reaches(space, light, point):
			continue
		total += amount
		if total >= LIT_THRESHOLD:
			break
	return total


## The light one lamp sends to point, ignoring anything in between: its energy, how bright its colour looks, its
## falloff over distance and, for a spot light, its cone.
static func light_from(light: Light3D, point: Vector3) -> float:
	var brightness := light.light_energy * light.light_color.get_luminance()
	if brightness <= 0.0:
		return 0.0
	if light is DirectionalLight3D:
		return brightness
	var to_point := point - light.global_position
	var distance := to_point.length()
	if light is OmniLight3D:
		var omni := light as OmniLight3D
		return brightness * attenuation(distance, omni.omni_range, omni.omni_attenuation)
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		var direction := -spot.global_basis.z.normalized()
		var along := direction.dot(to_point / maxf(distance, 0.0001))
		return brightness * attenuation(distance, spot.spot_range, spot.spot_attenuation) \
				* cone(along, spot.spot_angle, spot.spot_angle_attenuation)
	return 0.0


## Godot's light falloff: a window that reaches zero at the light's range, times the distance to the power of minus
## the light's attenuation.
static func attenuation(distance: float, light_range: float, decay: float) -> float:
	if distance >= light_range:
		return 0.0
	var window := pow(distance / light_range, 4.0)
	window = maxf(1.0 - window, 0.0)
	return window * window * pow(maxf(distance, 0.0001), -decay)


## Godot's spot cone: 1 along the spot's axis, fading to 0 at its edge. along is the cosine of the angle between the
## spot's axis and the point; angle is the spot's half-angle in degrees.
static func cone(along: float, angle: float, angle_attenuation: float) -> float:
	var edge := cos(deg_to_rad(angle))
	if along <= edge:
		return 0.0
	var rim := maxf(0.0001, (1.0 - along) / maxf(1.0 - edge, 0.0001))
	return maxf(1.0 - pow(rim, angle_attenuation), 0.0)


## Whether nothing on the world layer stands between the light and point.
static func _reaches(space: PhysicsDirectSpaceState3D, light: Light3D, point: Vector3) -> bool:
	var from := light.global_position
	if light is DirectionalLight3D:
		from = point + light.global_basis.z.normalized() * DIRECTIONAL_REACH
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, SHADOW_MASK)).is_empty()
