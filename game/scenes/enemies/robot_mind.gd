class_name RobotMind
extends RefCounted
## What a robot is doing, kept free of nodes so it can be unit tested: its state, where its attention is, and its
## lock-on. Every robot runs one, whatever its body; the body tells it each physics frame what it sees and whether it
## has got to its focus, and moves according to the state.
##
## Idle, a robot that sees the player starts locking on (slowly; quickly when it is already alert). A completed lock
## makes it attack. Losing sight before the lock completes makes it investigate where it saw the player; losing sight
## while attacking makes it search there, and it has to lock on again. A noise or a hit makes a robot that isn't
## attacking investigate the spot. Once a robot has got to its focus, its attention runs out and it goes idle again.

enum State { IDLE, INVESTIGATING, ATTACKING, SEARCHING, DESTROYED }

signal state_changed(previous: State, current: State)
## Emitted when it starts locking on, with the seconds the lock takes.
signal lock_started(lock_time: float)
## Emitted when it loses sight of the player before the lock completed.
signal lock_dropped

var definition: EnemyDefinition
var state := State.IDLE
## Where its attention is: the noise or hit it investigates, the player while it sees them, or where it last saw
## them.
var focus := Vector3.ZERO
## Whether it sees the player, including the short sight memory after the last point went out of sight.
var sees_player := false
## Whether it is locking on: it sees the player but the lock hasn't completed yet.
var is_locking := false
## How far the lock has got, from 0 to 1.
var lock := 0.0
## Seconds of attention left once it has got to its focus, while investigating or searching.
var attention_left := 0.0

var _lock_time := 0.0
var _unseen := INF


func _init(enemy: EnemyDefinition) -> void:
	definition = enemy


## Whether it has locked on and may fire.
func is_attacking() -> bool:
	return state == State.ATTACKING


## Runs the mind for one physics frame. sees_now is whether the robot sees part of the player this frame, at
## seen_point. at_focus is whether its body has got to its focus (turned to it or flown there), so its attention
## runs out.
func update(delta: float, sees_now: bool, seen_point: Vector3, at_focus: bool) -> void:
	if state == State.DESTROYED:
		return
	if sees_now:
		_unseen = 0.0
		focus = seen_point
	else:
		_unseen += delta
	var was_seeing := sees_player
	sees_player = sees_now or (was_seeing and _unseen <= definition.sight_memory)
	if sees_player:
		_update_lock(delta)
	elif was_seeing:
		_lose_sight()
	elif (state == State.INVESTIGATING or state == State.SEARCHING) and at_focus:
		attention_left -= delta
		if attention_left <= 0.0:
			_set_state(State.IDLE)


## A noise at position. A robot that isn't attacking or watching the player investigates it. Returns whether it
## reacted.
func hear(position: Vector3) -> bool:
	if state == State.DESTROYED or state == State.ATTACKING or sees_player:
		return false
	focus = position
	_set_state(State.INVESTIGATING, definition.investigate_time)
	return true


## A hit or a bump that came from position: the robot turns its attention there at once, unless it is attacking or
## already watching the player. Returns whether it reacted.
func feel(position: Vector3) -> bool:
	return hear(position)


## The robot's health ran out; nothing changes its state any more.
func destroy() -> void:
	is_locking = false
	sees_player = false
	lock = 0.0
	_set_state(State.DESTROYED)


func _update_lock(delta: float) -> void:
	if state == State.ATTACKING:
		return
	if not is_locking:
		is_locking = true
		lock = 0.0
		_lock_time = definition.lock_time(state == State.IDLE)
		lock_started.emit(_lock_time)
	lock = minf(lock + delta / maxf(_lock_time, 0.001), 1.0)
	if lock >= 1.0:
		is_locking = false
		_set_state(State.ATTACKING)


## Out of sight: a lock in progress drops and the robot investigates where it saw the player; an attacking robot
## searches there.
func _lose_sight() -> void:
	var was_attacking := state == State.ATTACKING
	if is_locking:
		is_locking = false
		lock_dropped.emit()
	lock = 0.0
	if was_attacking:
		_set_state(State.SEARCHING, definition.search_time)
	else:
		_set_state(State.INVESTIGATING, definition.investigate_time)


## Changes state and resets the attention; staying in the same state only resets the attention.
func _set_state(next: State, attention: float = 0.0) -> void:
	attention_left = attention
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)
