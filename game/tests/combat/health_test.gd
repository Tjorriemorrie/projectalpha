extends GdUnitTestSuite
## Unit tests for Health and for Hitbox passing hits on to it with its part's multiplier.

var _health: Health
var _damage_taken: Array[float] = []
var _deaths := 0


func before_test() -> void:
	_health = auto_free(Health.new())
	_health.max_health = 100.0
	add_child(_health)
	_damage_taken.clear()
	_deaths = 0
	_health.damaged.connect(func(amount: float, _source: Vector3, _part: Hitbox.Part) -> void:
		_damage_taken.append(amount))
	_health.died.connect(func() -> void: _deaths += 1)


func test_starts_full() -> void:
	assert_float(_health.health).is_equal(100.0)
	assert_bool(_health.is_dead()).is_false()


func test_damage_reduces_health() -> void:
	_health.take_damage(35.0, Vector3.ZERO)
	assert_float(_health.health).is_equal(65.0)
	assert_array(_damage_taken).is_equal([35.0])


func test_hitbox_multiplies_damage_by_its_part(multiplier: float, expected_health: float, test_parameters := [
	[2.0, 30.0],
	[1.0, 65.0],
	[0.5, 82.5],
]) -> void:
	var dealt := _hitbox(multiplier).take_hit(35.0, Vector3.ZERO)
	assert_float(dealt).is_equal(35.0 * multiplier)
	assert_float(_health.health).is_equal(expected_health)


func test_three_body_hits_kill_once() -> void:
	var body := _hitbox(1.0)
	for hit in 3:
		body.take_hit(35.0, Vector3.ZERO)
	assert_bool(_health.is_dead()).is_true()
	assert_float(_health.health).is_equal(0.0)
	assert_int(_deaths).is_equal(1)
	body.take_hit(35.0, Vector3.ZERO)
	assert_int(_deaths).is_equal(1)
	assert_int(_damage_taken.size()).is_equal(3)


func test_reset_restores_full_health() -> void:
	_health.take_damage(100.0, Vector3.ZERO)
	_health.reset()
	assert_float(_health.health).is_equal(100.0)
	assert_bool(_health.is_dead()).is_false()


func _hitbox(multiplier: float) -> Hitbox:
	var hitbox: Hitbox = auto_free(Hitbox.new())
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = SphereShape3D.new()
	hitbox.add_child(shape)
	hitbox.damage_multiplier = multiplier
	hitbox.health = _health
	add_child(hitbox)
	return hitbox
