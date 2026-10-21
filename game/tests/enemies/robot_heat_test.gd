extends GdUnitTestSuite
## Unit tests for RobotHeat with the turret's and the drone's numbers from the base pack: the turret vents after six
## shots in a row, the drone rarely, and heat cools off once the robot holds its fire.

const FRAME := 1.0 / 60.0
const TOLERANCE := 0.0001

var _turret: EnemyDefinition
var _drone: EnemyDefinition


func before_test() -> void:
	_turret = load("res://content/base/enemies/turret/turret.tres")
	_drone = load("res://content/base/enemies/drone/drone.tres")


## Fires a shot every fire_interval for count shots, cooling in between. Returns the shot that started a vent, or 0.
func _fire(heat: RobotHeat, definition: EnemyDefinition, count: int) -> int:
	for shot in count:
		if heat.add_shot(definition):
			return shot + 1
		for frame in roundi(definition.fire_interval / FRAME):
			heat.update(FRAME, definition)
	return 0


func test_turret_vents_after_six_shots_in_a_row() -> void:
	var heat := RobotHeat.new()
	assert_int(_fire(heat, _turret, 10)).is_equal(6)
	assert_bool(heat.is_venting).is_true()
	assert_bool(heat.can_fire()).is_false()


func test_drone_fires_many_shots_before_venting() -> void:
	assert_int(_fire(RobotHeat.new(), _drone, 12)).is_equal(0)


func test_vent_drains_the_heat_and_ends_on_time() -> void:
	var heat := RobotHeat.new()
	_fire(heat, _turret, 6)
	var finished_at := -1
	for frame in roundi(3.0 / FRAME):
		if heat.update(FRAME, _turret):
			finished_at = frame + 1
			break
	assert_int(finished_at).is_between(roundi(2.0 / FRAME) - 1, roundi(2.0 / FRAME) + 1)
	assert_float(heat.heat).is_equal(0.0)
	assert_bool(heat.can_fire()).is_true()


func test_heat_cools_only_after_the_cool_delay() -> void:
	var heat := RobotHeat.new()
	heat.add_shot(_turret)
	for frame in roundi(0.4 / FRAME):
		heat.update(FRAME, _turret)
	assert_float(heat.heat).is_equal_approx(_turret.shot_heat, TOLERANCE)
	for frame in roundi(1.0 / FRAME):
		heat.update(FRAME, _turret)
	assert_float(heat.heat).is_less(_turret.shot_heat)
