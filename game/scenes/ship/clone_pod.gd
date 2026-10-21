class_name ClonePod
extends StaticBody3D
## The clone pod in the ship's clone bay, where a new clone wakes up: an open-fronted pod on a low plinth the player
## stands on. Like a container it faces −Z, and its origin is the middle of its foot. Waking hisses and brings its
## glow up from dark.

## Seconds the pod's glow takes to come up when a clone wakes.
@export var wake_time := 2.0

@onready var _spawn: Marker3D = %Spawn
@onready var _hiss: AudioStreamPlayer3D = %Hiss
@onready var _glow: OmniLight3D = %Glow


## Where a new clone stands, facing out of the pod.
func get_spawn() -> Marker3D:
	return _spawn


## A new clone wakes up in the pod: the seal hisses open and the glow comes up.
func wake() -> void:
	var energy := _glow.light_energy
	_glow.light_energy = 0.0
	create_tween().tween_property(_glow, "light_energy", energy, wake_time).set_ease(Tween.EASE_OUT)
	_hiss.play()
	Log.info("🚀 Clone pod waking a clone: pod=%s, position=%s, wake_time=%.1f s" % [name, global_position, wake_time])
