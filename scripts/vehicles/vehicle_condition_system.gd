extends Node
## Vehicle wear, component damage and repair state.
signal condition_changed(overall: float)
var engine_health := 1.0
var body_health := 1.0
var tire_health := 1.0
var battery_health := 1.0
var fuel := 1.0

func apply_damage(component: String, amount: float) -> void:
	var damage := clampf(amount, 0.0, 1.0)
	match component:
		"engine": engine_health = clampf(engine_health - damage, 0.0, 1.0)
		"body": body_health = clampf(body_health - damage, 0.0, 1.0)
		"tires": tire_health = clampf(tire_health - damage, 0.0, 1.0)
		"battery": battery_health = clampf(battery_health - damage, 0.0, 1.0)
		"fuel": fuel = clampf(fuel - damage, 0.0, 1.0)
		_: return
	condition_changed.emit(get_overall_condition())

func consume_fuel(amount: float) -> bool:
	if amount < 0.0 or fuel < amount:
		return false
	fuel = clampf(fuel - amount, 0.0, 1.0)
	return true

func repair(component: String, amount: float) -> void:
	var repair_amount := clampf(amount, 0.0, 1.0)
	match component:
		"engine": engine_health = minf(1.0, engine_health + repair_amount)
		"body": body_health = minf(1.0, body_health + repair_amount)
		"tires": tire_health = minf(1.0, tire_health + repair_amount)
		"battery": battery_health = minf(1.0, battery_health + repair_amount)
		"fuel": fuel = minf(1.0, fuel + repair_amount)
		"all":
			engine_health = minf(1.0, engine_health + repair_amount)
			body_health = minf(1.0, body_health + repair_amount)
			tire_health = minf(1.0, tire_health + repair_amount)
			battery_health = minf(1.0, battery_health + repair_amount)
		_: return
	condition_changed.emit(get_overall_condition())

func get_engine_power_multiplier() -> float:
	return 0.35 + engine_health * 0.65

func get_handling_multiplier() -> float:
	return 0.4 + tire_health * 0.6

func get_overall_condition() -> float:
	return (engine_health + body_health + tire_health + battery_health) * 0.25

func get_snapshot() -> Dictionary:
	return {"engine": engine_health, "body": body_health, "tires": tire_health, "battery": battery_health, "fuel": fuel, "overall": get_overall_condition()}
