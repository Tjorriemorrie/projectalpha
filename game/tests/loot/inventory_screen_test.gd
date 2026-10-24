extends GdUnitTestSuite
## Works the inventory screen in the loot test level, through the calls its mouse input makes and through mouse
## events pushed into the viewport: dragging stacks between slots, topping up stacks of a kind, putting back what
## can't land, splitting a stack and taking one more or fewer, quick moves (shift-click and double-click) to and from
## the player, dropping onto, topping up and picking up from the floor, selecting, the item card, and where the
## placards and key hints sit. The player searches the store room's locker, which holds a gyroscope at (0, 0), a
## power cell at (1, 0) and a stack of two thermal clips at (2, 0); the player carries the laser pistol (₿200) in the
## weapon slot, two fresh clips in the ammo slots and two in the backpack, each stack at (0, 0), and stands in the
## store room with nothing on the floor.

const TEST_SCENE := "res://scenes/test/loot_test.tscn"

var _runner: GdUnitSceneRunner
var _wreck: Wreck
var _player: Player
var _screen: InventoryScreen
var _locker: Lootable
var _inventory: Inventory
var _window_size: Vector2i


func before_test() -> void:
	# Headless runs have a tiny window; the screen is laid out for a real one.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	_runner = scene_runner(TEST_SCENE)
	_runner.set_time_factor(5.0)
	_wreck = _runner.scene() as Wreck
	_player = _runner.find_child("Player") as Player
	_screen = _player.get_inventory_screen()
	_inventory = _player.inventory
	_locker = _wreck.containers[0].get_lootable()
	_player.global_position = Vector3(0.0, 0.0, 0.5)
	await _physics_frames(2)
	_locker.interact()
	_player.open_inventory(_locker)
	await _physics_frames(2)


func after_test() -> void:
	get_tree().root.size = _window_size


func test_shows_what_is_carried_and_an_empty_floor() -> void:
	assert_bool(_screen.is_open).is_true()
	assert_str(_screen.carried_text).is_equal("CARRIED  ₿300   ·   7 FREE SLOTS")
	assert_int(_locker.grid.item_at(Vector2i(2, 0)).quantity).is_equal(2)
	assert_array(_screen.floor_grid.items).is_empty()
	assert_vector(Vector2(_screen.floor_grid.size)).is_equal(Vector2(6, 1))


func test_drags_a_stack_into_a_free_slot() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	assert_bool(_screen.begin_drag(_locker.grid, Vector2i(0, 0))).is_true()
	assert_bool(_locker.grid.has(gyroscope)).is_false()
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(3, 0))).is_true()
	assert_object(_inventory.backpack.item_at(Vector2i(3, 0))).is_same(gyroscope)
	assert_object(_screen.dragged).is_null()
	assert_str(_screen.carried_text).is_equal("CARRIED  ₿460   ·   6 FREE SLOTS")


func test_a_stack_dropped_on_another_kind_goes_back() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(0, 0))).is_false()
	assert_object(_locker.grid.item_at(Vector2i(0, 0))).is_same(gyroscope)
	assert_int(_inventory.backpack.item_at(Vector2i(0, 0)).quantity).is_equal(2)


func test_only_clips_go_in_the_ammo_slots_and_only_a_gun_in_the_weapon_slot() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_inventory.ammo, Vector2i(1, 0))).is_false()
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	_screen.drop_drag(_inventory.pockets, Vector2i(0, 0))
	_screen.begin_drag(_inventory.weapon, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_inventory.pockets, Vector2i(0, 0))).is_false()
	assert_object(_inventory.pockets.item_at(Vector2i(0, 0))).is_same(gyroscope)
	assert_object(_inventory.gun()).is_not_null()


func test_a_stack_dropped_on_its_kind_tops_it_up_and_the_rest_goes_back() -> void:
	var packed := _inventory.backpack.item_at(Vector2i(0, 0))
	packed.quantity = 4
	_screen.begin_drag(_locker.grid, Vector2i(2, 0))
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(0, 0))).is_true()
	assert_int(packed.quantity).is_equal(5)
	var left := _locker.grid.item_at(Vector2i(2, 0))
	assert_str(left.definition.id).is_equal("base:thermal_clip")
	assert_int(left.quantity).is_equal(1)
	assert_object(_screen.dragged).is_null()


