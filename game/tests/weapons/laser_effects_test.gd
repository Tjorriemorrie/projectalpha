extends GdUnitTestSuite
## Scorch marks stay on the surface a shot hit for the rest of the run, move with it, and stop at
## LaserEffects.MAX_SCORCH_MARKS, the oldest going first.

var _effects: Node3D
var _wall: StaticBody3D


func before_test() -> void:
	_effects = auto_free(Node3D.new())
	add_child(_effects)
	_wall = auto_free(StaticBody3D.new())
	add_child(_wall)


func test_scorch_mark_stays_on_the_surface_and_moves_with_it() -> void:
	_scorch(Vector3(0.0, 1.0, 0.0))
	var marks := _marks()
	assert_int(marks.size()).is_equal(1)
	_wall.position = Vector3(5.0, 0.0, 0.0)
	assert_vector(marks[0].global_position).is_equal_approx(Vector3(5.0, 1.0, 0.0), Vector3.ONE * 0.001)
	await get_tree().create_timer(1.0).timeout
	assert_int(_marks().size()).is_equal(1)
	assert_float(marks[0].modulate.a).is_greater(0.5)


func test_hits_on_hitboxes_leave_no_mark() -> void:
	var before := LaserEffects.scorch_mark_count()
	LaserEffects.impact(_effects, Vector3.ZERO, Vector3.BACK, Color.WHITE, null)
	assert_int(LaserEffects.scorch_mark_count()).is_equal(before)


func test_scorch_marks_leave_the_viewmodel_alone() -> void:
	_scorch(Vector3.ZERO)
	assert_int(_marks()[0].cull_mask & WeaponViewmodel.VISUAL_LAYER).is_equal(0)


func test_keeps_only_the_newest_marks() -> void:
	for shot in LaserEffects.MAX_SCORCH_MARKS + 10:
		_scorch(Vector3(shot * 0.01, 1.0, 0.0))
	await get_tree().process_frame
	assert_int(_marks().size()).is_equal(LaserEffects.MAX_SCORCH_MARKS)
	assert_int(LaserEffects.scorch_mark_count()).is_equal(LaserEffects.MAX_SCORCH_MARKS)
	# The ten oldest went: the first mark left is the eleventh.
	assert_float(_marks()[0].global_position.x).is_equal_approx(0.1, 0.001)


func _scorch(point: Vector3) -> void:
	LaserEffects.impact(_effects, point, Vector3.BACK, Color.WHITE, _wall)


func _marks() -> Array[Decal]:
	var marks: Array[Decal] = []
	for mark in _wall.find_children("*", "Decal", false, false):
		marks.append(mark as Decal)
	return marks
