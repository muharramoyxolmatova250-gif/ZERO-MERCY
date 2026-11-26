extends Node
## Player hunger, thirst, stamina and fatigue simulation.
signal needs_changed(snapshot: Dictionary)
@export var hunger_decay_per_minute := 0.7
@export var thirst_decay_per_minute := 1.2
@export var fatigue_gain_per_minute := 0.45
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var fatigue := 0.0

func _process(delta: float) -> void:
	var minutes := delta / 60.0
	hunger = maxf(0.0, hunger - hunger_decay_per_minute * minutes)
	thirst = maxf(0.0, thirst - thirst_decay_per_minute * minutes)
	fatigue = minf(100.0, fatigue + fatigue_gain_per_minute * minutes)
	needs_changed.emit(get_snapshot())

func consume_food(nutrition: float, hydration: float = 0.0) -> void:
	hunger = clampf(hunger + maxf(0.0, nutrition), 0.0, 100.0)
	thirst = clampf(thirst + maxf(0.0, hydration), 0.0, 100.0)

func rest(minutes: float) -> void:
	var duration := maxf(0.0, minutes)
	fatigue = maxf(0.0, fatigue - duration * 2.0)
	stamina = minf(100.0, stamina + duration * 1.5)

func spend_stamina(amount: float) -> bool:
	if amount < 0.0 or stamina < amount:
		return false
	stamina = maxf(0.0, stamina - amount)
	return true

func get_performance_multiplier() -> float:
	return clampf(1.0 - (100.0 - hunger) * 0.002 - (100.0 - thirst) * 0.003 - fatigue * 0.002, 0.35, 1.0)

func get_snapshot() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "stamina": stamina, "fatigue": fatigue, "performance": get_performance_multiplier()}

func restore_snapshot(snapshot: Dictionary) -> bool:
	for key in ["hunger", "thirst", "stamina", "fatigue"]:
		var value: Variant = snapshot.get(key, get(key))
		if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)):
			return false
	hunger = clampf(float(snapshot.get("hunger", hunger)), 0.0, 100.0)
	thirst = clampf(float(snapshot.get("thirst", thirst)), 0.0, 100.0)
	stamina = clampf(float(snapshot.get("stamina", stamina)), 0.0, 100.0)
	fatigue = clampf(float(snapshot.get("fatigue", fatigue)), 0.0, 100.0)
	needs_changed.emit(get_snapshot())
	return true
