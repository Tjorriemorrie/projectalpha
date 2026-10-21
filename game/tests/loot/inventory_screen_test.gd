extends GdUnitTestSuite
## Works the inventory screen in the loot test level, through the calls its mouse input makes and through mouse
## events pushed into the viewport: dragging items between grids, turning and mirroring them while dragged, putting
## back what doesn't fit, dropping onto and picking up from the floor, selecting, the item card, and where the
## placards and key hints sit. Loot only moves by being dragged. The player searches the store room's locker, which
## holds a gyroscope at (0, 0), a power cell at (2, 0) and two thermal clips at (3, 0) and (3, 1); the player carries
## two fresh clips in the pockets and two in the backpack, at (0, 0) and (1, 0) of each, and stands in the store room
## with nothing on the floor.

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
	assert_str(_screen.carried_text).is_equal("CARRIED  100 CR   ·   30 FREE CELLS")
	assert_array(_screen.floor_grid.items).is_empty()
	assert_vector(Vector2(_screen.floor_grid.size)).is_equal(Vector2(6, 2))


func test_drags_an_item_into_the_backpack() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	# Picked up by its bottom right cell, which lands on (3, 3): the gyroscope covers (2, 2) to (3, 3).
	assert_bool(_screen.begin_drag(_locker.grid, Vector2i(1, 1))).is_true()
	assert_bool(_locker.grid.has(gyroscope)).is_false()
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(3, 3))).is_true()
	assert_object(_inventory.backpack.item_at(Vector2i(2, 2))).is_same(gyroscope)
	assert_object(_screen.dragged).is_null()
	assert_str(_screen.carried_text).is_equal("CARRIED  260 CR   ·   26 FREE CELLS")


func test_an_item_that_doesnt_fit_goes_back() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	# The backpack's clips are at (0, 0) and (1, 0).
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(0, 0))).is_false()
	assert_object(_locker.grid.item_at(Vector2i(0, 0))).is_same(gyroscope)
	assert_int(gyroscope.orientation).is_equal(0)


func test_turns_and_mirrors_the_dragged_item() -> void:
	var cell := _locker.grid.item_at(Vector2i(2, 0))
	assert_str(cell.definition.id).is_equal("base:power_cell")
	_screen.begin_drag(_locker.grid, Vector2i(2, 0))
	_screen.rotate_drag()
	assert_int(cell.orientation).is_equal(1)
	_screen.mirror_drag()
	assert_int(cell.orientation).is_equal(ItemShape.mirrored(1))
	# Turned and mirrored the L lies as "###" over "..#", held by the cell that was its top, now its left end.
	assert_bool(_screen.drop_drag(_inventory.backpack, Vector2i(2, 3))).is_true()
	assert_array(cell.cells()).contains_exactly_in_any_order(
		[Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4)])


func test_dragging_onto_the_floor_drops_it_into_the_world() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	assert_bool(_screen.drop_drag(_screen.floor_grid, Vector2i(1, 0))).is_true()
	assert_object(_screen.floor_grid.item_at(Vector2i(1, 0))).is_same(gyroscope)
	await _physics_frames(2)
	assert_object(_dropped(gyroscope)).is_not_null()


func test_releasing_outside_drops_it_onto_the_floor() -> void:
	var clip := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	assert_bool(_screen.floor_grid.has(clip)).is_true()
	assert_bool(_inventory.backpack.has(clip)).is_false()
	await _physics_frames(2)
	assert_object(_dropped(clip)).is_not_null()


func test_dragging_off_the_floor_picks_it_up() -> void:
	var clip := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	var dropped := _dropped(clip)
	assert_bool(_screen.begin_drag(_screen.floor_grid, clip.cell)).is_true()
	assert_bool(_screen.drop_drag(_inventory.pockets, Vector2i(3, 0))).is_true()
	assert_object(_inventory.pockets.item_at(Vector2i(3, 0))).is_same(clip)
	await _physics_frames(2)
	assert_bool(is_instance_valid(dropped)).is_false()


func test_a_floor_item_released_outside_stays_on_the_floor() -> void:
	var clip := _inventory.backpack.item_at(Vector2i(0, 0))
	_screen.begin_drag(_inventory.backpack, Vector2i(0, 0))
	_screen.drop_drag_outside()
	await _physics_frames(2)
	var cell := clip.cell
	_screen.begin_drag(_screen.floor_grid, cell)
	_screen.drop_drag_outside()
	assert_object(_screen.floor_grid.item_at(cell)).is_same(clip)
	await _physics_frames(2)
	assert_int(_all_dropped().size()).is_equal(1)


func test_the_floor_keeps_two_empty_rows() -> void:
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	_screen.drop_drag(_screen.floor_grid, Vector2i(0, 0))
	assert_int(_screen.floor_grid.size.y).is_equal(4)
	_screen.begin_drag(_locker.grid, Vector2i(2, 0))
	_screen.drop_drag_outside()
	# The power cell went to the floor's first free spot; the floor grew to keep two rows free below it.
	assert_int(_screen.floor_grid.size.y).is_equal(_screen.floor_grid.rows_used() + 2)


func test_drags_with_the_mouse() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_mouse_button(_screen.cell_center(_locker.grid, Vector2i(1, 1)), true)
	assert_object(_screen.dragged).is_same(gyroscope)
	_mouse_move(_screen.cell_center(_inventory.backpack, Vector2i(3, 3)))
	_mouse_button(_screen.cell_center(_inventory.backpack, Vector2i(3, 3)), false)
	assert_object(_inventory.backpack.item_at(Vector2i(2, 2))).is_same(gyroscope)
	assert_object(_screen.dragged).is_null()


func test_releasing_the_mouse_outside_drops_the_item() -> void:
	var clip := _inventory.backpack.item_at(Vector2i(0, 0))
	_mouse_button(_screen.cell_center(_inventory.backpack, Vector2i(0, 0)), true)
	# The middle of the screen is clear of every placard.
	var middle := _screen.size / 2.0
	_mouse_move(middle)
	_mouse_button(middle, false)
	assert_bool(_screen.floor_grid.has(clip)).is_true()


func test_pressing_an_item_selects_it_and_pressing_empty_space_clears_it() -> void:
	var clip := _locker.grid.item_at(Vector2i(3, 0))
	var at := _screen.cell_center(_locker.grid, Vector2i(3, 0))
	_mouse_button(at, true)
	_mouse_button(at, false)
	assert_object(_screen.selected).is_same(clip)
	assert_object(_locker.grid.item_at(Vector2i(3, 0))).is_same(clip)
	var empty := _screen.cell_center(_inventory.backpack, Vector2i(5, 4))
	_mouse_button(empty, true)
	_mouse_button(empty, false)
	assert_object(_screen.selected).is_null()


func test_the_item_under_the_pointer_shows_its_card() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_mouse_move(_screen.cell_center(_locker.grid, Vector2i(1, 0)))
	assert_object(_screen.focused).is_same(gyroscope)
	_mouse_move(_screen.cell_center(_inventory.backpack, Vector2i(5, 4)))
	assert_object(_screen.focused).is_null()


func test_puts_the_player_on_the_right_and_the_loot_on_the_left() -> void:
	var middle := _screen.size.x / 2.0
	assert_float(_screen.cell_center(_inventory.pockets, Vector2i(0, 0)).x).is_greater(middle)
	assert_float(_screen.cell_center(_inventory.backpack, Vector2i(0, 0)).x).is_greater(middle)
	assert_float(_screen.cell_center(_locker.grid, Vector2i(3, 0)).x).is_less(middle)
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


func test_closing_puts_a_dragged_item_back() -> void:
	var gyroscope := _locker.grid.item_at(Vector2i(0, 0))
	_screen.begin_drag(_locker.grid, Vector2i(0, 0))
	_screen.rotate_drag()
	_player.close_inventory()
	assert_object(_locker.grid.item_at(Vector2i(0, 0))).is_same(gyroscope)
	assert_int(gyroscope.orientation).is_equal(0)
	assert_bool(_screen.is_open).is_false()


func test_nothing_to_drag_on_an_empty_cell() -> void:
	assert_bool(_screen.begin_drag(_inventory.backpack, Vector2i(5, 4))).is_false()
	assert_object(_screen.dragged).is_null()


## A mouse move, pushed through the viewport the way the window sends it, so the screen gets it like a real one.
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
