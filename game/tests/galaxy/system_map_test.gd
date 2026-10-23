extends GdUnitTestSuite
## Flies the ship from the system map on the player's ship, with travel turned off, through the cockpit console and
## mouse events pushed into the viewport: interact on the console opens the map; pointing at a wreck shows its details
## and plots its course; clicking selects it and FLY flies there, docking it at the airlock and burning hydrogen, a
## unit at each share of the way on the map and the bar; a flight the tank couldn't fly there and back to the hub is
## refused, and away from the hub with no wreck in reach the map says to fly back; FLY back to the hub; Tab and Esc
## close the map; and the ship's bar stays over it.
## The ship is in Praetor, with its wrecks swapped for a hand-made few at known spots: the hub at (-1, 0), the hauler
## at the Granary at (2, 0) (3 from the hub), the courier at (2, 4) (5 from the hub, 4 from the hauler) and the
## freighter at (-1, -4). Positions in the ship refer to res://scenes/ship/ship.tscn: the cockpit console at
## (0, 0, -1.8), facing south, its screen 1.15 m up, with the pilot seat in front of it.

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"pause"]
const NORTH := 0.0
const BESIDE_SEAT := Vector3(0.6, 0.0, -0.7)
const CONSOLE_SCREEN := Vector3(0.0, 1.15, -1.7)

var _runner: GdUnitSceneRunner
var _player: Player
var _ship: Ship
var _screen: SystemMapScreen
var _window_size: Vector2i
var _hauler: SystemWreck
var _courier: SystemWreck
var _freighter: SystemWreck


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	var system := StarSystem.new(ContentRegistry.get_definition("base:praetor") as StarSystemDefinition)
	system.hub_position = Vector2(-1.0, 0.0)
	_hauler = SystemWreck.new(WreckRoll.new(_layout("base:hauler"), 2, 7), system.definition.places[4],
		Vector2(2.0, 0.0))
	_courier = SystemWreck.new(WreckRoll.new(_layout("base:courier"), 1, 3), null, Vector2(2.0, 4.0))
	_freighter = SystemWreck.new(WreckRoll.new(_layout("base:freighter"), 3, 5), null, Vector2(-1.0, -4.0))
	system.wrecks.assign([_hauler, _courier, _freighter])
	GameSession.system = system
	GameSession.ship_position = system.hub_position
	# Headless runs have a tiny window; the screen is laid out for a real one.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	GameSession.travel_enabled = true
	GameSession.new_game()
	get_tree().root.size = _window_size


func test_interact_on_the_console_opens_the_map() -> void:
	await _load_ship()
	await _look_at_console()
	assert_str(_hud().prompt_text).is_equal("E System map")
	await _press(&"interact")
	assert_bool(_screen.is_open).is_true()
	assert_bool(_player.is_viewing_map()).is_true()
	assert_str(_screen.hydrogen_text).is_equal("24/24")
	assert_str(_screen.target_text).is_equal("NOTHING SELECTED")
	# The ship's bar stays over the map.
	assert_str(_hud().wallet_text).is_equal("₿500")
	assert_str(_hud().day_text).is_equal("0")


func test_tab_and_esc_close_it() -> void:
	await _load_ship()
	await _open_map()
	await _press(&"inventory")
	assert_bool(_screen.is_open).is_false()
	assert_bool(_player.is_inventory_open()).is_false()
	assert_str(_hud().hydrogen_text).is_equal("24/24")
	await _open_map()
	await _press(&"pause")
	assert_bool(_screen.is_open).is_false()


func test_pointing_at_a_wreck_shows_what_makes_it_dangerous_and_plots_its_course() -> void:
	await _load_ship()
	await _open_map()
	_mouse_move(_screen.target_center(0))
	await _physics_frames(1)
	assert_int(_screen.shown).is_equal(0)
	assert_str(_screen.target_text).is_equal("HAULER")
	assert_str(_screen.details_text).is_equal("ROBOTS About 5 robots active · REQUIRES No special gear")
	assert_str(_screen.fly_text).is_equal("FLY  ·  3")
	# Nothing is selected until it is clicked; moving off it shows nothing again.
	assert_int(_screen.selected).is_equal(SystemMapView.NONE)
	_mouse_move(Vector2(4.0, 4.0))
	await _physics_frames(1)
	assert_str(_screen.target_text).is_equal("NOTHING SELECTED")


func test_clicking_a_wreck_and_fly_docks_it_at_the_airlock() -> void:
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(0))
	assert_int(_screen.selected).is_equal(0)
	await _fly()
	assert_object(GameSession.docked).is_same(_hauler.roll)
	assert_int(GameSession.hydrogen).is_equal(21)
	assert_bool(GameSession.at_hub).is_false()
	assert_str(_screen.status_text).is_equal("Docked with the hauler at the Granary. Board it through the airlock.")
	assert_str(_screen.hydrogen_text).is_equal("21/24")
	assert_str(_screen.fly_text).is_equal("DOCKED")
	var sign_label := _ship.airlocks[0].get_node("%Sign") as Label3D
	assert_str(sign_label.text).is_equal("HAULER DOCKED")
	# Flying takes no time.
	assert_int(GameSession.day).is_equal(0)


func test_a_loop_flies_from_wreck_to_wreck_and_back_to_the_hub() -> void:
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(0))
	await _fly()
	await _click(_screen.target_center(1))
	assert_str(_screen.fly_text).is_equal("FLY  ·  4")
	await _fly()
	assert_object(GameSession.docked).is_same(_courier.roll)
	await _click(_screen.target_center(SystemMapView.HUB))
	assert_str(_screen.fly_text).is_equal("FLY  ·  5")
	await _fly()
	assert_bool(GameSession.at_hub).is_true()
	assert_object(GameSession.docked).is_null()
	assert_int(GameSession.hydrogen).is_equal(24 - 3 - 4 - 5)
	assert_str(_screen.fly_text).is_equal("AT THE HUB")


func test_a_flight_the_tank_couldnt_get_back_from_is_refused() -> void:
	GameSession.hydrogen = 9
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(1))
	# The courier is 5 there and 5 back to the hub.
	assert_str(_screen.fly_text).is_equal("NOT ENOUGH HYDROGEN")
	await _fly()
	assert_bool(GameSession.at_hub).is_true()
	assert_int(GameSession.hydrogen).is_equal(9)
	assert_str(_screen.status_text).is_equal("Not enough hydrogen: flying there and back to the hub takes 10, "
		+ "the tank holds 9. Refuel at the trader terminal.")


func test_fly_with_nothing_selected_says_what_to_do() -> void:
	await _load_ship()
	await _open_map()
	await _fly()
	assert_str(_screen.status_text).is_equal("Select a wreck or the hub on the map first.")
	await _click(_screen.target_center(SystemMapView.HUB))
	assert_str(_screen.target_text).is_equal("PRAETOR HANSE")
	assert_str(_screen.fly_text).is_equal("AT THE HUB")
	await _fly()
	assert_str(_screen.status_text).is_equal("The ship is already there.")


func test_clicking_empty_space_on_the_map_clears_the_selection() -> void:
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(2))
	assert_int(_screen.selected).is_equal(2)
	assert_str(_screen.target_text).is_equal("FREIGHTER")
	var empty := _screen.target_center(SystemMapView.HUB) + Vector2(0.0, 80.0)
	await _click(empty)
	assert_int(_screen.selected).is_equal(SystemMapView.NONE)


