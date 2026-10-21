extends GdUnitTestSuite
## Unit tests for AimTrail: a robot aims where the player was a moment ago, so it trails a moving player and hits a
## still one. The lag is game time, whatever the physics tick rate.

const TOLERANCE := 0.0001
const FRAME := 1.0 / 60.0


func test_no_offset_before_anything_is_recorded() -> void:
	assert_vector(AimTrail.new(0.3).offset()).is_equal(Vector3.ZERO)


func test_still_target_has_no_offset() -> void:
	var trail := AimTrail.new(0.3)
	for frame in 60:
		trail.record(Vector3(2.0, 0.0, -1.0), FRAME)
	assert_vector(trail.offset()).is_equal(Vector3.ZERO)


func test_moving_target_is_aimed_at_where_it_was() -> void:
	var trail := AimTrail.new(0.3)
	# Walking east at 2 m/s for a second: 0.3 s ago it was 0.6 m further west.
	for frame in 61:
		trail.record(Vector3(2.0 * frame * FRAME, 0.0, 0.0), FRAME)
	assert_vector(trail.offset()).is_equal_approx(Vector3(-0.6, 0.0, 0.0), Vector3.ONE * TOLERANCE)


func test_lag_is_game_time_at_any_tick_rate() -> void:
	var trail := AimTrail.new(0.3)
	# Five times the tick rate: a frame is a fifth as long, and the lag is still 0.3 s, so still 0.6 m at 2 m/s.
	for frame in 301:
		trail.record(Vector3(2.0 * frame * FRAME / 5.0, 0.0, 0.0), FRAME / 5.0)
	assert_vector(trail.offset()).is_equal_approx(Vector3(-0.6, 0.0, 0.0), Vector3.ONE * 0.01)


func test_offset_only_reaches_back_as_far_as_recorded() -> void:
	var trail := AimTrail.new(0.3)
	for frame in 6:
		trail.record(Vector3(2.0 * frame * FRAME, 0.0, 0.0), FRAME)
	assert_vector(trail.offset()).is_equal_approx(Vector3(-2.0 * 5.0 * FRAME, 0.0, 0.0), Vector3.ONE * TOLERANCE)


func test_no_lag_aims_straight_at_it() -> void:
	var trail := AimTrail.new(0.0)
	for frame in 10:
		trail.record(Vector3(frame, 0.0, 0.0), FRAME)
	assert_vector(trail.offset()).is_equal(Vector3.ZERO)
