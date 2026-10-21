extends GdUnitTestSuite
## Plays the end of a run on the small wreck with travel turned off and its robots taken out: holding interact on the
## airlock's outer door extracts after its time, letting go cancels, cycling is a noise robots hear, the run summary
## shows on the black screen and a real key press continues to the ship with the kit handed over; a death shows its
## summary and the next clone gets the basic kit; and a player boarding from the ship arrives with what they carried.
## Positions refer to the layout of res://scenes/wreck/small_wreck.tscn: the player starts in the airlock at
## (-0.6, 0, 4), facing east into the wreck, with the outer door behind them at x = -1.72.

const WRECK_SCENE := "res://scenes/wreck/small_wreck.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"move_forward"]
const FRAMES_PER_SECOND := 60
const WEST := PI / 2.0
const OUTER_DOOR := Vector3(-1.6, 1.3, 4.0)

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _travelled: Array[String] = []


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_travelled.clear()
	GameSession.travelled.connect(_on_travelled)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	GameSession.travelled.disconnect(_on_travelled)
	GameSession.travel_enabled = true
	GameSession.new_game()


func test_the_outer_door_says_where_it_goes() -> void:
	await _load_wreck()
	await _look_at_outer_door()
	assert_str(_hud().prompt_text).is_equal("Hold E Return to ship")
	assert_int(_wreck.airlocks.size()).is_equal(1)


func test_holding_the_outer_door_extracts_after_its_time() -> void:
	await _load_wreck()
	await _look_at_outer_door()
	Input.action_press(&"interact")
	await _physics_frames(roundi(2.6 * FRAMES_PER_SECOND))
	assert_bool(_player.is_leaving).is_false()
	await _physics_frames(roundi(0.6 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	assert_bool(_player.is_leaving).is_true()
	for hitbox in _player.get_hitboxes():
		assert_bool(hitbox.is_active()).is_false()
	assert_bool(GameSession.last_run.extracted).is_true()


func test_letting_go_cancels_the_cycle() -> void:
	await _load_wreck()
	await _look_at_outer_door()
	Input.action_press(&"interact")
	await _physics_frames(roundi(2.0 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	await _physics_frames(2)
	# Holding again starts from the beginning.
	Input.action_press(&"interact")
	await _physics_frames(roundi(2.0 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	await _physics_frames(2)
	assert_bool(_player.is_leaving).is_false()
	assert_object(GameSession.last_run).is_null()


func test_cycling_is_a_noise_robots_hear() -> void:
	await _load_wreck()
	var ear := Node3D.new()
	ear.set_script(load("res://tests/loot/noise_ear.gd"))
	_wreck.add_child(ear)
	ear.global_position = Vector3(6.0, 0.0, 4.0)
	await _look_at_outer_door()
	Input.action_press(&"interact")
	await _physics_frames(roundi(1.5 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	var heard: Array[StringName] = ear.heard.filter(func(kind: StringName) -> bool: return kind == &"airlock")
	# Once when the hold starts and once a second after.
	assert_int(heard.size()).is_equal(2)


func test_the_summary_shows_the_haul_and_a_key_press_continues_to_the_ship() -> void:
	await _load_wreck()
	await _extract()
	assert_str(_hud().summary_text()).is_empty()
	await _physics_frames(roundi((_player.leave_fade_time + 0.2) * FRAMES_PER_SECOND))
	assert_str(_hud().summary_text()).is_equal("RUN COMPLETE | Haul 2 items  ·  50 CR | Gained +50 CR | E Continue")
	assert_array(_travelled).is_empty()
	await _runner.simulate_key_pressed(KEY_E)
	await _physics_frames(3)
	assert_array(_travelled).is_equal([GameSession.SHIP_SCENE])
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.EXTRACTED)
	assert_object(GameSession.take_carried()).is_same(_player.inventory)


func test_a_death_shows_its_summary_and_the_next_clone_gets_the_basic_kit() -> void:
	await _load_wreck()
	_player.get_health().take_damage(1000.0, _player.global_position + Vector3(3.0, 1.0, 0.0))
	await _physics_frames(roundi((_player.death_summary_delay + 0.2) * FRAMES_PER_SECOND))
	assert_str(_hud().summary_text()).is_equal("SIGNAL LOST | Lost 2 items  ·  50 CR | Clone 2 activated | E Continue")
	await _runner.simulate_key_pressed(KEY_E)
	await _physics_frames(3)
	assert_array(_travelled).is_equal([GameSession.SHIP_SCENE])
	assert_int(GameSession.clone_number).is_equal(2)
	assert_int(GameSession.arrival).is_equal(GameSession.Arrival.NEW_CLONE)
	assert_object(GameSession.take_carried()).is_null()


func test_a_player_boarding_from_the_ship_arrives_with_what_they_carried() -> void:
	var carried := Inventory.new()
	carried.pockets.add(Item.new(_item("base:thermal_clip")))
	carried.backpack.add(Item.new(_item("base:gyroscope")))
	GameSession.board(carried, 0.3)
	await _load_wreck()
	assert_object(_player.inventory).is_same(carried)
	assert_float(_player.clips.heat).is_equal_approx(0.3, 0.001)
	assert_int(_player.clips.fresh).is_equal(1)
	await _extract()
	await _physics_frames(roundi((_player.leave_fade_time + 0.2) * FRAMES_PER_SECOND))
	# Carried in 185 credits and carried them out again.
	assert_str(_hud().summary_text()).is_equal("RUN COMPLETE | Haul 2 items  ·  185 CR | Gained 0 CR | E Continue")


func _load_wreck() -> void:
	_runner = scene_runner(WRECK_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	for robot in _wreck.robots:
		robot.queue_free()
	await _physics_frames(2)


func _extract() -> void:
	await _look_at_outer_door()
	Input.action_press(&"interact")
	await _physics_frames(roundi(3.2 * FRAMES_PER_SECOND))
	Input.action_release(&"interact")
	assert_bool(_player.is_leaving).is_true()


func _look_at_outer_door() -> void:
	_player.set_look(WEST)
	_look_at(OUTER_DOOR)
	await _physics_frames(3)


## Points the player's view at a point.
func _look_at(point: Vector3) -> void:
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, point)
	_player.set_look(angles.x, angles.y)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _player.get_node("Hud") as Hud


func _on_travelled(scene_path: String) -> void:
	_travelled.append(scene_path)


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition
