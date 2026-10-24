extends GdUnitTestSuite
## Unit tests for Inventory: its weapon slot, ammo slots, pockets and backpack, what it reports about the stacks in
## them, where a stack moved to the player goes, and the haul unloading takes; the weapon slot, which holds one gun
## and nothing else; and the ammo slots, which hold thermal clips only.

var _clip: ItemDefinition
var _coil: ItemDefinition
var _pistol: WeaponDefinition


func before_test() -> void:
	_clip = ItemDefinition.new()
	_clip.id = "test:clip"
	_clip.value = 25
	_clip.stack_size = 5
	_clip.ammo = true
	_coil = ItemDefinition.new()
	_coil.id = "test:coil"
	_coil.value = 180
	_coil.stack_size = 2
	_pistol = WeaponDefinition.new()
	_pistol.id = "test:pistol"
	_pistol.value = 200


func test_has_a_weapon_slot_ammo_slots_pockets_and_a_backpack() -> void:
	var inventory := Inventory.new()
	assert_vector(Vector2(inventory.weapon.size)).is_equal(Vector2(1, 1))
	assert_vector(Vector2(inventory.ammo.size)).is_equal(Vector2(2, 1))
	assert_vector(Vector2(inventory.pockets.size)).is_equal(Vector2(2, 1))
	assert_vector(Vector2(inventory.backpack.size)).is_equal(Vector2(6, 1))
	assert_int(inventory.free_slots()).is_equal(8)
	assert_object(inventory.gun()).is_null()


func test_the_weapon_slot_holds_one_gun_and_nothing_else() -> void:
	var inventory := Inventory.new()
	assert_bool(inventory.weapon.fits(_clip, Vector2i(0, 0))).is_false()
	var pistol := Item.new(_pistol)
	assert_bool(inventory.weapon.place(pistol, Vector2i(0, 0))).is_true()
	assert_object(inventory.gun()).is_same(pistol)
	assert_object(inventory.weapon.add_one(_pistol)).is_null()


func test_the_ammo_slots_hold_clips_only() -> void:
	var inventory := Inventory.new()
	assert_bool(inventory.ammo.fits(_coil, Vector2i(0, 0))).is_false()
	assert_bool(inventory.ammo.add(Item.new(_coil))).is_false()
	assert_bool(inventory.ammo.add(Item.new(_clip, 3))).is_true()
	assert_int(inventory.ammo.count(_clip)).is_equal(3)


func test_the_gun_counts_as_carried_but_not_as_free_slots() -> void:
	var inventory := Inventory.new()
	var pistol := Item.new(_pistol)
	inventory.weapon.add(pistol)
	assert_object(inventory.grid_of(pistol)).is_same(inventory.weapon)
	assert_int(inventory.count(_pistol)).is_equal(1)
	assert_int(inventory.item_count()).is_equal(1)
	assert_int(inventory.value()).is_equal(200)
	assert_int(inventory.free_slots()).is_equal(8)


func test_counts_finds_and_values_what_it_holds() -> void:
	var inventory := Inventory.new()
	var clips := Item.new(_clip, 3)
	var coils := Item.new(_coil, 2)
	inventory.ammo.place(clips, Vector2i(0, 0))
	inventory.backpack.place(coils, Vector2i(0, 0))
	inventory.pockets.place(Item.new(_clip, 2), Vector2i(1, 0))
	assert_object(inventory.grid_of(clips)).is_same(inventory.ammo)
	assert_object(inventory.grid_of(coils)).is_same(inventory.backpack)
	assert_object(inventory.grid_of(Item.new(_clip))).is_null()
	assert_int(inventory.count(_clip)).is_equal(5)
	assert_int(inventory.item_count()).is_equal(7)
	assert_int(inventory.free_slots()).is_equal(6)
	assert_int(inventory.value()).is_equal(5 * 25 + 2 * 180)


func test_a_stack_moved_to_the_player_goes_to_its_own_slots_first_then_the_backpack_and_the_pockets() -> void:
	var inventory := Inventory.new()
	assert_array(inventory.stow_order(_clip)).contains_exactly(
		[inventory.ammo, inventory.backpack, inventory.pockets])
	assert_array(inventory.stow_order(_pistol)).contains_exactly(
		[inventory.weapon, inventory.backpack, inventory.pockets])
	assert_array(inventory.stow_order(_coil)).contains_exactly([inventory.backpack, inventory.pockets])


func test_the_haul_is_the_pockets_and_the_backpack() -> void:
	var inventory := Inventory.new()
	inventory.weapon.add(Item.new(_pistol))
	inventory.ammo.add(Item.new(_clip, 2))
	var pocketed := Item.new(_coil)
	var packed := Item.new(_clip, 4)
	inventory.pockets.add(pocketed)
	inventory.backpack.add(packed)
	assert_array(inventory.haul()).contains_exactly([pocketed, packed])
