extends GdUnitTestSuite
## Trades at the hub from the player's ship with travel turned off, through the trader terminal and mouse events
## pushed into the viewport: interact on the terminal opens the hub's screen; clicking a stack in the stash sells one
## of it into the wallet, holding the click sells the whole stack, and pressing and moving drags it to rearrange the
## stash; clicking an item in the shop buys one into the stash, onto a stack of it, unless the wallet is short, and the
## stash always has room; FILL UP fills the hydrogen tank as far as the wallet pays; ORDER orders the antimatter the
## tank is missing, one order at a time, and COLLECT, once it has arrived, fills the tank at once and its gauge a block
## at a time; the cards of the shop item and the stash stack under the pointer show their prices; at home the ship's
## bar shows the bitcoin in the wallet, the hydrogen and the day, over the hub's screen too; the player stands still
## while trading; and away from the hub the terminal is out of range.
## Positions refer to the layout of res://scenes/ship/ship.tscn: the stash room south of x = 12, with the trader
## terminal against its south wall at (13.35, 0, 5.8), facing north, its screen 1.5 m up.

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"pause", &"move_forward"]
const SOUTH := PI
const FRAMES_PER_SECOND := 60
const BEFORE_TERMINAL := Vector3(13.35, 0.0, 4.5)
const TERMINAL_SCREEN := Vector3(13.35, 1.45, 5.7)

var _runner: GdUnitSceneRunner
var _player: Player
var _screen: TraderScreen
var _window_size: Vector2i


func before_test() -> void:
	GameSession.new_game()
	GameSession.travel_enabled = false
	# Headless runs have a tiny window; the screen is laid out for a real one.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)


func after_test() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	GameSession.travel_enabled = true
	GameSession.new_game()
	get_tree().root.size = _window_size


func test_interact_on_the_terminal_opens_the_hub() -> void:
	await _load_ship()
	await _look_at_terminal()
	assert_str(_hud().prompt_text).is_equal("E Trade")
	await _press(&"interact")
	assert_bool(_screen.is_open).is_true()
	assert_bool(_player.is_trading()).is_true()
	assert_str(_screen.bitcoin_text).is_equal("₿500")


func test_the_terminal_shows_the_hub_its_linked_to() -> void:
	await _load_ship()
	var text := _runner.find_child("TraderTerminal").get_node("%ScreenText") as Label3D
	assert_str(GameSession.trader.title).is_equal("%s Hanse" % GameSession.system.definition.display_name)
	assert_str(text.text).is_equal("TRADER LINK\n%s" % GameSession.trader.title.to_upper())


func test_away_from_the_hub_the_terminal_is_out_of_range() -> void:
	GameSession.hydrogen = 1000
	GameSession.fly_to_wreck(GameSession.system.wrecks[0])
	await _load_ship()
	var text := _runner.find_child("TraderTerminal").get_node("%ScreenText") as Label3D
	assert_str(text.text).is_equal("TRADER LINK\nOUT OF RANGE")
	await _look_at_terminal()
	assert_str(_hud().prompt_text).is_empty()
	await _press(&"interact")
	assert_bool(_screen.is_open).is_false()
	# Back at the hub, the link is up again.
	GameSession.fly_to_hub()
	await _physics_frames(2)
	assert_str(text.text).is_equal("TRADER LINK\n%s" % GameSession.trader.title.to_upper())
	assert_str(_hud().prompt_text).is_equal("E Trade")


func test_fill_up_fills_the_tank_for_bitcoin() -> void:
	GameSession.hydrogen = 14
	await _load_ship()
	await _open_hub()
	var price := GameSession.trader.hydrogen_price(10)
	assert_str(_screen.hydrogen_text).is_equal("14/24")
	assert_str(_screen.fill_text).is_equal("FILL UP  %s" % Bitcoin.format(price))
	await _click(_screen.fill_button_center())
	assert_int(GameSession.hydrogen).is_equal(24)
	assert_int(GameSession.bitcoin).is_equal(500 - price)
	assert_str(_screen.hydrogen_text).is_equal("24/24")
	assert_str(_screen.fill_text).is_equal("FULL")
	assert_str(_screen.status_text).is_equal("Filled the tank: 10 hydrogen for %s." % Bitcoin.format(price))
	await _click(_screen.fill_button_center())
	assert_int(GameSession.bitcoin).is_equal(500 - price)
	assert_str(_screen.status_text).is_equal("The tank is already full.")


func test_fill_up_with_an_empty_wallet_is_refused() -> void:
	GameSession.hydrogen = 4
	GameSession.bitcoin = 0
	await _load_ship()
	await _open_hub()
	await _click(_screen.fill_button_center())
	assert_int(GameSession.hydrogen).is_equal(4)
	assert_str(_screen.status_text).starts_with("Not enough bitcoin for hydrogen")


