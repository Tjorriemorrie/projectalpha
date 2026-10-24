extends GdUnitTestSuite
## Checks the base game's own content as the ContentRegistry autoload registered it at startup.

const KIT_SECTIONS: Array[String] = [
	"base:airlock", "base:cargo_bay", "base:cockpit", "base:corridor_corner", "base:corridor_cross", "base:corridor_end",
	"base:corridor_straight", "base:corridor_t", "base:elevator", "base:room_large", "base:room_small",
	"base:vent_corner", "base:vent_straight"]
const ITEMS: Array[String] = [
	"base:circuit_board", "base:conduit", "base:data_drive", "base:gyroscope", "base:hull_plating",
	"base:laser_pistol", "base:plasma_coil", "base:power_cell", "base:servo_motor", "base:spent_thermal_clip",
	"base:thermal_clip"]


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


func test_every_item_has_a_value_a_stack_size_and_a_model_on_the_floor() -> void:
	for definition: ItemDefinition in ContentRegistry.get_all(ItemDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		assert_int(definition.value).override_failure_message("%s has no value" % definition.id).is_greater(0)
		assert_int(definition.stack_size).override_failure_message(
			"%s has no stack size" % definition.id).is_greater_equal(1)
		var model: Node3D = auto_free((load(definition.get_model_path()) as PackedScene).instantiate())
		var bounds := DroppedItem.model_bounds(model)
		# It stands on the floor, its footprint round its origin.
		assert_float(bounds.get_center().x).override_failure_message(
			"%s is off centre" % definition.id).is_equal_approx(0.0, 0.03)
		assert_float(bounds.position.y).override_failure_message(
			"%s doesn't stand on the floor" % definition.id).is_equal_approx(0.0, 0.005)


func test_stacks_are_set_by_bulk_and_only_clips_are_ammo() -> void:
	var stacks := {"base:circuit_board": 4, "base:conduit": 3, "base:data_drive": 5, "base:gyroscope": 2,
		"base:hull_plating": 2, "base:laser_pistol": 1, "base:plasma_coil": 2, "base:power_cell": 2,
		"base:servo_motor": 3, "base:spent_thermal_clip": 5, "base:thermal_clip": 5}
	for id: String in stacks:
		var definition := ContentRegistry.get_definition(id) as ItemDefinition
		assert_int(definition.stack_size).override_failure_message("%s stacks wrong" % id).is_equal(stacks[id])
		assert_bool(definition.ammo).override_failure_message("%s is ammo or isn't" % id).is_equal(
			id.ends_with("thermal_clip"))
	assert_str((ContentRegistry.get_definition("base:hull_plating") as ItemDefinition).name_for(2)).is_equal(
		"2 hull plating")
	assert_str((ContentRegistry.get_definition("base:circuit_board") as ItemDefinition).name_for(3)).is_equal(
		"3 circuit boards")


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


func test_registers_the_wreck_layouts() -> void:
	var ids := ContentRegistry.get_all(WreckDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(["base:courier", "base:freighter", "base:hauler"])


func test_every_wreck_scene_has_a_wreck_root() -> void:
	for definition: WreckDefinition in ContentRegistry.get_all(WreckDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var root: Node = auto_free((load(definition.get_scene_path()) as PackedScene).instantiate())
		assert_bool(root is Wreck).override_failure_message(
			"%s's scene root is not a Wreck" % definition.id).is_true()


func test_every_loot_table_draws_registered_items_within_reach() -> void:
	for definition: ContainerDefinition in ContentRegistry.get_all(ContainerDefinition):
		assert_int(definition.budget).override_failure_message("%s has no budget" % definition.id).is_greater(0)
		assert_dict(definition.loot).override_failure_message("%s has no loot table" % definition.id).is_not_empty()
		for id in definition.loot:
			var item := ContentRegistry.get_definition(id) as ItemDefinition
			assert_object(item).override_failure_message(
				"%s's loot table names %s, which isn't an item" % [definition.id, id]).is_not_null()
			# Every item can turn up at the highest level a wreck reaches today, or the table lies.
			assert_int(item.value).override_failure_message(
				"%s's %s never fits its budget" % [definition.id, id]).is_less_equal(
					LootRoll.budget_for(definition.budget, 3))


func test_bigger_containers_get_bigger_budgets() -> void:
	var case := ContentRegistry.get_definition("base:small_case") as ContainerDefinition
	var crate := ContentRegistry.get_definition("base:supply_crate") as ContainerDefinition
	var locker := ContentRegistry.get_definition("base:locker") as ContainerDefinition
	assert_int(case.budget).is_less(crate.budget)
	assert_int(crate.budget).is_less(locker.budget)


func test_registers_the_fifty_star_systems_of_the_galaxy() -> void:
	var systems := ContentRegistry.get_all(StarSystemDefinition)
	assert_int(systems.size()).is_equal(50)
	var map_ids := {}
	for definition: StarSystemDefinition in systems:
		assert_str(definition.display_name).override_failure_message(
			"%s has no name" % definition.id).is_not_empty()
		assert_int(definition.places.size()).override_failure_message(
			"%s has %d places" % [definition.id, definition.places.size()]).is_between(
				StarSystemDefinition.MIN_PLACES, StarSystemDefinition.MAX_PLACES)
		map_ids[definition.map_id] = definition.id
	assert_int(map_ids.size()).is_equal(50)


func test_star_systems_hold_what_galaxy_md_says() -> void:
	var praetor := ContentRegistry.get_definition("base:praetor") as StarSystemDefinition
	assert_str(praetor.map_id).is_equal("H2")
	assert_int(praetor.star).is_equal(StarSystemDefinition.Star.YELLOW)
	assert_int(praetor.owner).is_equal(StarSystemDefinition.Owner.HALDEN_MORI)
	var names := praetor.places.map(func(place: SystemPlace) -> String: return place.display_name)
	assert_array(names).is_equal(["Praetor I", "Hearth", "Calloway", "Praetor IV", "the Granary", "Dray's Gate"])
	assert_bool(praetor.places[1].habitable).is_true()
	assert_int(praetor.places[2].kind).is_equal(SystemPlace.Kind.MOON)
	assert_int(praetor.places[4].kind).is_equal(SystemPlace.Kind.BELT)
	assert_int(praetor.places[5].kind).is_equal(SystemPlace.Kind.STATION)
	var goldenrod := ContentRegistry.get_definition("base:goldenrod") as StarSystemDefinition
	assert_int(goldenrod.owner).is_equal(StarSystemDefinition.Owner.CONTESTED)
	assert_int(goldenrod.places[3].kind).is_equal(SystemPlace.Kind.BATTLEFIELD)
	assert_str(goldenrod.places[3].display_name).is_equal("the Long Fall")
	var kr_207 := ContentRegistry.get_definition("base:kr_207") as StarSystemDefinition
	assert_int(kr_207.star).is_equal(StarSystemDefinition.Star.NEUTRON)
	assert_str(kr_207.places[0].display_name).is_equal("KR-207 I")
	assert_int(kr_207.places[1].kind).is_equal(SystemPlace.Kind.ANOMALY)
