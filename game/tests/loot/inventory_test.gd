extends GdUnitTestSuite
## Unit tests for Inventory: its two grids, and what it reports about the items in them. Items only get into it by
## being dragged there, which the inventory screen suite covers.

var _clip: ItemDefinition
var _coil: ItemDefinition


func before_test() -> void:
	_clip = ItemDefinition.new()
	_clip.id = "test:clip"
	_clip.value = 25
	_coil = ItemDefinition.new()
	_coil.id = "test:coil"
	_coil.shape = PackedStringArray(["###", ".#."])
	_coil.value = 180


func test_has_pockets_and_a_backpack() -> void:
	var inventory := Inventory.new()
	assert_vector(Vector2(inventory.pockets.size)).is_equal(Vector2(4, 1))
	assert_vector(Vector2(inventory.backpack.size)).is_equal(Vector2(6, 5))
	assert_int(inventory.free_cells()).is_equal(34)


func test_counts_finds_and_values_what_it_holds() -> void:
	var inventory := Inventory.new()
	var clip := Item.new(_clip)
	var coil := Item.new(_coil)
	var loose := Item.new(_clip)
	inventory.pockets.place(clip, Vector2i(0, 0), 0)
	inventory.backpack.place(coil, Vector2i(0, 0), 0)
	inventory.backpack.place(Item.new(_clip), Vector2i(5, 4), 0)
	assert_object(inventory.grid_of(clip)).is_same(inventory.pockets)
	assert_object(inventory.grid_of(coil)).is_same(inventory.backpack)
	assert_object(inventory.grid_of(loose)).is_null()
	assert_int(inventory.count(_clip)).is_equal(2)
	assert_int(inventory.free_cells()).is_equal(28)
	assert_int(inventory.value()).is_equal(230)
