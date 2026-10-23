class_name Player
extends CharacterBody3D
## First-person player controller: walking, sprinting, crouching, mouse look, stepping onto low obstacles,
## riding elevators, the flashlight, using interactables by looking at them (pressing interact, or holding it to pry
## a container open), peeking and aiming out of cover, the hitboxes enemies can hit, the weapon (aim down sights
## zoom, kick) and health (hit feedback, death), the inventory (weapon slot, pockets and backpack, searching
## containers, picking up and dropping items), trading at the hub from the ship, and what enemies sense of the player:
## footsteps they can hear, and which parts are lit so they can be seen from afar. MovementRules and PeekRules make the
## decisions; this script applies them to the body, head and camera. The Weapon fires and reloads the gun in the weapon
## slot (none: unarmed), Health counts the damage, the HUD's InventoryScreen moves the items and its TraderScreen
## trades. While either screen is open the player stands still: no moving, looking, peeking or shooting.
## A run ends by dying or by leaving through an airlock (extracting from a wreck, or boarding one from the ship): the
## player stops, the screen fades to black, and the GameSession takes what they carry on to the next scene. The
## player takes it over in turn when it is ready; with none, the first clone of a new game builds the basic kit and a
## clone after a death starts empty-handed.

## Emitted when the movement state changes, so systems such as noise and footsteps can react to it.
signal movement_state_changed(previous: MovementRules.State, current: MovementRules.State)
## Emitted when the player starts or stops peeking or aiming out of cover.
signal peek_state_changed(previous: PeekRules.State, current: PeekRules.State)
## Emitted once, when the player dies. The run ends, and a new clone wakes up on the ship.
signal died

## Physics layers the look ray hits: world (1) blocks it, interactable (3) is what it looks for.
const INTERACT_MASK := 0b101
## Physics layer that stops the head while peeking: world (1).
const HEAD_MASK := 0b1
## The group enemies find the player by.
const GROUP := &"player"

## The camera stops this many degrees short of looking straight up or down.
const PITCH_LIMIT_DEGREES := 89.0
## Aspect ratio at which horizontal_fov applies; wider screens see more at the sides.
const REFERENCE_ASPECT := 16.0 / 9.0
## Smallest height change that counts as a step rather than floor unevenness.
const MIN_STEP_HEIGHT := 0.01
## Extra rise when testing a step, so obstacles exactly max_step_height tall still fit.
const STEP_CLEARANCE := 0.02
## How far ahead to look for floor when stepping up or down, so the body lands clear of the obstacle's edge
## (Jolt rounds collision shape edges slightly) even when this frame's motion is only a few millimetres.
const STEP_PROBE_DISTANCE := 0.05
## Seconds the camera takes to catch up with the body after stepping up or down.
const STEP_SMOOTHING_TIME := 0.12
## Seconds the head bob takes to fade in or out.
const BOB_FADE_TIME := 0.2
## The body hitbox stops this far below the eyes, where the head hitbox takes over.
const NECK_LENGTH := 0.1
## The arm hitbox starts this far below the eyes and reaches forward along the view.
const SHOULDER_DROP := 0.2
## Seconds the camera takes to move between the hip and aiming down sights zoom.
const ZOOM_TIME := 0.15
## A kick or flinch settles to 5% of its size over the weapon's kick recovery time.
const KICK_SETTLE := 3.0
## On death the view slumps to the floor over DEATH_SLUMP_TIME seconds: the eyes drop to DEATH_EYE_HEIGHT, and
## the view rolls by DEATH_ROLL degrees and tips to DEATH_PITCH degrees.
const DEATH_SLUMP_TIME := 1.2
const DEATH_EYE_HEIGHT := 0.3
const DEATH_ROLL := 70.0
const DEATH_PITCH := -20.0
## Seconds after death before the screen starts fading to black, and how long the fade takes.
const DEATH_FADE_DELAY := 0.6
const DEATH_FADE_TIME := 2.5
## Metres to either side that a dropped item may land.
const DROP_SCATTER := 0.2

@export_group("Speeds")
@export var walk_speed: float = 1.5
@export var sprint_speed: float = 3.0
@export var crouch_speed: float = 1.0
## Seconds to reach the target speed.
@export var acceleration_time: float = 0.15
## Seconds to slide to a stop from walk speed; stopping from a sprint takes proportionally longer.
@export var deceleration_time: float = 0.2

@export_group("Body")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var stand_eye_height: float = 1.65
@export var crouch_eye_height: float = 0.85
## Seconds the camera takes to move between standing and crouched eye height.
@export var crouch_transition_time: float = 0.2
## Tallest obstacle the player steps onto without jumping.
@export var max_step_height: float = 0.35

@export_group("Camera")
## Degrees the view turns per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.1
## Horizontal field of view in degrees at 16:9.
@export var horizontal_fov: float = 90.0
## Turn off for players who get motion sick.
@export var head_bob_enabled: bool = true
## Metres the camera bobs up and down while walking.
@export var walk_bob_amplitude: float = 0.013
## Metres the camera bobs up and down while sprinting.
@export var sprint_bob_amplitude: float = 0.017
## Metres travelled per full bob cycle (two footsteps).
@export var bob_stride_length: float = 1.6

@export_group("Interaction")
## Metres from the camera within which the player can use an interactable.
@export var interact_reach: float = 2.0

@export_group("Peek")
## Metres the head reaches to either side, up and down while peeking.
@export var peek_side_reach: float = 0.4
@export var peek_up_reach: float = 0.35
@export var peek_down_reach: float = 0.15
## Metres the head reaches to either side and up while aiming out of cover; down stays at peek_down_reach.
@export var aim_out_side_reach: float = 0.6
@export var aim_out_up_reach: float = 0.5
## Degrees the view tilts at a full sideways peek; 0 turns the tilt off.
@export var peek_tilt: float = 8.0
## Metres the head moves per pixel of mouse movement while peeking.
@export var peek_sensitivity: float = 0.0015
## Metres per second the head moves towards where the peek wants it.
@export var head_speed: float = 3.0
## Radius of the sphere that stops the head at walls.
@export var head_radius: float = 0.15

@export_group("Combat")
## The gun in the basic kit, by content ID; it comes with a fresh clip loaded.
@export var starting_weapon_id := "base:laser_pistol"
## At or below this much health one more body hit could kill, so the screen edges stay faintly red.
@export var critical_health: float = 10.0
## Degrees the view flinches when hit.
@export var flinch_degrees: float = 1.5
## Seconds from death until the run summary shows on the black screen.
@export var death_summary_delay: float = 4.0
## Holstered on the ship: the pistol is lowered and can't aim or fire, but reloads still work.
@export var holstered := false
## At home on the ship the HUD shows the bitcoin in the wallet, the hydrogen and antimatter in the tanks and the day;
## on a wreck it doesn't.
@export var shows_wallet := false

@export_group("Travel")
## Seconds the screen takes to fade to black when leaving through an airlock, and to fade in on arriving.
@export var leave_fade_time: float = 1.2
@export var arrive_fade_time: float = 1.5
## Docking clunks and hiss, playing through the fade when the player boards or extracts.
@export var dock_sound: AudioStream
## Seconds the screen takes to fade to black for a jump to another system, and to fade back in at the next hub; the
## jump drive's sound plays through both.
@export var jump_fade_time: float = 0.9
@export var jump_sound: AudioStream = preload("res://assets/audio/ship/jump.wav")

