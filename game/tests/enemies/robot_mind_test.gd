extends GdUnitTestSuite
## Unit tests for RobotMind: the shared robot states (idle, investigating, attacking, searching, destroyed), the
## lock-on and the attention timers, using an EnemyDefinition with its defaults (0.8 s to lock on when idle, 0.4 s
## when alert, a quarter second of sight memory, 5 s investigating and 6 s searching).

## One physics frame.
const FRAME := 1.0 / 60.0
const PLAYER := Vector3(0.0, 1.5, -6.0)
const NOISE := Vector3(4.0, 0.0, 2.0)

var _mind: RobotMind
var _changes: Array[String] = []
var _locks: Array[float] = []
var _drops := 0


func before_test() -> void:
	_mind = RobotMind.new(EnemyDefinition.new())
	_changes.clear()
	_locks.clear()
	_drops = 0
	_mind.state_changed.connect(func(previous: RobotMind.State, current: RobotMind.State) -> void:
		_changes.append("%s>%s" % [RobotMind.State.keys()[previous], RobotMind.State.keys()[current]]))
	_mind.lock_started.connect(func(lock_time: float) -> void: _locks.append(lock_time))
	_mind.lock_dropped.connect(func() -> void: _drops += 1)


## Runs the mind for seconds of game time, frame by frame.
func _run(seconds: float, sees: bool, at_focus: bool = true) -> void:
	for frame in roundi(seconds / FRAME):
		_mind.update(FRAME, sees, PLAYER, at_focus)


func test_starts_idle() -> void:
	assert_int(_mind.state).is_equal(RobotMind.State.IDLE)
	assert_bool(_mind.is_attacking()).is_false()


func test_idle_robot_locks_on_slowly_then_attacks() -> void:
	_run(0.7, true)
	assert_bool(_mind.is_locking).is_true()
	assert_int(_mind.state).is_equal(RobotMind.State.IDLE)
	_run(0.15, true)
	assert_bool(_mind.is_attacking()).is_true()
	assert_array(_locks).is_equal([0.8])
	assert_array(_changes).is_equal(["IDLE>ATTACKING"])
	assert_vector(_mind.focus).is_equal(PLAYER)


func test_alert_robot_locks_on_quickly() -> void:
	_mind.hear(NOISE)
	_run(0.45, true)
	assert_bool(_mind.is_attacking()).is_true()
	assert_array(_locks).is_equal([0.4])


func test_quick_glimpse_drops_the_lock_and_investigates() -> void:
	_run(0.3, true)
	_run(0.5, false)
	assert_int(_drops).is_equal(1)
	assert_bool(_mind.is_locking).is_false()
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	assert_vector(_mind.focus).is_equal(PLAYER)


func test_sight_memory_bridges_a_flicker() -> void:
	_run(0.3, true)
	_run(0.15, false)
	_run(0.4, true)
	assert_int(_drops).is_equal(0)
	assert_bool(_mind.is_attacking()).is_true()


func test_losing_sight_while_attacking_searches_and_needs_a_new_lock() -> void:
	_run(1.0, true)
	_run(0.5, false)
	assert_int(_mind.state).is_equal(RobotMind.State.SEARCHING)
	_run(0.2, true)
	assert_bool(_mind.is_attacking()).is_false()
	_run(0.25, true)
	assert_bool(_mind.is_attacking()).is_true()
	assert_array(_locks).is_equal([0.8, 0.4])
	assert_array(_changes).is_equal(["IDLE>ATTACKING", "ATTACKING>SEARCHING", "SEARCHING>ATTACKING"])


func test_noise_makes_it_investigate_the_spot() -> void:
	assert_bool(_mind.hear(NOISE)).is_true()
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	assert_vector(_mind.focus).is_equal(NOISE)


func test_attacking_robot_ignores_noise_and_contact() -> void:
	_run(1.0, true)
	assert_bool(_mind.hear(NOISE)).is_false()
	assert_bool(_mind.feel(NOISE)).is_false()
	assert_bool(_mind.is_attacking()).is_true()
	assert_vector(_mind.focus).is_equal(PLAYER)


func test_contact_turns_its_attention_to_the_hit() -> void:
	assert_bool(_mind.feel(NOISE)).is_true()
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	assert_vector(_mind.focus).is_equal(NOISE)


func test_attention_only_runs_out_once_at_the_focus() -> void:
	_mind.hear(NOISE)
	_run(10.0, false, false)
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	_run(4.9, false, true)
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	_run(0.2, false, true)
	assert_int(_mind.state).is_equal(RobotMind.State.IDLE)


func test_search_times_out_back_to_idle() -> void:
	_run(1.0, true)
	_run(0.3, false)
	_run(6.1, false)
	assert_int(_mind.state).is_equal(RobotMind.State.IDLE)
	assert_array(_changes).is_equal(["IDLE>ATTACKING", "ATTACKING>SEARCHING", "SEARCHING>IDLE"])


func test_noise_while_searching_investigates_it() -> void:
	_run(1.0, true)
	_run(0.3, false)
	assert_bool(_mind.hear(NOISE)).is_true()
	assert_int(_mind.state).is_equal(RobotMind.State.INVESTIGATING)
	assert_vector(_mind.focus).is_equal(NOISE)


func test_destroyed_robot_stays_destroyed() -> void:
	_run(1.0, true)
	_mind.destroy()
	_run(1.0, true)
	assert_int(_mind.state).is_equal(RobotMind.State.DESTROYED)
	assert_bool(_mind.hear(NOISE)).is_false()
	assert_bool(_mind.is_attacking()).is_false()
