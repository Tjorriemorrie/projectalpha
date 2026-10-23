extends GdUnitTestSuite
## Plays the player's ship with travel turned off: it assembles, the first clone wakes in the clone pod with the basic
## kit, a clone after a death wakes empty-handed and arms by dragging a gun from the stash into the weapon slot (which
## takes nothing else), and a player back from the wreck arrives in the airlock with what they carried; the stash
## opens with the session's grid and takes items dragged with the mouse, there is no floor, the pistol is holstered but
## reloads, the airlock says which wreck is docked and what the scan says about its robots, and holding interact on
## its outer door boards that wreck with the kit and the wreck's roll handed over; with nothing docked the outer door
## is shut and the window shows no hull, and flying to a wreck docks it at once. The cockpit console names the system.
## Positions refer to the layout of res://scenes/ship/ship.tscn: one deck at y = 0, the cockpit at the origin, a
## corridor east along z = 0 to x = 12, the clone bay south of x = 4 with the pod at (4, 0, 5), the bedroom north of
## x = 8, the stash room south of x = 12 with the stash against its south wall at z = 5.8, and the airlock north of
## x = 12 with its outer door at z = -5.72.

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"shoot", &"aim", &"reload"]
const FRAMES_PER_SECOND := 60
const NORTH := 0.0
const SOUTH := PI
const BEFORE_STASH := Vector3(12.0, 0.0, 4.3)
const STASH_FRONT := Vector3(12.0, 1.2, 5.2)
const BEFORE_OUTER_DOOR := Vector3(12.0, 0.0, -4.6)
const OUTER_DOOR := Vector3(12.0, 1.3, -5.6)

var _runner: GdUnitSceneRunner
var _ship: Ship
var _player: Player
var _window_size: Vector2i
var _travelled: Array[String] = []


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_travelled.clear()
	GameSession.travelled.connect(_on_travelled)
	# Headless runs have a tiny window; the inventory screen is laid out for a real one.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	GameSession.travelled.disconnect(_on_travelled)
	GameSession.travel_enabled = true
	GameSession.new_game()
	get_tree().root.size = _window_size


func test_assembles_without_errors() -> void:
	await _load_ship()
	assert_array(_ship.assembly_errors).is_empty()
	assert_int(_ship.sections.size()).is_equal(8)
	assert_int(_ship.plan.joins).is_equal(7)
	assert_int(_ship.plan.count_openings(Socket.Opening.DOORWAY)).is_equal(5)
	assert_array(_ship.robots).is_empty()
	assert_array(_ship.navigation_regions).is_empty()
	assert_int(_ship.airlocks.size()).is_equal(1)


func test_lamps_are_warm_and_steady() -> void:
	await _load_ship()
	var lamps := _ship.find_children("*", "CeilingLamp", true, false)
	assert_int(lamps.size()).is_equal(8)
	for lamp: CeilingLamp in lamps:
		assert_bool(lamp.flickering).is_false()
		var light := lamp.get_node("SpotLight3D") as SpotLight3D
		assert_that(light.light_color).is_equal(_ship.lamp_color)


func test_a_new_clone_wakes_in_the_clone_pod_with_the_basic_kit() -> void:
	await _load_ship()
	assert_float(_player.global_position.distance_to(Vector3(4.0, 0.12, 5.0))).is_less(0.1)
	var facing := -_player.global_basis.z
	assert_float(facing.z).is_equal_approx(-1.0, 0.01)
	assert_int(_player.clips.fresh).is_equal(2)
	assert_int(_player.clips.packed).is_equal(0)
	assert_int(_player.inventory.item_count()).is_equal(3)
	assert_str(_player.inventory.gun().definition.id).is_equal("base:laser_pistol")
	assert_bool(_player.get_weapon().is_equipped()).is_true()
	assert_float(_player.clips.heat).is_equal(0.0)
	assert_float(_player.get_health().health).is_equal(_player.get_health().max_health)


func test_a_clone_after_a_death_wakes_empty_handed_and_unarmed() -> void:
	GameSession.die(Inventory.new())
	await _load_ship()
	assert_float(_player.global_position.distance_to(Vector3(4.0, 0.12, 5.0))).is_less(0.1)
	assert_int(_player.inventory.item_count()).is_equal(0)
	assert_bool(_player.get_weapon().is_equipped()).is_false()
	await _physics_frames(2)
	assert_str(_hud().clips_text).is_empty()
	assert_bool((_hud().get_node("Root/Clips") as Control).visible).is_false()


