class_name WeaponViewmodel
extends Node3D
## The weapon as the player sees it: the root of a weapon's viewmodel scene, holding its model, muzzle, muzzle light
## and sounds. Its origin is the rear sight, so the aim pose lines the sights up with the centre dot. Weapon tells it
## every physics frame what is happening (set_state) and calls it for shots and reloads; it moves the model between
## the hip, aim and lowered poses, plays the reload, makes the emitter glow while charging and flashes the muzzle
## light. The model's materials are swapped for the viewmodel shader, which draws the weapon in front of the world.
## Runs every frame, so it never logs from _process.

const VIEWMODEL_SHADER := preload("res://scenes/weapons/viewmodel.gdshader")
## The visual layer viewmodels draw on (20, "viewmodel"), so effects such as scorch marks can leave them out.
const VISUAL_LAYER := 1 << 19
## Names of the model's materials that react to the weapon, as named in its Blender script.
const EMITTER_MATERIAL := "Emitter"
const CLIP_HEAT_MATERIAL := "ClipHeat"
## Reload progress at which the old clip starts sliding out, is gone, the new one starts sliding in, and is home.
const CLIP_OUT_START := 0.15
const CLIP_OUT_END := 0.3
const CLIP_IN_START := 0.55
const CLIP_IN_END := 0.75
## Reload progress over which the weapon turns over at the start and back at the end.
const TURN_IN_END := 0.15
const TURN_OUT_START := 0.85
## How quickly the kick of a shot dies away (per second, exponential).
const KICK_RECOVERY := 14.0
const MUZZLE_FLASH_TIME := 0.06

@export_group("Poses")
## Where the rear sight sits in the camera's frame at the hip, in metres (x right, y up, -z forward).
@export var hip_position := Vector3(0.15, -0.15, -0.38)
## Degrees the weapon is turned at the hip (x pitch, y yaw, z roll).
@export var hip_rotation := Vector3(0.0, 4.0, 0.0)
## Where the rear sight sits while aiming down sights: on the centre line, so the sights meet the centre dot.
@export var aim_position := Vector3(0.0, -0.001, -0.36)
@export var lowered_position := Vector3(0.11, -0.26, -0.32)
@export var lowered_rotation := Vector3(-30.0, 20.0, 15.0)
## Seconds to move between the hip and the sights.
@export var aim_time: float = 0.15

@export_group("Reload")
## How far the weapon moves and turns at the middle of the reload: up and rolled over, so the grip and the clip
## sliding out of it come into view.
@export var reload_offset := Vector3(0.0, 0.1, 0.05)
@export var reload_turn := Vector3(30.0, 0.0, -50.0)
## Metres the clip slides out of the grip.
@export var clip_travel: float = 0.1

@export_group("Shot")
## Metres the weapon jumps back and degrees it tips up on an uncharged and a fully charged shot.
@export var kick_back := Vector2(0.015, 0.04)
@export var kick_tip := Vector2(4.0, 12.0)
@export var muzzle_flash_energy: float = 3.0

@export_group("Glow")
## Emission energy of the emitter when idle and at a full charge.
@export var idle_glow: float = 0.8
@export var charged_glow: float = 10.0
## The clip's heat band glows from cool to hot as the loaded clip heats up.
@export var cool_color := Color(0.35, 0.65, 1.0)
@export var hot_color := Color(1.0, 0.4, 0.08)
@export var clip_glow: float = 2.5

var _raise := 1.0
var _aiming := false
var _charge := -1.0
var _reload_progress := -1.0
var _heat := 0.0
var _aim_blend := 0.0
## 1 just after a shot, dying away to 0; _kick_charge is that shot's charge.
var _kick := 0.0
var _kick_charge := 0.0
var _flash := 0.0
var _clip_rest: Transform3D
var _emitter_materials: Array[ShaderMaterial] = []
var _clip_heat_materials: Array[ShaderMaterial] = []

@onready var _muzzle: Marker3D = $Muzzle
@onready var _muzzle_light: OmniLight3D = $MuzzleLight
@onready var _clip: Node3D = $Model/Clip
@onready var _shot_sound: AudioStreamPlayer = $Sounds/Shot
@onready var _charged_shot_sound: AudioStreamPlayer = $Sounds/ChargedShot
@onready var _charge_hum: AudioStreamPlayer = $Sounds/ChargeHum
@onready var _clip_out_sound: AudioStreamPlayer = $Sounds/ClipOut
@onready var _clip_in_sound: AudioStreamPlayer = $Sounds/ClipIn
@onready var _dry_click_sound: AudioStreamPlayer = $Sounds/DryClick


func _ready() -> void:
	_clip_rest = _clip.transform
	_muzzle_light.visible = false
	var converted := _apply_viewmodel_shader()
	_update_pose()
	Log.info("🔫 Viewmodel ready: scene=%s, materials=%d, emitters=%d, clip_bands=%d" % [
		scene_file_path, converted, _emitter_materials.size(), _clip_heat_materials.size()])


## What the weapon is doing, from Weapon every physics frame: how far it is raised (0 lowered for a sprint, 1 ready),
## whether it aims down sights, the charge being held (-1 when none), the reload's progress (-1 when not reloading)
## and the heat in the loaded clip. Reload sounds play as the progress passes their moments.
func set_state(raise: float, aiming: bool, charge: float, reload_progress: float, heat: float) -> void:
	if reload_progress >= 0.0:
		var previous := maxf(_reload_progress, 0.0)
		if previous < CLIP_OUT_START and reload_progress >= CLIP_OUT_START:
			_clip_out_sound.play()
		if previous < CLIP_IN_END and reload_progress >= CLIP_IN_END:
			_clip_in_sound.play()
	_update_charge_hum(charge)
	_raise = raise
	_aiming = aiming
	_charge = charge
	_reload_progress = reload_progress
	_heat = heat


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func play_shot(charge: float) -> void:
	_kick = 1.0
	_kick_charge = charge
	_flash = 1.0
	_muzzle_light.visible = true
	_charge_hum.stop()
	var sound := _charged_shot_sound if charge >= 0.5 else _shot_sound
	sound.pitch_scale = randf_range(0.96, 1.04)
	sound.play()


func play_dry_click() -> void:
	_dry_click_sound.play()


func _process(delta: float) -> void:
	_aim_blend = move_toward(_aim_blend, 1.0 if _aiming else 0.0, delta / aim_time)
	_kick *= exp(-KICK_RECOVERY * delta)
	_flash = maxf(_flash - delta / MUZZLE_FLASH_TIME, 0.0)
	_muzzle_light.light_energy = muzzle_flash_energy * (1.0 + _kick_charge) * _flash
	_muzzle_light.visible = _flash > 0.0
	_update_pose()
	_update_glow()


func _update_pose() -> void:
	var aim := smoothstep(0.0, 1.0, _aim_blend)
	var lowered := 1.0 - smoothstep(0.0, 1.0, _raise)
	var pose_position := hip_position.lerp(aim_position, aim).lerp(lowered_position, lowered)
	var pose_rotation := hip_rotation.lerp(Vector3.ZERO, aim).lerp(lowered_rotation, lowered)
	var turn := _reload_turn_amount()
	pose_position += reload_offset * turn
	pose_rotation += reload_turn * turn
	pose_position.z += lerpf(kick_back.x, kick_back.y, _kick_charge) * _kick
	pose_rotation.x += lerpf(kick_tip.x, kick_tip.y, _kick_charge) * _kick
	transform = Transform3D(Basis.from_euler(pose_rotation * (PI / 180.0)), pose_position)
	_clip.transform = _clip_rest.translated_local(Vector3.DOWN * clip_travel * _clip_out_amount())
	_clip.visible = not (_reload_progress >= CLIP_OUT_END and _reload_progress < CLIP_IN_START)


func _reload_turn_amount() -> float:
	if _reload_progress < 0.0:
		return 0.0
	return smoothstep(0.0, TURN_IN_END, _reload_progress) * (1.0 - smoothstep(TURN_OUT_START, 1.0, _reload_progress))


## How far out of the grip the clip is: sliding out, gone, then the fresh one sliding back in.
func _clip_out_amount() -> float:
	if _reload_progress < 0.0:
		return 0.0
	if _reload_progress < CLIP_IN_START:
		return smoothstep(CLIP_OUT_START, CLIP_OUT_END, _reload_progress)
	return 1.0 - smoothstep(CLIP_IN_START, CLIP_IN_END, _reload_progress)


func _update_glow() -> void:
	var charge := maxf(_charge, 0.0)
	var glow := lerpf(idle_glow, charged_glow, charge * charge) + charged_glow * _flash
	if _reload_progress >= 0.0 and _reload_progress < CLIP_IN_END:
		glow = 0.0
	for material in _emitter_materials:
		material.set_shader_parameter("emission_energy", glow)
	var band := cool_color.lerp(hot_color, _heat)
	for material in _clip_heat_materials:
		material.set_shader_parameter("emission", band)
		material.set_shader_parameter("emission_energy", clip_glow)


func _update_charge_hum(charge: float) -> void:
	if charge <= 0.0:
		if _charge_hum.playing:
			_charge_hum.stop()
		return
	if not _charge_hum.playing:
		_charge_hum.play()
	_charge_hum.pitch_scale = lerpf(0.8, 1.6, charge)


## Swaps every material of the model for the viewmodel shader with the same colours, so the weapon is drawn in
## front of the world, moves the model onto the viewmodel's visual layer, and keeps the materials that glow.
## Returns how many materials were swapped.
func _apply_viewmodel_shader() -> int:
	var converted := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.layers = VISUAL_LAYER
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			var material := ShaderMaterial.new()
			material.shader = VIEWMODEL_SHADER
			if source:
				material.resource_name = source.resource_name
				material.set_shader_parameter("albedo", source.albedo_color)
				material.set_shader_parameter("metallic", source.metallic)
				material.set_shader_parameter("roughness", source.roughness)
				if source.emission_enabled:
					material.set_shader_parameter("emission", source.emission)
					material.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
			if material.resource_name == EMITTER_MATERIAL:
				material.set_shader_parameter("emission", source.emission if source else Color.WHITE)
				_emitter_materials.append(material)
			elif material.resource_name == CLIP_HEAT_MATERIAL:
				_clip_heat_materials.append(material)
			mesh_instance.set_surface_override_material(surface, material)
			converted += 1
	return converted
