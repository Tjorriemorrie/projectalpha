extends GdUnitTestSuite
## Runs a fresh content registry on the fixture packs in content_fixtures/: "valid" holds the packs alpha and beta
## with a test-only kind of content (gadgets), and "broken" holds one of every problem the registry reports.

const ContentRegistryScript := preload("res://autoload/content_registry.gd")
const GadgetDefinition := preload("res://tests/autoload/content_fixtures/gadget_definition.gd")
const FIXTURES := "res://tests/autoload/content_fixtures"
const HALL_SCENE := "res://tests/autoload/content_fixtures/valid/alpha/sections/hall/hall.tscn"


func test_registers_ids_from_paths() -> void:
	var registry := _load("valid")
	assert_array(registry.errors).is_empty()
	assert_array(Array(registry.packs)).is_equal(["alpha", "beta"])
	var hall := registry.get_definition("alpha:hall") as SectionDefinition
	assert_object(hall).is_not_null()
	assert_str(hall.id).is_equal("alpha:hall")
	assert_str(hall.pack).is_equal("alpha")
	assert_str(hall.display_name).is_equal("Alpha hall")
	assert_str(hall.get_scene_path()).is_equal(HALL_SCENE)


func test_same_name_in_two_packs_does_not_clash() -> void:
	var registry := _load("valid")
	var beta_hall := registry.get_definition("beta:hall")
	assert_object(beta_hall).is_not_null()
	assert_str(beta_hall.display_name).is_equal("Beta hall")
	assert_object(beta_hall).is_not_same(registry.get_definition("alpha:hall"))


func test_lists_one_kind_sorted_by_id() -> void:
	var registry := _load("valid")
	assert_array(_ids(registry.get_all(SectionDefinition))).is_equal(["alpha:hall", "beta:hall"])
	assert_array(_ids(registry.get_all(GadgetDefinition))).is_equal(["alpha:widget", "beta:lamp"])
	assert_array(_ids(registry.get_all(ContentDefinition))).is_equal(
		["alpha:hall", "alpha:widget", "beta:hall", "beta:lamp"])


func test_registers_a_new_kind_with_no_change_to_the_registry() -> void:
	var registry := _load("valid")
	var widget := registry.get_definition("alpha:widget") as GadgetDefinition
	assert_object(widget).is_not_null()
	assert_str(widget.display_name).is_equal("Widget")
	assert_int(widget.power).is_equal(3)


func test_ignores_other_resources_in_content_folders() -> void:
	# The widget's folder also holds a material, which is not a definition.
	var registry := _load("valid")
	assert_array(registry.errors).is_empty()
	assert_bool(registry.has_definition("alpha:widget")).is_true()
	assert_bool(registry.has_definition("alpha:widget_paint")).is_false()


func test_unknown_id_returns_null() -> void:
	var registry := _load("valid")
	assert_bool(registry.has_definition("alpha:nothing")).is_false()
	assert_object(registry.get_definition("alpha:nothing")).is_null()
	assert_object(registry.get_definition("hall")).is_null()


func test_reports_broken_content_and_loads_the_rest() -> void:
	var registry := _load("broken")
	assert_array(registry.errors).has_size(4)
	assert_bool(_has_error(registry, "Content folder has no definition: id=alpha:empty")).is_true()
	assert_bool(_has_error(registry, "Content folder has more than one definition: id=alpha:twins")).is_true()
	assert_bool(_has_error(registry, "Content definition has problems: id=alpha:lost")).is_true()
	assert_bool(_has_error(registry, "Section scene not found")).is_true()
	assert_bool(_has_error(registry, "Duplicate content ID: id=alpha:dupe")).is_true()
	# What could be registered still is: the good section, and the first of the duplicates (kind folders load in
	# alphabetical order, so the gadget).
	assert_array(_ids(registry.get_all(ContentDefinition))).is_equal(["alpha:dupe", "alpha:good"])
	assert_bool(is_instance_of(registry.get_definition("alpha:dupe"), GadgetDefinition)).is_true()


func test_reports_a_root_without_packs() -> void:
	var registry := _load("no_such_folder")
	assert_array(registry.errors).has_size(1)
	assert_bool(_has_error(registry, "No content packs found")).is_true()
	assert_array(Array(registry.packs)).is_empty()


func _load(root: String) -> ContentRegistryScript:
	var registry: ContentRegistryScript = auto_free(ContentRegistryScript.new())
	registry.load_content(FIXTURES.path_join(root))
	return registry


func _ids(definitions: Array[ContentDefinition]) -> Array:
	return definitions.map(func(definition: ContentDefinition) -> String: return definition.id)


func _has_error(registry: ContentRegistryScript, text: String) -> bool:
	return Array(registry.errors).any(func(error: String) -> bool: return error.contains(text))
