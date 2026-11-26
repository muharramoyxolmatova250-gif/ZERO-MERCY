extends Node
## District-level power generation, demand and controlled outage simulation.
signal district_power_changed(district_id: String, powered: bool)
var _districts: Dictionary = {}

func register_district(district_id: String, generation_kw: float, demand_kw: float) -> bool:
	if district_id.is_empty():
		return false
	_districts[district_id] = {"generation_kw": maxf(0.0, generation_kw), "demand_kw": maxf(0.0, demand_kw), "powered": true, "battery_kwh": 0.0}
	_refresh_district(district_id)
	return true

func set_generation(district_id: String, generation_kw: float) -> void:
	if not _districts.has(district_id):
		return
	var district: Dictionary = _districts[district_id]
	district["generation_kw"] = maxf(0.0, generation_kw)
	_districts[district_id] = district
	_refresh_district(district_id)

func set_demand(district_id: String, demand_kw: float) -> void:
	if not _districts.has(district_id):
		return
	var district: Dictionary = _districts[district_id]
	district["demand_kw"] = maxf(0.0, demand_kw)
	_districts[district_id] = district
	_refresh_district(district_id)

func add_battery_energy(district_id: String, energy_kwh: float) -> void:
	if not _districts.has(district_id):
		return
	var district: Dictionary = _districts[district_id]
	district["battery_kwh"] = maxf(0.0, float(district.get("battery_kwh", 0.0)) + energy_kwh)
	_districts[district_id] = district

func _refresh_district(district_id: String) -> void:
	var district: Dictionary = _districts[district_id]
	var has_power := float(district.get("generation_kw", 0.0)) >= float(district.get("demand_kw", 0.0))
	if bool(district.get("powered", true)) != has_power:
		district["powered"] = has_power
		district_power_changed.emit(district_id, has_power)
	_districts[district_id] = district

func get_district_snapshot(district_id: String) -> Dictionary:
	return (_districts.get(district_id, {}) as Dictionary).duplicate(true)

func get_grid_snapshot() -> Dictionary:
	var powered := 0
	var demand := 0.0
	var generation := 0.0
	for district in _districts.values():
		if bool(district.get("powered", false)):
			powered += 1
		demand += float(district.get("demand_kw", 0.0))
		generation += float(district.get("generation_kw", 0.0))
	return {"districts": _districts.size(), "powered_districts": powered, "total_generation_kw": generation, "total_demand_kw": demand}
