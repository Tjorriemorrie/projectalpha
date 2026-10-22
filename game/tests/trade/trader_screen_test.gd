extends GdUnitTestSuite
## Trades at the hub from the player's ship with travel turned off, through the trader terminal and mouse events
## pushed into the viewport: interact on the terminal opens the hub's screen; items dragged from the stash into the
## sell crate show the hub's offer, and SELL sells them into the wallet; clicking an item in the shop buys one into
## the stash, unless the wallet is short or the stash is full; the card of the shop item under the pointer shows its
## price; closing puts what is left in the crate back into the stash; at home the HUD shows the bitcoin in the wallet,
## except while trading; and the player stands still while trading.
## Positions refer to the layout of res://scenes/ship/ship.tscn: the stash room south of x = 12, with the trader
## terminal against its south wall at (13.35, 0, 5.8), facing north, its screen 1.5 m up.

const SHIP_SCENE := "res://scenes/ship/ship.tscn"
const ACTIONS: Array[StringName] = [&"interact", &"inventory", &"pause", &"move_forward"]
const SOUTH := PI
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
	assert_str(_screen.offer_text).is_equal("EMPTY")


func test_the_terminal_shows_the_hub_its_linked_to() -> void:
	await _load_ship()
	var text := _runner.find_child("TraderTerminal").get_node("%ScreenText") as Label3D
	assert_str(text.text).is_equal("TRADER LINK\nTRADER HUB")


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


func test_items_dragged_into_the_crate_sell_for_the_hubs_offer() -> void:
	var gyroscope := _stash_item("base:gyroscope", Vector2i(0, 0))
	var drive := _stash_item("base:data_drive", Vector2i(4, 0))
	await _load_ship()
	await _open_hub()
	await _drag(_screen.cell_center(GameSession.stash, Vector2i(0, 0)),
		_screen.cell_center(GameSession.crate, Vector2i(0, 0)))
	await _drag(_screen.cell_center(GameSession.stash, Vector2i(4, 0)),
		_screen.cell_center(GameSession.crate, Vector2i(3, 0)))
	assert_bool(GameSession.crate.has(gyroscope)).is_true()
	assert_bool(GameSession.crate.has(drive)).is_true()
	var offer := GameSession.trader.sell_price(gyroscope.definition) + GameSession.trader.sell_price(drive.definition)
	assert_str(_screen.offer_text).is_equal("OFFER  %s" % Bitcoin.format(offer))
	await _click(_screen.sell_button_center())
	assert_int(GameSession.bitcoin).is_equal(500 + offer)
	assert_array(GameSession.crate.items).is_empty()
	assert_array(GameSession.stash.items).is_empty()
	assert_str(_screen.status_text).is_equal("Sold 2 items for %s." % Bitcoin.format(offer))
	assert_str(_screen.offer_text).is_equal("EMPTY")


func test_selling_an_empty_crate_says_how_to_sell() -> void:
	await _load_ship()
	await _open_hub()
	await _click(_screen.sell_button_center())
	assert_int(GameSession.bitcoin).is_equal(500)
	assert_str(_screen.status_text).is_equal("Drag items from the stash into the crate to sell them.")


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


func test_a_buy_with_no_room_in_the_stash_is_refused() -> void:
	var drive := _item("base:data_drive")
	for i in GameSession.STASH_SIZE.x * GameSession.STASH_SIZE.y:
		GameSession.stash.add(Item.new(drive))
	await _load_ship()
	await _open_hub()
	await _click(_screen.shop_tile_center(_item("base:thermal_clip")))
	assert_int(GameSession.bitcoin).is_equal(500)
	assert_str(_screen.status_text).is_equal(
		"No room in the stash for Thermal clip. Make space or sell something first.")


func test_the_shop_item_under_the_pointer_shows_its_card() -> void:
	await _load_ship()
	await _open_hub()
	var coil := _item("base:plasma_coil")
	_mouse_move(_screen.shop_tile_center(coil))
	await _physics_frames(1)
	assert_object(_screen.shop_item_at_pointer()).is_same(coil)
	assert_object(_screen.focused).is_null()


func test_closing_puts_whats_left_in_the_crate_back_in_the_stash() -> void:
	var gyroscope := _stash_item("base:gyroscope", Vector2i(0, 0))
	await _load_ship()
	await _open_hub()
	await _drag(_screen.cell_center(GameSession.stash, Vector2i(0, 0)),
		_screen.cell_center(GameSession.crate, Vector2i(2, 1)))
	assert_bool(GameSession.crate.has(gyroscope)).is_true()
	_player.close_trader()
	assert_bool(GameSession.stash.has(gyroscope)).is_true()
	assert_array(GameSession.crate.items).is_empty()
	assert_int(GameSession.bitcoin).is_equal(500)


func test_at_home_the_hud_shows_the_wallet_except_while_trading() -> void:
	await _load_ship()
	assert_str(_hud().wallet_text).is_equal("₿500")
	await _open_hub()
	# The hub's screen shows its own wallet.
	assert_str(_hud().wallet_text).is_empty()
	var drive := _stash_item("base:data_drive", Vector2i(0, 0))
	await _drag(_screen.cell_center(GameSession.stash, Vector2i(0, 0)),
		_screen.cell_center(GameSession.crate, Vector2i(0, 0)))
	await _click(_screen.sell_button_center())
	await _press(&"inventory")
	assert_str(_hud().wallet_text).is_equal(Bitcoin.format(500 + GameSession.trader.sell_price(drive.definition)))


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


static func _stash_item(id: String, cell: Vector2i) -> Item:
	var item := Item.new(_item(id))
	GameSession.stash.place(item, cell, 0)
	return item


static func _item(id: String) -> ItemDefinition:
	return ContentRegistry.get_definition(id) as ItemDefinition
