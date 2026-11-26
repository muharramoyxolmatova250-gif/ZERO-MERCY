extends Node3D
## Simple deterministic intersection signal with demand-aware green extensions.
signal phase_changed(phase: String)
@export_range(2.0, 90.0, 1.0) var base_green_seconds := 18.0
@export_range(1.0, 12.0, 0.5) var yellow_seconds := 3.0
@export_range(1.0, 20.0, 0.5) var all_red_seconds := 1.5
var phase := "north_south_green"
var north_south_demand := 0
var east_west_demand := 0
var _timer := 0.0

func report_vehicle_approach(direction: String, amount: int = 1) -> void:
	if direction in ["north", "south"]:
		north_south_demand = mini(100, north_south_demand + maxi(1, amount))
	elif direction in ["east", "west"]:
		east_west_demand = mini(100, east_west_demand + maxi(1, amount))

func _process(delta: float) -> void:
	_timer += delta
	var duration := _phase_duration()
	if _timer < duration:
		return
	_timer = 0.0
	match phase:
		"north_south_green": phase = "north_south_yellow"
		"north_south_yellow": phase = "all_red_to_east_west"
		"all_red_to_east_west": phase = "east_west_green"
		"east_west_green": phase = "east_west_yellow"
		"east_west_yellow": phase = "all_red_to_north_south"
		_: phase = "north_south_green"
	if phase == "east_west_green":
		north_south_demand = maxi(0, north_south_demand - 3)
	elif phase == "north_south_green":
		east_west_demand = maxi(0, east_west_demand - 3)
	phase_changed.emit(phase)

func _phase_duration() -> float:
	if phase.ends_with("_yellow"):
		return yellow_seconds
	if phase.begins_with("all_red"):
		return all_red_seconds
	var demand := north_south_demand if phase == "north_south_green" else east_west_demand
	return base_green_seconds + minf(12.0, float(demand) * 0.18)

func can_vehicle_pass(direction: String) -> bool:
	if phase == "north_south_green":
		return direction in ["north", "south"]
	if phase == "east_west_green":
		return direction in ["east", "west"]
	return false

func get_signal_snapshot() -> Dictionary:
	return {"phase": phase, "timer": _timer, "north_south_demand": north_south_demand, "east_west_demand": east_west_demand}
