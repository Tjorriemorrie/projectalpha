extends GdUnitTestSuite
## Plays looting in the loot test level: the containers it places, prying one open by holding interact (and letting
## go or looking away), the noise it makes, searching an open one, standing still while the inventory is open,
## dropping a stack, finding it on the inventory screen's floor and dragging it back, and reloading from the ammo
## slots, with a spent clip that has no room dropping on the floor.
## Positions refer to the layout of res://scenes/test/loot_test.tscn: the store room is the cell round the origin,
## with a locker against its north wall at x = -1.25 and a supply crate at x = 1.25, both facing south; the corridor
## runs south from its doorway at z = 2 to the entrance stub, which holds a small case; a vent leads east from the
## store room to a closet and holds another case.

const TEST_SCENE := "res://scenes/test/loot_test.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"pause", &"move_forward", &"shoot", &"reload"]
## Physics frames per second of game time at the runner's time factor.
const FRAMES_PER_SECOND := 60
## A metre in front of the locker, and the middle of its door.
const BEFORE_LOCKER := Vector3(-1.25, 0.0, -0.2)
const LOCKER_DOOR := Vector3(-1.25, 1.2, -1.3)
## In the corridor, with two metres of floor in front (north) to drop things on.
const IN_CORRIDOR := Vector3(0.0, 0.0, 4.0)

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _locker: Lootable


func before_test() -> void:
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	_locker = _wreck.containers[0].get_lootable()
	await _physics_frames(2)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func test_places_and_fills_the_containers() -> void:
	assert_array(_wreck.assembly_errors).is_empty()
	var names := _wreck.containers.map(func(container: LootContainer) -> String: return container.name)
	assert_array(names).contains_exactly(["Locker_Store", "SupplyCrate_Store", "SmallCase_Entrance", "SmallCase_Vent"])
	assert_vector(Vector2(_locker.grid.size)).is_equal(Vector2(3, 3))
	# The two thermal clips share a stack.
	assert_int(_locker.grid.items.size()).is_equal(3)
	assert_int(_locker.grid.count(_item("base:thermal_clip"))).is_equal(2)
	assert_int(_wreck.containers[3].get_lootable().grid.count(_item("base:plasma_coil"))).is_equal(1)
	assert_bool(_locker.is_open).is_false()


func test_containers_stand_clear_of_walls_facing_the_room() -> void:
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
			"%s overlaps the level" % container.name).is_empty()
		# Its front faces open floor, not a wall.
		var front := container.global_transform * Vector3(0.0, 0.1, -box.size.z - 0.05)
		var ray := PhysicsRayQueryParameters3D.create(front, front - container.global_basis.z * 0.4, 1)
		assert_dict(space.intersect_ray(ray)).override_failure_message(
			"%s faces a wall" % container.name).is_empty()


func test_holding_interact_pries_open_after_its_time() -> void:
	await _look_at_locker()
	assert_str(_hud().prompt_text).is_equal("Hold E Pry open locker")
	Input.action_press(&"interact")
	await _physics_frames(roundi(1.2 * FRAMES_PER_SECOND))
	assert_bool(_locker.is_open).is_false()
	await _physics_frames(roundi(0.4 * FRAMES_PER_SECOND))
	assert_bool(_locker.is_open).is_true()
	assert_bool(_player.is_inventory_open()).is_true()
	assert_object(_player.get_inventory_screen().loot).is_same(_locker)


func test_letting_go_cancels_prying() -> void:
	await _look_at_locker()
	Input.action_press(&"interact")
	await _physics_frames(FRAMES_PER_SECOND)
	Input.action_release(&"interact")
	await _physics_frames(2)
	Input.action_press(&"interact")
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(_locker.is_open).is_false()
	await _physics_frames(roundi(0.6 * FRAMES_PER_SECOND))
	assert_bool(_locker.is_open).is_true()


func test_looking_away_cancels_prying() -> void:
	await _look_at_locker()
	Input.action_press(&"interact")
	await _physics_frames(FRAMES_PER_SECOND)
	_player.set_look(PI)
	await _physics_frames(3)
	# Still holding interact, but a hold only starts with a fresh press on the container.
	await _look_at_locker()
	await _physics_frames(FRAMES_PER_SECOND)
	assert_bool(_locker.is_open).is_false()


func test_prying_open_is_a_noise() -> void:
	var ear := _add_ear(Vector3(1.0, 0.0, 0.0))
	await _pry_locker()
	assert_array(ear.heard).contains([&"pry"])


func test_an_open_container_is_searched_straight_away() -> void:
	await _pry_locker()
	await _press(&"inventory")
	assert_bool(_player.is_inventory_open()).is_false()
	assert_str(_hud().prompt_text).is_equal("E Search locker")
	await _press(&"interact")
	assert_bool(_player.is_inventory_open()).is_true()
	assert_object(_player.get_inventory_screen().loot).is_same(_locker)


func test_player_stands_still_and_cannot_shoot_while_sorting() -> void:
	await _place(IN_CORRIDOR)
	await _press(&"inventory")
	assert_bool(_player.is_inventory_open()).is_true()
	assert_bool(_player.get_inventory_screen().loot == null).is_true()
	Input.action_press(&"move_forward")
	Input.action_press(&"shoot")
	await _physics_frames(30)
	Input.action_release(&"shoot")
	await _physics_frames(5)
	assert_float(_player.global_position.distance_to(IN_CORRIDOR)).is_less(0.01)
	assert_int(_player.get_weapon().shots_fired).is_equal(0)
	Input.action_release(&"move_forward")
	await _press(&"inventory")
	assert_bool(_player.is_inventory_open()).is_false()
	Input.action_press(&"move_forward")
	await _physics_frames(30)
	assert_float(_player.global_position.distance_to(IN_CORRIDOR)).is_greater(0.2)


func test_esc_and_interact_close_the_inventory() -> void:
	await _place(IN_CORRIDOR)
	await _press(&"inventory")
	await _press(&"pause")
	assert_bool(_player.is_inventory_open()).is_false()
	await _press(&"inventory")
	await _press(&"interact")
	assert_bool(_player.is_inventory_open()).is_false()


func test_a_dropped_item_lands_on_the_floor_and_interact_opens_the_floor() -> void:
	var ear := _add_ear(IN_CORRIDOR + Vector3(0.0, 0.0, -1.0))
	await _place(IN_CORRIDOR)
	var dropped := await _drop_backpack_clip()
	assert_int(_player.clips.packed).is_equal(0)
	assert_array(ear.heard).contains([&"item_drop"])
	assert_float(dropped.global_position.y).is_less(0.2)
	assert_float(dropped.global_position.distance_to(IN_CORRIDOR)).is_less(1.0)
	_look_at(dropped.global_position)
	await _physics_frames(3)
	assert_str(_hud().prompt_text).is_equal("E Pick up 2 thermal clips")
	await _press(&"interact")
	# Nothing goes into a grid by itself: the floor opens with the clip on it, to be dragged.
	var screen := _player.get_inventory_screen()
	assert_bool(_player.is_inventory_open()).is_true()
	assert_bool(screen.floor_grid.has(dropped.item)).is_true()
	assert_int(_player.clips.packed + _player.clips.fresh).is_equal(2)
	screen.begin_drag(screen.floor_grid, dropped.item.cell)
	screen.drop_drag(_player.inventory.ammo, Vector2i(0, 0))
	await _physics_frames(2)
	assert_bool(is_instance_valid(dropped)).is_false()
	assert_int(_player.clips.fresh).is_equal(4)


func test_the_floor_shows_dropped_items_in_reach_and_in_sight() -> void:
	await _place(IN_CORRIDOR)
	var near := _lay(Vector3(0.5, 0.05, 3.5))
	# Within reach, but on the other side of the corridor's wall.
	var behind_wall := _lay(Vector3(1.4, 0.05, 4.0))
	var far := _lay(Vector3(0.0, 0.05, 6.5))
	await _press(&"inventory")
	var floor := _player.get_inventory_screen().floor_grid
	assert_bool(floor.has(near.item)).is_true()
	assert_bool(floor.has(behind_wall.item)).is_false()
	assert_bool(floor.has(far.item)).is_false()


func test_reload_takes_a_clip_from_the_ammo_slots() -> void:
	await _place(IN_CORRIDOR)
	_player.clips.heat = 0.5
	await _press(&"reload")
	assert_bool(_player.get_weapon().is_reloading).is_true()
	assert_int(_player.clips.fresh).is_equal(1)
	await _physics_frames(roundi(3.2 * FRAMES_PER_SECOND))
	var ammo := _player.inventory.ammo
	assert_str(ammo.item_at(Vector2i(0, 0)).definition.id).is_equal("base:thermal_clip")
	assert_int(ammo.item_at(Vector2i(0, 0)).quantity).is_equal(1)
	assert_str(ammo.item_at(Vector2i(1, 0)).definition.id).is_equal("base:spent_thermal_clip")
	assert_int(_player.clips.packed).is_equal(2)


func test_a_spent_clip_with_no_room_drops_on_the_floor_with_a_clatter() -> void:
	var ear := _add_ear(IN_CORRIDOR + Vector3(0.0, 0.0, -1.0))
	await _place(IN_CORRIDOR)
	var inventory := _player.inventory
	var spent := ContentRegistry.get_definition("base:spent_thermal_clip") as ItemDefinition
	var drive := ContentRegistry.get_definition("base:data_drive") as ItemDefinition
	inventory.ammo.place(Item.new(spent, spent.stack_size), Vector2i(1, 0))
	for grid: ItemGrid in [inventory.pockets, inventory.backpack]:
		while grid.free_slots() > 0:
			grid.add(Item.new(drive, drive.stack_size))
	_player.clips.heat = 0.5
	await _press(&"reload")
	await _physics_frames(roundi(3.2 * FRAMES_PER_SECOND))
	var dropped := _wreck.get_children().filter(func(node: Node) -> bool: return node is DroppedItem)
	assert_int(dropped.size()).is_equal(1)
	assert_str((dropped[0] as DroppedItem).item.definition.id).is_equal("base:spent_thermal_clip")
	assert_array(ear.heard).contains([&"item_drop"])
	assert_float(_player.clips.heat).is_equal(0.0)


func test_reload_needs_a_clip_in_the_ammo_slots() -> void:
	await _place(IN_CORRIDOR)
	for item in _player.inventory.ammo.items.duplicate():
		_player.inventory.ammo.remove(item)
	_player.clips.heat = 0.5
	await _press(&"reload")
	assert_bool(_player.get_weapon().is_reloading).is_false()
	await _physics_frames(2)
	assert_str(_hud().clips_text).is_equal("50% 0 fresh  ·  2 packed  ·  0 spent")


func test_a_reload_finishes_while_the_inventory_is_open() -> void:
	await _place(IN_CORRIDOR)
	_player.clips.heat = 0.5
	await _press(&"reload")
	await _press(&"inventory")
	assert_bool(_player.is_inventory_open()).is_true()
	await _physics_frames(roundi(3.2 * FRAMES_PER_SECOND))
	assert_bool(_player.get_weapon().is_reloading).is_false()
	assert_str(_player.inventory.ammo.item_at(Vector2i(1, 0)).definition.id).is_equal("base:spent_thermal_clip")
	assert_bool(_player.is_inventory_open()).is_true()


## Drops the backpack's stack of clips from the inventory screen, closes it, and waits for the stack to land.
func _drop_backpack_clip() -> DroppedItem:
	await _press(&"inventory")
	var screen := _player.get_inventory_screen()
	screen.begin_drag(_player.inventory.backpack, Vector2i(0, 0))
	screen.drop_drag_outside()
	await _press(&"inventory")
	await _physics_frames(FRAMES_PER_SECOND)
	var dropped := _wreck.get_children().filter(func(node: Node) -> bool: return node is DroppedItem)
	assert_int(dropped.size()).is_equal(1)
	return dropped[0] as DroppedItem


## A dropped data drive held still at a position, as if it had been lying there.
func _lay(position: Vector3) -> DroppedItem:
	var dropped := DroppedItem.create(Item.new(_item("base:data_drive")), null)
	dropped.freeze = true
	_wreck.add_child(dropped, true)
	dropped.global_position = position
	return dropped


func _pry_locker() -> void:
	await _look_at_locker()
	Input.action_press(&"interact")
	await _physics_frames(roundi(1.6 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	await _physics_frames(2)
	assert_bool(_locker.is_open).is_true()


func _look_at_locker() -> void:
	await _place(BEFORE_LOCKER)
	_look_at(LOCKER_DOOR)
	await _physics_frames(3)


func _add_ear(position: Vector3) -> Node3D:
	var ear := Node3D.new()
	ear.set_script(load("res://tests/loot/noise_ear.gd"))
	_wreck.add_child(ear)
	ear.global_position = position
	return ear


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition


## Points the player's view at a point.
func _look_at(point: Vector3) -> void:
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, point)
	_player.set_look(angles.x, angles.y)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(2)


func _place(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0)
	_player.reset_physics_interpolation()
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _player.get_node("Hud") as Hud
