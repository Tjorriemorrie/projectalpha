extends GdUnitTestSuite
## Checks the base game's own content as the ContentRegistry autoload registered it at startup.

const KIT_SECTIONS: Array[String] = [
	"base:airlock", "base:corridor_corner", "base:corridor_end", "base:corridor_straight", "base:corridor_t",
	"base:elevator", "base:room_large", "base:room_small", "base:vent_corner", "base:vent_straight"]


func test_loads_without_errors() -> void:
	assert_array(ContentRegistry.errors).is_empty()
	assert_array(Array(ContentRegistry.packs)).is_equal(["base"])


func test_registers_every_kit_section() -> void:
	var ids := ContentRegistry.get_all(SectionDefinition).map(func(definition: ContentDefinition) -> String:
		return definition.id)
	assert_array(ids).is_equal(KIT_SECTIONS)


func test_every_section_scene_has_a_section_root() -> void:
	for definition: SectionDefinition in ContentRegistry.get_all(SectionDefinition):
		assert_str(definition.display_name).override_failure_message(
			"%s has no display name" % definition.id).is_not_empty()
		var scene := load(definition.get_scene_path()) as PackedScene
		assert_object(scene).override_failure_message("%s has no scene" % definition.id).is_not_null()
		var root: Node = auto_free(scene.instantiate())
		assert_bool(root is Section).override_failure_message(
			"%s's scene root is not a Section" % definition.id).is_true()