func test_order_buys_the_antimatter_the_tank_is_missing_which_arrives_days_later() -> void:
	GameSession.antimatter = 4
	GameSession.bitcoin = 5000
	await _load_ship()
	await _open_hub()
	var price := GameSession.trader.antimatter_price(6)
	assert_str(_screen.antimatter_text).is_equal("4/10")
	assert_str(_screen.order_text).is_equal("ORDER  %s" % Bitcoin.format(price))
	await _click(_screen.order_button_center())
	assert_int(GameSession.order_units).is_equal(6)
	assert_int(GameSession.bitcoin).is_equal(5000 - price)
	assert_int(GameSession.antimatter).is_equal(4)
	assert_str(_screen.order_text).is_equal("ARRIVES DAY 1")
	assert_str(_screen.status_text).is_equal(
		"Ordered 6 antimatter for %s. It arrives at the hub on day 1: board ships while you wait." % Bitcoin.format(price))
	await _click(_screen.order_button_center())
	assert_int(GameSession.bitcoin).is_equal(5000 - price)
	assert_str(_screen.status_text).is_equal("Antimatter is on order already: 6 arriving at the hub on day 1.")


func test_collect_fills_the_tank_a_block_every_tenth_of_a_second() -> void:
	GameSession.order_units = 8
	GameSession.order_day = 0
	await _load_ship()
	await _open_hub()
	# Arrived antimatter waits at the hub until it is collected.
	assert_int(GameSession.antimatter).is_equal(2)
	assert_str(_screen.order_text).is_equal("COLLECT  ·  8")
	await _click(_screen.order_button_center())
	assert_int(GameSession.antimatter).is_equal(10)
	assert_int(GameSession.order_units).is_equal(0)
	assert_bool(_screen.is_filling()).is_true()
	assert_str(_screen.order_text).is_equal("FILLING")
	assert_str(_screen.antimatter_text).is_not_equal("10/10")
	# The ship's bar fills with the gauge.
	assert_str(_hud().antimatter_text).is_equal(_screen.antimatter_text)
	# 8 blocks at 0.1 s each: under a second of game time.
	await _physics_frames(60)
	assert_bool(_screen.is_filling()).is_false()
	assert_str(_screen.antimatter_text).is_equal("10/10")
	assert_str(_hud().antimatter_text).is_equal("10/10")
	assert_str(_screen.order_text).is_equal("FULL")
	assert_str(_screen.status_text).is_equal("Collected 8 antimatter: the tank is full.")


func test_closing_while_the_tank_fills_leaves_it_full() -> void:
	GameSession.order_units = 8
	GameSession.order_day = 0
	await _load_ship()
	await _open_hub()
	await _click(_screen.order_button_center())
	await _press(&"inventory")
	assert_bool(_screen.is_filling()).is_false()
	assert_int(GameSession.antimatter).is_equal(10)
	assert_str(_hud().antimatter_text).is_equal("10/10")
	await _open_hub()
	assert_str(_screen.antimatter_text).is_equal("10/10")


func test_order_with_too_little_bitcoin_is_refused() -> void:
	GameSession.bitcoin = 100
	await _load_ship()
	await _open_hub()
	await _click(_screen.order_button_center())
	assert_int(GameSession.order_units).is_equal(0)
	assert_int(GameSession.bitcoin).is_equal(100)
	assert_str(_screen.status_text).starts_with("Not enough bitcoin for antimatter")


func test_the_ships_bar_shows_the_hydrogen_and_the_day_while_trading_too() -> void:
	GameSession.hydrogen = 20
	GameSession.day = 3
	await _load_ship()
	assert_str(_hud().hydrogen_text).is_equal("20/24")
	assert_str(_hud().day_text).is_equal("3")
	await _open_hub()
	assert_str(_hud().hydrogen_text).is_equal("20/24")
	await _click(_screen.fill_button_center())
	assert_str(_hud().hydrogen_text).is_equal("24/24")
	await _press(&"inventory")
	assert_str(_hud().hydrogen_text).is_equal("24/24")


func test_tab_and_esc_close_it() -> void:
	await _load_ship()
	await _open_hub()
	await _press(&"inventory")
	assert_bool(_screen.is_open).is_false()
	assert_bool(_player.is_trading()).is_false()
	# Tab closed the hub without opening the inventory as well.
	assert_bool(_player.is_inventory_open()).is_false()
	await _open_hub()
	await _press(&"pause")
	assert_bool(_screen.is_open).is_false()


