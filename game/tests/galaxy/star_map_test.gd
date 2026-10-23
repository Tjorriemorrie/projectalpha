extends GdUnitTestSuite
## Uses the star map on the player's ship, with travel turned off, through the cockpit console, Q and mouse events
## pushed into the viewport: Q and the tab headers switch between the system map and the star map; pointing at a
## system shows its star, distance and the jump's antimatter; BUY INTEL reveals a system in range and lists its ships;
## Q on a known system shows its system map read-only; holding JUMP for a second jumps (a day, antimatter by distance)
## and arrives on the new system's map, while letting go early or a refused jump doesn't; and the ship's bar, which
## stays over the maps, follows the wallet, the antimatter and its order, and the day. The ship is at Praetor's hub; Mori is 7.2 ly away (8 units), Centurion out of range.
## Positions in the ship refer to res://scenes/ship/ship.tscn, as in system_map_test.gd.

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"pause", &"map_tab"]
const NORTH := 0.0
const BESIDE_SEAT := Vector3(0.6, 0.0, -0.7)
const CONSOLE_SCREEN := Vector3(0.0, 1.15, -1.7)

var _runner: GdUnitSceneRunner
var _player: Player
var _system_map: SystemMapScreen
var _star_map: StarMapScreen
var _window_size: Vector2i
var _praetor: StarSystemDefinition
var _mori: StarSystemDefinition
var _centurion: StarSystemDefinition


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	_praetor = _system("base:praetor")
	_mori = _system("base:mori")
	_centurion = _system("base:centurion")
	GameSession.arrive_in(_praetor)
	GameSession.bitcoin = 1000
	# Headless runs have a tiny window; the screen is laid out for a real one.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	GameSession.travel_enabled = true
	GameSession.new_game()
	get_tree().root.size = _window_size


func test_q_switches_between_the_system_map_and_the_star_map() -> void:
	await _load_ship()
	await _open_console()
	assert_bool(_system_map.is_open).is_true()
	await _press(&"map_tab")
	assert_bool(_system_map.is_open).is_false()
	assert_bool(_star_map.is_open).is_true()
	assert_bool(_player.is_viewing_map()).is_true()
	# The ship's bar stays over the maps.
	assert_str(_hud().wallet_text).is_equal("₿1,000")
	assert_str(_hud().day_text).is_equal("0")
	await _press(&"map_tab")
	assert_bool(_system_map.is_open).is_true()
	assert_bool(_star_map.is_open).is_false()
	# Tab closes whichever is open, and the console opens on the system map again.
	await _press(&"map_tab")
	await _press(&"inventory")
	assert_bool(_player.is_viewing_map()).is_false()
	await _open_console()
	assert_bool(_system_map.is_open).is_true()


func test_clicking_a_tab_header_switches_to_it() -> void:
	await _load_ship()
	await _open_console()
	await _click(_system_map, _system_map.tab_header_center(MapScreen.Tab.STAR))
	assert_bool(_star_map.is_open).is_true()
	await _click(_star_map, _star_map.tab_header_center(MapScreen.Tab.SYSTEM))
	assert_bool(_system_map.is_open).is_true()


func test_pointing_at_a_system_shows_its_star_distance_and_jump() -> void:
	await _load_star_map()
	_mouse_move(_star_map, _star_map.system_center(_mori))
	await _physics_frames(1)
	assert_object(_star_map.shown).is_same(_mori)
	assert_str(_star_map.target_text).is_equal("MORI")
	assert_str(_star_map.details_text).is_equal("DISTANCE 7.2 ly · JUMP 8 antimatter · SHIPS Unknown")
	assert_str(_star_map.antimatter_text).is_equal("2/10")
	assert_str(_star_map.jump_text).is_equal("NOT ENOUGH ANTIMATTER")
	assert_bool(_star_map.is_intel_offered()).is_true()
	_mouse_move(_star_map, _star_map.system_center(_centurion))
	await _physics_frames(1)
	assert_str(_star_map.jump_text).is_equal("OUT OF RANGE")
	assert_str(_star_map.intel_text).is_equal("NO INTEL OUT OF RANGE")
	_mouse_move(_star_map, _star_map.system_center(_praetor))
	await _physics_frames(1)
	assert_str(_star_map.jump_text).is_equal("THE SHIP IS HERE")
	assert_bool(_star_map.is_intel_offered()).is_false()
	assert_int(_star_map.ships_text.split("\n").size()).is_equal(GameSession.system.wrecks.size())


