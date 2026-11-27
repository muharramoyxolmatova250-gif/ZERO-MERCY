extends Node
## Gameplay-facing weather state; visuals can subscribe to weather_changed.
signal weather_changed(weather: String, intensity: float)
var weather := "clear"
var intensity := 0.0
var _change_timer := 0.0
@export_range(20.0, 900.0, 10.0) var weather_interval := 180.0

func _ready() -> void:
	add_to_group("weather_impact_controller")
	_apply_traffic_weather()

func _process(delta: float) -> void:
	_change_timer += delta
	if _change_timer < weather_interval:
		return
	_change_timer = 0.0
	_roll_weather()

func set_weather(next_weather: String, next_intensity: float = 0.5) -> void:
	var allowed := ["clear", "cloudy", "rain", "storm", "fog", "snow"]
	if not allowed.has(next_weather):
		return
	weather = next_weather
	intensity = clampf(next_intensity, 0.0, 1.0)
	weather_changed.emit(weather, intensity)
	_apply_traffic_weather()

func _roll_weather() -> void:
	var choices := ["clear", "cloudy", "rain", "fog", "storm"]
	var weights := [38, 25, 22, 10, 5]
	var roll := randi_range(1, 100)
	var total := 0
	for index in range(choices.size()):
		total += int(weights[index])
		if roll <= total:
			set_weather(str(choices[index]), randf_range(0.2, 1.0))
			return

func get_movement_multiplier() -> float:
	match weather:
		"rain": return 1.0 - intensity * 0.12
		"storm": return 1.0 - intensity * 0.22
		"snow": return 1.0 - intensity * 0.28
		"fog": return 1.0 - intensity * 0.06
		_: return 1.0

func get_visibility_multiplier() -> float:
	match weather:
		"fog": return 1.0 - intensity * 0.7
		"storm": return 1.0 - intensity * 0.45
		"rain": return 1.0 - intensity * 0.2
		"snow": return 1.0 - intensity * 0.3
		_: return 1.0

func get_weather_snapshot() -> Dictionary:
	return {"weather": weather, "intensity": intensity, "movement_multiplier": get_movement_multiplier(), "visibility_multiplier": get_visibility_multiplier()}

 
func _apply_traffic_weather() -> void:
	var manager := get_tree().get_first_node_in_group("road_traffic_manager")
	if manager != null and manager.has_method("set_weather_effect"):
		manager.call("set_weather_effect", weather, intensity)

func get_driving_condition_snapshot() -> Dictionary:
    var risk := 0.0
    match weather:
        "rain": risk = intensity * 0.25
        "storm": risk = intensity * 0.55
        "snow": risk = intensity * 0.7
        "fog": risk = intensity * 0.18
    return {"weather": weather, "intensity": intensity, "driving_risk": risk, "visibility": get_visibility_multiplier(), "traction": get_movement_multiplier()}