func test_clicking_a_stash_stack_sells_one_of_it() -> void:
	var boards := _stash_item("base:circuit_board", Vector2i(0, 0), 3)
	var price := GameSession.trader.sell_price(boards.definition)
	await _load_ship()
	await _open_hub()
	await _click(_screen.cell_center(GameSession.stash, Vector2i(0, 0)))
	assert_int(GameSession.bitcoin).is_equal(500 + price)
	assert_int(boards.quantity).is_equal(2)
	assert_str(_screen.status_text).is_equal("Sold circuit board for %s." % Bitcoin.format(price))
	assert_str(_screen.bitcoin_text).is_equal(Bitcoin.format(500 + price))


func test_selling_the_last_one_empties_its_slot() -> void:
	var drive := _stash_item("base:data_drive", Vector2i(2, 1))
	await _load_ship()
	await _open_hub()
	await _click(_screen.cell_center(GameSession.stash, Vector2i(2, 1)))
	assert_bool(GameSession.stash.has(drive)).is_false()
	assert_int(GameSession.bitcoin).is_equal(500 + GameSession.trader.sell_price(drive.definition))


func test_holding_the_click_still_sells_the_whole_stack() -> void:
	var boards := _stash_item("base:circuit_board", Vector2i(0, 0), 3)
	var price := GameSession.trader.sell_price(boards.definition)
	await _load_ship()
	await _open_hub()
	var at := _screen.cell_center(GameSession.stash, Vector2i(0, 0))
	_mouse_move(at)
	_mouse_button(at, true)
	await _physics_frames(2)
	assert_bool(_screen.is_selling()).is_true()
	assert_float(_screen.sell_hold_progress()).is_between(0.0, 1.0)
	assert_int(GameSession.bitcoin).is_equal(500)
	await _physics_frames(roundi(TraderScreen.SELL_HOLD_TIME * 1.2 * FRAMES_PER_SECOND))
	assert_bool(GameSession.stash.has(boards)).is_false()
	assert_int(GameSession.bitcoin).is_equal(500 + 3 * price)
	assert_str(_screen.status_text).is_equal("Sold 3 circuit boards for %s." % Bitcoin.format(3 * price))
	# Letting go afterwards sells nothing more.
	_mouse_button(at, false)
	await _physics_frames(1)
	assert_int(GameSession.bitcoin).is_equal(500 + 3 * price)


func test_pressing_and_moving_drags_the_stack_to_rearrange_the_stash() -> void:
	var boards := _stash_item("base:circuit_board", Vector2i(0, 0), 3)
	await _load_ship()
	await _open_hub()
	await _drag(_screen.cell_center(GameSession.stash, Vector2i(0, 0)),
		_screen.cell_center(GameSession.stash, Vector2i(3, 1)))
	assert_object(GameSession.stash.item_at(Vector2i(3, 1))).is_same(boards)
	assert_int(boards.quantity).is_equal(3)
	assert_int(GameSession.bitcoin).is_equal(500)


func test_closing_while_a_click_is_held_sells_nothing() -> void:
	var boards := _stash_item("base:circuit_board", Vector2i(0, 0), 3)
	await _load_ship()
	await _open_hub()
	var at := _screen.cell_center(GameSession.stash, Vector2i(0, 0))
	_mouse_move(at)
	_mouse_button(at, true)
	await _physics_frames(1)
	_player.close_trader()
	_mouse_button(at, false)
	await _physics_frames(roundi(TraderScreen.SELL_HOLD_TIME * 1.2 * FRAMES_PER_SECOND))
	assert_int(boards.quantity).is_equal(3)
	assert_int(GameSession.bitcoin).is_equal(500)


func test_a_stash_stacks_card_shows_what_one_and_all_of_it_sell_for() -> void:
	var boards := _stash_item("base:circuit_board", Vector2i(0, 0), 3)
	var price := GameSession.trader.sell_price(boards.definition)
	await _load_ship()
	await _open_hub()
	_mouse_move(_screen.cell_center(GameSession.stash, Vector2i(0, 0)))
	await _physics_frames(1)
	assert_object(_screen.focused).is_same(boards)
	assert_array(_screen._card_stats(boards.definition)).is_equal([["SELLS FOR", Bitcoin.format(price)],
		["STACK", "3 / 4"], ["ALL FOR", Bitcoin.format(3 * price)]])


func test_clicking_an_item_in_the_shop_buys_one_into_the_stash() -> void:
	await _load_ship()
	await _open_hub()
	var clip := _item("base:thermal_clip")
	var price := GameSession.trader.buy_price(clip)
	await _click(_screen.shop_tile_center(clip))
	assert_int(GameSession.bitcoin).is_equal(500 - price)
	var bought := GameSession.stash.item_at(Vector2i(0, 0))
	assert_object(bought).is_not_null()
	assert_object(bought.definition).is_same(clip)
	assert_object(_screen.selected).is_same(bought)
	assert_str(_screen.bitcoin_text).is_equal(Bitcoin.format(500 - price))
	assert_str(_screen.status_text).is_equal("Thermal clip bought for %s, delivered to the stash." % [
		Bitcoin.format(price)])
	# Another tops up the same stack.
	await _click(_screen.shop_tile_center(clip))
	assert_int(bought.quantity).is_equal(2)
	assert_int(GameSession.stash.items.size()).is_equal(1)


