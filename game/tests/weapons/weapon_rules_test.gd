extends GdUnitTestSuite
## Unit tests for WeaponRules and ThermalClips, using a WeaponDefinition with its defaults (the laser pistol's
## starting numbers: 5% heat and 25 damage uncharged, 15% heat and 4x damage at a full charge). The clips are items
## in an inventory: fresh ones in the pockets are the ones a reload can use.

const TOLERANCE := 0.0001

var _pistol: WeaponDefinition
var _fresh: ItemDefinition
var _spent: ItemDefinition


func before_test() -> void:
	_pistol = WeaponDefinition.new()
	_fresh = ItemDefinition.new()
	_fresh.id = "test:fresh_clip"
	_spent = ItemDefinition.new()
	_spent.id = "test:spent_clip"


## Clips with this much heat in the loaded one, and fresh clips in the pockets and the backpack.
func _clips(heat: float, in_pockets: int = 0, in_backpack: int = 0) -> ThermalClips:
	var inventory := Inventory.new()
	for i in in_pockets:
		inventory.pockets.add(Item.new(_fresh))
	for i in in_backpack:
		inventory.backpack.add(Item.new(_fresh))
	return ThermalClips.new(inventory, _fresh, _spent, heat)


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


func test_reload_needs_a_fresh_clip_in_the_pockets_and_a_used_one_loaded() -> void:
	assert_bool(_clips(0.5).can_reload()).is_false()
	assert_bool(_clips(0.0, 2).can_reload()).is_false()
	assert_bool(_clips(0.05, 2).can_reload()).is_true()
	# Fresh clips in the backpack have to go into the pockets first.
	assert_bool(_clips(0.5, 0, 2).can_reload()).is_false()


func test_counts_fresh_packed_and_spent_clips() -> void:
	var clips := _clips(0.0, 2, 3)
	clips.inventory.backpack.add(Item.new(_spent))
	assert_int(clips.fresh).is_equal(2)
	assert_int(clips.packed).is_equal(3)
	assert_int(clips.spent).is_equal(1)


func test_reload_wastes_the_loaded_clip() -> void:
	var clips := _clips(0.3, 4)
	clips.swap()
	assert_int(clips.fresh).is_equal(3)
	assert_int(clips.spent).is_equal(1)
	assert_float(clips.heat).is_equal(0.0)


func test_reload_takes_the_first_pocket_clip_and_puts_the_spent_one_in_its_cell() -> void:
	var clips := _clips(0.5, 3, 1)
	var pockets := clips.inventory.pockets
	var cell := clips.take_fresh()
	assert_vector(Vector2(cell)).is_equal(Vector2(0, 0))
	assert_bool(pockets.is_reserved(cell)).is_true()
	assert_int(clips.fresh).is_equal(2)
	assert_int(clips.packed).is_equal(1)
	# Nothing else can go into the reserved cell while the reload runs.
	assert_bool(pockets.add(Item.new(_fresh))).is_true()
	assert_object(pockets.item_at(cell)).is_null()
	clips.swap()
	assert_bool(pockets.is_reserved(cell)).is_false()
	assert_str(pockets.item_at(cell).definition.id).is_equal("test:spent_clip")
	assert_float(clips.heat).is_equal(0.0)


func test_swap_without_a_fresh_clip_in_the_pockets_changes_nothing() -> void:
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
