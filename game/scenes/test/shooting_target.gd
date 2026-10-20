class_name ShootingTarget
extends Node3D
## A shooting target for the test level: a plate on a post, with health. It flashes when hit, tips over when its
## health runs out, and stands back up at full health a few seconds later. Its health shows above it.

## Seconds the plate glows after a hit.
const FLASH_TIME := 0.15
const FLASH_ENERGY := 2.5
## Degrees the plate tips back when it breaks, and seconds it takes to fall or stand up.
const FALL_ANGLE := -85.0
const FALL_TIME := 0.3

## Seconds after breaking before the target stands up again.
@export var reset_time: float = 4.0

var _material: StandardMaterial3D
var _flash: Tween

@onready var _health: Health = $Health
@onready var _plate: Node3D = $Plate
@onready var _hitbox: Hitbox = $Plate/Hitbox
@onready var _plate_mesh: MeshInstance3D = $Plate/Mesh
@onready var _label: Label3D = $Label


func _ready() -> void:
	_material = (_plate_mesh.get_active_material(0) as StandardMaterial3D).duplicate()
	_plate_mesh.material_override = _material
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_show_health()
	Log.info("🎯 Target ready: target=%s, position=%s, health=%.0f, reset_time=%.1f s" % [
		name, global_position, _health.max_health, reset_time])


func get_health() -> Health:
	return _health


func _on_damaged(amount: float, _source_position: Vector3, _part: Hitbox.Part) -> void:
	if _flash:
		_flash.kill()
	_material.emission_energy_multiplier = FLASH_ENERGY
	_flash = create_tween()
	_flash.tween_property(_material, "emission_energy_multiplier", 0.0, FLASH_TIME)
	_show_health()
	Log.info("🎯 Target hit: target=%s, damage=%.1f, health=%.1f" % [name, amount, _health.health])


func _on_died() -> void:
	_hitbox.set_active(false)
	var fall := create_tween()
	fall.tween_property(_plate, "rotation_degrees:x", FALL_ANGLE, FALL_TIME).set_ease(Tween.EASE_IN)
	get_tree().create_timer(reset_time).timeout.connect(_stand_up)
	_show_health()
	Log.info("🎯 Target broken: target=%s, stands up in %.1f s" % [name, reset_time])


func _stand_up() -> void:
	if not is_inside_tree():
		return
	var rise := create_tween()
	rise.tween_property(_plate, "rotation_degrees:x", 0.0, FALL_TIME).set_ease(Tween.EASE_OUT)
	_health.reset()
	_hitbox.set_active(true)
	_show_health()
	Log.info("🎯 Target reset: target=%s, health=%.0f" % [name, _health.health])


func _show_health() -> void:
	_label.text = "%s\n%s" % [name, "broken" if _health.is_dead() else "%d" % ceili(_health.health)]
