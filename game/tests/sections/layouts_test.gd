extends GdUnitTestSuite
## Loads every wreck layout, boarded at its highest level from a fixed seed, and checks what they all need: they
## assemble cleanly with one airlock and the player in it, they have enough markers for the robots and containers
## they roll (robot markers counted clear of the airlock), every loot marker takes its biggest container clear of
## the walls and facing the room, drones get navigation on every deck, and a level-1 roll holds a gun. hauler_test
## plays one layout through.

const LAYOUTS := [["base:courier"], ["base:hauler"], ["base:freighter"]]
const SEED := 5

var _runner: GdUnitSceneRunner
var _layout: WreckDefinition
var _wreck: Wreck


func after_test() -> void:
	GameSession.travel_enabled = true
	GameSession.new_game()


func test_assembles_cleanly_with_the_player_in_its_airlock(id: String, test_parameters := LAYOUTS) -> void:
	await _board(id, _layout_of(id).levels.y)
	assert_array(_wreck.assembly_errors).is_empty()
	assert_int(_wreck.airlocks.size()).is_equal(1)
	var player := _runner.find_child("Player") as Player
	var airlock := _wreck.airlocks[0]
	assert_that(WreckAssembly.to_cell(player.global_position)).is_equal(
		WreckAssembly.to_cell(airlock.global_position))
	# Facing the inner door, into the wreck.
	var to_door := airlock.get_sockets()[0].global_position - player.global_position
	assert_float((-player.global_basis.z).dot(to_door.normalized())).is_greater(0.9)


func test_has_markers_for_everything_it_rolls(id: String, test_parameters := LAYOUTS) -> void:
	await _board(id, _layout_of(id).levels.y)
	var most_robots := 0
	for count in _layout.expected_robots:
		most_robots = maxi(most_robots, count + WreckRoll.ROBOT_SPREAD)
	var markers: Array[Node] = _wreck.find_children("*", "SectionMarker", true, false)
	var door := _wreck.airlocks[0].get_sockets()[0].global_position
	var robot_markers := markers.filter(func(marker: SectionMarker) -> bool:
		return marker.kind == SectionMarker.Kind.ENEMY \
			and marker.global_position.distance_to(door) >= Wreck.AIRLOCK_CLEARANCE)
	var loot_markers := markers.filter(func(marker: SectionMarker) -> bool:
		return marker.kind == SectionMarker.Kind.LOOT)
	# Room to spare, so robots and containers move around from run to run (a full hauler leaves one marker empty).
	assert_int(robot_markers.size()).is_greater_equal(most_robots + 1)
	assert_int(loot_markers.size()).is_greater_equal(_layout.containers + 3)
	assert_int(_wreck.containers.size()).is_equal(_layout.containers)
	assert_int(_wreck.robots.size()).is_equal(_wreck.roll.robots)


func test_every_loot_marker_takes_its_biggest_container(id: String, test_parameters := LAYOUTS) -> void:
	await _board(id, _layout_of(id).levels.y)
	for container in _wreck.containers:
		container.free()
	_wreck.containers.clear()
	var placements: Array[LootPlacement] = []
	for marker: SectionMarker in _wreck.find_children("*", "SectionMarker", true, false):
		if marker.kind != SectionMarker.Kind.LOOT:
			continue
		var placement := LootPlacement.new()
		placement.marker = str(_wreck.get_path_to(marker))
		placement.container = "base:locker" if marker.space == SectionMarker.Space.ROOM else "base:small_case"
		placements.append(placement)
	_wreck.loot = placements
	_wreck.place_loot()
	await _physics_frames(2)
	assert_array(_wreck.assembly_errors).is_empty()
	var space := _wreck.get_world_3d().direct_space_state
	for container in _wreck.containers:
		var body := container.get_node("CollisionShape3D") as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = (body.shape as BoxShape3D).size - Vector3.ONE * 0.04
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.transform = body.global_transform
		query.collision_mask = 1
		query.exclude = [container.get_rid()]
		assert_array(space.intersect_shape(query)).override_failure_message(
			"%s overlaps the level in %s" % [container.name, id]).is_empty()
		var front := container.global_transform * Vector3(0.0, 0.1, -box.size.z - 0.05)
		var ray := PhysicsRayQueryParameters3D.create(front, front - container.global_basis.z * 0.4, 1)
		assert_dict(space.intersect_ray(ray)).override_failure_message(
			"%s faces a wall in %s" % [container.name, id]).is_empty()


func test_bakes_navigation_for_every_deck(id: String, test_parameters := LAYOUTS) -> void:
	await _board(id, _layout_of(id).levels.y)
	var decks := {}
	for section in _wreck.sections:
		for cell in section.get_cells():
			decks[cell.y] = true
	assert_int(_wreck.navigation_regions.size()).is_equal(decks.size())
	for region in _wreck.navigation_regions:
		assert_int(region.navigation_mesh.get_polygon_count()).is_greater(0)


func test_a_level_one_roll_holds_a_gun(id: String, test_parameters := [["base:courier"], ["base:hauler"]]) -> void:
	await _board(id, 1)
	for attempt in 20:
		_wreck.apply_roll(WreckRoll.new(_layout, 1, SEED + attempt))
		var guns := 0
		for placement in _wreck.loot:
			for item in placement.items:
				if ContentRegistry.get_definition(item) is WeaponDefinition:
					guns += 1
		assert_int(guns).override_failure_message("%s seed %d holds no gun" % [id, SEED + attempt]) \
			.is_greater_equal(1)


func _layout_of(id: String) -> WreckDefinition:
	return ContentRegistry.get_definition(id) as WreckDefinition


## Boards a layout at a level, the way the ship does, and loads it with its robots taken out once navigation is baked.
func _board(id: String, level: int, roll_seed := SEED) -> void:
	_layout = _layout_of(id)
	GameSession.new_game()
	GameSession.travel_enabled = false
	GameSession.docked = WreckRoll.new(_layout, level, roll_seed)
	GameSession.board(Inventory.new())
	_runner = scene_runner(_layout.get_scene_path())
	_wreck = _runner.scene() as Wreck
	await _physics_frames(2)
	for robot in _wreck.robots:
		robot.queue_free()
	await _physics_frames(1)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
