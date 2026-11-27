extends Node
## Tracks traffic density, weather penalties and temporary incidents per road segment.
var _segments: Dictionary = {}
var _weather := "clear"
var _weather_intensity := 0.0
var _active_incidents: Dictionary = {}

func register_segment(segment_id: String, speed_limit: float = 13.9, capacity: int = 24) -> void:
	if segment_id.is_empty():
		return
	var previous: Dictionary = _segments.get(segment_id, {})
	_segments[segment_id] = {
		"speed_limit": maxf(1.0, speed_limit),
		"capacity": maxi(1, capacity),
		"vehicles": previous.get("vehicles", {}),
		"closed": bool(previous.get("closed", false)),
		"incident_factor": float(previous.get("incident_factor", 1.0)),
		"surface_factor": float(previous.get("surface_factor", 1.0))
	}

func report_vehicle(segment_id: String, vehicle_id: String, entering: bool) -> void:
	if not _segments.has(segment_id) or vehicle_id.is_empty():
		return
	var segment: Dictionary = _segments[segment_id]
	var vehicles: Dictionary = segment.get("vehicles", {})
	if entering:
		vehicles[vehicle_id] = true
	else:
		vehicles.erase(vehicle_id)
	segment["vehicles"] = vehicles
	_segments[segment_id] = segment

func set_segment_closed(segment_id: String, closed: bool) -> void:
	if _segments.has(segment_id):
		var segment: Dictionary = _segments[segment_id]
		segment["closed"] = closed
		_segments[segment_id] = segment

func set_weather_effect(next_weather: String, intensity: float) -> void:
	_weather = next_weather
	_weather_intensity = clampf(intensity, 0.0, 1.0)
	var surface_factor := 1.0
	match _weather:
		"rain": surface_factor = 1.0 - _weather_intensity * 0.12
		"storm": surface_factor = 1.0 - _weather_intensity * 0.24
		"snow": surface_factor = 1.0 - _weather_intensity * 0.32
		"fog": surface_factor = 1.0 - _weather_intensity * 0.05
	for segment_id in _segments.keys():
		var segment: Dictionary = _segments[segment_id]
		segment["surface_factor"] = surface_factor
		_segments[segment_id] = segment

func report_incident(segment_id: String, incident_id: String, severity: float = 0.5, duration_factor: float = 0.55) -> void:
	if not _segments.has(segment_id) or incident_id.is_empty():
		return
	var segment: Dictionary = _segments[segment_id]
	segment["incident_factor"] = minf(float(segment.get("incident_factor", 1.0)), clampf(duration_factor, 0.1, 1.0))
	segment["active_incident"] = incident_id
	segment["incident_severity"] = clampf(severity, 0.0, 1.0)
	_segments[segment_id] = segment
	_active_incidents[incident_id] = segment_id

func clear_incident(incident_id: String) -> void:
	if not _active_incidents.has(incident_id):
		return
	var segment_id := str(_active_incidents[incident_id])
	_active_incidents.erase(incident_id)
	if _segments.has(segment_id):
		var segment: Dictionary = _segments[segment_id]
		segment["incident_factor"] = 1.0
		segment.erase("active_incident")
		segment.erase("incident_severity")
		_segments[segment_id] = segment

func get_recommended_speed(segment_id: String) -> float:
	if not _segments.has(segment_id):
		return 8.0
	var segment: Dictionary = _segments[segment_id]
	if bool(segment.get("closed", false)):
		return 0.0
	var count := (segment.get("vehicles", {}) as Dictionary).size()
	var capacity := maxi(1, int(segment.get("capacity", 1)))
	var congestion := clampf(float(count) / float(capacity), 0.0, 1.5)
	var traffic_factor := clampf(1.0 - congestion * 0.62, 0.18, 1.0)
	return float(segment.get("speed_limit", 13.9)) * traffic_factor * float(segment.get("incident_factor", 1.0)) * float(segment.get("surface_factor", 1.0))

func get_segment_snapshot(segment_id: String) -> Dictionary:
	if not _segments.has(segment_id):
		return {}
	var segment: Dictionary = _segments[segment_id]
	var count := (segment.get("vehicles", {}) as Dictionary).size()
	return {"id": segment_id, "vehicles": count, "capacity": int(segment.get("capacity", 1)), "closed": bool(segment.get("closed", false)), "recommended_speed": get_recommended_speed(segment_id), "incident": str(segment.get("active_incident", "")), "weather_factor": float(segment.get("surface_factor", 1.0))}

func get_traffic_snapshot() -> Dictionary:
	var total_vehicles := 0
	var congested := 0
	for segment in _segments.values():
		var count := (segment.get("vehicles", {}) as Dictionary).size()
		total_vehicles += count
		if float(count) / float(maxi(1, int(segment.get("capacity", 1)))) >= 0.8:
			congested += 1
	return {"road_segments": _segments.size(), "vehicles_tracked": total_vehicles, "congested_segments": congested, "active_incidents": _active_incidents.size(), "weather": _weather, "weather_intensity": _weather_intensity}
