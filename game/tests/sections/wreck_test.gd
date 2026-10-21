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


func test_reports_enemies_that_cant_be_placed() -> void:
	var wreck: Wreck = auto_free(Wreck.new())
	var room: Section = load("res://content/base/sections/room_small/room_small.tscn").instantiate()
	room.name = "Room"
	wreck.add_child(room)
	wreck.enemies = {
		"Room/LootSpotWest": "base:drone",
		"Room/EnemySpot": "base:nothing",
		"Room/TurretMount": "base:drone",
		"Room/Nowhere": "base:turret",
	}

	add_child(wreck)

	assert_array(wreck.robots).is_empty()
	assert_array(wreck.assembly_errors).contains_exactly_in_any_order([
		"Not an enemy marker: marker=Room/LootSpotWest, enemy=base:drone",
		"Not a registered enemy: marker=Room/EnemySpot, enemy=base:nothing",
		"Enemy doesn't fit its marker: marker=Room/TurretMount, enemy=base:drone, mount=FLOOR, marker_mount=CEILING",
		"Not an enemy marker: marker=Room/Nowhere, enemy=base:turret",
	])


func test_places_enemies_on_their_markers() -> void:
	var wreck: Wreck = auto_free(Wreck.new())
	var room: Section = load("res://content/base/sections/room_small/room_small.tscn").instantiate()
	room.name = "Room"
	room.position = Vector3(8.0, 0.0, 0.0)
	wreck.add_child(room)
	wreck.enemies = {"Room/TurretMount": "base:turret"}

	add_child(wreck)

	assert_array(wreck.assembly_errors).is_empty()
	assert_int(wreck.robots.size()).is_equal(1)
	var turret := wreck.robots[0]
	assert_bool(turret is Turret).is_true()
	assert_str(turret.definition.id).is_equal("base:turret")
	assert_vector(turret.global_position).is_equal_approx(Vector3(8.0, 3.0, -1.5), Vector3.ONE * 0.001)