func test_a_gun_dragged_from_the_stash_into_the_weapon_slot_arms_the_player() -> void:
	GameSession.die(Inventory.new())
	var pistol := Item.new(_item("base:laser_pistol"))
	pistol.clip_heat = 0.25
	GameSession.stash.place(pistol, Vector2i(0, 0), 0)
	await _load_ship()
	await _look_at_stash()
	await _press(&"interact")
	var screen := _player.get_inventory_screen()
	await _drag(screen, screen.cell_center(GameSession.stash, Vector2i(0, 0)),
		screen.cell_center(_player.inventory.weapon, Vector2i(0, 0)))
	assert_object(_player.inventory.gun()).is_same(pistol)
	assert_bool(_player.get_weapon().is_equipped()).is_true()
	assert_float(_player.clips.heat).is_equal_approx(0.25, 0.001)
	# Dragging it back out leaves the player unarmed again.
	await _drag(screen, screen.cell_center(_player.inventory.weapon, Vector2i(0, 0)),
		screen.cell_center(GameSession.stash, Vector2i(5, 5)))
	assert_object(_player.inventory.gun()).is_null()
	assert_bool(_player.get_weapon().is_equipped()).is_false()


func test_only_a_gun_fits_the_weapon_slot() -> void:
	await _load_ship()
	await _look_at_stash()
	await _press(&"interact")
	var screen := _player.get_inventory_screen()
	var clip := _player.inventory.pockets.item_at(Vector2i(0, 0))
	await _drag(screen, screen.cell_center(_player.inventory.pockets, Vector2i(0, 0)),
		screen.cell_center(_player.inventory.weapon, Vector2i(2, 1)))
	assert_object(_player.inventory.pockets.item_at(Vector2i(0, 0))).is_same(clip)
	assert_int(_player.inventory.weapon.items.size()).is_equal(1)


func test_a_player_back_from_the_wreck_arrives_in_the_airlock_with_their_kit() -> void:
	var carried := Inventory.new()
	carried.backpack.add(Item.new(_item("base:gyroscope")))
	var gun := Item.new(_item("base:laser_pistol"))
	gun.clip_heat = 0.6
	carried.weapon.add(gun)
	GameSession.extract(carried)
	await _load_ship()
	assert_float(_player.global_position.distance_to(Vector3(12.0, 0.0, -4.9))).is_less(0.1)
	var facing := -_player.global_basis.z
	assert_float(facing.z).is_equal_approx(1.0, 0.01)
	assert_object(_player.inventory).is_same(carried)
	assert_float(_player.clips.heat).is_equal_approx(0.6, 0.001)
	assert_int(_player.clips.fresh).is_equal(0)


func test_the_stash_opens_with_the_sessions_grid_and_no_floor() -> void:
	await _load_ship()
	await _look_at_stash()
	assert_str(_hud().prompt_text).is_equal("E Open stash")
	await _press(&"interact")
	var screen := _player.get_inventory_screen()
	assert_bool(screen.is_open).is_true()
	assert_object(screen.loot.grid).is_same(GameSession.stash)
	assert_object(screen.floor_grid).is_null()


func test_an_item_dragged_with_the_mouse_goes_into_the_stash_and_stays() -> void:
	await _load_ship()
	await _look_at_stash()
	await _press(&"interact")
	var screen := _player.get_inventory_screen()
	var clip := _player.inventory.pockets.item_at(Vector2i(0, 0))
	await _drag(screen, screen.cell_center(_player.inventory.pockets, Vector2i(0, 0)),
		screen.cell_center(GameSession.stash, Vector2i(4, 3)))
	assert_object(GameSession.stash.item_at(Vector2i(4, 3))).is_same(clip)
	assert_bool(_player.inventory.pockets.has(clip)).is_false()


func test_an_item_released_outside_goes_back_with_no_floor() -> void:
	await _load_ship()
	await _look_at_stash()
	await _press(&"interact")
	var screen := _player.get_inventory_screen()
	var clip := _player.inventory.pockets.item_at(Vector2i(0, 0))
	# The middle of the screen, between the placards.
	await _drag(screen, screen.cell_center(_player.inventory.pockets, Vector2i(0, 0)), Vector2(640.0, 680.0))
	assert_object(_player.inventory.pockets.item_at(Vector2i(0, 0))).is_same(clip)
	assert_array(get_tree().get_nodes_in_group(DroppedItem.GROUP)).is_empty()


func test_the_pistol_is_holstered_but_reloads() -> void:
	await _load_ship()
	await _place(Vector3(8.0, 0.0, 0.0), NORTH)
	var weapon := _player.get_weapon()
	assert_bool(weapon.holstered).is_true()
	await _press(&"shoot")
	await _physics_frames(30)
	assert_int(weapon.shots_fired).is_equal(0)
	Input.action_press(&"aim")
	await _physics_frames(5)
	assert_bool(weapon.is_aiming).is_false()
	Input.action_release(&"aim")
	_player.clips.heat = 0.5
	await _press(&"reload")
	assert_bool(weapon.is_reloading).is_true()
	await _physics_frames(roundi((weapon.definition.reload_time + 0.2) * FRAMES_PER_SECOND))
	assert_float(_player.clips.heat).is_equal(0.0)
	assert_int(_player.clips.spent).is_equal(1)
	assert_int(_player.clips.fresh).is_equal(1)


func test_the_airlock_shows_the_docked_wreck() -> void:
	GameSession.docked = WreckRoll.new(ContentRegistry.get_definition("base:hauler") as WreckDefinition, 2, 7)
	await _load_ship()
	await _look_at_outer_door()
	assert_str(_hud().prompt_text).is_equal("Hold E Board the hauler · about 5 robots active")
	var sign_label := _ship.airlocks[0].get_node("%Sign") as Label3D
	assert_str(sign_label.text).is_equal("HAULER DOCKED")


