extends GdUnitTestSuite
## Unit tests for Hearing: how far a noise carries, that it stays on its deck, and that it reaches the listeners in
## range but not the one that made it.


## A listener that writes down what it hears, and reacts to all of it.
class Listener:
	extends Node3D

	var heard: Array[StringName] = []

	func hear_noise(_position: Vector3, _loudness: float, kind: StringName, _source: Node) -> bool:
		heard.append(kind)
		return true


func _listener(position: Vector3) -> Listener:
	var listener: Listener = auto_free(Listener.new())
	add_child(listener)
	listener.global_position = position
	listener.add_to_group(Hearing.LISTENER_GROUP)
	return listener


func test_carries_to(to: Vector3, loudness: float, expected: bool, test_parameters := [
	[Vector3(4.0, 0.0, 0.0), 5.0, true],
	[Vector3(6.0, 0.0, 0.0), 5.0, false],
	# Through the ceiling of a deck into the next deck up: never, however loud.
	[Vector3(0.0, 4.5, 0.0), 20.0, false],
	# A turret hanging under a 3 m ceiling is on the same deck as the floor below it.
	[Vector3(0.0, 2.6, 0.0), 20.0, true],
]) -> void:
	assert_bool(Hearing.carries_to(Vector3(0.0, 0.2, 0.0), to, loudness)).is_equal(expected)


func test_deck_of() -> void:
	assert_int(Hearing.deck_of(Vector3(3.0, 0.0, 1.0))).is_equal(0)
	assert_int(Hearing.deck_of(Vector3(3.0, 3.9, 1.0))).is_equal(0)
	assert_int(Hearing.deck_of(Vector3(3.0, 4.0, 1.0))).is_equal(1)


func test_noise_reaches_listeners_in_range_only() -> void:
	var near := _listener(Vector3(3.0, 1.0, 0.0))
	var far := _listener(Vector3(30.0, 1.0, 0.0))
	var above := _listener(Vector3(1.0, 5.0, 0.0))
	var source: Node3D = auto_free(Node3D.new())
	add_child(source)
	assert_int(Hearing.make_noise(source, Vector3.ZERO, 10.0, &"shot")).is_equal(1)
	assert_array(near.heard).is_equal([&"shot"])
	assert_array(far.heard).is_empty()
	assert_array(above.heard).is_empty()


func test_the_source_doesnt_hear_itself() -> void:
	var listener := _listener(Vector3.ZERO)
	assert_int(Hearing.make_noise(listener, Vector3.ZERO, 10.0, &"robot_shot")).is_equal(0)
	assert_array(listener.heard).is_empty()
