extends GdUnitTestSuite
## Unit tests for ItemGrid: slots holding stacks of one kind, placing and moving stacks, topping up and adding,
## taking part of a stack, the room for more, counting and values, growing grids that keep a spare row, and stowing
## a stack across grids.

var _drive: ItemDefinition
var _coil: ItemDefinition
var _clip: ItemDefinition


func before_test() -> void:
	_drive = _item("drive", 5, 150)
	_coil = _item("coil", 2, 180)
	_clip = _item("clip", 5, 25)


func test_a_stack_takes_one_free_slot() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	var stack := Item.new(_drive, 3)
	assert_bool(grid.place(stack, Vector2i(1, 1))).is_true()
	assert_object(grid.item_at(Vector2i(1, 1))).is_same(stack)
	assert_object(grid.item_at(Vector2i(0, 0))).is_null()
	assert_int(grid.free_slots()).is_equal(5)
	assert_int(grid.item_count()).is_equal(3)


func test_nothing_shares_a_slot_or_sits_outside_the_grid() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	grid.place(Item.new(_drive), Vector2i(0, 0))
	assert_bool(grid.place(Item.new(_drive), Vector2i(0, 0))).is_false()
	assert_bool(grid.place(Item.new(_coil), Vector2i(0, 0))).is_false()
	assert_bool(grid.fits(_coil, Vector2i(3, 0))).is_false()
	assert_bool(grid.fits(_coil, Vector2i(-1, 0))).is_false()
	assert_bool(grid.fits(_coil, Vector2i(2, 1))).is_true()


func test_a_stack_moves_to_another_slot_and_frees_its_own() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	var stack := Item.new(_coil)
	grid.place(stack, Vector2i(0, 0))
	assert_bool(grid.place(stack, Vector2i(2, 1))).is_true()
	assert_object(grid.item_at(Vector2i(0, 0))).is_null()
	assert_object(grid.item_at(Vector2i(2, 1))).is_same(stack)
	assert_int(grid.items.size()).is_equal(1)


func test_removes_a_stack() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	var stack := Item.new(_coil)
	grid.place(stack, Vector2i(1, 0))
	assert_bool(grid.remove(stack)).is_true()
	assert_object(grid.item_at(Vector2i(1, 0))).is_null()
	assert_bool(grid.remove(stack)).is_false()
	assert_int(grid.free_slots()).is_equal(6)


func test_tops_up_stacks_of_its_kind_in_reading_order() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	var second := Item.new(_drive, 4)
	var first := Item.new(_drive, 3)
	grid.place(second, Vector2i(0, 1))
	grid.place(first, Vector2i(2, 0))
	grid.place(Item.new(_coil), Vector2i(0, 0))
	var more := Item.new(_drive, 4)
	assert_int(grid.top_up(more)).is_equal(3)
	assert_int(first.quantity).is_equal(5)
	assert_int(second.quantity).is_equal(5)
	assert_int(more.quantity).is_equal(1)


func test_add_tops_up_first_and_puts_the_rest_in_the_first_free_slot() -> void:
	var grid := ItemGrid.new(Vector2i(3, 1))
	var stack := Item.new(_drive, 4)
	grid.place(stack, Vector2i(1, 0))
	var more := Item.new(_drive, 3)
	assert_bool(grid.add(more)).is_true()
	assert_int(stack.quantity).is_equal(5)
	assert_object(grid.item_at(Vector2i(0, 0))).is_same(more)
	assert_int(more.quantity).is_equal(2)


func test_add_into_a_full_grid_keeps_what_doesnt_fit() -> void:
	var grid := ItemGrid.new(Vector2i(1, 1))
	grid.place(Item.new(_drive, 4), Vector2i(0, 0))
	var more := Item.new(_drive, 3)
	assert_bool(grid.add(more)).is_false()
	assert_int(grid.item_at(Vector2i(0, 0)).quantity).is_equal(5)
	assert_int(more.quantity).is_equal(2)
	assert_bool(grid.has(more)).is_false()


func test_adds_one_onto_a_stack_with_room_or_a_free_slot() -> void:
	var grid := ItemGrid.new(Vector2i(2, 1))
	var first := grid.add_one(_coil)
	assert_object(grid.add_one(_coil)).is_same(first)
	assert_int(first.quantity).is_equal(2)
	var second := grid.add_one(_coil)
	assert_object(second).is_not_same(first)
	assert_vector(Vector2(second.cell)).is_equal(Vector2(1, 0))
	grid.add_one(_coil)
	assert_object(grid.add_one(_coil)).is_null()


func test_the_room_for_a_kind_counts_its_stacks_and_free_slots() -> void:
	var grid := ItemGrid.new(Vector2i(3, 1))
	grid.place(Item.new(_drive, 3), Vector2i(0, 0))
	grid.place(Item.new(_coil), Vector2i(1, 0))
	assert_int(grid.room_for(_drive)).is_equal(2 + 5)
	assert_int(grid.room_for(_coil)).is_equal(1 + 2)
	assert_int(grid.room_at(_drive, Vector2i(0, 0))).is_equal(2)
	assert_int(grid.room_at(_drive, Vector2i(1, 0))).is_equal(0)
	assert_int(grid.room_at(_drive, Vector2i(2, 0))).is_equal(5)


func test_takes_part_of_a_stack_or_all_of_it() -> void:
	var grid := ItemGrid.new(Vector2i(3, 1))
	var stack := Item.new(_drive, 5)
	grid.place(stack, Vector2i(0, 0))
	var part := grid.take(stack, 2)
	assert_int(part.quantity).is_equal(2)
	assert_int(stack.quantity).is_equal(3)
	assert_bool(grid.has(part)).is_false()
	assert_object(grid.take(stack, 9)).is_same(stack)
	assert_int(stack.quantity).is_equal(3)
	assert_bool(grid.has(stack)).is_false()


func test_counts_finds_and_values_what_it_holds() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	grid.place(Item.new(_clip, 2), Vector2i(2, 1))
	var first := Item.new(_clip, 3)
	grid.place(first, Vector2i(1, 0))
	grid.place(Item.new(_coil, 2), Vector2i(0, 1))
	assert_int(grid.count(_clip)).is_equal(5)
	assert_object(grid.first_of(_clip)).is_same(first)
	assert_object(grid.first_of(_drive)).is_null()
	assert_int(grid.value()).is_equal(5 * 25 + 2 * 180)
	assert_int(grid.item_count()).is_equal(7)
	assert_int(grid.rows_used()).is_equal(2)


func test_a_quantity_change_redraws_the_grid() -> void:
	var grid := ItemGrid.new(Vector2i(3, 1))
	var stack := Item.new(_drive, 2)
	grid.place(stack, Vector2i(0, 0))
	var changes := [0]
	grid.changed.connect(func() -> void: changes[0] += 1)
	stack.quantity = 3
	assert_int(changes[0]).is_equal(1)
	grid.remove(stack)
	stack.quantity = 4
	assert_int(changes[0]).is_equal(2)


func test_a_growing_grid_keeps_a_spare_row_below_its_last_stack() -> void:
	var grid := ItemGrid.new(Vector2i(2, 1), 1)
	assert_bool(grid.is_growing()).is_true()
	assert_int(grid.size.y).is_equal(1)
	grid.place(Item.new(_coil), Vector2i(0, 0))
	assert_int(grid.size.y).is_equal(2)
	var low := Item.new(_coil)
	grid.place(low, Vector2i(1, 1))
	assert_int(grid.size.y).is_equal(3)
	grid.remove(low)
	assert_int(grid.size.y).is_equal(2)


func test_a_growing_grid_always_has_room() -> void:
	var grid := ItemGrid.new(Vector2i(2, 2), 1)
	for i in 9:
		assert_object(grid.add_one(_coil)).is_not_null()
	assert_int(grid.items.size()).is_equal(5)
	assert_int(grid.size.y).is_equal(4)
	assert_int(grid.free_slots()).is_greater(0)
	assert_int(grid.room_for(_coil)).is_greater(0)


func test_stow_tops_up_across_grids_then_takes_the_first_free_slot() -> void:
	var from := ItemGrid.new(Vector2i(1, 1))
	var first := ItemGrid.new(Vector2i(1, 1))
	var second := ItemGrid.new(Vector2i(2, 1))
	first.place(Item.new(_coil, 2), Vector2i(0, 0))
	var waiting := Item.new(_drive, 4)
	second.place(waiting, Vector2i(1, 0))
	var stack := Item.new(_drive, 5)
	from.place(stack, Vector2i(0, 0))
	assert_int(ItemGrid.stow(stack, [first, second], from)).is_equal(5)
	assert_int(waiting.quantity).is_equal(5)
	assert_object(second.item_at(Vector2i(0, 0))).is_same(stack)
	assert_int(stack.quantity).is_equal(4)
	assert_bool(from.has(stack)).is_false()


func test_stow_leaves_what_doesnt_fit_where_it_was() -> void:
	var from := ItemGrid.new(Vector2i(1, 1))
	var into := ItemGrid.new(Vector2i(1, 1))
	var waiting := Item.new(_drive, 3)
	into.place(waiting, Vector2i(0, 0))
	var stack := Item.new(_drive, 4)
	from.place(stack, Vector2i(0, 0))
	assert_int(ItemGrid.stow(stack, [into], from)).is_equal(2)
	assert_int(waiting.quantity).is_equal(5)
	assert_int(stack.quantity).is_equal(2)
	assert_object(from.item_at(Vector2i(0, 0))).is_same(stack)


func _item(item_name: String, stack: int, value: int) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = "test:%s" % item_name
	definition.stack_size = stack
	definition.value = value
	return definition