func test_the_airlock_shows_a_level_1_courier_with_its_robots() -> void:
	GameSession.docked = WreckRoll.new(ContentRegistry.get_definition("base:courier") as WreckDefinition, 1, 7)
	await _load_ship()
	await _look_at_outer_door()
	assert_str(_hud().prompt_text).is_equal("Hold E Board the courier · about 3 robots active")


func test_with_nothing_docked_the_airlock_is_shut_and_the_window_shows_only_stars() -> void:
	await _load_ship()
	await _look_at_outer_door()
	assert_object(GameSession.docked).is_null()
	assert_str(_hud().prompt_text).is_empty()
	assert_bool(_ship.airlocks[0].get_outer_door().is_enabled()).is_false()
	var sign_label := _ship.airlocks[0].get_node("%Sign") as Label3D
	assert_str(sign_label.text).is_equal("NOTHING DOCKED")
	assert_bool((_ship.get_node("Outside/Hull") as Node3D).visible).is_false()
	Input.action_press(&"interact")
	await _physics_frames(roundi(1.5 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	assert_bool(_player.is_leaving).is_false()
	assert_array(_travelled).is_empty()


func test_flying_to_a_wreck_docks_it_at_the_airlock_and_shows_its_hull() -> void:
	GameSession.hydrogen = 1000
	var wreck := GameSession.system.wrecks[0]
	await _load_ship()
	GameSession.fly_to_wreck(wreck)
	await _look_at_outer_door()
	var layout := wreck.title()
	assert_str(_hud().prompt_text).is_equal("Hold E Board the %s · %s" % [layout.to_lower(), wreck.roll.robots_estimate()])
	assert_bool(_ship.airlocks[0].get_outer_door().is_enabled()).is_true()
	var sign_label := _ship.airlocks[0].get_node("%Sign") as Label3D
	assert_str(sign_label.text).is_equal("%s DOCKED" % layout.to_upper())
	assert_bool((_ship.get_node("Outside/Hull") as Node3D).visible).is_true()


func test_the_cockpit_console_shows_the_system() -> void:
	await _load_ship()
	var text := _ship.get_node("%SystemConsole").get_node("%ScreenText") as Label3D
	assert_str(text.text).is_equal("SYSTEM MAP\n%s" % GameSession.system.definition.display_name.to_upper())


func test_holding_interact_on_the_outer_door_boards_the_wreck() -> void:
	var docked := WreckRoll.new(ContentRegistry.get_definition("base:hauler") as WreckDefinition, 2, 7)
	GameSession.docked = docked
	await _load_ship()
	await _look_at_outer_door()
	assert_str(_hud().prompt_text).starts_with("Hold E Board the %s" % docked.definition.display_name.to_lower())
	Input.action_press(&"interact")
	await _physics_frames(roundi(0.8 * FRAMES_PER_SECOND))
	assert_bool(_player.is_leaving).is_false()
	await _physics_frames(roundi(0.3 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	assert_bool(_player.is_leaving).is_true()
	assert_array(_travelled).is_empty()
	await _physics_frames(roundi((_player.leave_fade_time + 0.2) * FRAMES_PER_SECOND))
	assert_array(_travelled).is_equal([docked.definition.get_scene_path()])
	assert_object(GameSession.take_carried()).is_same(_player.inventory)
	assert_object(GameSession.take_boarding(docked.definition)).is_same(docked)
	assert_int(GameSession.runs).is_equal(1)


func _load_ship() -> void:
	_runner = scene_runner(SHIP_SCENE)
	_runner.set_time_factor(5.0)
	_ship = _runner.scene() as Ship
	_player = _runner.find_child("Player") as Player
	await _physics_frames(2)


func _look_at_stash() -> void:
	await _place(BEFORE_STASH, SOUTH)
	_look_at(STASH_FRONT)
	await _physics_frames(3)


func _look_at_outer_door() -> void:
	await _place(BEFORE_OUTER_DOOR, NORTH)
	_look_at(OUTER_DOOR)
	await _physics_frames(3)


## Presses the drag button at from, moves to to and lets go there, as mouse events through the viewport.
func _drag(screen: InventoryScreen, from: Vector2, to: Vector2) -> void:
	_mouse_move(screen, from)
	_mouse_button(screen, from, true)
	await _physics_frames(1)
	_mouse_move(screen, to)
	await _physics_frames(1)
	_mouse_button(screen, to, false)
	await _physics_frames(1)


func _mouse_move(screen: InventoryScreen, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	screen.get_viewport().push_input(event)


func _mouse_button(screen: InventoryScreen, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	screen.get_viewport().push_input(event)


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


func _place(position: Vector3, yaw: float) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.set_look(yaw)
	_player.reset_physics_interpolation()
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _player.get_node("Hud") as Hud


func _on_travelled(scene_path: String) -> void:
	_travelled.append(scene_path)


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition
