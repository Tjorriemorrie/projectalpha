class_name Robot
extends CharacterBody3D
## The brain every robot shares, whatever its body. Every physics frame it looks for the player (the sample points of
## their hitboxes inside its view cone and range, further when the part is lit, with nothing in between), hears noises
## and feels hits, lets its RobotMind decide what it is doing, and fires red lasers once it has locked on. Its first
## shots are wide and walk in the longer it keeps the player in sight, and it aims at where the player was a moment
## ago (AimTrail), so moving draws misses. Its shots heat it up, and at full heat it vents. Its searchlight, eye and voice show its state. Turret and Drone extend it
## for how they move; the robot's numbers come from its EnemyDefinition, set by whoever spawns it (the Wreck). It
## wakes up a physics frame after the end of the frame it was placed in, once the wreck's walls (CSG shapes, which
## rebuild at the end of the frame) are there to block its sight.
##
## A robot scene's root is a Robot on the enemy layer (or on none, for one out of reach), with these unique nodes:
## %Eye (where it sees and fires from, facing −Z, with %Searchlight under it), %Health, %Model, hitboxes anywhere
## below the root, and the sounds %IdleSound, %Voice, %LockTone, %ShotSound, %VentSound, %HitSound, %DestroyedSound
## and %CrashSound, plus %Label for the debug readout.

signal state_changed(previous: RobotMind.State, current: RobotMind.State)
## Emitted for every shot, with what it hit ("nothing" for a miss) and the damage it dealt.
signal fired(target: String, dealt: float)
signal vent_started
## Emitted once, when its health runs out.
signal destroyed

const GROUP := &"robots"
## Physics layers that block its sight: world (1).
const SIGHT_MASK := 0b1
## Physics layers its shots hit: world (1) stops them, hitbox (4) is what they damage.
const SHOT_MASK := 0b1001
## The physics layer of a robot's body (5, enemy), and world (1), which a destroyed robot's wreckage moves to.
const ENEMY_LAYER := 1 << 4
const WORLD_LAYER := 0b1
## Metres a shot carries on past the point it aimed at, so a near miss can still hit what is behind it.
const SHOT_OVERREACH := 1.0
## The colour of robot lasers, as opposed to the player's blue-white.
const LASER_COLOR := Color(1.0, 0.12, 0.08)
## Searchlight and eye colours: cold white idle, amber investigating or searching, red attacking.
const IDLE_COLOR := Color(0.85, 0.92, 1.0)
const ALERT_COLOR := Color(1.0, 0.6, 0.15)
const ATTACK_COLOR := Color(1.0, 0.12, 0.08)
## Names of the model's materials that light up, as named in its Blender script.
const EYE_MATERIAL := "Eye"
const VENTS_MATERIAL := "Vents"
const SPARK_COLOR := Color(1.0, 0.55, 0.2)
## Seconds the wreckage smokes after the robot is destroyed.
const SMOKE_TIME := 20.0

## Set by whoever spawns the robot, before it enters the tree.
@export var definition: EnemyDefinition
## Show the state, lock and heat above the robot, for test levels.
@export var debug_label := false

@export_group("Voice")
## The questioning chirp when it starts investigating.
@export var investigate_chirp: AudioStream
## The alarm when it locks on and attacks.
@export var alarm_chirp: AudioStream
## The falling tone when it loses the player and starts searching.
@export var lost_chirp: AudioStream

@export_group("Salvage")
## Size and centre of the area round its wreckage that the player pries open for its salvage, a little bigger than
## the wreckage so the look ray finds it first.
@export var salvage_box := Vector3(0.8, 0.8, 0.8)
@export var salvage_offset := Vector3.ZERO

@export_group("Glow")
@export var eye_glow: float = 4.0
## Emission energy of the vents at full heat while venting.
@export var vent_glow: float = 6.0
@export var vent_color := Color(1.0, 0.35, 0.08)

var mind: RobotMind
var heat := RobotHeat.new()
var player: Player
## The player's sample points the robot sees this physics frame.
var seen_points := PackedVector3Array()
var shots_fired := 0
## Spread and target choice are random; tests can seed them.
var rng := RandomNumberGenerator.new()

var _cooldown := 0.0
## Seconds it has kept the player in sight since locking on; its spread tightens with it.
var _aim_time := 0.0
var _trail: AimTrail
var _exclude: Array[RID] = []
var _eye_materials: Array[StandardMaterial3D] = []
var _vent_materials: Array[StandardMaterial3D] = []
var _lock_tone_length := 1.0
var _shown_label := ""

@onready var _eye: Node3D = %Eye
@onready var _searchlight: SpotLight3D = %Searchlight
@onready var _health: Health = %Health
@onready var _model: Node3D = %Model
@onready var _idle_sound: AudioStreamPlayer3D = %IdleSound
@onready var _voice: AudioStreamPlayer3D = %Voice
@onready var _lock_tone: AudioStreamPlayer3D = %LockTone
@onready var _shot_sound: AudioStreamPlayer3D = %ShotSound
@onready var _vent_sound: AudioStreamPlayer3D = %VentSound
@onready var _hit_sound: AudioStreamPlayer3D = %HitSound
@onready var _destroyed_sound: AudioStreamPlayer3D = %DestroyedSound
@onready var _crash_sound: AudioStreamPlayer3D = %CrashSound
@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Hearing.LISTENER_GROUP)
	_label.visible = debug_label
	if definition == null:
		Log.error("🤖 Robot has no enemy definition, so it stays switched off: robot=%s, scene=%s" % [
			name, scene_file_path])
		set_physics_process(false)
		return
	player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	mind = RobotMind.new(definition)
	_trail = AimTrail.new(definition.aim_lag)
	mind.state_changed.connect(_on_state_changed)
	mind.lock_started.connect(_on_lock_started)
	mind.lock_dropped.connect(_on_lock_dropped)
	_health.max_health = definition.max_health
	_health.reset()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	for hitbox in get_hitboxes():
		_exclude.append(hitbox.get_rid())
	if _lock_tone.stream:
		_lock_tone_length = _lock_tone.stream.get_length()
	_collect_glow_materials()
	_ready_body()
	_update_tells()
	set_physics_process(false)
	_wake.call_deferred()
	Log.info(("🤖 Robot ready: robot=%s, enemy=%s, position=%s, health=%.0f, sight=%.0f m/%.0f°, "
		+ "dark_sight=%.0f m, player=%s") % [name, definition.id, global_position, _health.health,
		definition.sight_range, definition.sight_angle, definition.dark_sight_range,
		player.name if player else "none"])


## Switches the robot on, a physics frame after the walls built at the end of the frame are in the physics world.
## A robot destroyed before it woke wakes all the same, so its wreckage falls.
func _wake() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		Log.info("🤖 Robot left the level before it woke: robot=%s" % name)
		return
	set_physics_process(true)
	Log.info("🤖 Robot awake: robot=%s, state=%s, position=%s" % [
		name, RobotMind.State.keys()[mind.state], global_position])


## Runs every physics frame, so it only logs when something happens.
func _physics_process(delta: float) -> void:
	if mind.state == RobotMind.State.DESTROYED:
		_update_wreckage(delta)
		return
	_sense(delta)
	if heat.update(delta, definition):
		Log.info("🤖 Vent finished: robot=%s, state=%s" % [name, RobotMind.State.keys()[mind.state]])
	mind.update(delta, not seen_points.is_empty(), _seen_centre(), _is_at_focus())
	_aim_time = _aim_time + delta if mind.is_attacking() else 0.0
	_move(delta)
	_update_fire(delta)
	_update_tells()


## The robot's hitboxes: its eye and its body or housing.
func get_hitboxes() -> Array[Hitbox]:
	var hitboxes: Array[Hitbox] = []
	for node in find_children("*", "Hitbox", true, false):
		hitboxes.append(node as Hitbox)
	return hitboxes


func get_health() -> Health:
	return _health


func get_eye_position() -> Vector3:
	return _eye.global_position


## Where the eye looks: its −Z.
func get_eye_forward() -> Vector3:
	return -_eye.global_basis.z.normalized()


## Degrees from the aimed point its next shot lands within: wide right after locking on, tighter the longer it has
## kept the player in sight.
func aim_spread() -> float:
	return RobotRules.aim_spread(definition, _aim_time)


func is_destroyed() -> bool:
	return mind != null and mind.state == RobotMind.State.DESTROYED


## How many robots in the tree are attacking, for the combat music.
static func count_attacking(tree: SceneTree) -> int:
	var attacking := 0
	for node in tree.get_nodes_in_group(GROUP):
		var robot := node as Robot
		if robot and robot.mind and robot.mind.is_attacking():
			attacking += 1
	return attacking


