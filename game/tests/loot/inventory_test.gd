extends GdUnitTestSuite
## Unit tests for Inventory: its weapon slot and two grids, and what it reports about the items in them; and the
## weapon slot, which holds one gun and nothing else. Items only get into it by being dragged there, which the
## inventory screen suite covers.

var _clip: ItemDefinition
var _coil: ItemDefinition
var _pistol: WeaponDefinition


func before_test() -> void:
	_clip = ItemDefinition.new()
	_clip.id = "test:clip"
	_clip.value = 25
	_coil = ItemDefinition.new()
	_coil.id = "test:coil"
	_coil.shape = PackedStringArray(["###", ".#."])
	_coil.value = 180
	_pistol = WeaponDefinition.new()
	_pistol.id = "test:pistol"
	_pistol.shape = PackedStringArray(["##", ".#"])
	_pistol.value = 200


func test_has_a_weapon_slot_pockets_and_a_backpack() -> void:
	var inventory := Inventory.new()
	assert_vector(Vector2(inventory.weapon.size)).is_equal(Vector2(3, 2))
	assert_vector(Vector2(inventory.pockets.size)).is_equal(Vector2(4, 1))
	assert_vector(Vector2(inventory.backpack.size)).is_equal(Vector2(6, 5))
	assert_int(inventory.free_cells()).is_equal(34)
	assert_object(inventory.gun()).is_null()


func test_the_weapon_slot_holds_one_gun_and_nothing_else() -> void:
	var inventory := Inventory.new()
	assert_bool(inventory.weapon.fits(_clip, 0, Vector2i(0, 0))).is_false()
	var pistol := Item.new(_pistol)
	assert_bool(inventory.weapon.place(pistol, Vector2i(0, 0), 0)).is_true()
	assert_object(inventory.gun()).is_same(pistol)
	# A second gun doesn't fit, even where there is room for its shape, but the gun itself can move about.
	assert_bool(inventory.weapon.fits(_pistol, 0, Vector2i(1, 0))).is_false()
	assert_bool(inventory.weapon.place(pistol, Vector2i(1, 0), 0)).is_true()
	assert_object(inventory.weapon.item_at(Vector2i(2, 1))).is_same(pistol)


func test_the_gun_counts_as_carried_but_not_as_free_space() -> void:
	var inventory := Inventory.new()
	var pistol := Item.new(_pistol)
	inventory.weapon.add(pistol)
	assert_object(inventory.grid_of(pistol)).is_same(inventory.weapon)
	assert_int(inventory.count(_pistol)).is_equal(1)
	assert_int(inventory.item_count()).is_equal(1)
	assert_int(inventory.value()).is_equal(200)
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
