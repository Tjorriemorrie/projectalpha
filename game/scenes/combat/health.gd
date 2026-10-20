class_name Health
extends Node
## Health for anything that can be damaged: the player, the test level's shooting targets, and robots in 006.
## Hitboxes pass their hits to it. It emits damaged for every hit and died once, when it reaches 0.

## Emitted for every hit that does damage, with the damage done and where the shot came from.
signal damaged(amount: float, source_position: Vector3, part: Hitbox.Part)
## Emitted once, when health reaches 0.
signal died

@export var max_health: float = 100.0

var health := 0.0


func _ready() -> void:
	health = max_health


func is_dead() -> bool:
	return health <= 0.0


## Takes amount of damage from a hit that came from source_position. Hits after death do nothing.
func take_damage(amount: float, source_position: Vector3, part: Hitbox.Part = Hitbox.Part.BODY) -> void:
	if is_dead() or amount <= 0.0:
		Log.info("🩸 Damage ignored: owner=%s, amount=%.1f, health=%.1f, dead=%s" % [
			get_parent().name, amount, health, is_dead()])
		return
	health = maxf(health - amount, 0.0)
	Log.info("🩸 Damaged: owner=%s, part=%s, amount=%.1f, health=%.1f/%.1f, source=%s" % [
		get_parent().name, Hitbox.Part.keys()[part], amount, health, max_health, source_position])
	damaged.emit(amount, source_position, part)
	if is_dead():
		Log.info("🩸 Died: owner=%s, part=%s, last_hit=%.1f" % [get_parent().name, Hitbox.Part.keys()[part], amount])
		died.emit()


## Back to full health, e.g. when a shooting target stands up again.
func reset() -> void:
	health = max_health
	Log.info("🩸 Health reset: owner=%s, health=%.1f" % [get_parent().name, health])