func test_splitting_takes_half_and_the_wheel_takes_one_more_or_fewer() -> void:
	var clips := _locker.grid.item_at(Vector2i(2, 0))
	clips.quantity = 5
	assert_bool(_screen.begin_split(_locker.grid, Vector2i(2, 0))).is_true()
	assert_int(_screen.dragged.quantity).is_equal(3)
	assert_int(clips.quantity).is_equal(2)
	_screen.adjust_drag(1)
	_screen.adjust_drag(1)
	# All of it in hand: its slot is empty.
	assert_int(_screen.dragged.quantity).is_equal(5)
	assert_object(_locker.grid.item_at(Vector2i(2, 0))).is_null()
	assert_bool(_screen.adjust_drag(1)).is_false()
	_screen.adjust_drag(-1)
	assert_int(_screen.dragged.quantity).is_equal(4)
	assert_int(_locker.grid.item_at(Vector2i(2, 0)).quantity).is_equal(1)
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(5, 0))).is_true()
	assert_int(_inventory.backpack.item_at(Vector2i(5, 0)).quantity).is_equal(4)
	assert_int(_locker.grid.item_at(Vector2i(2, 0)).quantity).is_equal(1)


func test_splits_with_the_right_button_and_the_wheel() -> void:
	var clips := _locker.grid.item_at(Vector2i(2, 0))
	clips.quantity = 4
	var at := _screen.cell_center(_locker.grid, Vector2i(2, 0))
	_mouse_button(at, true, MOUSE_BUTTON_RIGHT)
	assert_int(_screen.dragged.quantity).is_equal(2)
	_mouse_button(at, true, MOUSE_BUTTON_WHEEL_UP)
	assert_int(_screen.dragged.quantity).is_equal(3)
	var target := _screen.cell_center(_inventory.backpack, Vector2i(4, 0))
	_mouse_move(target)
	_mouse_button(target, false, MOUSE_BUTTON_RIGHT)
	assert_int(_inventory.backpack.item_at(Vector2i(4, 0)).quantity).is_equal(3)
	assert_int(clips.quantity).is_equal(1)


func test_closing_puts_a_stack_in_hand_back() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	var clips := _locker.grid.item_at(Vector2i(2, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	_player.close_inventory()
	assert_object(_locker.grid.item_at(Vector2i(0, 0))).is_same(gyroscope)
	_player.open_inventory(_locker)
	_screen.begin_split(_locker.grid, Vector2i(2, 0))
	_player.close_inventory()
	assert_object(_locker.grid.item_at(Vector2i(2, 0))).is_same(clips)
	assert_int(clips.quantity).is_equal(2)
	assert_bool(_screen.is_open).is_false()


func test_a_quick_move_from_a_container_goes_to_the_players_slots() -> void:
	# Clips top up the stack in the ammo slots; anything else goes to the backpack's first free slot.
	assert_bool(_screen.quick_move(_locker.grid, Vector2i(2, 0))).is_true()
	assert_int(_inventory.ammo.item_at(Vector2i(0, 0)).quantity).is_equal(4)
	assert_object(_locker.grid.item_at(Vector2i(2, 0))).is_null()
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.quick_move(_locker.grid, Vector2i(0, 0))
	assert_object(_inventory.backpack.item_at(Vector2i(1, 0))).is_same(gyroscope)


func test_a_quick_move_from_the_player_goes_into_the_open_container() -> void:
	assert_bool(_screen.quick_move(_inventory.backpack, Vector2i(0, 0))).is_true()
	assert_object(_inventory.backpack.item_at(Vector2i(0, 0))).is_null()
	assert_int(_locker.grid.item_at(Vector2i(2, 0)).quantity).is_equal(4)


func test_a_quick_move_leaves_what_doesnt_fit() -> void:
	var drive := ContentRegistry.get_definition("base:data_drive") as ItemDefinition
	for grid: ItemGrid in [_inventory.pockets, _inventory.backpack]:
		while grid.free_slots() > 0:
			grid.add(Item.new(drive, drive.stack_size))
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	assert_bool(_screen.quick_move(_locker.grid, Vector2i(0, 0))).is_false()
	assert_object(_locker.grid.item_at(Vector2i(0, 0))).is_same(gyroscope)


func test_shift_click_and_double_click_quick_move() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	var at := _screen.cell_center(_locker.grid, Vector2i(0, 0))
	_mouse_button(at, true, MOUSE_BUTTON_LEFT, true)
	_mouse_button(at, false, MOUSE_BUTTON_LEFT, true)
	assert_object(_inventory.backpack.item_at(Vector2i(1, 0))).is_same(gyroscope)
	assert_object(_screen.dragged).is_null()
	var cell := _locker.grid.item_at(Vector2i(1, 0))
	var power := _screen.cell_center(_locker.grid, Vector2i(1, 0))
	_mouse_button(power, true)
	_mouse_button(power, false)
	_mouse_button(power, true, MOUSE_BUTTON_LEFT, false, true)
	_mouse_button(power, false)
	assert_object(_inventory.backpack.item_at(Vector2i(2, 0))).is_same(cell)


func test_without_a_container_a_quick_move_drops_on_the_floor() -> void:
	_player.close_inventory()
	_player.open_inventory()
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	assert_bool(_screen.quick_move(_inventory.backpack, Vector2i(0, 0))).is_true()
	assert_bool(_screen.floor_grid.has(clips)).is_true()
	await _physics_frames(2)
	assert_object(_dropped(clips)).is_not_null()


func test_dragging_onto_the_floor_drops_it_into_the_world() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_screen.floor_grid, Vector2i(1, 0))).is_true()
	assert_object(_screen.floor_grid.item_at(Vector2i(1, 0))).is_same(gyroscope)
	await _physics_frames(2)
	assert_object(_dropped(gyroscope)).is_not_null()


func test_releasing_outside_drops_it_onto_the_floor() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	assert_bool(_screen.floor_grid.has(clips)).is_true()
	assert_bool(_inventory.backpack.has(clips)).is_false()
	await _physics_frames(2)
	var dropped := _dropped(clips)
	assert_object(dropped).is_not_null()
	assert_int(dropped.item.quantity).is_equal(2)


func test_dragging_off_the_floor_picks_it_up() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	var dropped := _dropped(clips)
	assert_bool(_screen.begin_drag(_screen.floor_grid, clips.cell)).is_true()
	assert_bool(_screen.drop_drag(_inventory.pockets, Vector2i(1, 0))).is_true()
	assert_object(_inventory.pockets.item_at(Vector2i(1, 0))).is_same(clips)
	await _physics_frames(2)
	assert_bool(is_instance_valid(dropped)).is_false()


func test_taking_part_of_a_floor_stack_leaves_the_rest_lying_there() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	var dropped := _dropped(clips)
	_screen.begin_split(_screen.floor_grid, clips.cell)
	_screen.drop_drag(_inventory.pockets, Vector2i(1, 0))
	await _physics_frames(2)
	assert_bool(is_instance_valid(dropped)).is_true()
	assert_int(dropped.item.quantity).is_equal(1)
	assert_int(_inventory.pockets.item_at(Vector2i(1, 0)).quantity).is_equal(1)


func test_dropping_onto_a_floor_stack_of_its_kind_tops_it_up_with_no_new_object() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	_screen.begin_drag(_inventory.ammo, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_screen.floor_grid, clips.cell)).is_true()
	await _physics_frames(2)
	assert_int(clips.quantity).is_equal(4)
	assert_int(_all_dropped().size()).is_equal(1)
	assert_object(_inventory.ammo.item_at(Vector2i(0, 0))).is_null()


func test_a_floor_stack_released_outside_stays_on_the_floor() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	var cell := clips.cell
	_screen.begin_drag(_screen.floor_grid, cell)
	_screen.drop_drag_outside()
	assert_object(_screen.floor_grid.item_at(cell)).is_same(clips)
	await _physics_frames(2)
	assert_int(_all_dropped().size()).is_equal(1)


func test_the_floor_keeps_a_spare_row() -> void:
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	_screen.drop_drag(_screen.floor_grid, Vector2i(0, 0))
	assert_int(_screen.floor_grid.size.y).is_equal(2)
	_screen.begin_drag(_locker.grid, Vector2i(1, 0))
	_screen.drop_drag(_screen.floor_grid, Vector2i(3, 1))
	assert_int(_screen.floor_grid.size.y).is_equal(3)


func test_drags_with_the_mouse() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_mouse_button(_screen.cell_center(_locker.grid, Vector2i(0, 0)), true)
	assert_object(_screen.dragged).is_same(gyroscope)
	_mouse_move(_screen.cell_center(_inventory.backpack, Vector2i(3, 0)))
	_mouse_button(_screen.cell_center(_inventory.backpack, Vector2i(3, 0)), false)
	assert_object(_inventory.backpack.item_at(Vector2i(3, 0))).is_same(gyroscope)
	assert_object(_screen.dragged).is_null()


func test_releasing_the_mouse_outside_drops_the_stack() -> void:
	var clips := _inventory.backpack.item_at(Vector2i(0, 0))
	_mouse_button(_screen.cell_center(_inventory.backpack, Vector2i(0, 0)), true)
	# The middle of the screen is clear of every placard.
	var middle := _screen.size / 2.0
	_mouse_move(middle)
	_mouse_button(middle, false)
	assert_bool(_screen.floor_grid.has(clips)).is_true()


func test_pressing_a_stack_selects_it_and_pressing_empty_space_clears_it() -> void:
	var clips := _locker.grid.item_at(Vector2i(2, 0))
	var at := _screen.cell_center(_locker.grid, Vector2i(2, 0))
	_mouse_button(at, true)
	_mouse_button(at, false)
	assert_object(_screen.selected).is_same(clips)
	assert_object(_locker.grid.item_at(Vector2i(2, 0))).is_same(clips)
	var empty := _screen.cell_center(_inventory.backpack, Vector2i(5, 0))
	_mouse_button(empty, true)
	_mouse_button(empty, false)
	assert_object(_screen.selected).is_null()


func test_the_stack_under_the_pointer_shows_its_card() -> void:
	var clips := _locker.grid.item_at(Vector2i(2, 0))
	_mouse_move(_screen.cell_center(_locker.grid, Vector2i(2, 0)))
	assert_object(_screen.focused).is_same(clips)
	assert_array(_screen._card_stats(clips.definition)).is_equal(
		[["VALUE", "₿25"], ["STACK", "2 / 5"], ["SLOT", "₿50"]])
	_mouse_move(_screen.cell_center(_inventory.backpack, Vector2i(5, 0)))
	assert_object(_screen.focused).is_null()


func test_puts_the_player_on_the_right_and_the_loot_on_the_left() -> void:
	var middle := _screen.size.x / 2.0
	for grid: ItemGrid in [_inventory.weapon, _inventory.ammo, _inventory.pockets, _inventory.backpack]:
		assert_float(_screen.cell_center(grid, Vector2i(0, 0)).x).is_greater(middle)
	assert_float(_screen.cell_center(_locker.grid, Vector2i(2, 0)).x).is_less(middle)
	assert_float(_screen.cell_center(_screen.floor_grid, Vector2i(5, 0)).x).is_less(middle)


func test_key_hints_stay_on_screen_when_it_opens_again() -> void:
	for i in 3:
		_player.close_inventory()
		await _physics_frames(2)
		_player.open_inventory(_locker)
		await _physics_frames(2)
		var hint := _screen.hint_rect()
		assert_float(hint.position.x).is_greater_equal(0.0)
		assert_float(hint.end.x).is_less_equal(_screen.size.x)


func test_nothing_to_drag_in_an_empty_slot() -> void:
	assert_bool(_screen.begin_drag(_inventory.backpack, Vector2i(5, 0))).is_false()
	assert_bool(_screen.begin_split(_inventory.backpack, Vector2i(5, 0))).is_false()
	assert_object(_screen.dragged).is_null()


## A mouse move, pushed through the viewport the way the window sends it, so the screen gets it like a real one.
func _mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_screen.get_viewport().push_input(event)


func _mouse_button(position: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false,
		double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.double_click = double
	event.button_mask = (1 << (button - 1)) if pressed else 0
	event.position = position
	event.global_position = position
	_screen.get_viewport().push_input(event)


func _dropped(item: Item) -> DroppedItem:
	for dropped in _all_dropped():
		if dropped.item == item:
			return dropped
	return null


func _all_dropped() -> Array[DroppedItem]:
	var found: Array[DroppedItem] = []
	for node in get_tree().get_nodes_in_group(DroppedItem.GROUP):
		found.append(node as DroppedItem)
	return found


func _physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