## A noise heard through Hearing.make_noise(), which logs every noise someone hears. Returns whether the robot
## reacted to it; only then does the robot log it too.
func hear_noise(position: Vector3, loudness: float, kind: StringName, source: Node) -> bool:
	if mind == null:
		Log.warning("🤖 Noise ignored, robot has no enemy definition: robot=%s, kind=%s" % [name, kind])
		return false
	var reacted := mind.hear(position)
	if reacted:
		Log.info("🤖 Reacting to a noise: robot=%s, kind=%s, source=%s, loudness=%.1f m, distance=%.1f m, state=%s" % [
			name, kind, source.name, loudness, global_position.distance_to(position),
			RobotMind.State.keys()[mind.state]])
	return reacted


## Something touched the robot (the player bumping into a drone) from position.
func feel_contact(position: Vector3) -> void:
	if mind == null:
		Log.warning("🤖 Contact ignored, robot has no enemy definition: robot=%s, from=%s" % [name, position])
		return
	var reacted := mind.feel(position)
	Log.info("🤖 Contact: robot=%s, from=%s, reacted=%s, state=%s" % [
		name, position, reacted, RobotMind.State.keys()[mind.state]])


## How each kind moves: the turret turns, the drone flies. Called every physics frame after the mind updated.
func _move(_delta: float) -> void:
	pass


## Whether the body has got to the mind's focus (turned to it, or flown there), so its attention runs out.
func _is_at_focus() -> bool:
	return true


## Called at the end of _ready, for the body's own set-up.
func _ready_body() -> void:
	pass


## Called once when the robot is destroyed: the turret slumps, the drone drops. Call _crash() when it comes to rest.
func _destroy_body() -> void:
	_crash()


## Runs every physics frame after the robot was destroyed.
func _update_wreckage(_delta: float) -> void:
	pass


## The wreckage comes to rest: a crash that other robots hear.
func _crash() -> void:
	_crash_sound.play()
	Hearing.make_noise(self, global_position, definition.crash_loudness, &"robot_crash")
	Log.info("🤖 Wreckage came to rest: robot=%s, position=%s, loudness=%.1f m" % [
		name, global_position, definition.crash_loudness])


## Finds the player's sample points the robot can see: inside its view cone, within its sight range (its dark sight
## range for a part that isn't lit), and with nothing on the world layer in between.
func _sense(delta: float) -> void:
	seen_points.clear()
	if player == null or player.is_dead:
		return
	_trail.record(player.global_position, delta)
	var eye := get_eye_position()
	var forward := get_eye_forward()
	var space := get_world_3d().direct_space_state
	for hitbox in player.get_hitboxes():
		if not hitbox.is_active():
			continue
		var sight_range := RobotRules.sight_range_for(definition, player.is_part_lit(hitbox))
		for point in hitbox.sample_points():
			if not RobotRules.in_view(eye, forward, point, sight_range, definition.sight_angle):
				continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)).is_empty():
				seen_points.append(point)


func _seen_centre() -> Vector3:
	if seen_points.is_empty():
		return mind.focus
	var centre := Vector3.ZERO
	for point in seen_points:
		centre += point
	return centre / seen_points.size()


