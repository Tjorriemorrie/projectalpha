class_name Weapon
extends Node3D
## The weapon the player holds, under the player's camera so shots go where the player looks. It reads the shoot,
## aim and reload actions, charges and fires laser shots, reloads thermal clips and drives the viewmodel. The player
## equips it with a WeaponDefinition and the clips it carries, and calls physics_update() every physics frame with
## what the player is doing. WeaponRules makes the decisions; this applies them.

## Emitted for every shot, with its charge and how many degrees it kicks the view up.
signal fired(charge: float, kick_degrees: float)
signal reload_started
signal reload_finished

## Physics layers a shot hits: world (1) stops it, hitbox (4) is what it damages.
const SHOT_MASK := 0b1001
## Seconds sprint stays blocked after a shot.
const SPRINT_BLOCK_AFTER_SHOT := 0.5
## Seconds a trigger pull waits for the weapon to be ready (raised after a sprint, or the next shot allowed by the
## fire rate) before it is dropped.
const TRIGGER_WAIT := 0.3
## The colour of the player's lasers: cold blue-white, so they can't be mistaken for the robots' red ones.
const LASER_COLOR := Color(0.62, 0.82, 1.0)

var definition: WeaponDefinition
var clips: ThermalClips
## The charge of the shot being held, from 0 to 1, or -1 when the trigger isn't charging.
var charge := -1.0
var is_reloading := false
## Whether the weapon aims down sights: aim is held and nothing stops it (a reload, a sprint).
var is_aiming := false
## How far the weapon is raised: 0 is lowered for a sprint, 1 is up and ready to fire.
var raise := 1.0
var shots_fired := 0
## Spread is random; tests can seed it.
var rng := RandomNumberGenerator.new()

var _viewmodel: WeaponViewmodel
var _exclude: Array[RID] = []
var _enabled := true
var _cooldown := 0.0
var _since_shot := INF
var _held_time := 0.0
## Seconds a trigger pull still waits for the weapon to be ready; negative when no pull is waiting.
var _trigger_wait := -1.0
## The click that captured the mouse again must not fire, so the trigger is ignored until it is released.
var _trigger_suppressed := false
var _reload_left := 0.0
var _bloom := 0.0


## Arms the weapon: loads its viewmodel, takes the clips the player carries, and the RIDs its shots must pass
## through (the shooter's own hitboxes).
func equip(weapon: WeaponDefinition, carried_clips: ThermalClips, exclude: Array[RID]) -> void:
	definition = weapon
	clips = carried_clips
	_exclude = exclude
	var scene := load(weapon.get_viewmodel_path()) as PackedScene
	_viewmodel = scene.instantiate() as WeaponViewmodel
	if _viewmodel == null:
		Log.error("🔫 Weapon viewmodel root is not a WeaponViewmodel: weapon=%s, viewmodel=%s" % [
			weapon.id, weapon.viewmodel])
		definition = null
		return
	add_child(_viewmodel)
	Log.info("🔫 Weapon equipped: weapon=%s, damage=%.1f, heat=%.0f-%.0f%%, reload=%.1f s, fresh=%d, spent=%d" % [
		weapon.id, weapon.damage, weapon.shot_heat * 100.0, weapon.full_charge_heat * 100.0, weapon.reload_time,
		clips.fresh, clips.spent])


func is_equipped() -> bool:
	return definition != null


## Runs the weapon for one physics frame. can_shoot is false while the player can't fire (peeking); lowered is true
## while sprinting or sorting the inventory. has_input is false while the inventory is open: the shoot, aim and
## reload actions are ignored (they work the grids then), but a reload under way still finishes. Runs every physics
## frame, so it only logs when something happens.
func physics_update(delta: float, can_shoot: bool, lowered: bool, has_input: bool = true) -> void:
	if not is_equipped() or not _enabled:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since_shot += delta
	_bloom = move_toward(_bloom, 0.0, definition.bloom_recovery * delta)
	raise = move_toward(raise, 0.0 if lowered else 1.0, delta / maxf(definition.raise_time, 0.001))
	_update_reload(delta)
	if not has_input:
		_ignore_input()
		_viewmodel.set_state(raise, is_aiming, charge, reload_progress(), clips.heat)
		return
	is_aiming = Input.is_action_pressed("aim") and not is_reloading and not lowered
	_update_trigger(delta, can_shoot)
	if Input.is_action_just_pressed("reload"):
		start_reload()
	_viewmodel.set_state(raise, is_aiming, charge, reload_progress(), clips.heat)


## Whether the weapon keeps the player from sprinting: holding the trigger or aim, charging, reloading, or having
## just fired. Pulling the trigger mid-sprint therefore ends the sprint.
func blocks_sprint() -> bool:
	if not is_equipped() or not _enabled:
		return false
	var trigger_held := Input.is_action_pressed("shoot") and not _trigger_suppressed
	return trigger_held or Input.is_action_pressed("aim") or charge >= 0.0 or is_reloading \
			or _since_shot < SPRINT_BLOCK_AFTER_SHOT


## Starts a reload, if there is a fresh clip and the loaded one has been used. Returns whether it started.
func start_reload() -> bool:
	if not is_equipped() or not _enabled or is_reloading or charge >= 0.0:
		Log.info("🔫 Reload not started: equipped=%s, enabled=%s, reloading=%s, charging=%s" % [
			is_equipped(), _enabled, is_reloading, charge >= 0.0])
		return false
	if not clips.can_reload():
		Log.info(("🔫 Reload not started: fresh=%d, packed=%d, heat=%.0f%% (needs a fresh clip in the pockets and "
			+ "a used one loaded)") % [clips.fresh, clips.packed, clips.heat * 100.0])
		return false
	var cell := clips.take_fresh()
	is_reloading = true
	_reload_left = definition.reload_time
	_trigger_wait = -1.0
	Log.info("🔫 Reload started: heat=%.0f%% (wasted), pocket_cell=%s, fresh=%d, packed=%d, spent=%d, time=%.1f s" % [
		clips.heat * 100.0, cell, clips.fresh, clips.packed, clips.spent, definition.reload_time])
	reload_started.emit()
	return true


## How far the reload has got, from 0 to 1, or -1 when not reloading.
func reload_progress() -> float:
	if not is_reloading:
		return -1.0
	return clampf(1.0 - _reload_left / maxf(definition.reload_time, 0.001), 0.0, 1.0)


## Whether the loaded clip can't take a fully charged shot any more, for the HUD's warning.
func is_clip_low() -> bool:
	return is_equipped() and not clips.has_room_for(definition.full_charge_heat)


## Ignores the trigger until it is released, e.g. for the click that captured the mouse again.
func suppress_trigger() -> void:
	_trigger_suppressed = true


## Stops the weapon for good when the player dies: the charge is dropped with no heat used, and a reload in
## progress never finishes.
func disable() -> void:
	if not _enabled:
		return
	_enabled = false
	var was_charging := charge >= 0.0
	charge = -1.0
	is_reloading = false
	is_aiming = false
	_trigger_wait = -1.0
	if _viewmodel:
		_viewmodel.set_state(0.0, false, -1.0, -1.0, clips.heat if clips else 0.0)
		_viewmodel.visible = false
	Log.info("🔫 Weapon disabled: charge_dropped=%s, shots_fired=%d, heat=%.0f%%, fresh=%d, spent=%d" % [
		was_charging, shots_fired, clips.heat * 100.0 if clips else 0.0, clips.fresh if clips else 0,
		clips.spent if clips else 0])


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	_reload_left -= delta
	if _reload_left > 0.0:
		return
	is_reloading = false
	clips.swap()
	Log.info("🔫 Reload finished: fresh=%d, packed=%d, spent=%d" % [clips.fresh, clips.packed, clips.spent])
	reload_finished.emit()


## While the inventory is open the buttons work the grids: a charge is dropped with no heat used, aiming stops, and
## the trigger is ignored until it is released after the inventory closes. Runs every physics frame while it is
## open, so it only logs when it drops a charge or a waiting pull.
func _ignore_input() -> void:
	if charge >= 0.0 or _trigger_wait >= 0.0:
		Log.info("🔫 Charge and trigger dropped, inventory open: charge=%.2f, pull_waiting=%s" % [
			charge, _trigger_wait >= 0.0])
	charge = -1.0
	_trigger_wait = -1.0
	is_aiming = false
	_trigger_suppressed = true