func test_a_gun_is_on_the_shelf_and_can_be_bought() -> void:
	GameSession.bitcoin = 1000
	await _load_ship()
	await _open_hub()
	var pistol := _item("base:laser_pistol")
	await _click(_screen.shop_tile_center(pistol))
	assert_int(GameSession.stash.count(pistol)).is_equal(1)
	assert_int(GameSession.bitcoin).is_equal(1000 - GameSession.trader.buy_price(pistol))


func test_a_buy_the_wallet_cant_cover_is_refused() -> void:
	GameSession.bitcoin = 20
	await _load_ship()
	await _open_hub()
	var pistol := _item("base:laser_pistol")
	await _click(_screen.shop_tile_center(pistol))
	assert_int(GameSession.bitcoin).is_equal(20)
	assert_array(GameSession.stash.items).is_empty()
	assert_str(_screen.status_text).is_equal("Not enough bitcoin: Laser pistol costs %s." % [
		Bitcoin.format(GameSession.trader.buy_price(pistol))])


func test_the_stash_always_has_room_for_a_buy() -> void:
	var drive := _item("base:data_drive")
	for i in GameSession.STASH_SIZE.x * GameSession.STASH_SIZE.y:
		GameSession.stash.add(Item.new(drive, drive.stack_size))
	assert_int(GameSession.stash.size.y).is_equal(GameSession.STASH_SIZE.y + 1)
	await _load_ship()
	await _open_hub()
	var clip := _item("base:thermal_clip")
	await _click(_screen.shop_tile_center(clip))
	assert_int(GameSession.bitcoin).is_equal(500 - GameSession.trader.buy_price(clip))
	assert_str(GameSession.stash.item_at(Vector2i(0, GameSession.STASH_SIZE.y)).definition.id).is_equal(
		"base:thermal_clip")


func test_the_shop_item_under_the_pointer_shows_its_card() -> void:
	await _load_ship()
	await _open_hub()
	var coil := _item("base:plasma_coil")
	_mouse_move(_screen.shop_tile_center(coil))
	await _physics_frames(1)
	assert_object(_screen.shop_item_at_pointer()).is_same(coil)
	assert_object(_screen.focused).is_null()


func test_the_ships_bar_shows_the_wallet_while_trading_too() -> void:
	await _load_ship()
	assert_str(_hud().wallet_text).is_equal("₿500")
	await _open_hub()
	assert_str(_hud().wallet_text).is_equal("₿500")
	var drive := _stash_item("base:data_drive", Vector2i(0, 0))
	await _click(_screen.cell_center(GameSession.stash, Vector2i(0, 0)))
	var wallet := Bitcoin.format(500 + GameSession.trader.sell_price(drive.definition))
	assert_str(_hud().wallet_text).is_equal(wallet)
	await _press(&"inventory")
	assert_str(_hud().wallet_text).is_equal(wallet)


func test_the_player_stands_still_while_trading() -> void:
	await _load_ship()
	await _open_hub()
	var start := _player.global_position
	Input.action_press(&"move_forward")
	await _physics_frames(20)
	Input.action_release(&"move_forward")
	assert_float(_player.global_position.distance_to(start)).is_less(0.01)


func _load_ship() -> void:
	_runner = scene_runner(SHIP_SCENE)
	_runner.set_time_factor(5.0)
	_player = _runner.find_child("Player") as Player
	_screen = _player.get_trader_screen()
	await _physics_frames(2)


func _look_at_terminal() -> void:
	_player.global_position = BEFORE_TERMINAL
	_player.velocity = Vector3.ZERO
	_player.set_look(SOUTH)
	_player.reset_physics_interpolation()
	await _physics_frames(2)
	var camera := _player.get_viewport().get_camera_3d().global_position
	var angles := RobotRules.aim_angles(Basis.IDENTITY, camera, TERMINAL_SCREEN)
	_player.set_look(angles.x, angles.y)
	await _physics_frames(3)


func _open_hub() -> void:
	await _look_at_terminal()
	await _press(&"interact")
	assert_bool(_screen.is_open).is_true()


## Presses the drag button at from, moves to to and lets go there, as mouse events through the viewport.
func _drag(from: Vector2, to: Vector2) -> void:
	_mouse_move(from)
	_mouse_button(from, true)
	await _physics_frames(1)
	_mouse_move(to)
	await _physics_frames(1)
	_mouse_button(to, false)
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


static func _stash_item(id: String, cell: Vector2i, quantity: int = 1) -> Item:
	var item := Item.new(_item(id), quantity)
	GameSession.stash.place(item, cell)
	return item


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition
