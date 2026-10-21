extends GdUnitTestSuite
## Unit tests for ItemGrid: placing and moving items, overlaps and edges, removing, finding space in any
## orientation, reserved cells and counting.

var _square: ItemDefinition
var _bar: ItemDefinition
var _ell: ItemDefinition
var _chip: ItemDefinition


func before_test() -> void:
	_square = _item("square", ["##", "##"], 100)
	_bar = _item("bar", ["###"], 30)
	_ell = _item("ell", ["#.", "#.", "##"], 50)
	_chip = _item("chip", ["#"], 10)


func test_places_an_item_where_it_fits() -> void:
	var grid := ItemGrid.new(Vector2i(4, 3))
	var item := Item.new(_square)
	assert_bool(grid.place(item, Vector2i(1, 1), 0)).is_true()
	assert_object(grid.item_at(Vector2i(2, 2))).is_same(item)
	assert_object(grid.item_at(Vector2i(0, 0))).is_null()
	assert_int(grid.free_cells()).is_equal(8)


func test_items_never_overlap_or_stick_out() -> void:
	var grid := ItemGrid.new(Vector2i(4, 3))
	grid.place(Item.new(_square), Vector2i(0, 0), 0)
	assert_bool(grid.place(Item.new(_chip), Vector2i(1, 1), 0)).is_false()
	assert_bool(grid.place(Item.new(_bar), Vector2i(2, 0), 0)).is_false()
	assert_bool(grid.place(Item.new(_bar), Vector2i(1, 2), 0)).is_true()
	assert_bool(grid.fits(_ell, 0, Vector2i(3, 0))).is_false()
	assert_bool(grid.fits(_chip, 0, Vector2i(-1, 0))).is_false()


func test_an_item_moves_over_its_own_cells() -> void:
	var grid := ItemGrid.new(Vector2i(4, 3))
	var item := Item.new(_square)
	grid.place(item, Vector2i(0, 0), 0)
	assert_bool(grid.place(item, Vector2i(1, 0), 0)).is_true()
	assert_object(grid.item_at(Vector2i(0, 0))).is_null()
	assert_object(grid.item_at(Vector2i(2, 1))).is_same(item)
	assert_int(grid.items.size()).is_equal(1)


func test_turned_items_take_their_turned_cells() -> void:
	var grid := ItemGrid.new(Vector2i(3, 2))
	var item := Item.new(_ell)
	# An L of 2 by 3 only fits a 3 by 2 grid turned.
	assert_bool(grid.place(item, Vector2i(0, 0), 0)).is_false()
	assert_bool(grid.place(item, Vector2i(0, 0), 1)).is_true()
	assert_array(item.cells()).contains_exactly_in_any_order(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)])


func test_removing_frees_the_cells() -> void:
	var grid := ItemGrid.new(Vector2i(2, 2))
	var item := Item.new(_square)
	grid.place(item, Vector2i(0, 0), 0)
	assert_bool(grid.remove(item)).is_true()
	assert_bool(grid.remove(item)).is_false()
	assert_int(grid.free_cells()).is_equal(4)
	assert_bool(grid.fits(_square, 0, Vector2i(0, 0))).is_true()


func test_finds_the_first_free_spot_in_reading_order() -> void:
	var grid := ItemGrid.new(Vector2i(4, 3))
	grid.place(Item.new(_chip), Vector2i(0, 0), 0)
	var spot := grid.find_space(_square)
	assert_vector(Vector2(spot.cell)).is_equal(Vector2(1, 0))
	assert_int(spot.orientation).is_equal(0)


func test_turns_an_item_to_find_space() -> void:
	var grid := ItemGrid.new(Vector2i(1, 3))
	var spot := grid.find_space(_bar)
	assert_object(spot).is_not_null()
	assert_int(spot.orientation).is_equal(1)
	assert_bool(grid.add(Item.new(_bar))).is_true()
	assert_object(grid.find_space(_chip)).is_null()


func test_adds_until_full() -> void:
	var grid := ItemGrid.new(Vector2i(4, 2))
	assert_bool(grid.add(Item.new(_square))).is_true()
	assert_bool(grid.add(Item.new(_square))).is_true()
	assert_bool(grid.add(Item.new(_chip))).is_false()
	assert_int(grid.free_cells()).is_equal(0)


func test_reserved_cells_stay_free() -> void:
	var grid := ItemGrid.new(Vector2i(2, 1))
	assert_bool(grid.reserve(Vector2i(0, 0))).is_true()
	assert_bool(grid.fits(_chip, 0, Vector2i(0, 0))).is_false()
	assert_bool(grid.add(Item.new(_chip))).is_true()
	assert_bool(grid.add(Item.new(_chip))).is_false()
	assert_int(grid.free_cells()).is_equal(0)
	grid.release(Vector2i(0, 0))
	assert_bool(grid.add(Item.new(_chip))).is_true()
	# A covered cell can't be reserved.
	assert_bool(grid.reserve(Vector2i(1, 0))).is_false()


func test_counts_and_values() -> void:
	var grid := ItemGrid.new(Vector2i(4, 4))
	var second := Item.new(_chip)
	grid.place(Item.new(_square), Vector2i(0, 0), 0)
	grid.place(second, Vector2i(3, 0), 0)
	grid.place(Item.new(_chip), Vector2i(2, 3), 0)
	assert_int(grid.count(_chip)).is_equal(2)
	assert_int(grid.count(_bar)).is_equal(0)
	assert_object(grid.first_of(_chip)).is_same(second)
	assert_int(grid.value()).is_equal(120)


func test_grows_but_never_shrinks() -> void:
	var grid := ItemGrid.new(Vector2i(6, 2))
	assert_int(grid.rows_used()).is_equal(0)
	grid.place(Item.new(_ell), Vector2i(0, 0), 1)
	grid.place(Item.new(_chip), Vector2i(5, 1), 0)
	assert_int(grid.rows_used()).is_equal(2)
	grid.grow_to(4)
	assert_vector(Vector2(grid.size)).is_equal(Vector2(6, 4))
	assert_bool(grid.fits(_square, 0, Vector2i(0, 2))).is_true()
	grid.grow_to(3)
	assert_int(grid.size.y).is_equal(4)


func test_emits_changed() -> void:
	var grid := ItemGrid.new(Vector2i(2, 2))
	var changes := [0]
	grid.changed.connect(func() -> void: changes[0] += 1)
	var item := Item.new(_chip)
	grid.place(item, Vector2i(0, 0), 0)
	grid.remove(item)
	grid.reserve(Vector2i(1, 1))
	grid.release(Vector2i(1, 1))
	assert_int(changes[0]).is_equal(4)


static func _item(item_name: String, rows: Array, value: int) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = "test:" + item_name
	definition.shape = PackedStringArray(rows)
	definition.value = value
	return definition