@export_group("Inventory")
## Cells of the pockets, for things at hand (a reload takes its clips from there), of the backpack, and of the weapon
## slot, which holds one gun.
@export var pocket_size := Vector2i(4, 1)
@export var backpack_size := Vector2i(6, 5)
@export var weapon_slot_size := Vector2i(3, 2)
## Fresh thermal clips in the basic kit besides the loaded one, in the pockets and in the backpack: the first clone of
## a new game wakes with it, and so does a player in a level started on its own. A player arriving from another scene
## carries on with what they had instead, and a clone after a death wakes empty-handed. Test levels pack two in the
## backpack.
@export var starting_pocket_clips: int = 2
@export var starting_backpack_clips: int = 0
## Whether dropped items lie on the floor here. There is no floor on the ship: nothing can be dropped there.
@export var has_floor := true
## Metres an item dropped on the floor carries as noise, so enemies hear it clatter.
@export var drop_loudness: float = 3.0
## Metres in front of the feet where dropped items land.
@export var drop_distance: float = 0.5
## Metres from the feet within which dropped items in sight show on the inventory screen's floor.
@export var floor_reach: float = 1.5
@export var drop_sound: AudioStream = preload("res://assets/audio/loot/item_drop.wav")

@export_group("Footsteps")
## Metres a footstep carries as noise, so enemies hear it: sprinting is loud, walking quieter, crouching quietest.
@export var sprint_step_loudness: float = 10.0
@export var walk_step_loudness: float = 4.0
@export var crouch_step_loudness: float = 1.5
@export var sprint_step_sound: AudioStream
@export var walk_step_sound: AudioStream
@export var crouch_step_sound: AudioStream

var movement_state: MovementRules.State = MovementRules.State.IDLE
var is_crouched: bool = false
## The interactable the player is looking at within reach, or null.
var interact_target: Interactable
## Whether the player is peeking or aiming out of cover. Weapons (005) read it, because a peek can't shoot.
var peek_state: PeekRules.State = PeekRules.State.NONE
## Where the head is relative to its normal position, in metres in the body's frame (x right, y up).
var head_offset := Vector2.ZERO
## The thermal clips the player carries for the gun in hand; the weapon fires from them. The clips themselves are items
## in the inventory, and the loaded clip's heat lives on the gun.
var clips: ThermalClips
## What the player carries: the weapon slot, the pockets and the backpack.
var inventory: Inventory
var is_dead := false
## Leaving through an airlock: the player stands still and can't be hit while the screen fades to black.
var is_leaving := false
## How the run ended, once its summary shows; null before.
var run_summary: RunSummary

var _crouch_toggled := false
var _stand_blocked := false
var _yaw := 0.0
var _pitch := 0.0
var _eye_height := 0.0
var _step_offset := 0.0
var _bob_phase := 0.0
var _bob_amplitude := 0.0
var _body_shape: CylinderShape3D
var _shown_prompt := ""
var _shown_hold := false
## The interactable interact is being held on, and for how many seconds; -1 when nothing is held.
var _held_target: Interactable
var _hold := -1.0
## Where the mouse has moved the peek to; the head follows it unless a wall is in the way.
var _peek_target := Vector2.ZERO
## head_offset at the previous physics frame, so the camera can interpolate the head between frames.
var _head_offset_previous := Vector2.ZERO
var _head_query: PhysicsShapeQueryParameters3D
var _body_hitbox_shape: CylinderShape3D
var _arm_length := 0.0
## Vertical field of view without zoom, in degrees.
var _base_fov := 0.0
## 0 at the hip, 1 fully zoomed in for aiming down sights.
var _zoom := 0.0
## How far a shot's kick or a hit's flinch has turned the view, in radians (x up, y left); it settles back to zero.
var _view_kick := Vector2.ZERO
var _death_time := 0.0
## Metres walked since the last footstep.
var _step_distance := 0.0
## Which hitboxes are lit, worked out at most once per physics frame (_lit_frame).
var _lit_parts := {}
var _lit_frame := -1
## The run summary is showing, and interact goes on to the ship.
var _awaiting_continue := false
## Whether a jump to another system is under way, between the fade to black and the fade back in.
var _jumping := false

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _camera: Camera3D = $Camera3D
@onready var _flashlight: SpotLight3D = $Camera3D/Flashlight
@onready var _hud: Hud = $Hud
@onready var _head_hitbox: Hitbox = $Hitboxes/Head
@onready var _body_hitbox: Hitbox = $Hitboxes/Body
@onready var _arm_hitbox: Hitbox = $Hitboxes/Arm
@onready var _health: Health = $Health
@onready var _weapon: Weapon = $Camera3D/Weapon
@onready var _hit_sound: AudioStreamPlayer = $HitSound
@onready var _footstep_sound: AudioStreamPlayer = $FootstepSound
@onready var _inventory_screen: InventoryScreen = _hud.get_inventory_screen()
@onready var _trader_screen: TraderScreen = _hud.get_trader_screen()
@onready var _system_map: SystemMapScreen = _hud.get_system_map_screen()
@onready var _star_map: StarMapScreen = _hud.get_star_map_screen()


func _ready() -> void:
	add_to_group(GROUP)
	# Each player gets its own shape, because crouching changes its height.
	_body_shape = (_collision_shape.shape as CylinderShape3D).duplicate()
	_collision_shape.shape = _body_shape
	_apply_body_height(stand_height)
	_eye_height = stand_eye_height
	_yaw = rotation.y
	floor_snap_length = max_step_height
	_base_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_fov) / 2.0) / REFERENCE_ASPECT))
	_camera.fov = _base_fov
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_setup_head()
	_setup_combat()
	_inventory_screen.dropped_on_floor.connect(_on_dropped_on_floor)
	_inventory_screen.taken_from_floor.connect(_on_taken_from_floor)
	_star_map.jump_confirmed.connect(jump_to)
	if shows_wallet:
		_hud.show_wallet(GameSession.bitcoin, GameSession.hydrogen, GameSession.day)
		GameSession.bitcoin_changed.connect(_hud.set_wallet)
		GameSession.hydrogen_changed.connect(_hud.set_hydrogen)
		GameSession.antimatter_changed.connect(_hud.set_antimatter)
		GameSession.day_changed.connect(_hud.set_day)
	_update_camera()
	_set_mouse_captured(true)
	if GameSession.fade_in_next:
		GameSession.fade_in_next = false
		_hud.fade_in(arrive_fade_time)
	Log.info(("🏃 Player ready: position=%s, walk=%.1f, sprint=%.1f, crouch=%.1f m/s, max_step=%.2f m, fov=%.0f°, "
		+ "peek=%.2f/%.2f/%.2f m, aim_out=%.2f/%.2f m, wallet=%s") % [
		global_position, walk_speed, sprint_speed, crouch_speed, max_step_height, horizontal_fov,
		peek_side_reach, peek_up_reach, peek_down_reach, aim_out_side_reach, aim_out_up_reach,
		Bitcoin.format(GameSession.bitcoin) if shows_wallet else "hidden"])


func _unhandled_input(event: InputEvent) -> void:
	var mouse_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and mouse_captured:
		# screen_relative is raw pixel movement, unaffected by window scaling.
		var motion := (event as InputEventMouseMotion).screen_relative
		if is_dead or is_leaving:
			return
		# While peeking the mouse moves the head; aiming out turns the view again, so the player can aim.
		if Input.is_action_pressed("peek") and peek_state != PeekRules.State.AIM_OUT:
			move_head(motion)
			return
		var turn := motion * deg_to_rad(mouse_sensitivity)
		var pitch_limit := deg_to_rad(PITCH_LIMIT_DEGREES)
		_yaw = wrapf(_yaw - turn.x, -PI, PI)
		_pitch = clampf(_pitch - turn.y, -pitch_limit, pitch_limit)
	elif _is_menu_open():
		# Esc closes the inventory or the hub (read in _physics_process), and the mouse stays free for the grids.
		return
	elif event.is_action_pressed("pause") and mouse_captured:
		_set_mouse_captured(false)
	elif event is InputEventMouseButton and event.is_pressed() and not mouse_captured:
		# The click that captures the mouse again must not also fire.
		_weapon.suppress_trigger()
		_set_mouse_captured(true)


func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	if _awaiting_continue and Input.is_action_just_pressed("interact"):
		# Changing the scene takes this one out of the tree at once, so nothing more may run this frame.
		_continue_to_ship()
		return
	if is_dead or is_leaving:
		# The body comes to rest where it fell (or stands in the airlock); only interact, past the summary, does
		# anything any more.
		_set_movement_state(MovementRules.State.CROUCH_IDLE if is_crouched else MovementRules.State.IDLE)
		_update_velocity(Vector2.ZERO, delta)
		_move_and_follow_floor()
		return
	if _is_menu_open():
		_update_while_sorting(delta)
		return
	_update_peek_state()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint_blocked := peek_state != PeekRules.State.NONE or _weapon.blocks_sprint()
	var sprint_wanted := MovementRules.wants_sprint(input_dir, Input.is_action_pressed("sprint"), sprint_blocked)
	_crouch_toggled = MovementRules.next_crouch_toggle(
		_crouch_toggled, Input.is_action_just_pressed("crouch_toggle"), sprint_wanted)
	_update_crouch(MovementRules.wants_crouch(Input.is_action_pressed("crouch_hold"), _crouch_toggled, sprint_wanted))
	_set_movement_state(MovementRules.resolve_state(input_dir, sprint_wanted, is_crouched))
	_update_velocity(input_dir, delta)
	_try_step_up(delta)
	_move_and_follow_floor()
	_update_footsteps(delta)
	_update_head(delta)
	_update_interact_target()
	_update_interact(delta)
	if Input.is_action_just_pressed("flashlight"):
		set_flashlight(not is_flashlight_on())
	# A peek can't shoot; aiming out can.
	_weapon.physics_update(delta, peek_state != PeekRules.State.PEEK, movement_state == MovementRules.State.SPRINT)
	if Input.is_action_just_pressed("inventory") and not _is_menu_open():
		open_inventory()


func _process(delta: float) -> void:
	var eye_target := crouch_eye_height if is_crouched else stand_eye_height
	var eye_speed := (stand_eye_height - crouch_eye_height) / crouch_transition_time
	_eye_height = move_toward(_eye_height, eye_target, eye_speed * delta)
	_step_offset = move_toward(_step_offset, 0.0, max_step_height / STEP_SMOOTHING_TIME * delta)
	_update_head_bob(delta)
	_update_zoom_and_kick(delta)
	if is_dead:
		_death_time += delta
	_update_camera()
	_update_hud()


## Turns the body and tilts the camera, for example to face the right way when spawning.
func set_look(yaw: float, pitch: float = 0.0) -> void:
	var pitch_limit := deg_to_rad(PITCH_LIMIT_DEGREES)
	_yaw = wrapf(yaw, -PI, PI)
	_pitch = clampf(pitch, -pitch_limit, pitch_limit)
	rotation.y = _yaw
	_update_camera()
	Log.info("🏃 Look set: yaw=%.1f°, pitch=%.1f°" % [rad_to_deg(_yaw), rad_to_deg(_pitch)])


## Moves the head while peeking, by a mouse motion in pixels (right and down are positive, as on screen).
## The gamepad's right stick will feed it too. The head follows over the next physics frames.
func move_head(motion: Vector2) -> void:
	_peek_target = PeekRules.clamp_to_range(_peek_target + Vector2(motion.x, -motion.y) * peek_sensitivity,
		peek_side_reach, peek_up_reach, peek_down_reach)


## The parts of the player enemies can hit. Only the active ones are out (see Hitbox.is_active()).
func get_hitboxes() -> Array[Hitbox]:
	return [_head_hitbox, _body_hitbox, _arm_hitbox]


func get_health() -> Health:
	return _health


func get_weapon() -> Weapon:
	return _weapon


func get_inventory_screen() -> InventoryScreen:
	return _inventory_screen


func is_inventory_open() -> bool:
	return _inventory_screen.is_open


func get_trader_screen() -> TraderScreen:
	return _trader_screen


func is_trading() -> bool:
	return _trader_screen.is_open


## Opens the inventory screen with the dropped items within reach on its floor, searching a container when one is
## given. picked is a dropped item the player looked at, which is on the floor even if it is a little out of reach.
## The player stands still until it closes.
func open_inventory(loot: Lootable = null, picked: DroppedItem = null) -> void:
	if is_dead or is_leaving or _is_menu_open():
		Log.info("🏃 Inventory not opened: dead=%s, leaving=%s, menu_open=%s" % [
			is_dead, is_leaving, _is_menu_open()])
		return
	_enter_menu()
	var floor := _gather_floor(picked) if has_floor else null
	_inventory_screen.open(inventory, loot, floor, has_floor)
	Log.info("🏃 Inventory opened: loot=%s, floor_items=%s, position=%s, crouched=%s" % [
		loot.title if loot else "none", floor.items.size() if floor else "no floor", global_position, is_crouched])


func close_inventory() -> void:
	if not is_inventory_open():
		Log.info("🏃 Inventory not closed, it isn't open: position=%s" % global_position)
		return
	_inventory_screen.close()
	_leave_menu()
	Log.info("🏃 Inventory closed: position=%s" % global_position)


## Opens the trader hub's screen, from the ship's trader terminal: the system's hub, its sell crate and the ship's
## stash, all kept by the GameSession. The player stands still until it closes.
func open_trader() -> void:
	if is_dead or is_leaving or _is_menu_open():
		Log.info("🏃 Trader not opened: dead=%s, leaving=%s, menu_open=%s" % [is_dead, is_leaving, _is_menu_open()])
		return
	_enter_menu()
	_trader_screen.open()
	Log.info("🏃 Trader opened: hub=%s, bitcoin=%d, position=%s" % [
		GameSession.trader.title, GameSession.bitcoin, global_position])


func close_trader() -> void:
	if not is_trading():
		Log.info("🏃 Trader not closed, it isn't open: position=%s" % global_position)
		return
	_trader_screen.close()
	_leave_menu()
	Log.info("🏃 Trader closed: bitcoin=%d, position=%s" % [GameSession.bitcoin, global_position])


func get_system_map() -> SystemMapScreen:
	return _system_map


func get_star_map() -> StarMapScreen:
	return _star_map


## Whether either map tab is open: the system map or the star map.
func is_viewing_map() -> bool:
	return _system_map.is_open or _star_map.is_open


func is_jumping() -> bool:
	return _jumping


## Opens the system map, from the cockpit console: the system the ship is in, kept by the GameSession, where the
## player inspects its wrecks and flies the ship; its other tab is the star map. The player stands still until it
## closes.
func open_system_map() -> void:
	if is_dead or is_leaving or _is_menu_open():
		Log.info("🏃 System map not opened: dead=%s, leaving=%s, menu_open=%s" % [is_dead, is_leaving, _is_menu_open()])
		return
	_enter_menu()
	_system_map.open()
	Log.info("🏃 System map opened: system=%s, hydrogen=%d, position=%s" % [
		GameSession.system.definition.id if GameSession.system else "none", GameSession.hydrogen, global_position])


func close_system_map() -> void:
	if not is_viewing_map():
		Log.info("🏃 System map not closed, it isn't open: position=%s" % global_position)
		return
	if _star_map.is_open:
		_star_map.close()
	else:
		_system_map.close()
	_leave_menu()
	Log.info("🏃 System map closed: hydrogen=%d, at_hub=%s, docked=%s, position=%s" % [
		GameSession.hydrogen, GameSession.at_hub,
		GameSession.docked.definition.id if GameSession.docked else "none", global_position])


func _is_menu_open() -> bool:
	return is_inventory_open() or is_trading() or is_viewing_map()


## Closes whichever screen is open over the game.
func _close_menu() -> void:
	if is_trading():
		close_trader()
	elif is_viewing_map():
		close_system_map()
	else:
		close_inventory()


## Before a screen opens over the game: a hold ends, the prompt goes and the mouse is freed for the screen.
func _enter_menu() -> void:
	_end_hold()
	interact_target = null
	_shown_prompt = ""
	_shown_hold = false
	_hud.set_prompt("", "")
	_set_mouse_captured(false)


## After a screen closes: the button that worked it must not fire when the view comes back, and the mouse is
## captured again.
func _leave_menu() -> void:
	_weapon.suppress_trigger()
	if not is_dead:
		_set_mouse_captured(true)


func is_flashlight_on() -> bool:
	return _flashlight.visible


func set_flashlight(on: bool) -> void:
	_flashlight.visible = on
	Log.info("🏃 Flashlight %s: position=%s" % ["on" if on else "off", global_position])


## Whether a hitbox is lit, so enemies see it from their full sight range rather than only up close: light from a
## lamp, a searchlight or a muzzle flash reaches its centre, or the flashlight is on, which shows all of the player.
## Worked out at most once per physics frame, however many enemies ask.
func is_part_lit(hitbox: Hitbox) -> bool:
	if is_flashlight_on():
		return true
	var frame := Engine.get_physics_frames()
	if frame != _lit_frame:
		_lit_frame = frame
		_lit_parts.clear()
	if not _lit_parts.has(hitbox):
		_lit_parts[hitbox] = LightLevel.is_lit(get_world_3d().direct_space_state, get_tree(), hitbox.sample_points()[0])
	return _lit_parts[hitbox]


func _setup_head() -> void:
	var head_shape := SphereShape3D.new()
	head_shape.radius = head_radius
	_head_query = PhysicsShapeQueryParameters3D.new()
	_head_query.shape = head_shape
	_head_query.collision_mask = HEAD_MASK
	_head_query.exclude = [get_rid()]
	# The body hitbox changes height when crouching, so each player gets its own shape.
	var body_hitbox_collision := _body_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	_body_hitbox_shape = (body_hitbox_collision.shape as CylinderShape3D).duplicate()
	body_hitbox_collision.shape = _body_hitbox_shape
	var arm_collision := _arm_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	_arm_length = (arm_collision.shape as BoxShape3D).size.z
	_arm_hitbox.set_active(false)
	_update_hitboxes()


## Takes over the kit the last scene's player carried; with none, packs the basic kit when the session says so (a new
## game, or a level started on its own) or starts empty-handed (after a death). Arms the player with the gun in the
## weapon slot, again whenever the slot changes, and listens for hits.
func _setup_combat() -> void:
	var carried := GameSession.take_carried()
	var kit := "carried"
	if carried:
		inventory = carried
	else:
		inventory = Inventory.new(pocket_size, backpack_size, weapon_slot_size)
		kit = "basic" if GameSession.basic_kit_next else "none"
		if GameSession.basic_kit_next:
			_pack_basic_kit()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_weapon.fired.connect(_on_weapon_fired)
	_weapon.holstered = holstered
	_arm()
	inventory.weapon.changed.connect(_arm)
	_hud.set_health(_health.health, _health.max_health, false)
	Log.info(("🏃 Combat ready: health=%.0f, weapon=%s, kit=%s, pockets=%s, backpack=%s, items=%d, fresh=%d, "
		+ "packed=%d, heat=%.0f%%, holstered=%s, critical_health=%.0f") % [_health.health,
		_weapon.definition.id if _weapon.is_equipped() else "none", kit, pocket_size, backpack_size,
		inventory.item_count(), clips.fresh, clips.packed, clips.heat * 100.0, holstered, critical_health])


## The basic kit: the starting gun, with a fresh clip loaded, in the weapon slot, and fresh clips for it in the
## pockets and the backpack.
func _pack_basic_kit() -> void:
	var gun := ContentRegistry.get_definition(starting_weapon_id) as WeaponDefinition
	if gun == null:
		Log.error("🏃 Basic kit has no gun, not a registered weapon: starting_weapon_id=%s" % starting_weapon_id)
		return
	inventory.weapon.add(Item.new(gun))
	var clip := ContentRegistry.get_definition(gun.clip_item) as ItemDefinition
	if clip == null:
		Log.error("🏃 Basic kit has no clips, not a registered item: weapon=%s, clip_item=%s" % [gun.id, gun.clip_item])
		return
	for i in starting_pocket_clips:
		inventory.pockets.add(Item.new(clip))
	for i in starting_backpack_clips:
		inventory.backpack.add(Item.new(clip))
	Log.info("🏃 Basic kit packed: gun=%s, pocket_clips=%d, backpack_clips=%d" % [
		gun.id, starting_pocket_clips, starting_backpack_clips])


## Holds the gun in the weapon slot: equips it with its clips when it changed, and puts the weapon away when the slot
## is empty, leaving the player unarmed. Runs whenever the weapon slot changes, also when the gun is only moved about
## inside it.
func _arm() -> void:
	var gun := inventory.gun()
	if clips and clips.gun == gun and _weapon.is_equipped() == (gun != null):
		Log.info("🏃 Weapon slot changed, same gun in hand: weapon=%s" % [gun.definition.id if gun else "none"])
		return
	if _weapon.is_equipped():
		_weapon.unequip()
	var definition := gun.definition as WeaponDefinition if gun else null
	if definition == null:
		clips = ThermalClips.new(inventory)
		_hud.hide_clips()
		Log.info("🏃 Unarmed, no gun in the weapon slot: items=%d" % inventory.item_count())
		return
	var fresh_clip := ContentRegistry.get_definition(definition.clip_item) as ItemDefinition
	var spent_clip := ContentRegistry.get_definition(definition.spent_clip_item) as ItemDefinition
	if fresh_clip == null or spent_clip == null:
		Log.error("🏃 Weapon clips are not registered items: weapon=%s, clip_item=%s, spent_clip_item=%s" % [
			definition.id, definition.clip_item, definition.spent_clip_item])
	clips = ThermalClips.new(inventory, fresh_clip, spent_clip, gun)
	var own_hitboxes: Array[RID] = []
	for hitbox in get_hitboxes():
		own_hitboxes.append(hitbox.get_rid())
	_weapon.equip(definition, clips, own_hitboxes)
	Log.info("🏃 Armed: weapon=%s, heat=%.0f%%, fresh=%d, packed=%d, holstered=%s" % [
		definition.id, clips.heat * 100.0, clips.fresh, clips.packed, holstered])


## The peek follows the peek and aim actions (see PeekRules.next_state). Releasing peek centres the peek target,
## so the next peek starts from the body. Runs every physics frame, so it only logs when the state changes.
func _update_peek_state(allowed: bool = true) -> void:
	var centred := PeekRules.is_centred(_peek_target, peek_side_reach, peek_up_reach, peek_down_reach)
	var next := PeekRules.next_state(peek_state, Input.is_action_pressed("peek"), Input.is_action_pressed("aim"),
		centred) if allowed else PeekRules.State.NONE
	if next == peek_state:
		return
	var previous := peek_state
	peek_state = next
	if next == PeekRules.State.NONE:
		_peek_target = Vector2.ZERO
	_arm_hitbox.set_active(next == PeekRules.State.AIM_OUT)
	Log.info("🏃 Peek state changed: %s -> %s, peek_target=%s, head=%s, position=%s" % [
		PeekRules.State.keys()[previous], PeekRules.State.keys()[next], _peek_target, head_offset, global_position])
	peek_state_changed.emit(previous, next)


## Moves the head towards where the peek wants it (further out in the same direction while aiming out, back to
## the body when not peeking), stops it at walls, and moves the hitboxes with it. Runs every physics frame.
func _update_head(delta: float) -> void:
	var target := _peek_target
	if peek_state == PeekRules.State.AIM_OUT:
		target = PeekRules.aim_out_offset(_peek_target, peek_side_reach, peek_up_reach, peek_down_reach,
			aim_out_side_reach, aim_out_up_reach)
	_head_offset_previous = head_offset
	head_offset = _clear_head_path(head_offset.move_toward(target, head_speed * delta))
	_update_hitboxes()


## Shortens a head offset so the head stops where it would touch a wall, by sweeping a sphere out from the normal
## eye position.
func _clear_head_path(offset: Vector2) -> Vector2:
	if offset.is_zero_approx():
		return Vector2.ZERO
	_head_query.transform = Transform3D(Basis.IDENTITY, global_position + up_direction * _eye_height)
	_head_query.motion = global_basis * Vector3(offset.x, offset.y, 0.0)
	var safe_fraction := get_world_3d().direct_space_state.cast_motion(_head_query)[0]
	return offset * safe_fraction


## Places the hitboxes: the head where the camera is, the body below the neck, and the arm reaching forward
## along the view from below the head, so it comes out of cover with the head when aiming out.
func _update_hitboxes() -> void:
	var head := Vector3(head_offset.x, _eye_height + head_offset.y, 0.0)
	_head_hitbox.position = head
	var body_height := _eye_height - NECK_LENGTH
	if not is_equal_approx(_body_hitbox_shape.height, body_height):
		_body_hitbox_shape.height = body_height
	_body_hitbox.position = Vector3(0.0, body_height / 2.0, 0.0)
	var aim := Basis(Vector3.RIGHT, _pitch)
	var shoulder := head + Vector3.DOWN * SHOULDER_DROP
	_arm_hitbox.transform = Transform3D(aim, shoulder + aim * Vector3.FORWARD * (_arm_length / 2.0))


## Casts the look ray and keeps interact_target and the prompt up to date. Runs every physics frame, so it only
## logs when the target changes.
func _update_interact_target() -> void:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * interact_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, INTERACT_MASK, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Interactable = hit.get("collider") as Interactable if not hit.is_empty() else null
	var action := target.prompt if target else ""
	var dropped := target.get_parent() as DroppedItem if target else null
	if dropped:
		action = "Pick up %s" % dropped.item.definition.display_name.to_lower()
	var hold := target != null and target.hold_time > 0.0
	if target != interact_target:
		interact_target = target
		Log.info("🏃 Interact target changed: target=%s, prompt=%s" % [
			"%s/%s" % [target.get_parent().name, target.name] if target else "none", action])
	# The prompt can change while looking at the same target (the elevator's "Ride up" becomes "Ride down").
	if action != _shown_prompt or hold != _shown_hold:
		_shown_prompt = action
		_shown_hold = hold
		_hud.set_prompt(Hud.key_label(&"interact"), action, hold)


## Uses the interactable looked at: on the press, or, for one with a hold time (prying a container open), once
## interact has been held on it that long. Letting go or looking away cancels a hold. Runs every physics frame, so
## it only logs (through the interactable) when a hold starts or stops.
func _update_interact(delta: float) -> void:
	var target := interact_target
	if _held_target and (target != _held_target or not Input.is_action_pressed("interact")):
		_end_hold()
	if target == null:
		return
	if target.hold_time <= 0.0:
		if Input.is_action_just_pressed("interact"):
			_use(target)
		return
	if _held_target == null:
		if Input.is_action_just_pressed("interact"):
			_held_target = target
			_hold = 0.0
			target.set_held(true)
		return
	_hold += delta
	if _hold >= target.hold_time:
		_end_hold()
		_use(target)


func _end_hold() -> void:
	if _held_target and is_instance_valid(_held_target):
		_held_target.set_held(false)
	_held_target = null
	_hold = -1.0


## Uses an interactable: a dropped item opens the inventory with it on the floor, to be dragged into a grid; loot is
## searched once it is open; anything else is interacted with.
func _use(target: Interactable) -> void:
	var dropped := target.get_parent() as DroppedItem
	if dropped:
		target.interact()
		open_inventory(null, dropped)
		return
	target.interact()
	var loot := target as Lootable
	if loot and loot.is_open:
		open_inventory(loot)


