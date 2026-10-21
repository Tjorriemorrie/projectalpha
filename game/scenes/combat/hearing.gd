class_name Hearing
extends RefCounted
## What enemies hear. Anything can make a noise at a position with a loudness: the distance in metres it
## carries. It reaches every listener in the noise_listeners group within that distance on the same deck: noise
## carries through walls, but not through the slabs between decks. Listeners are Node3Ds with
## hear_noise(position: Vector3, loudness: float, kind: StringName, source: Node) -> bool, which returns whether they
## reacted. New noise sources only call make_noise(); the listeners don't change.

const LISTENER_GROUP := &"noise_listeners"
## Footsteps come every step, so a footstep nobody hears isn't logged.
const FOOTSTEP := &"footstep"


## Makes a noise at position that carries loudness metres, and returns how many listeners heard it. The source
## (what made the noise) doesn't hear its own noise.
static func make_noise(source: Node, position: Vector3, loudness: float, kind: StringName) -> int:
	if not source.is_inside_tree():
		Log.warning("🔊 Noise from outside the scene tree ignored: source=%s, kind=%s, loudness=%.1f m" % [
			source.name, kind, loudness])
		return 0
	var heard := 0
	var reacted := 0
	for listener: Node in source.get_tree().get_nodes_in_group(LISTENER_GROUP):
		var ears := listener as Node3D
		if ears == null or ears == source or not carries_to(position, ears.global_position, loudness):
			continue
		heard += 1
		if listener.call(&"hear_noise", position, loudness, kind, source):
			reacted += 1
	if heard > 0 or kind != FOOTSTEP:
		Log.info("🔊 Noise: kind=%s, source=%s, loudness=%.1f m, position=%s, heard_by=%d, reacted=%d" % [
			kind, source.name, loudness, position, heard, reacted])
	return heard


## Whether a noise at from that carries loudness metres reaches to: within that distance and on the same deck.
static func carries_to(from: Vector3, to: Vector3, loudness: float) -> bool:
	return from.distance_to(to) <= loudness and deck_of(from) == deck_of(to)


## The deck a position is on, counting from 0 at the lowest; deck n spans y = 4n up to the next deck's floor.
static func deck_of(position: Vector3) -> int:
	return WreckAssembly.to_cell(position).y
