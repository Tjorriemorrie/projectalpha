extends Node3D
## A noise listener for tests: it remembers the kinds of noise it hears (see Hearing).

var heard: Array[StringName] = []


func _ready() -> void:
	add_to_group(Hearing.LISTENER_GROUP)


func hear_noise(_position: Vector3, _loudness: float, kind: StringName, _source: Node) -> bool:
	heard.append(kind)
	return true
