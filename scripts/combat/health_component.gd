extends Node
class_name HealthComponent
## Reusable health component for NPCs, enemies, and destructible props.

signal health_changed(current: float, maximum: float)
signal died

@export var maximum_health := 100.0
@export var allow_overheal := false
var current_health := 100.0
var is_dead := false


func _ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var cap := INF if allow_overheal else maximum_health
	current_health = minf(cap, current_health + amount)
	health_changed.emit(current_health, maximum_health)


func restore_full() -> void:
	is_dead = false
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)
