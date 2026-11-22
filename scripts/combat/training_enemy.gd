extends CharacterBody3D
## Simple combat target for the first ZERO MERCY combat slice.

@export var max_health: float = 100.0
var health: float

func _ready() -> void:
	health = max_health
	add_to_group("damageable")

func take_damage(amount: float, _source: Node = null) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	print("ENEMY HP: ", int(health), "/", int(max_health))
	if health <= 0.0:
		print("Target eliminated.")
		queue_free()
