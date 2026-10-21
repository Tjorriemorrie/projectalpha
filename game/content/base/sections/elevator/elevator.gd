class_name Elevator
extends Section
## A shaft spanning two decks, with a platform that rides between them. The call button beside the doors on
## each deck brings the platform, or opens the doors when it is already there; the button on the platform sends
## it to the other deck. A deck's doors only open while the platform is at that deck, and they close once nobody
## has been aboard or in the doorway for close_delay seconds. Arriving dings: a signal, and a noise that enemies
## on that deck hear and come to investigate. Drones don't ride it, so it is not navigable.

## Emitted when the platform arrives and dings, with the deck it reached and where the ding sounded.
signal dinged(deck: int, sound_position: Vector3)

enum State { IDLE, CLOSING, MOVING }

## Metres per second.
@export var speed := 1.5
## Seconds the doors stay open once nobody is aboard or in the doorway.
@export var close_delay := 3.0
## Height of the ding above the deck's floor, at the doors.
@export var ding_height := 2.0
## Metres the ding carries as noise, so enemies come to see who arrived.
@export var ding_loudness := 20.0

var state: State = State.IDLE
## The deck the platform is at, or is leaving while its doors close and it moves.
var deck := 0

var _target_deck := 0
var _pending_call := -1
var _empty_time := 0.0
var _doors: Array[SlidingDoor] = []

@onready var _platform: AnimatableBody3D = $Platform
@onready var _aboard: Area3D = $Platform/Aboard
@onready var _send_button: Interactable = $Platform/SendButton
@onready var _ding: AudioStreamPlayer3D = $Ding
@onready var _sockets: Array[Socket] = [$SocketDeck1, $SocketDeck2]


func _ready() -> void:
	($CallButtonDeck1 as Interactable).interacted.connect(call_to.bind(0))
	($CallButtonDeck2 as Interactable).interacted.connect(call_to.bind(1))
	_send_button.interacted.connect(send)
	_update_send_prompt()
	Log.info("🛗 Elevator ready: elevator=%s, decks=%d, deck=%d, speed=%.1f m/s, close_delay=%.1f s" % [
		name, _sockets.size(), deck, speed, close_delay])


## Picks up the doors the wreck built into the elevator's sockets.
func assembled() -> void:
	_doors.clear()
	for socket in _sockets:
		if socket.door == null:
			Log.error("🛗 Elevator deck has no door, nothing joins its socket: elevator=%s, socket=%s" % [
				name, socket.name])
			_doors.clear()
			return
		_doors.append(socket.door)
	Log.info("🛗 Elevator assembled: elevator=%s, doors=%d" % [name, _doors.size()])


func get_platform_height() -> float:
	return _platform.position.y


## Called by a deck's call button.
func call_to(called_deck: int) -> void:
	if _doors.is_empty():
		Log.warning("🛗 Elevator called before it was assembled, ignoring: elevator=%s, deck=%d" % [name, called_deck])
		return
	if state == State.IDLE and called_deck == deck:
		_open_doors()
		Log.info("🛗 Elevator called to the deck it is at, opening doors: elevator=%s, deck=%d" % [name, deck])
	elif state == State.IDLE:
		Log.info("🛗 Elevator called: elevator=%s, from_deck=%d, to_deck=%d" % [name, deck, called_deck])
		_depart(called_deck)
	elif state == State.CLOSING and called_deck == deck:
		state = State.IDLE
		_open_doors()
		Log.info("🛗 Elevator departure cancelled by a call, reopening doors: elevator=%s, deck=%d" % [name, deck])
	elif called_deck != _target_deck:
		_pending_call = called_deck
		Log.info("🛗 Elevator busy, call queued: elevator=%s, state=%s, queued_deck=%d" % [
			name, State.keys()[state], called_deck])
	else:
		Log.info("🛗 Elevator already on its way to the calling deck: elevator=%s, deck=%d" % [name, called_deck])


## Called by the button on the platform.
func send() -> void:
	if _doors.is_empty():
		Log.warning("🛗 Elevator sent before it was assembled, ignoring: elevator=%s" % name)
		return
	if state != State.IDLE:
		Log.info("🛗 Elevator send ignored, already leaving: elevator=%s, state=%s" % [name, State.keys()[state]])
		return
	Log.info("🛗 Elevator sent: elevator=%s, from_deck=%d, to_deck=%d" % [name, deck, 1 - deck])
	_depart(1 - deck)


## Runs every physics frame, so it only logs when the elevator changes state.
func _physics_process(delta: float) -> void:
	if _doors.is_empty():
		return
	match state:
		State.CLOSING:
			if _doors[deck].is_closed():
				state = State.MOVING
				Log.info("🛗 Elevator doors closed, moving: elevator=%s, from_deck=%d, to_deck=%d" % [
					name, deck, _target_deck])
		State.MOVING:
			var target_height := _target_deck * WreckAssembly.DECK_HEIGHT
			_platform.position.y = move_toward(_platform.position.y, target_height, speed * delta)
			if is_equal_approx(_platform.position.y, target_height):
				_arrive()
		State.IDLE:
			_update_idle(delta)


func _depart(to_deck: int) -> void:
	_target_deck = to_deck
	state = State.CLOSING
	_doors[deck].close()
	Log.info("🛗 Elevator closing doors to leave: elevator=%s, from_deck=%d, to_deck=%d" % [name, deck, to_deck])


func _arrive() -> void:
	deck = _target_deck
	state = State.IDLE
	_update_send_prompt()
	_ding.position = Vector3(0.0, deck * WreckAssembly.DECK_HEIGHT + ding_height, -WreckAssembly.CELL_SIZE / 2.0)
	_ding.play()
	_open_doors()
	Log.info("🛗 Elevator arrived and dinged: elevator=%s, deck=%d, height=%.2f m, queued_deck=%d" % [
		name, deck, _platform.position.y, _pending_call])
	dinged.emit(deck, _ding.global_position)
	Hearing.make_noise(self, _ding.global_position, ding_loudness, &"elevator_ding")


## Closes the doors once nobody has been aboard or in the doorway for close_delay, then answers a queued call.
func _update_idle(delta: float) -> void:
	var door := _doors[deck]
	if door.open_requested:
		if _aboard.has_overlapping_bodies() or door.is_doorway_occupied():
			_empty_time = 0.0
		else:
			_empty_time += delta
			if _empty_time >= close_delay:
				door.close()
				Log.info("🛗 Nobody aboard, elevator doors closing: elevator=%s, deck=%d" % [name, deck])
	elif _pending_call >= 0 and door.is_closed():
		var called := _pending_call
		_pending_call = -1
		Log.info("🛗 Elevator answering queued call: elevator=%s, deck=%d" % [name, called])
		call_to(called)


func _open_doors() -> void:
	_empty_time = 0.0
	_doors[deck].open()


func _update_send_prompt() -> void:
	_send_button.prompt = "Ride up" if deck == 0 else "Ride down"
