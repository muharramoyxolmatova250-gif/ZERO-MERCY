extends Node
## Lightweight public transport route registry and stop-to-stop trip planner.
var _stops: Dictionary = {}
var _routes: Dictionary = {}

func register_stop(stop_id: String, position: Vector3, name: String = "") -> bool:
	if stop_id.is_empty():
		return false
	_stops[stop_id] = {"id": stop_id, "name": name if not name.is_empty() else stop_id, "position": position}
	return true

func register_route(route_id: String, stop_ids: Array[String], vehicle_type: String = "bus", interval_minutes: int = 12) -> bool:
	if route_id.is_empty() or stop_ids.size() < 2:
		return false
	for stop_id in stop_ids:
		if not _stops.has(stop_id):
			return false
	_routes[route_id] = {"id": route_id, "stops": stop_ids.duplicate(), "vehicle_type": vehicle_type, "interval_minutes": maxi(1, interval_minutes), "active": true}
	return true

func find_route_between(start_stop: String, destination_stop: String) -> Dictionary:
	if not _stops.has(start_stop) or not _stops.has(destination_stop):
		return {}
	var best: Dictionary = {}
	var best_hops := 2147483647
	for route_id in _routes:
		var route: Dictionary = _routes[route_id]
		if not bool(route.get("active", true)):
			continue
		var stops: Array = route.get("stops", [])
		var a := stops.find(start_stop)
		var b := stops.find(destination_stop)
		if a >= 0 and b >= 0 and absi(a - b) < best_hops:
			best_hops = absi(a - b)
			best = route.duplicate(true)
			best["start_index"] = a
			best["destination_index"] = b
			best["stops_away"] = best_hops
	return best

func set_route_active(route_id: String, active: bool) -> void:
	if _routes.has(route_id):
		var route: Dictionary = _routes[route_id]
		route["active"] = active
		_routes[route_id] = route

func get_transit_snapshot() -> Dictionary:
	var active_routes := 0
	for route in _routes.values():
		if bool(route.get("active", true)):
			active_routes += 1
	return {"stops": _stops.size(), "routes": _routes.size(), "active_routes": active_routes}