func test_buy_intel_reveals_a_system_in_range_and_lists_its_ships() -> void:
	await _load_star_map()
	await _click(_star_map, _star_map.system_center(_mori))
	assert_object(_star_map.selected).is_same(_mori)
	var price := GameSession.trader.intel_price()
	assert_str(_star_map.intel_text).is_equal("BUY INTEL  ·  %s" % Bitcoin.format(price))
	await _click(_star_map, _star_map.intel_button_center())
	var mori := GameSession.known_system(_mori)
	assert_object(mori).is_not_null()
	assert_int(GameSession.bitcoin).is_equal(1000 - price)
	assert_str(_hud().wallet_text).is_equal(Bitcoin.format(1000 - price))
	assert_str(_star_map.details_text).is_equal(
		"DISTANCE 7.2 ly · JUMP 8 antimatter · SHIPS %d known, by intel" % mori.wrecks.size())
	var first := mori.wrecks[0]
	assert_str(_star_map.ships_text.split("\n")[0]).is_equal(
		"%s · about %d robots" % [first.title(), first.roll.expected_robots()])
	assert_bool(_star_map.is_intel_offered()).is_false()


func test_q_on_a_known_system_shows_its_system_map_read_only() -> void:
	GameSession.buy_intel(_mori)
	await _load_star_map()
	await _click(_star_map, _star_map.system_center(_mori))
	await _press(&"map_tab")
	assert_bool(_system_map.is_open).is_true()
	assert_bool(_system_map.is_viewing_elsewhere()).is_true()
	assert_str(_system_map.system_text).is_equal("MORI")
	assert_str(_system_map.status_text).contains("Viewing Mori from the star map")
	_mouse_move(_system_map, _system_map.target_center(0))
	await _physics_frames(1)
	assert_str(_system_map.target_text).is_equal(GameSession.known_system(_mori).wrecks[0].title().to_upper())
	# Nothing flies there from here.
	assert_bool(_system_map.fly()).is_false()
	assert_bool(GameSession.at_hub).is_true()
	await _press(&"map_tab")
	assert_bool(_star_map.is_open).is_true()
	assert_object(_star_map.selected).is_same(_mori)


func test_holding_jump_for_a_second_jumps_and_arrives_on_the_new_systems_map() -> void:
	GameSession.antimatter = 10
	await _load_star_map()
	await _click(_star_map, _star_map.system_center(_mori))
	assert_str(_star_map.jump_text).is_equal("HOLD TO JUMP  ·  8")
	await _hold(_star_map, _star_map.jump_button_center(), 75)
	await _wait_for_jump()
	assert_object(GameSession.system.definition).is_same(_mori)
	assert_int(GameSession.day).is_equal(1)
	assert_int(GameSession.antimatter).is_equal(2)
	assert_bool(_star_map.is_open).is_false()
	assert_bool(_system_map.is_open).is_true()
	assert_bool(_system_map.is_viewing_elsewhere()).is_false()
	assert_str(_system_map.system_text).is_equal("MORI")
	assert_str(_system_map.status_text).is_equal(
		"Arrived at Mori Hanse on day 1. The jump drive recharges until a ship is boarded.")
	var console := _runner.find_child("SystemConsole") as SystemConsole
	assert_str(console.screen_text()).is_equal("SYSTEM MAP\nMORI")
	var terminal := _runner.find_child("TraderTerminal")
	assert_str((terminal.get_node("%ScreenText") as Label3D).text).is_equal("TRADER LINK\nMORI HANSE")
	await _press(&"inventory")
	assert_str(_hud().day_text).is_equal("1")
	assert_str(_hud().antimatter_text).is_equal("2/10")


func test_letting_go_of_jump_early_doesnt_jump() -> void:
	GameSession.antimatter = 10
	await _load_star_map()
	await _click(_star_map, _star_map.system_center(_mori))
	await _hold(_star_map, _star_map.jump_button_center(), 20)
	await _physics_frames(30)
	assert_object(GameSession.system.definition).is_same(_praetor)
	assert_int(GameSession.day).is_equal(0)
	assert_str(_star_map.status_text).is_equal("Keep holding JUMP for a second to jump.")


func test_a_jump_the_tank_cant_fly_says_why() -> void:
	GameSession.antimatter = 3
	await _load_star_map()
	await _click(_star_map, _star_map.system_center(_mori))
	await _click(_star_map, _star_map.jump_button_center())
	assert_object(GameSession.system.definition).is_same(_praetor)
	assert_str(_star_map.status_text).is_equal(
		"Not enough antimatter: the jump to Mori burns 8, the tank holds 3. Order more at the trader terminal.")


func test_the_ships_bar_shows_the_antimatter_and_the_day_an_order_arrives() -> void:
	GameSession.antimatter = 4
	await _load_ship()
	assert_str(_hud().antimatter_text).is_equal("4/10")
	GameSession.bitcoin = 10000
	GameSession.order_antimatter()
	await _physics_frames(1)
	assert_str(_hud().antimatter_text).is_equal("4/10 6 ARRIVING DAY 1")
	GameSession.day = 1
	GameSession.antimatter_changed.emit(GameSession.antimatter)
	assert_str(_hud().antimatter_text).is_equal("4/10 6 READY AT THE HUB")


func _load_ship() -> void:
	_runner = scene_runner(SHIP_SCENE)
	_runner.set_time_factor(5.0)
	_player = _runner.find_child("Player") as Player
	_system_map = _player.get_system_map()
	_star_map = _player.get_star_map()
	await _physics_frames(2)


func _load_star_map() -> void:
	await _load_ship()
	await _open_console()
	await _press(&"map_tab")
	assert_bool(_star_map.is_open).is_true()
	await _physics_frames(1)


func _open_console() -> void:
	_player.global_position = BESIDE_SEAT
	_player.velocity = Vector3.ZERO
	_player.set_look(NORTH)
	_player.reset_physics_interpolation()
	await _physics_frames(2)
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, CONSOLE_SCREEN)
	_player.set_look(angles.x, angles.y)
	await _physics_frames(3)
	await _press(&"interact")
	await _physics_frames(1)


func _wait_for_jump() -> void:
	for _frame in 240:
		if not _player.is_jumping() and GameSession.day > 0:
			break
		await _physics_frames(1)
	await _physics_frames(2)


func _click(screen: MenuScreen, at: Vector2) -> void:
	_mouse_move(screen, at)
	_mouse_button(screen, at, true)
	await _physics_frames(1)
	_mouse_button(screen, at, false)
	await _physics_frames(1)


## Presses the left button at a spot, holds it for some physics frames (1/60 s each) and lets go.
func _hold(screen: MenuScreen, at: Vector2, frames: int) -> void:
	_mouse_move(screen, at)
	_mouse_button(screen, at, true)
	await _physics_frames(frames)
	_mouse_button(screen, at, false)
	await _physics_frames(1)


func _mouse_move(screen: MenuScreen, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	screen.get_viewport().push_input(event)


func _mouse_button(screen: MenuScreen, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	screen.get_viewport().push_input(event)


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


static func _system(id: String) -> StarSystemDefinition:
	return ContentRegistry.get_definition(id) as StarSystemDefinition