## Holding the trigger charges the shot and releasing it fires. A pull waits briefly while the weapon is being
## raised or the fire rate holds the next shot back; a quick click released in that time still fires, uncharged.
func _update_trigger(delta: float, can_shoot: bool) -> void:
	var pressed := Input.is_action_pressed("shoot")
	if _trigger_suppressed:
		_trigger_suppressed = pressed
		return
	if charge >= 0.0:
		_update_charge(delta, can_shoot, pressed)
		return
	if Input.is_action_just_pressed("shoot"):
		_on_trigger_pulled(can_shoot)
	if _trigger_wait < 0.0:
		return
	if _ready_to_fire(can_shoot):
		_trigger_wait = -1.0
		if pressed:
			charge = 0.0
			_held_time = 0.0
		else:
			_fire(0.0)
		return
	_trigger_wait -= delta
	if _trigger_wait < 0.0:
		Log.info("🔫 Trigger pull dropped, weapon not ready in time: raise=%.2f, cooldown=%.2f s, can_shoot=%s" % [
			raise, _cooldown, can_shoot])


func _on_trigger_pulled(can_shoot: bool) -> void:
	if not can_shoot or is_reloading:
		Log.info("🔫 Trigger ignored: can_shoot=%s, reloading=%s" % [can_shoot, is_reloading])
		return
	if WeaponRules.max_charge(definition, clips) == WeaponRules.SATURATED:
		_viewmodel.play_dry_click()
		Log.info("🔫 Dry click, clip saturated: heat=%.0f%%, fresh=%d, spent=%d" % [
			clips.heat * 100.0, clips.fresh, clips.spent])
		return
	_trigger_wait = maxf(TRIGGER_WAIT, definition.raise_time + 0.05)


## A charge is kept for as long as the trigger is held, also through a peek, so the player can charge behind cover,
## peek and aim out to fire. Released while the player can shoot it fires; released during a peek, which can't
## fire, it is dropped with no heat used.
func _update_charge(delta: float, can_shoot: bool, pressed: bool) -> void:
	if pressed:
		_held_time += delta
		charge = minf(WeaponRules.charge_for_hold(definition, _held_time), WeaponRules.max_charge(definition, clips))
		return
	if not can_shoot:
		Log.info("🔫 Charge dropped, released while unable to shoot: charge=%.2f, held=%.2f s" % [charge, _held_time])
		charge = -1.0
		return
	_fire(charge)


func _ready_to_fire(can_shoot: bool) -> bool:
	return can_shoot and not is_reloading and raise >= 1.0 and _cooldown <= 0.0 \
			and clips.has_room_for(definition.shot_heat)


## Fires a shot straight from the eye along the view, spread around the centre dot, and draws the beam from the
## muzzle to where it hit.
func _fire(shot_charge: float) -> void:
	var damage := WeaponRules.shot_damage(definition, shot_charge)
	var heat := WeaponRules.shot_heat(definition, shot_charge)
	var kick := WeaponRules.shot_kick(definition, shot_charge)
	var spread := WeaponRules.spread(definition, is_aiming, _bloom)
	var origin := global_position
	var direction := WeaponRules.shot_direction(global_basis.orthonormalized(), spread, rng.randf(), rng.randf())
	var end := origin + direction * definition.shot_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, SHOT_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := "nothing"
	var dealt := 0.0
	if not hit.is_empty():
		end = hit["position"]
		var hitbox := hit["collider"] as Hitbox
		target = (hit["collider"] as Node).name if hit["collider"] is Node else "unknown"
		if hitbox:
			dealt = hitbox.take_hit(damage, origin)
		LaserEffects.impact(self, end, hit["normal"], LASER_COLOR, null if hitbox else hit["collider"] as Node3D)
	LaserEffects.beam(self, _viewmodel.muzzle_position(), end, LASER_COLOR)
	var heat_before := clips.heat
	clips.add_heat(heat)
	charge = -1.0
	_cooldown = definition.fire_interval
	_since_shot = 0.0
	_bloom = minf(_bloom + definition.bloom_per_shot, definition.max_bloom)
	shots_fired += 1
	_viewmodel.play_shot(shot_charge)
	Log.info(("🔫 Fired: charge=%.2f, damage=%.1f, dealt=%.1f, target=%s, distance=%.1f m, spread=%.1f°, "
		+ "aiming=%s, heat=%.0f%%->%.0f%%") % [shot_charge, damage, dealt, target, origin.distance_to(end), spread,
		is_aiming, heat_before * 100.0, clips.heat * 100.0])
	fired.emit(shot_charge, kick)
	Hearing.make_noise(self, origin, WeaponRules.shot_loudness(definition, shot_charge), &"shot")