func test_a_flight_burns_its_hydrogen_a_unit_at_a_time() -> void:
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(0))
	_mouse_button(_screen.fly_button_center(), true)
	await _physics_frames(1)
	_mouse_button(_screen.fly_button_center(), false)
	# The ship is docked at once; on the map the hauler's 3 units burn one at each third of the way, and the bar too.
	assert_object(GameSession.docked).is_same(_hauler.roll)
	var seen: Array[String] = []
	var frames := 0
	while _screen.is_flying() and frames < 600:
		if seen.is_empty() or seen.back() != _screen.hydrogen_text:
			seen.append(_screen.hydrogen_text)
		assert_str(_hud().hydrogen_text).is_equal(_screen.hydrogen_text)
		# The thrusters roar for as long as the flight.
		assert_bool(_screen.is_engine_running()).is_true()
		await _physics_frames(1)
		frames += 1
	await _physics_frames(1)
	assert_bool(_screen.is_engine_running()).is_false()
	assert_array(seen).is_equal(["24/24", "23/24", "22/24"])
	assert_str(_screen.hydrogen_text).is_equal("21/24")
	assert_str(_hud().hydrogen_text).is_equal("21/24")
	# Half a second a unit: 1.5 s of game time at 60 physics frames a second.
	assert_int(frames).is_between(80, 100)
	assert_str(_screen.status_text).is_equal("Docked with the hauler at the Granary. Board it through the airlock.")


func test_closing_the_map_mid_flight_stops_the_engine_with_the_ship_there() -> void:
	await _load_ship()
	await _open_map()
	await _click(_screen.target_center(0))
	await _click(_screen.fly_button_center())
	assert_bool(_screen.is_engine_running()).is_true()
	await _press(&"inventory")
	assert_bool(_screen.is_engine_running()).is_false()
	assert_object(GameSession.docked).is_same(_hauler.roll)
	assert_str(_hud().hydrogen_text).is_equal("21/24")


func test_low_on_hydrogen_away_from_the_hub_only_the_hub_is_left() -> void:
	# The ship boarded the hauler and sits where it was, 3 from the hub, with 3 hydrogen: no other wreck is in reach.
	GameSession.system.remove(_hauler)
	GameSession.ship_position = _hauler.position
	GameSession.at_hub = false
	GameSession.hydrogen = 3
	await _load_ship()
	await _open_map()
	assert_str(_screen.status_text).is_equal(
		"Low on hydrogen: no wreck is in reach with enough left to get back. Fly back to the hub to buy more.")
	await _click(_screen.target_center(0))
	await _fly()
	assert_bool(GameSession.at_hub).is_false()
	assert_str(_screen.status_text).ends_with("Fly back to the hub to buy more.")
	await _click(_screen.target_center(SystemMapView.HUB))
	await _fly()
	assert_bool(GameSession.at_hub).is_true()
	assert_int(GameSession.hydrogen).is_equal(0)
	assert_str(_screen.status_text).is_equal("Back at the hub. Trade and refuel at the trader terminal.")


func _load_ship() -> void:
	_runner = scene_runner(SHIP_SCENE)
	_runner.set_time_factor(5.0)
	_ship = _runner.scene() as Ship
	_player = _runner.find_child("Player") as Player
	_screen = _player.get_system_map()
	await _physics_frames(2)


func _look_at_console() -> void:
	_player.global_position = BESIDE_SEAT
	_player.velocity = Vector3.ZERO
	_player.set_look(NORTH)
	_player.reset_physics_interpolation()
	await _physics_frames(2)
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, CONSOLE_SCREEN)
	_player.set_look(angles.x, angles.y)
	await _physics_frames(3)


func _open_map() -> void:
	await _look_at_console()
	await _press(&"interact")
	assert_bool(_screen.is_open).is_true()
	await _physics_frames(1)


## Clicks FLY and waits for the flight to end on the map.
func _fly() -> void:
	await _click(_screen.fly_button_center())
	for _frame in 600:
		if not _screen.is_flying():
			break
		await _physics_frames(1)


func _click(at: Vector2) -> void:
	_mouse_move(at)
	_mouse_button(at, true)
	await _physics_frames(1)
	_mouse_button(at, false)
	await _physics_frames(1)


func _mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_screen.get_viewport().push_input(event)


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	_screen.get_viewport().push_input(event)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(2)


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _player.get_node("Hud") as Hud


static func _layout(id: String) -> WreckDefinition:
	return ContentRegistry.get_definition(id) as WreckDefinition