## The floor for the inventory screen: the dropped items in sight within floor_reach of the feet (and picked, if
## given), nearest first, laid out in a grid InventoryScreen.FLOOR_COLUMNS wide that grows to hold them all.
func _gather_floor(picked: DroppedItem) -> ItemGrid:
	var space := get_world_3d().direct_space_state
	var eye := _camera.global_position
	var nearby: Array[DroppedItem] = []
	for node in get_tree().get_nodes_in_group(DroppedItem.GROUP):
		var dropped := node as DroppedItem
		if dropped == null or dropped.is_queued_for_deletion():
			continue
		var offset := dropped.global_position - global_position
		var in_reach := Vector2(offset.x, offset.z).length() <= floor_reach and absf(offset.y) <= 1.0
		if dropped != picked and not in_reach:
			continue
		var sight := PhysicsRayQueryParameters3D.create(eye, dropped.global_position + Vector3.UP * 0.05, HEAD_MASK)
		if dropped != picked and not space.intersect_ray(sight).is_empty():
			continue
		nearby.append(dropped)
	nearby.sort_custom(func(a: DroppedItem, b: DroppedItem) -> bool:
		return a.global_position.distance_squared_to(global_position) \
			< b.global_position.distance_squared_to(global_position))
	var floor := ItemGrid.new(Vector2i(InventoryScreen.FLOOR_COLUMNS, InventoryScreen.FLOOR_SPARE_ROWS))
	for dropped in nearby:
		if not floor.add(dropped.item):
			floor.grow_to(floor.size.y + ItemShape.size_of(dropped.item.definition.get_cells()).y)
			floor.add(dropped.item)
	Log.info("🏃 Gathered the floor: items=%d, reach=%.1f m, picked=%s" % [
		floor.items.size(), floor_reach, picked.item.definition.id if picked else "none"])
	return floor


## While the inventory, the hub or the system map is open the player stands still in their stance and can't look,
## peek or shoot; Tab, Esc and interact close it. The world keeps going, and a reload under way still finishes.
func _update_while_sorting(delta: float) -> void:
	var close_pressed := Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("pause") \
		or Input.is_action_just_pressed("interact")
	# A jump under way keeps the map open until the ship has arrived.
	if close_pressed and not _jumping:
		_close_menu()
	elif Input.is_action_just_pressed("map_tab") and not _jumping and _star_map.is_open:
		_star_map.switch_tab()
	elif Input.is_action_just_pressed("map_tab") and not _jumping and _system_map.is_open:
		_system_map.switch_tab()
	_update_peek_state(false)
	_set_movement_state(MovementRules.State.CROUCH_IDLE if is_crouched else MovementRules.State.IDLE)
	_update_velocity(Vector2.ZERO, delta)
	_move_and_follow_floor()
	_update_footsteps(delta)
	_update_head(delta)
	_weapon.physics_update(delta, false, true, false)


## An item was dragged onto the inventory screen's floor (or out of the inventory): it lands in front of the
## player's feet (at their feet when a wall is in the way), and clatters, a noise enemies hear.
func _on_dropped_on_floor(item: Item) -> void:
	var forward := -global_basis.z
	var chest := global_position + up_direction * 0.5
	var query := PhysicsRayQueryParameters3D.create(chest, chest + forward * (drop_distance + 0.15), HEAD_MASK,
		[get_rid()])
	var distance := drop_distance
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		distance = maxf(chest.distance_to(hit["position"]) - 0.2, 0.0)
	var body := DroppedItem.create(item, drop_sound)
	get_parent().add_child(body, true)
	# A little to either side, so things dropped one after another don't land in a stack.
	var aside := global_basis.x * randf_range(-DROP_SCATTER, DROP_SCATTER)
	body.global_position = global_position + forward * distance + aside + up_direction * 0.3
	body.rotation.y = randf() * TAU
	body.linear_velocity = forward * 0.4
	Log.info("🏃 Dropped item: item=%s, position=%s, distance=%.2f m, wall_in_front=%s" % [
		item.definition.id, body.global_position, distance, not hit.is_empty()])
	Hearing.make_noise(body, body.global_position, drop_loudness, &"item_drop")


## An item was dragged off the inventory screen's floor into a grid: it leaves the world.
func _on_taken_from_floor(item: Item) -> void:
	for node in get_tree().get_nodes_in_group(DroppedItem.GROUP):
		var dropped := node as DroppedItem
		if dropped and dropped.item == item:
			Log.info("🏃 Picked up item: item=%s, position=%s, into=%s" % [
				item.definition.id, dropped.global_position, "pockets" if inventory.grid_of(item) == inventory.pockets
				else "backpack" if inventory.grid_of(item) else "container"])
			dropped.remove_from_group(DroppedItem.GROUP)
			dropped.queue_free()
			return
	Log.warning("🏃 Item taken from the floor had no dropped item in the world: item=%s" % item.definition.id)


func _update_crouch(wants_crouch: bool) -> void:
	if wants_crouch:
		_stand_blocked = false
		if not is_crouched:
			is_crouched = true
			_apply_body_height(crouch_height)
			Log.info("🏃 Crouched: toggled=%s, position=%s" % [_crouch_toggled, global_position])
	elif is_crouched:
		_try_stand_up()


func _try_stand_up() -> void:
	if test_move(global_transform, up_direction * (stand_height - crouch_height)):
		if not _stand_blocked:
			_stand_blocked = true
			Log.info("🏃 No room to stand up, staying crouched: position=%s" % global_position)
	else:
		is_crouched = false
		_stand_blocked = false
		_apply_body_height(stand_height)
		Log.info("🏃 Stood up: position=%s" % global_position)


func _set_movement_state(new_state: MovementRules.State) -> void:
	if new_state != movement_state:
		var previous := movement_state
		movement_state = new_state
		Log.info("🏃 Movement state changed: %s -> %s" % [
			MovementRules.State.keys()[previous], MovementRules.State.keys()[new_state]])
		movement_state_changed.emit(previous, new_state)


func _update_velocity(input_dir: Vector2, delta: float) -> void:
	var slowed := peek_state != PeekRules.State.NONE or _weapon.is_aiming
	var target_speed := MovementRules.speed_for_state(movement_state, walk_speed, sprint_speed, crouch_speed, slowed)
	var target := global_basis * Vector3(input_dir.x, 0.0, input_dir.y) * target_speed
	var moving := input_dir.length() > MovementRules.MOVE_THRESHOLD
	var rate := target_speed / acceleration_time if moving else walk_speed / deceleration_time
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta


## Lifts the body onto an obstacle no taller than max_step_height when one blocks this frame's move:
## rise as far as the ceiling allows, move forward at that height, then come back down onto the obstacle.
## Pressed against an obstacle, a frame's motion is only millimetres, so the body moves at least
## STEP_PROBE_DISTANCE forward to land on top of it. Runs every physics frame, so it only logs when it steps.
func _try_step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	var blocker := KinematicCollision3D.new()
	if not is_on_floor() or motion.is_zero_approx() or not test_move(global_transform, motion, blocker):
		return
	if blocker.get_normal().angle_to(up_direction) <= floor_max_angle:
		return

	var raised := global_transform
	var rise := up_direction * (max_step_height + STEP_CLEARANCE)
	var ceiling := KinematicCollision3D.new()
	if test_move(raised, rise, ceiling):
		rise = ceiling.get_travel()
	raised.origin += rise
	var forward := motion.normalized() * maxf(motion.length(), STEP_PROBE_DISTANCE)
	if test_move(raised, forward):
		return

	var ahead := raised.translated(forward)
	var landing := KinematicCollision3D.new()
	if not test_move(ahead, -rise, landing):
		return
	var landing_position := ahead.origin + landing.get_travel()
	var step_height := (landing_position - global_position).dot(up_direction)
	var too_steep := landing.get_normal().angle_to(up_direction) > floor_max_angle
	if step_height < MIN_STEP_HEIGHT or step_height > max_step_height + MIN_STEP_HEIGHT or too_steep:
		return

	global_position = landing_position
	_smooth_camera_step(step_height)
	Log.info("🏃 Stepped up: height=%.2f m, obstacle=%s, position=%s" % [
		step_height, (landing.get_collider() as Node).name, global_position])


