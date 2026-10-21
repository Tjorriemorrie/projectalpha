extends GdUnitTestSuite
## Checks the base game's own content as the ContentRegistry autoload registered it at startup.

const KIT_SECTIONS: Array[String] = [
	"base:airlock", "base:cockpit", "base:corridor_corner", "base:corridor_end", "base:corridor_straight",
	"base:corridor_t", "base:elevator", "base:room_large", "base:room_small", "base:vent_corner", "base:vent_straight"]
const ITEMS: Array[String] = [
	"base:circuit_board", "base:conduit", "base:data_drive", "base:gyroscope", "base:hull_plating",
	"base:plasma_coil", "base:power_cell", "base:servo_motor", "base:spent_thermal_clip", "base:thermal_clip"]


func test_loads_without_errors() -> void:
	assert_array(ContentRegistry.errors).is_empty()
	assert_array(Array(ContentRegistry.packs)).is_equal(["base"])


func test_registers_every_kit_section() -> void:
	var ids := ContentRegistry.get_all(SectionDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(KIT_SECTIONS)


func test_registers_the_laser_pistol() -> void:
	var ids := ContentRegistry.get_all(WeaponDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(["base:laser_pistol"])


func test_registers_the_robots() -> void:
	var ids := ContentRegistry.get_all(EnemyDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(["base:drone", "base:turret"])


func test_every_enemy_scene_has_a_robot_root() -> void:
	for definition: EnemyDefinition in ContentRegistry.get_all(EnemyDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var scene := load(definition.get_scene_path()) as PackedScene
		assert_object(scene).override_failure_message("%s has no scene" % definition.id).is_not_null()
		var root: Node = auto_free(scene.instantiate())
		assert_bool(root is Robot).override_failure_message(
			"%s's scene root is not a Robot" % definition.id).is_true()


func test_every_weapon_viewmodel_has_a_viewmodel_root() -> void:
	for definition: WeaponDefinition in ContentRegistry.get_all(WeaponDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var scene := load(definition.get_viewmodel_path()) as PackedScene
		assert_object(scene).override_failure_message("%s has no viewmodel" % definition.id).is_not_null()
		var root: Node = auto_free(scene.instantiate())
		assert_bool(root is WeaponViewmodel).override_failure_message(
			"%s's viewmodel root is not a WeaponViewmodel" % definition.id).is_true()


func test_every_section_scene_has_a_section_root() -> void:
	for definition: SectionDefinition in ContentRegistry.get_all(SectionDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var scene := load(definition.get_scene_path()) as PackedScene
		assert_object(scene).override_failure_message("%s has no scene" % definition.id).is_not_null()
		var root: Node = auto_free(scene.instantiate())
		assert_bool(root is Section).override_failure_message(
			"%s's scene root is not a Section" % definition.id).is_true()


func test_registers_the_items() -> void:
	var ids := ContentRegistry.get_all(ItemDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(ITEMS)


func test_every_item_model_is_built_to_its_shape() -> void:
	for definition: ItemDefinition in ContentRegistry.get_all(ItemDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		assert_int(definition.value).override_failure_message("%s has no value" % definition.id).is_greater(0)
		var model: Node3D = auto_free((load(definition.get_model_path()) as PackedScene).instantiate())
		var bounds := AABB()
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			bounds = bounds.merge(mesh.transform * mesh.get_aabb())
		# Seen from above it covers its cells, give or take a few millimetres of bevel.
		var footprint := Vector2(ItemShape.size_of(definition.get_cells())) * ItemDefinition.CELL_SIZE
		assert_float(bounds.size.x).override_failure_message("%s is too wide" % definition.id).is_less_equal(
			footprint.x + 0.01)
		assert_float(bounds.size.z).override_failure_message("%s is too deep" % definition.id).is_less_equal(
			footprint.y + 0.01)
		assert_float(bounds.get_center().x).is_equal_approx(0.0, 0.03)
		assert_float(bounds.position.y).is_equal_approx(0.0, 0.005)


func test_registers_the_containers() -> void:
	var ids := ContentRegistry.get_all(ContainerDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(["base:locker", "base:small_case", "base:supply_crate"])


func test_every_container_scene_has_a_container_root_with_a_lid() -> void:
	for definition: ContainerDefinition in ContentRegistry.get_all(ContainerDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var root: Node = auto_free((load(definition.get_scene_path()) as PackedScene).instantiate())
		assert_bool(root is LootContainer).override_failure_message(
			"%s's scene root is not a LootContainer" % definition.id).is_true()
		assert_object(root.get_node_or_null("%Lootable") as Lootable).override_failure_message(
			"%s has no Lootable" % definition.id).is_not_null()
		assert_object(root.get_node("%Model").find_child("Lid", true, false)).override_failure_message(
			"%s's model has no Lid" % definition.id).is_not_null()


func test_the_pistol_loads_registered_clips() -> void:
	var pistol := ContentRegistry.get_definition("base:laser_pistol") as WeaponDefinition
	var fresh := ContentRegistry.get_definition(pistol.clip_item) as ItemDefinition
	var spent := ContentRegistry.get_definition(pistol.spent_clip_item) as ItemDefinition
	assert_object(fresh).is_not_null()
	assert_object(spent).is_not_null()


func test_robot_salvage_fits_their_wreckage() -> void:
	for definition: EnemyDefinition in ContentRegistry.get_all(EnemyDefinition):
		assert_array(Array(definition.salvage)).override_failure_message(
			"%s has no salvage" % definition.id).is_not_empty()
		var grid := ItemGrid.new(definition.salvage_grid)
		for id in definition.salvage:
			var part := ContentRegistry.get_definition(id) as ItemDefinition
			assert_object(part).override_failure_message("%s salvage %s isn't an item" % [definition.id, id]) \
				.is_not_null()
			assert_bool(grid.add(Item.new(part))).override_failure_message(
				"%s salvage %s doesn't fit" % [definition.id, id]).is_true()
