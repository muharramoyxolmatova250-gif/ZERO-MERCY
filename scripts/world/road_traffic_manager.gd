extends Node
## Tracks traffic density per road segment and exposes congestion-aware speed.
var _segments: Dictionary = {}

func register_segment(segment_id: String, speed_limit: float = 13.9, capacity: int = 24) -> void:
	if segment_id.is_empty():
		return
	_segments[segment_id] = {"speed_limit": maxf(1.0, speed_limit), "capacity": maxi(1, capacity), "vehicles": {}, "closed": false}

func report_vehicle(segment_id: String, vehicle_id: String, entering: bool) -> void:
	if not _segments.has(segment_id):
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

func get_recommended_speed(segment_id: String) -> float:
	if not _segments.has(segment_id):
		return 8.0
	var segment: Dictionary = _segments[segment_id]
	if bool(segment.get("closed", false)):
		return 0.0
	var count := (segment.get("vehicles", {}) as Dictionary).size()
	var capacity := maxi(1, int(segment.get("capacity", 1)))
	var congestion := clampf(float(count) / float(capacity), 0.0, 1.5)
	return float(segment.get("speed_limit", 13.9)) * clampf(1.0 - congestion * 0.62, 0.18, 1.0)

func get_traffic_snapshot() -> Dictionary:
	var total_vehicles := 0
	var congested := 0
	for segment in _segments.values():
		var count := (segment.get("vehicles", {}) as Dictionary).size()
		total_vehicles += count
		if float(count) / float(maxi(1, int(segment.get("capacity", 1)))) >= 0.8:
			congested += 1
	return {"road_segments": _segments.size(), "vehicles_tracked": total_vehicles, "congested_segments": congested}
