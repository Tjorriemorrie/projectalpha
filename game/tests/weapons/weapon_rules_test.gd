extends GdUnitTestSuite
## Unit tests for WeaponRules and ThermalClips, using a WeaponDefinition with its defaults (the laser pistol's
## starting numbers: 5% heat and 25 damage uncharged, 15% heat and 4x damage at a full charge). The clips are stacks
## in an inventory: fresh ones in the ammo slots are the ones a reload can use, and the spent one goes back there
## first, then to the pockets or the backpack, and overflows when there is no room anywhere.

const TOLERANCE := 0.0001

var _pistol: WeaponDefinition
var _fresh: ItemDefinition
var _spent: ItemDefinition


func before_test() -> void:
	_pistol = WeaponDefinition.new()
	_fresh = _clip("fresh_clip")
	_spent = _clip("spent_clip")


## Clips with this much heat in the gun's loaded one, and stacks of fresh clips in the ammo slots and the backpack.
func _clips(heat: float, in_ammo: int = 0, in_backpack: int = 0) -> ThermalClips:
	var inventory := Inventory.new()
	if in_ammo > 0:
		inventory.ammo.add(Item.new(_fresh, in_ammo))
	if in_backpack > 0:
		inventory.backpack.add(Item.new(_fresh, in_backpack))
	var gun := Item.new(_pistol)
	gun.clip_heat = heat
	inventory.weapon.add(gun)
	return ThermalClips.new(inventory, _fresh, _spent, gun)


func test_the_heat_lives_on_the_gun() -> void:
	var clips := _clips(0.3)
	clips.add_heat(0.2)
	assert_float(clips.gun.clip_heat).is_equal_approx(0.5, TOLERANCE)
	var unarmed := ThermalClips.new(Inventory.new(), _fresh, _spent)
	unarmed.heat = 0.4
	assert_float(unarmed.heat).is_equal(0.0)


func test_uncharged_shot() -> void:
	assert_float(WeaponRules.shot_heat(_pistol, 0.0)).is_equal_approx(0.05, TOLERANCE)
	assert_float(WeaponRules.shot_damage(_pistol, 0.0)).is_equal_approx(25.0, TOLERANCE)
	assert_float(WeaponRules.shot_kick(_pistol, 0.0)).is_equal_approx(0.5, TOLERANCE)


func test_full_charge() -> void:
	assert_float(WeaponRules.shot_heat(_pistol, 1.0)).is_equal_approx(0.15, TOLERANCE)
	assert_float(WeaponRules.shot_damage(_pistol, 1.0)).is_equal_approx(100.0, TOLERANCE)
	assert_float(WeaponRules.shot_kick(_pistol, 1.0)).is_equal_approx(3.0, TOLERANCE)


func test_part_charge_scales_between() -> void:
	assert_float(WeaponRules.shot_heat(_pistol, 0.5)).is_equal_approx(0.1, TOLERANCE)
	assert_float(WeaponRules.shot_damage(_pistol, 0.5)).is_equal_approx(62.5, TOLERANCE)
	assert_float(WeaponRules.shot_kick(_pistol, 0.5)).is_equal_approx(1.75, TOLERANCE)


func test_charge_for_hold(held_time: float, expected: float, test_parameters := [
	[0.0, 0.0],
	# A quick click stays uncharged.
	[0.1, 0.0],
	[0.15, 0.0],
	[0.65, 0.5],
	[1.15, 1.0],
	[5.0, 1.0],
]) -> void:
	assert_float(WeaponRules.charge_for_hold(_pistol, held_time)).is_equal_approx(expected, TOLERANCE)


func test_twenty_uncharged_shots_saturate_a_clip() -> void:
	var clips := _clips(0.0, 4)
	for shot in 19:
		clips.add_heat(WeaponRules.shot_heat(_pistol, 0.0))
	assert_bool(clips.has_room_for(_pistol.shot_heat)).is_true()
	clips.add_heat(WeaponRules.shot_heat(_pistol, 0.0))
	assert_float(WeaponRules.max_charge(_pistol, clips)).is_equal(WeaponRules.SATURATED)


func test_charge_stops_where_the_clip_would_saturate(heat: float, expected: float, test_parameters := [
	[0.0, 1.0],
	[0.85, 1.0],
	# 10% room: an uncharged shot takes 5%, so the charge can add only half of the 10% a full charge adds.
	[0.9, 0.5],
	[0.95, 0.0],
	[0.97, WeaponRules.SATURATED],
]) -> void:
	var clips := _clips(heat)
	assert_float(WeaponRules.max_charge(_pistol, clips)).is_equal_approx(expected, 0.001)


func test_spread() -> void:
	assert_float(WeaponRules.spread(_pistol, false, 0.0)).is_equal(5.0)
	assert_float(WeaponRules.spread(_pistol, true, 0.0)).is_equal(1.0)
	assert_float(WeaponRules.spread(_pistol, true, 2.0)).is_equal(3.0)


func test_shot_direction_lands_within_spread() -> void:
	var view := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, -0.2)
	var forward := -view.z
	assert_vector(WeaponRules.shot_direction(view, 5.0, 0.0, 0.3)).is_equal_approx(forward, Vector3.ONE * 0.0001)
	for random_radius: float in [0.1, 0.5, 0.9, 1.0]:
		for random_angle: float in [0.0, 0.25, 0.6]:
			var direction := WeaponRules.shot_direction(view, 5.0, random_radius, random_angle)
			assert_float(rad_to_deg(direction.angle_to(forward))).is_less_equal(5.0001)
	var edge := WeaponRules.shot_direction(view, 5.0, 1.0, 0.4)
	assert_float(rad_to_deg(edge.angle_to(forward))).is_equal_approx(5.0, 0.001)


func test_reload_needs_a_fresh_clip_in_the_ammo_slots_and_a_used_one_loaded() -> void:
	assert_bool(_clips(0.5).can_reload()).is_false()
	assert_bool(_clips(0.0, 2).can_reload()).is_false()
	assert_bool(_clips(0.05, 2).can_reload()).is_true()
	# Fresh clips in the backpack have to go into the ammo slots first.
	assert_bool(_clips(0.5, 0, 2).can_reload()).is_false()


func test_counts_fresh_packed_and_spent_clips() -> void:
	var clips := _clips(0.0, 2, 3)
	clips.inventory.pockets.add(Item.new(_fresh))
	clips.inventory.backpack.add(Item.new(_spent))
	assert_int(clips.fresh).is_equal(2)
	assert_int(clips.packed).is_equal(4)
	assert_int(clips.spent).is_equal(1)


func test_reload_wastes_the_loaded_clip() -> void:
	var clips := _clips(0.3, 4)
	clips.swap()
	assert_int(clips.fresh).is_equal(3)
	assert_int(clips.spent).is_equal(1)
	assert_float(clips.heat).is_equal(0.0)


func test_reload_takes_a_clip_off_the_fresh_stack_and_the_spent_one_takes_a_free_ammo_slot() -> void:
	var clips := _clips(0.5, 3, 1)
	var ammo := clips.inventory.ammo
	assert_bool(clips.take_fresh()).is_true()
	assert_bool(clips.is_swapping()).is_true()
	assert_int(clips.fresh).is_equal(2)
	assert_int(clips.packed).is_equal(1)
	clips.swap()
	assert_bool(clips.is_swapping()).is_false()
	assert_int(ammo.item_at(Vector2i(0, 0)).quantity).is_equal(2)
	assert_str(ammo.item_at(Vector2i(1, 0)).definition.id).is_equal("test:spent_clip")
	assert_float(clips.heat).is_equal(0.0)


func test_the_last_fresh_clip_leaves_its_slot_for_the_spent_one() -> void:
	var clips := _clips(0.5, 1)
	var ammo := clips.inventory.ammo
	ammo.place(Item.new(_fresh, 5), Vector2i(1, 0))
	clips.swap()
	assert_str(ammo.item_at(Vector2i(0, 0)).definition.id).is_equal("test:spent_clip")
	assert_int(clips.fresh).is_equal(5)


func test_a_spent_clip_tops_up_the_spent_stack_in_the_ammo_slots() -> void:
	var clips := _clips(0.5, 3)
	var spent := Item.new(_spent, 2)
	clips.inventory.ammo.place(spent, Vector2i(1, 0))
	clips.swap()
	assert_int(spent.quantity).is_equal(3)
	assert_int(clips.spent).is_equal(3)


func test_with_full_ammo_slots_the_spent_clip_goes_to_the_pockets_then_the_backpack() -> void:
	var clips := _clips(0.5, 5)
	var inventory := clips.inventory
	inventory.ammo.place(Item.new(_spent, 5), Vector2i(1, 0))
	clips.swap()
	# A clip came off the fresh stack, but its slot still holds four, and the spent stack is full.
	assert_int(inventory.pockets.count(_spent)).is_equal(1)
	inventory.pockets.item_at(Vector2i(0, 0)).quantity = 5
	inventory.pockets.place(Item.new(_fresh), Vector2i(1, 0))
	clips.add_heat(0.5)
	clips.swap()
	assert_int(inventory.backpack.count(_spent)).is_equal(1)


func test_a_spent_clip_with_no_room_anywhere_overflows() -> void:
	var clips := _clips(0.5, 5)
	var inventory := clips.inventory
	inventory.ammo.place(Item.new(_spent, 5), Vector2i(1, 0))
	for grid: ItemGrid in [inventory.pockets, inventory.backpack]:
		for row in grid.size.y:
			for column in grid.size.x:
				grid.place(Item.new(_pistol), Vector2i(column, row))
	var overflowed: Array[Item] = []
	clips.overflowed.connect(func(clip: Item) -> void: overflowed.append(clip))
	clips.swap()
	assert_int(overflowed.size()).is_equal(1)
	assert_str(overflowed[0].definition.id).is_equal("test:spent_clip")
	assert_float(clips.heat).is_equal(0.0)


func test_calling_off_a_swap_puts_the_fresh_clip_back() -> void:
	var clips := _clips(0.5, 3)
	clips.take_fresh()
	assert_int(clips.fresh).is_equal(2)
	assert_bool(clips.cancel_swap()).is_true()
	assert_int(clips.fresh).is_equal(3)
	assert_float(clips.heat).is_equal(0.5)
	assert_bool(clips.cancel_swap()).is_false()


func test_swap_without_a_fresh_clip_in_the_ammo_slots_changes_nothing() -> void:
	var clips := _clips(0.6, 0, 2)
	clips.swap()
	assert_float(clips.heat).is_equal(0.6)
	assert_int(clips.packed).is_equal(2)
	assert_int(clips.spent).is_equal(0)


func test_heat_never_passes_saturation() -> void:
	var clips := _clips(0.95)
	clips.add_heat(0.15)
	assert_float(clips.heat).is_equal(1.0)
	assert_float(clips.room()).is_equal(0.0)


func _clip(clip_name: String) -> ItemDefinition:
	var clip := ItemDefinition.new()
	clip.id = "test:%s" % clip_name
	clip.stack_size = 5
	clip.ammo = true
	return clip