## Moves the body, keeps it on the floor when it walks off an obstacle, and smooths the camera on the way down.
func _move_and_follow_floor() -> void:
	var was_on_floor := is_on_floor()
	var height_before := global_position.dot(up_direction)
	move_and_slide()
	if was_on_floor and not is_on_floor() and velocity.dot(up_direction) <= 0.0:
		_snap_down_off_edge()
	var drop := height_before - global_position.dot(up_direction)
	var on_moving_platform := not get_platform_velocity().is_zero_approx()
	if was_on_floor and is_on_floor() and drop > MIN_STEP_HEIGHT and not on_moving_platform:
		_smooth_camera_step(-drop)
		Log.info("🏃 Stepped down: height=%.2f m, position=%s" % [drop, global_position])


## Godot's floor snap fails while the body still touches the edge it just walked off, because the downward
## test hits that edge first. Look for floor a little further along the direction of travel instead, and
## drop onto it when it is no deeper than a step. Deeper drops are left to gravity.
func _snap_down_off_edge() -> void:
	var travel_direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var probe := global_transform.translated(travel_direction * STEP_PROBE_DISTANCE)
	var landing := KinematicCollision3D.new()
	if test_move(probe, -up_direction * (max_step_height + STEP_CLEARANCE), landing) \
			and landing.get_normal().angle_to(up_direction) <= floor_max_angle:
		global_position += up_direction * landing.get_travel().dot(up_direction)
		apply_floor_snap()


## A footstep every half stride while moving on the floor, as loud as the movement: a sound for the player and a
## noise for enemies. Runs every physics frame; Hearing logs the steps someone hears.
func _update_footsteps(delta: float) -> void:
	var stepping := movement_state != MovementRules.State.IDLE and movement_state != MovementRules.State.CROUCH_IDLE
	if not is_on_floor() or not stepping:
		return
	_step_distance += Vector2(velocity.x, velocity.z).length() * delta
	if _step_distance < bob_stride_length / 2.0:
		return
	_step_distance -= bob_stride_length / 2.0
	var loudness := walk_step_loudness
	var sound := walk_step_sound
	if movement_state == MovementRules.State.SPRINT:
		loudness = sprint_step_loudness
		sound = sprint_step_sound
	elif movement_state == MovementRules.State.CROUCH_WALK:
		loudness = crouch_step_loudness
		sound = crouch_step_sound
	if sound:
		_footstep_sound.stream = sound
		_footstep_sound.pitch_scale = randf_range(0.9, 1.1)
		_footstep_sound.play()
	Hearing.make_noise(self, global_position, loudness, Hearing.FOOTSTEP)


## Keeps the camera where it was when the body moves up or down a step, then lets it catch up smoothly.
func _smooth_camera_step(height_change: float) -> void:
	_step_offset = clampf(_step_offset - height_change, -max_step_height, max_step_height)
	reset_physics_interpolation()


func _on_weapon_fired(_charge: float, kick_degrees: float) -> void:
	_view_kick.x += deg_to_rad(kick_degrees)


## A hit flinches the view, flashes the screen edges, points at where it came from and plays the hit sound.
func _on_damaged(amount: float, source_position: Vector3, part: Hitbox.Part) -> void:
	_view_kick += Vector2(randf_range(0.6, 1.0), randf_range(-1.0, 1.0)) * deg_to_rad(flinch_degrees)
	_hit_sound.play()
	var critical := _health.health <= critical_health
	_hud.set_health(_health.health, _health.max_health, critical)
	_hud.show_hit(source_position)
	Log.info("🏃 Hit: part=%s, damage=%.1f, health=%.1f, critical=%s, source=%s, position=%s" % [
		Hitbox.Part.keys()[part], amount, _health.health, critical, source_position, global_position])


## The run ends: the controls stop, the weapon and hitboxes go, the view slumps to the floor and fades to black, and
## everything carried is lost. Once the screen is black the run summary shows.
func _on_died() -> void:
	is_dead = true
	_death_time = 0.0
	_stop_acting()
	_hud.fade_out(DEATH_FADE_TIME, DEATH_FADE_DELAY)
	var summary := GameSession.die(inventory)
	Log.info("🏃 Player died: position=%s, summary_in=%.1f s, fresh=%d, spent=%d, items=%d, value=%d" % [
		global_position, death_summary_delay, clips.fresh, clips.spent, inventory.item_count(), inventory.value()])
	died.emit()
	get_tree().create_timer(death_summary_delay).timeout.connect(_show_summary.bind(summary))


## The player got out through the wreck's airlock: nothing can hit them any more, the screen fades to black over the
## docking sound, and then the run summary shows what they carried out. What they carry stays theirs and goes on to
## the ship with them; the gun's loaded clip keeps its heat.
func extract() -> void:
	if not _start_leaving("extract"):
		return
	var summary := GameSession.extract(inventory)
	get_tree().create_timer(leave_fade_time).timeout.connect(_show_summary.bind(summary))
	Log.info("🏃 Extracting: position=%s, items=%d, value=%d, heat=%.0f%%, summary_in=%.1f s" % [
		global_position, inventory.item_count(), inventory.value(), clips.heat * 100.0, leave_fade_time])


## The ship jumps to another system, from the star map: the screen fades to black over the jump drive's sound, the
## ship jumps (a day passes, see GameSession.jump_to()), and the screen fades back in on the system map of the system
## it arrived in. The player stays where they are, at the console.
func jump_to(to: StarSystemDefinition) -> void:
	if _jumping or is_dead or is_leaving:
		Log.info("🏃 Not jumping: to=%s, jumping=%s, dead=%s, leaving=%s" % [to.id, _jumping, is_dead, is_leaving])
		return
	_jumping = true
	GameSession.play_travel_sound(jump_sound)
	_hud.fade_out(jump_fade_time)
	get_tree().create_timer(jump_fade_time).timeout.connect(_finish_jump.bind(to))
	Log.info("🏃 Jumping: to=%s, from=%s, fade=%.1f s" % [
		to.id, GameSession.system.definition.id if GameSession.system else "none", jump_fade_time])


func _finish_jump(to: StarSystemDefinition) -> void:
	if not is_inside_tree():
		Log.warning("🏃 Jump cut short, the player has left the tree: to=%s" % to.id)
		return
	var jumped := GameSession.jump_to(to)
	if jumped:
		_hud.show_arrival("Arrived at %s on day %d. The jump drive recharges until a ship is boarded." % [
			GameSession.trader.title, GameSession.day])
	else:
		_star_map.say("The jump to %s didn't go ahead." % to.display_name, true)
	_hud.fade_in(jump_fade_time)
	_jumping = false
	Log.info("🏃 Jump finished: to=%s, jumped=%s, system=%s, day=%d, antimatter=%d" % [
		to.id, jumped, GameSession.system.definition.id if GameSession.system else "none", GameSession.day,
		GameSession.antimatter])


## The player boards the wreck through the ship's airlock: the screen fades to black over the docking sound, and then
## the game travels to the wreck with what they carry.
func board() -> void:
	if not _start_leaving("board"):
		return
	get_tree().create_timer(leave_fade_time).timeout.connect(_finish_boarding)
	Log.info("🏃 Boarding: position=%s, items=%d, value=%d, heat=%.0f%%, travel_in=%.1f s" % [
		global_position, inventory.item_count(), inventory.value(), clips.heat * 100.0, leave_fade_time])


func _finish_boarding() -> void:
	if not is_inside_tree():
		Log.warning("🏃 Boarding cut short, the player has left the tree")
		return
	Log.info("🏃 Faded to black, travelling to the wreck: items=%d, value=%d" % [
		inventory.item_count(), inventory.value()])
	GameSession.board(inventory)


## Stops the player to leave through an airlock, without the death's slump: a reload under way finishes, the player
## is taken out of the action, and the screen fades to black over the docking sound. Returns false when they are dead
## or already leaving.
func _start_leaving(why: String) -> bool:
	if is_dead or is_leaving:
		Log.info("🏃 Not leaving: why=%s, dead=%s, already_leaving=%s" % [why, is_dead, is_leaving])
		return false
	is_leaving = true
	_weapon.finish_reload()
	_stop_acting()
	GameSession.play_travel_sound(dock_sound)
	_hud.fade_out(leave_fade_time)
	Log.info("🏃 Leaving through the airlock: why=%s, position=%s, fade=%.1f s" % [why, global_position, leave_fade_time])
	return true


## Takes the player out of the action when they die or leave: the weapon and hitboxes go (so nothing can see or hit
## them any more), the peek centres, a hold ends, the inventory or hub closes and the prompt goes.
func _stop_acting() -> void:
	_weapon.disable()
	for hitbox in get_hitboxes():
		hitbox.set_active(false)
	if peek_state != PeekRules.State.NONE:
		var previous := peek_state
		peek_state = PeekRules.State.NONE
		peek_state_changed.emit(previous, peek_state)
	_peek_target = Vector2.ZERO
	_head_offset_previous = Vector2.ZERO
	head_offset = Vector2.ZERO
	_end_hold()
	_close_menu()
	interact_target = null
	_shown_prompt = ""
	_shown_hold = false
	_hud.set_prompt("", "")
	Log.info("🏃 Stopped acting: dead=%s, leaving=%s, position=%s" % [is_dead, is_leaving, global_position])


## The screen is black and the run is over: its summary shows until the player presses interact to go on to the ship.
func _show_summary(summary: RunSummary) -> void:
	if not is_inside_tree():
		Log.info("🏃 Run summary not shown, the player has left the tree: %s" % summary)
		return
	run_summary = summary
	_awaiting_continue = true
	_hud.show_summary(summary)
	Log.info("🏃 Run summary shown, waiting for interact: %s" % summary)


func _continue_to_ship() -> void:
	_awaiting_continue = false
	_hud.hide_summary()
	Log.info("🏃 Continuing past the run summary: %s" % run_summary)
	GameSession.continue_to_ship()


## Zooms in while aiming down sights, and lets the kick of shots and the flinch of hits settle back.
func _update_zoom_and_kick(delta: float) -> void:
	_zoom = move_toward(_zoom, 1.0 if _weapon.is_aiming else 0.0, delta / ZOOM_TIME)
	var aim_zoom := _weapon.definition.aim_zoom if _weapon.is_equipped() else 1.0
	var zoom := lerpf(1.0, aim_zoom, smoothstep(0.0, 1.0, _zoom))
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_base_fov) / 2.0) / zoom))
	var recovery_time := _weapon.definition.kick_recovery_time if _weapon.is_equipped() else 0.3
	_view_kick *= exp(-KICK_SETTLE / maxf(recovery_time, 0.01) * delta)


## Runs every frame; the HUD only redraws what changed. Unarmed, the clip readout stays hidden.
func _update_hud() -> void:
	_hud.set_hold(_hold / _held_target.hold_time if _held_target and _held_target.hold_time > 0.0 else -1.0)
	_hud.set_charge(_weapon.charge)
	if not _weapon.is_equipped():
		return
	var definition := _weapon.definition
	var charge_heat := WeaponRules.shot_heat(definition, _weapon.charge) if _weapon.charge >= 0.0 else 0.0
	var saturated := not clips.has_room_for(definition.shot_heat)
	_hud.set_clips(clips.heat, charge_heat, clips.fresh, clips.packed, clips.spent, _weapon.is_clip_low(), saturated,
		_weapon.reload_progress())


## The head doesn't bob while peeking, so the peek holds steady.
func _update_head_bob(delta: float) -> void:
	var bobbing := head_bob_enabled and peek_state == PeekRules.State.NONE
	var target_amplitude := 0.0
	if bobbing and movement_state == MovementRules.State.WALK:
		target_amplitude = walk_bob_amplitude
	elif bobbing and movement_state == MovementRules.State.SPRINT:
		target_amplitude = sprint_bob_amplitude
	_bob_amplitude = move_toward(_bob_amplitude, target_amplitude, sprint_bob_amplitude / BOB_FADE_TIME * delta)
	var speed := Vector2(velocity.x, velocity.z).length()
	_bob_phase = fmod(_bob_phase + speed * delta / bob_stride_length * TAU, TAU)


## Places the camera at eye height on the physics-interpolated body, so movement looks smooth on high
## refresh rate screens, while the look direction comes straight from the latest mouse input. The peeking head is
## interpolated between physics frames the same way, and a sideways lean rolls the view towards it. Kicks and
## flinches turn the view on top of where the player aims, and after death the view slumps to the floor.
func _update_camera() -> void:
	var head := _head_offset_previous.lerp(head_offset, Engine.get_physics_interpolation_fraction())
	var roll := -deg_to_rad(PeekRules.tilt_degrees(head.x, peek_side_reach, peek_tilt))
	var pitch := _pitch + _view_kick.x
	var eye_height := _eye_height + _step_offset
	if is_dead:
		var slump := smoothstep(0.0, DEATH_SLUMP_TIME, _death_time)
		pitch = lerpf(pitch, deg_to_rad(DEATH_PITCH), slump)
		roll = lerpf(roll, deg_to_rad(DEATH_ROLL), slump)
		eye_height = lerpf(eye_height, DEATH_EYE_HEIGHT, slump)
	var look := Basis.from_euler(Vector3(pitch, _yaw + _view_kick.y, roll))
	var body_turn := Basis(Vector3.UP, _yaw)
	var bob := body_turn * Vector3(
		sin(_bob_phase) * _bob_amplitude * 0.5, sin(_bob_phase * 2.0) * _bob_amplitude, 0.0)
	var feet := get_global_transform_interpolated().origin
	var eye := feet + up_direction * eye_height + body_turn * Vector3(head.x, head.y, 0.0)
	_camera.global_transform = Transform3D(look, eye + bob)


func _apply_body_height(height: float) -> void:
	_body_shape.height = height
	_collision_shape.position.y = height / 2.0


func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	Log.info("🏃 Mouse %s" % ("captured" if captured else "released"))
