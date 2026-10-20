class_name SlidingDoor
extends Node3D
## A door panel that slides sideways into its wall. Its origin is the bottom centre of the doorway, in the
## middle of the wall. It never closes on the player: while someone stands in the doorway a closing door opens
## again. Automatic doors open when the player comes near and close after a delay; other doors, such as the
## elevator's, are opened and closed by their owner.

signal opened
signal closed

## Opens when the player comes near and closes close_delay seconds after they leave.
@export var automatic := true
## Seconds the panel takes to slide fully open or closed.
@export var open_time := 0.6
@export var close_delay := 2.0
@export var slide_distance := 1.2

## Whether the door has been told to open (it may still be sliding).
var open_requested := false

## 0 is closed, 1 is fully open.
var _open_amount := 0.0
var _close_timer := 0.0

@onready var _panel: AnimatableBody3D = $Panel
@onready var _doorway: Area3D = $Doorway
@onready var _proximity: Area3D = $Proximity


func _ready() -> void:
	_proximity.monitoring = automatic


func open() -> void:
	if not open_requested:
		open_requested = true
		Log.info("🚪 Door opening: door=%s, automatic=%s, position=%s" % [_label(), automatic, global_position])


func close() -> void:
	if open_requested:
		open_requested = false
		Log.info("🚪 Door closing: door=%s, automatic=%s, position=%s" % [_label(), automatic, global_position])


func is_closed() -> bool:
	return _open_amount <= 0.0 and not open_requested


func is_fully_open() -> bool:
	return _open_amount >= 1.0


func is_doorway_occupied() -> bool:
	return _doorway.has_overlapping_bodies()


## Runs every physics frame, so it only logs when the door finishes opening or closing.
func _physics_process(delta: float) -> void:
	if automatic:
		_update_automatic(delta)
	# Someone in the doorway holds a door open, but never opens a closed one (elevator doors must stay shut).
	var held_open := _open_amount > 0.0 and is_doorway_occupied()
	var target := 1.0 if open_requested or held_open else 0.0
	if is_equal_approx(_open_amount, target):
		return
	_open_amount = move_toward(_open_amount, target, delta / open_time)
	_panel.position.x = _open_amount * slide_distance
	if _open_amount >= 1.0:
		Log.info("🚪 Door open: door=%s, held_by_player=%s" % [_label(), held_open and not open_requested])
		opened.emit()
	elif _open_amount <= 0.0:
		Log.info("🚪 Door closed: door=%s" % _label())
		closed.emit()


func _update_automatic(delta: float) -> void:
	if _proximity.has_overlapping_bodies():
		_close_timer = close_delay
		open()
	elif open_requested:
		_close_timer -= delta
		if _close_timer <= 0.0:
			close()


## Section and socket name, such as "RoomSmall/SocketSouth".
func _label() -> String:
	var socket := get_parent()
	if socket == null or socket.get_parent() == null:
		return name
	return "%s/%s" % [socket.get_parent().name, socket.name]
