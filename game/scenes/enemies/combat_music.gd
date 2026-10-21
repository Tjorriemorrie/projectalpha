class_name CombatMusic
extends AudioStreamPlayer
## Music that only plays while a robot is attacking: it fades in when the first robot locks on and attacks, and fades
## out a few seconds after the last one stopped. Investigating and searching don't start it, so exploring stays
## silent. The player scene owns it, because the player is who hears it.

## Seconds to fade in and out, and seconds it holds on after the last robot stopped attacking.
@export var fade_in_time: float = 1.0
@export var fade_out_time: float = 3.0
@export var hold_time: float = 4.0

## Whether the music is on: a robot is attacking, or one was within the last hold_time seconds.
var is_combat := false

var _full_volume_db := 0.0
var _volume := 0.0
var _hold_left := 0.0


func _ready() -> void:
	_full_volume_db = volume_db
	volume_db = linear_to_db(0.0001)
	Log.info("🎵 Combat music ready: stream=%s, fade_in=%.1f s, hold=%.1f s, fade_out=%.1f s" % [
		stream.resource_path if stream else "none", fade_in_time, hold_time, fade_out_time])


## Runs every physics frame, so it only logs when the combat starts or ends.
func _physics_process(delta: float) -> void:
	var attacking := Robot.count_attacking(get_tree())
	if attacking > 0:
		_hold_left = hold_time
	else:
		_hold_left -= delta
	var wanted := _hold_left > 0.0
	if wanted != is_combat:
		is_combat = wanted
		if wanted and not playing and stream:
			play()
		Log.info("🎵 Combat music %s: robots_attacking=%d" % ["starts" if wanted else "fades out", attacking])
	var fade_time := fade_in_time if wanted else fade_out_time
	_volume = move_toward(_volume, 1.0 if wanted else 0.0, delta / maxf(fade_time, 0.001))
	volume_db = _full_volume_db + linear_to_db(maxf(_volume, 0.0001))
	if _volume <= 0.0 and playing:
		stop()
