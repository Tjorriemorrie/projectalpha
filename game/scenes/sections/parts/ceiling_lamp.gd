class_name CeilingLamp
extends Node3D
## A dim lamp under the ceiling: a glowing fixture and a shadow-casting spot light pointing down, so walls stop
## its light. Some lamps flicker in short bursts. Which ones is decided from the lamp's position, so the same
## lamps flicker on every run. Its origin is the ceiling surface.

## Chance that this lamp flickers.
@export_range(0.0, 1.0) var flicker_chance := 0.25
## Seconds between flicker bursts.
@export var burst_interval := Vector2(1.5, 6.0)
## Seconds a flicker burst lasts.
@export var burst_length := Vector2(0.15, 0.9)

var flickering := false

var _rng := RandomNumberGenerator.new()
var _base_energy := 0.0
var _base_emission := 0.0
var _next_burst := 0.0
var _burst_left := 0.0
var _flick_left := 0.0
var _material: StandardMaterial3D

@onready var _light: SpotLight3D = $SpotLight3D
@onready var _fixture: MeshInstance3D = $Fixture


func _ready() -> void:
	_rng.seed = hash(global_position.snapped(Vector3.ONE * 0.01))
	flickering = _rng.randf() < flicker_chance
	_base_energy = _light.light_energy
	_next_burst = _rng.randf_range(burst_interval.x, burst_interval.y)
	set_process(flickering)
	if flickering:
		# Only flickering lamps get their own material, so steady lamps keep sharing one.
		_material = (_fixture.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
		_base_emission = _material.emission_energy_multiplier
		_fixture.material_override = _material


## Makes it a steady lamp of this colour that never flickers, its light energy_scale times as strong, such as the
## ship's warm lamps. Its fixture glows in the same colour.
func set_steady(color: Color, energy_scale: float = 1.0) -> void:
	flickering = false
	set_process(false)
	_base_energy *= energy_scale
	_light.light_color = color
	_light.light_energy = _base_energy
	_material = (_fixture.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_material.albedo_color = color
	_material.emission = color
	_fixture.material_override = _material
	Log.info("💡 Lamp made steady: lamp=%s/%s, color=%s, energy=%.2f" % [get_parent().name, name, color, _base_energy])


## Runs every frame on flickering lamps only, so it doesn't log.
func _process(delta: float) -> void:
	if _burst_left <= 0.0:
		_next_burst -= delta
		if _next_burst <= 0.0:
			_burst_left = _rng.randf_range(burst_length.x, burst_length.y)
		return
	_burst_left -= delta
	_flick_left -= delta
	if _burst_left <= 0.0:
		_set_brightness(1.0)
		_next_burst = _rng.randf_range(burst_interval.x, burst_interval.y)
	elif _flick_left <= 0.0:
		_flick_left = _rng.randf_range(0.03, 0.12)
		_set_brightness(_rng.randf_range(0.0, 0.3) if _rng.randf() < 0.6 else 1.0)


func _set_brightness(brightness: float) -> void:
	_light.light_energy = _base_energy * brightness
	_material.emission_energy_multiplier = _base_emission * brightness
