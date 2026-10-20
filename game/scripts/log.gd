class_name Log
extends RefCounted
## Project-wide logging with INFO, WARNING and ERROR levels. The project never logs at DEBUG level.
## Start every message with the emoji of the module that logs it (e.g. 🏃 for the player), so related
## entries are easy to scan.


static func info(message: String) -> void:
	print("%s INFO %s" % [_timestamp(), message])


static func warning(message: String) -> void:
	push_warning("%s %s" % [_timestamp(), message])


static func error(message: String) -> void:
	push_error("%s %s" % [_timestamp(), message])


static func _timestamp() -> String:
	return Time.get_time_string_from_system()
