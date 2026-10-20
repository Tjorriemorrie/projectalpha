extends GdUnitTestSuite
## Assembles wrecks built in code, for the checks the hand-built small wreck can't show.

const UNREGISTERED_SCENE := "res://tests/autoload/content_fixtures/valid/alpha/sections/hall/hall.tscn"


func test_reports_unregistered_sections() -> void:
	var wreck: Wreck = auto_free(Wreck.new())
	var registered: Section = load("res://content/base/sections/room_small/room_small.tscn").instantiate()
	registered.name = "Registered"
	wreck.add_child(registered)
	var unregistered: Section = load(UNREGISTERED_SCENE).instantiate()
	unregistered.name = "Unregistered"
	unregistered.position = Vector3(8.0, 0.0, 0.0)
	wreck.add_child(unregistered)
	var bare := Section.new()
	bare.name = "Bare"
	bare.position = Vector3(16.0, 0.0, 0.0)
	wreck.add_child(bare)

	add_child(wreck)

	assert_array(wreck.assembly_errors).contains_exactly_in_any_order([
		"Section is not a registered section: section=Unregistered, scene=%s" % UNREGISTERED_SCENE,
		"Section is not a registered section: section=Bare, scene=",
	])
