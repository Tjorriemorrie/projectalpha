extends GdUnitTestSuite
## Assembles wrecks built in code, for the checks the hand-built layouts can't show: unregistered sections,
## and placing robots and loot on markers, with the problems each can report.

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


func test_places_loot_on_its_markers() -> void:
	var wreck: Wreck = auto_free(Wreck.new())
	var room: Section = load("res://content/base/sections/room_small/room_small.tscn").instantiate()
	room.name = "Room"
	room.position = Vector3(8.0, 0.0, 0.0)
	wreck.add_child(room)
	wreck.loot = [_placement("Room/LootSpotWest", "base:locker", ["base:gyroscope", "base:thermal_clip"])]

	add_child(wreck)

	assert_array(wreck.assembly_errors).is_empty()
	assert_int(wreck.containers.size()).is_equal(1)
	var locker := wreck.containers[0]
	assert_str(locker.name).is_equal("Locker_Room")
	assert_str(locker.definition.id).is_equal("base:locker")
	# It stands against the room's north wall, facing into the room.
	assert_vector(locker.global_position).is_equal_approx(Vector3(6.75, 0.0, -1.8), Vector3.ONE * 0.001)
	assert_vector(-locker.global_basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.001)
	assert_int(locker.get_lootable().grid.items.size()).is_equal(2)


func test_reports_loot_that_cant_be_placed() -> void:
	var wreck: Wreck = auto_free(Wreck.new())
	var room: Section = load("res://content/base/sections/room_small/room_small.tscn").instantiate()
	room.name = "Room"
	wreck.add_child(room)
	var nook := SectionMarker.new()
	nook.name = "Nook"
	nook.space = SectionMarker.Space.TIGHT
	room.add_child(nook)
	wreck.loot = [
		_placement("Room/EnemySpot", "base:supply_crate", []),
		_placement("Room/LootSpotWest", "base:nothing", []),
		_placement("Room/Nook", "base:locker", []),
		_placement("Room/LootSpotEast", "base:small_case",
			["base:plasma_coil", "base:unknown", "base:gyroscope", "base:power_cell", "base:data_drive"]),
	]

	add_child(wreck)

	assert_int(wreck.containers.size()).is_equal(1)
	# The small case has three slots.
	assert_int(wreck.containers[0].get_lootable().grid.items.size()).is_equal(3)
	assert_array(wreck.assembly_errors).contains_exactly_in_any_order([
		"Not a loot marker: marker=Room/EnemySpot, container=base:supply_crate",
		"Not a registered container: marker=Room/LootSpotWest, container=base:nothing",
		"Container doesn't fit its marker: marker=Room/Nook, container=base:locker, space=TIGHT",
		"Not a registered item: marker=Room/LootSpotEast, item=base:unknown",
		"Item doesn't fit its container: marker=Room/LootSpotEast, container=base:small_case, item=base:data_drive",
	])


static func _placement(marker: String, container: String, items: Array) -> LootPlacement:
	var placement := LootPlacement.new()
	placement.marker = marker
	placement.container = container
	placement.items = PackedStringArray(items)
	return placement
