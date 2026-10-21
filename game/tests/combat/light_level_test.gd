extends GdUnitTestSuite
## Unit tests for LightLevel: Godot's light falloff and spot cone, which lights count, and walls casting shadows.
## A spot lamp hangs 2.5 m up, pointing down, as in a corridor.

const TOLERANCE := 0.001
const LAMP_HEIGHT := 2.5

var _lamp: SpotLight3D


func before_test() -> void:
	_lamp = auto_free(SpotLight3D.new())
	_lamp.light_energy = 1.2
	_lamp.spot_range = 5.5
	_lamp.spot_angle = 65.0
	add_child(_lamp)
	_lamp.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0.0, LAMP_HEIGHT, 0.0))
	_lamp.add_to_group(LightLevel.GROUP)


func test_attenuation_reaches_zero_at_the_range() -> void:
	assert_float(LightLevel.attenuation(1.0, 5.0, 1.0)).is_greater(0.9)
	assert_float(LightLevel.attenuation(4.99, 5.0, 1.0)).is_less(0.01)
	assert_float(LightLevel.attenuation(6.0, 5.0, 1.0)).is_equal(0.0)


func test_cone_is_full_on_the_axis_and_empty_outside() -> void:
	assert_float(LightLevel.cone(1.0, 45.0, 1.0)).is_equal_approx(1.0, TOLERANCE)
	assert_float(LightLevel.cone(cos(deg_to_rad(50.0)), 45.0, 1.0)).is_equal(0.0)


func test_under_the_lamp_is_lit_and_far_from_it_dark() -> void:
	var space := _space()
	assert_bool(LightLevel.is_lit(space, get_tree(), Vector3(0.0, 1.0, 0.0))).is_true()
	assert_bool(LightLevel.is_lit(space, get_tree(), Vector3(6.0, 1.0, 0.0))).is_false()


func test_outside_the_cone_is_dark() -> void:
	# 70° off the lamp's axis, outside its 65° cone, though well within its range.
	var point := Vector3(sin(deg_to_rad(70.0)), -cos(deg_to_rad(70.0)), 0.0) * 2.0 + _lamp.global_position
	assert_float(LightLevel.light_from(_lamp, point)).is_equal(0.0)


func test_hidden_or_dimmed_lamps_dont_light() -> void:
	var space := _space()
	_lamp.visible = false
	assert_bool(LightLevel.is_lit(space, get_tree(), Vector3(0.0, 1.0, 0.0))).is_false()
	_lamp.visible = true
	_lamp.light_energy = 0.0
	assert_bool(LightLevel.is_lit(space, get_tree(), Vector3(0.0, 1.0, 0.0))).is_false()


func test_lights_outside_the_group_dont_count() -> void:
	_lamp.remove_from_group(LightLevel.GROUP)
	assert_bool(LightLevel.is_lit(_space(), get_tree(), Vector3(0.0, 1.0, 0.0))).is_false()


func test_a_wall_in_between_casts_a_shadow() -> void:
	var slab: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.1, 2.0)
	shape.shape = box
	slab.add_child(shape)
	add_child(slab)
	slab.global_position = Vector3(0.0, 1.8, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(LightLevel.is_lit(_space(), get_tree(), Vector3(0.0, 1.0, 0.0))).is_false()


func _space() -> PhysicsDirectSpaceState3D:
	return get_tree().root.get_world_3d().direct_space_state