## Fires at a seen point once locked on, as often as the fire interval and the heat allow, when it faces the target
## closely enough. It aims where that point was the aim lag ago.
func _update_fire(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not mind.is_attacking() or seen_points.is_empty() or not heat.can_fire() or _cooldown > 0.0:
		return
	var target := seen_points[rng.randi() % seen_points.size()] + _trail.offset()
	var eye := get_eye_position()
	if get_eye_forward().angle_to(target - eye) > deg_to_rad(definition.aim_tolerance):
		return
	_fire(eye, target)


## Fires a red laser at a point, spread around it as widely as its aim allows; what it hits first takes the damage.
func _fire(eye: Vector3, aim_point: Vector3) -> void:
	var aim := aim_point - eye
	# Straight down (a turret above the player) needs another up direction to look along.
	var up := Vector3.UP if absf(aim.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var view := Basis.looking_at(aim, up)
	var spread := aim_spread()
	var direction := WeaponRules.shot_direction(view, spread, rng.randf(), rng.randf())
	var end := eye + direction * minf(eye.distance_to(aim_point) + SHOT_OVERREACH, definition.shot_range)
	var query := PhysicsRayQueryParameters3D.create(eye, end, SHOT_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := "nothing"
	var dealt := 0.0
	if not hit.is_empty():
		end = hit["position"]
		var hitbox := hit["collider"] as Hitbox
		target = (hit["collider"] as Node).name if hit["collider"] is Node else "unknown"
		if hitbox:
			dealt = hitbox.take_hit(definition.damage, eye)
		LaserEffects.impact(self, end, hit["normal"], LASER_COLOR, null if hitbox else hit["collider"] as Node3D)
	LaserEffects.beam(self, eye, end, LASER_COLOR)
	_cooldown = definition.fire_interval
	shots_fired += 1
	_shot_sound.pitch_scale = rng.randf_range(0.95, 1.05)
	_shot_sound.play()
	var vents := heat.add_shot(definition)
	Log.info(("🤖 Fired: robot=%s, target=%s, dealt=%.1f, distance=%.1f m, spread=%.1f°, lag=%.2f m, heat=%.0f%%, "
		+ "shots=%d") % [name, target, dealt, eye.distance_to(end), spread, _trail.offset().length(),
		heat.heat * 100.0, shots_fired])
	fired.emit(target, dealt)
	Hearing.make_noise(self, eye, definition.shot_loudness, &"robot_shot")
	if vents:
		_vent_sound.play()
		Log.info("🤖 Venting: robot=%s, shots=%d, vent_time=%.1f s" % [name, shots_fired, definition.vent_time])
		vent_started.emit()


func _on_state_changed(previous: RobotMind.State, current: RobotMind.State) -> void:
	var chirp: AudioStream = null
	if current == RobotMind.State.INVESTIGATING:
		chirp = investigate_chirp
	elif current == RobotMind.State.ATTACKING:
		chirp = alarm_chirp
		_lock_tone.stop()
	elif previous == RobotMind.State.ATTACKING and current == RobotMind.State.SEARCHING:
		chirp = lost_chirp
	if chirp:
		_voice.stream = chirp
		_voice.play()
	Log.info("🤖 State changed: robot=%s, %s -> %s, focus=%s, position=%s, health=%.0f" % [
		name, RobotMind.State.keys()[previous], RobotMind.State.keys()[current], mind.focus, global_position,
		_health.health])
	state_changed.emit(previous, current)


## The rising lock-on tone plays faster and higher for a quicker lock.
func _on_lock_started(lock_time: float) -> void:
	_lock_tone.pitch_scale = clampf(_lock_tone_length / maxf(lock_time, 0.01), 0.5, 4.0)
	_lock_tone.play()
	Log.info("🤖 Locking on: robot=%s, lock_time=%.2f s, state=%s, seen_points=%d, distance=%.1f m" % [
		name, lock_time, RobotMind.State.keys()[mind.state], seen_points.size(),
		global_position.distance_to(player.global_position) if player else 0.0])


func _on_lock_dropped() -> void:
	_lock_tone.stop()
	Log.info("🤖 Lock dropped, lost sight: robot=%s, focus=%s" % [name, mind.focus])


func _on_damaged(amount: float, source_position: Vector3, part: Hitbox.Part) -> void:
	_hit_sound.pitch_scale = rng.randf_range(0.9, 1.1)
	_hit_sound.play()
	var reacted := mind.feel(source_position)
	Log.info("🤖 Hit: robot=%s, part=%s, damage=%.1f, health=%.1f, reacted=%s, source=%s" % [
		name, Hitbox.Part.keys()[part], amount, _health.health, reacted, source_position])


## Shuts down for good: the eye and searchlight go dark, it whines, sparks and smokes, and its wreckage stays,
## solid, on the world layer.
func _on_died() -> void:
	mind.destroy()
	remove_from_group(Hearing.LISTENER_GROUP)
	collision_layer = WORLD_LAYER
	for hitbox in get_hitboxes():
		hitbox.set_active(false)
	_idle_sound.stop()
	_lock_tone.stop()
	_destroyed_sound.play()
	_searchlight.visible = false
	_set_glow(_eye_materials, Color.BLACK, 0.0)
	_set_glow(_vent_materials, vent_color, 0.0)
	_label.visible = false
	LaserEffects.impact(self, get_eye_position(), Vector3.UP, SPARK_COLOR, null)
	_start_smoke()
	_add_salvage()
	Log.info("🤖 Destroyed: robot=%s, enemy=%s, position=%s, shots_fired=%d" % [
		name, definition.id, global_position, shots_fired])
	_destroy_body()
	destroyed.emit()


## The wreckage becomes loot: an area round it that the player pries open, holding the salvage from its definition.
func get_salvage() -> Lootable:
	return get_node_or_null("Salvage") as Lootable


func _add_salvage() -> void:
	var salvage := Lootable.new()
	salvage.name = "Salvage"
	var box := BoxShape3D.new()
	box.size = salvage_box
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = salvage_offset
	salvage.add_child(shape)
	add_child(salvage)
	salvage.setup("%s wreckage" % definition.display_name, definition.salvage_grid)
	var parts: Array[ItemDefinition] = []
	for id in definition.salvage:
		var part := ContentRegistry.get_definition(id) as ItemDefinition
		if part == null:
			Log.error("🤖 Salvage is not a registered item: robot=%s, item=%s" % [name, id])
			continue
		parts.append(part)
	var left_out := salvage.fill(parts)
	if not left_out.is_empty():
		Log.error("🤖 Salvage doesn't fit the wreckage's grid: robot=%s, grid=%s, left_out=%d" % [
			name, definition.salvage_grid, left_out.size()])
	Log.info("🤖 Wreckage holds salvage: robot=%s, parts=%d, value=%d" % [name, salvage.grid.items.size(),
		salvage.grid.value()])


## The searchlight and eye take the state's colour, turning red as a lock-on builds; the vents glow while venting.
## Runs every physics frame; the debug label only changes when its text does.
func _update_tells() -> void:
	var color := _state_color()
	_searchlight.light_color = color
	_set_glow(_eye_materials, color, eye_glow)
	_set_glow(_vent_materials, vent_color, vent_glow * heat.heat if heat.is_venting else 0.0)
	if debug_label:
		var text := "%s\n%s\nlock %d%%  heat %d%%%s" % [name, RobotMind.State.keys()[mind.state].to_lower(),
			roundi(mind.lock * 100.0) if mind.is_locking else (100 if mind.is_attacking() else 0),
			roundi(heat.heat * 100.0), "  VENT" if heat.is_venting else ""]
		if text != _shown_label:
			_shown_label = text
			_label.text = text
			_label.modulate = color


func _state_color() -> Color:
	var base := IDLE_COLOR
	match mind.state:
		RobotMind.State.INVESTIGATING, RobotMind.State.SEARCHING:
			base = ALERT_COLOR
		RobotMind.State.ATTACKING:
			base = ATTACK_COLOR
	if mind.is_locking:
		return base.lerp(ATTACK_COLOR, mind.lock)
	return base


## Each robot gets its own copies of the materials that light up, so robots in different states glow differently.
func _collect_glow_materials() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if source == null or not source.resource_name in [EYE_MATERIAL, VENTS_MATERIAL]:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.emission_enabled = true
			mesh_instance.set_surface_override_material(surface, material)
			if source.resource_name == EYE_MATERIAL:
				_eye_materials.append(material)
			else:
				_vent_materials.append(material)


static func _set_glow(materials: Array[StandardMaterial3D], color: Color, energy: float) -> void:
	for material in materials:
		material.emission = color
		material.emission_energy_multiplier = energy


## Grey smoke rising from the wreckage for a while.
func _start_smoke() -> void:
	var puff := QuadMesh.new()
	puff.size = Vector2(0.25, 0.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puff_texture()
	puff.material = material
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.mesh = puff
	smoke.amount = 24
	smoke.lifetime = 2.5
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 0.2
	smoke.initial_velocity_max = 0.5
	smoke.gravity = Vector3(0.0, 0.15, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.25, 0.25, 0.27, 0.5))
	fade.set_color(1, Color(0.3, 0.3, 0.32, 0.0))
	smoke.color_ramp = fade
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eye.add_child(smoke)
	smoke.emitting = true
	# A tween of the smoke's own, so it goes with the smoke if the level unloads first.
	smoke.create_tween().tween_property(smoke, "emitting", false, 0.0).set_delay(SMOKE_TIME)


## A soft round puff, so the smoke isn't made of squares.
static func _puff_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
