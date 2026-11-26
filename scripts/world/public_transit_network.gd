extends Node
## Lightweight public transport route registry and stop-to-stop trip planner.
var _stops: Dictionary = {}
var _routes: Dictionary = {}
var _waiting_passengers: Dictionary = {}
var _total_boardings := 0
var _total_generated_passengers := 0

func register_stop(stop_id: String, position: Vector3, name: String = "") -> bool:
	if stop_id.is_empty():
		return false
	_stops[stop_id] = {"id": stop_id, "name": name if not name.is_empty() else stop_id, "position": position}
	_waiting_passengers[stop_id] = 0
	return true

func register_route(route_id: String, stop_ids: Array[String], vehicle_type: String = "bus", interval_minutes: int = 12) -> bool:
	if route_id.is_empty() or stop_ids.size() < 2:
		return false
	for stop_id in stop_ids:
		if not _stops.has(stop_id):
			return false
	_routes[route_id] = {"id": route_id, "stops": stop_ids.duplicate(), "vehicle_type": vehicle_type, "interval_minutes": maxi(1, interval_minutes), "active": true, "vehicles_serving": 0, "stops_served": 0, "passenger_boardings": 0}
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
		if a < 0 or b < 0:
			continue
		var forward_hops := absi(a - b)
		var reverse_hops := stops.size() - forward_hops
		var chosen_hops := mini(forward_hops, reverse_hops)
		if chosen_hops < best_hops:
			best_hops = chosen_hops
			best = route.duplicate(true)
			best["start_index"] = a
			best["destination_index"] = b
			best["stops_away"] = chosen_hops
			best["travel_direction"] = "forward" if (b - a + stops.size()) % stops.size() == chosen_hops else "reverse"
	return best

func get_nearest_stop(position: Vector3, max_distance: float = 120.0) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := max_distance
	for stop_id in _stops:
		var stop: Dictionary = _stops[stop_id]
		var distance := position.distance_to(stop.get("position", Vector3.ZERO))
		if distance < best_distance:
			best_distance = distance
			nearest = stop.duplicate(true)
			nearest["distance"] = distance
	return nearest

func get_stop_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stop_id in _stops:
		result.append(_stops[stop_id].duplicate(true))
	return result

func add_waiting_passengers(stop_id: String, amount: int) -> int:
	if not _stops.has(stop_id):
		return 0
	var current := int(_waiting_passengers.get(stop_id, 0))
	var added := mini(maxi(0, amount), 60 - current)
	_waiting_passengers[stop_id] = current + added
	_total_generated_passengers += added
	return added

func board_waiting_passengers(stop_id: String, available_seats: int) -> int:
	if not _stops.has(stop_id):
		return 0
	var waiting := int(_waiting_passengers.get(stop_id, 0))
	var boarded := mini(waiting, maxi(0, available_seats))
	_waiting_passengers[stop_id] = waiting - boarded
	_total_boardings += boarded
	return boarded

func get_waiting_passengers(stop_id: String) -> int:
	return int(_waiting_passengers.get(stop_id, 0))

func get_passenger_statistics() -> Dictionary:
	var waiting_total := 0
	for count in _waiting_passengers.values():
		waiting_total += int(count)
	return {"waiting": waiting_total, "boardings": _total_boardings, "generated": _total_generated_passengers}

func report_vehicle_stop(route_id: String, stop_id: String, passengers: int) -> void:
	if not _routes.has(route_id) or not _stops.has(stop_id):
		return
	var route: Dictionary = _routes[route_id]
	var stops: Array = route.get("stops", [])
	if not stops.has(stop_id):
		return
	route["stops_served"] = int(route.get("stops_served", 0)) + 1
	route["passenger_boardings"] = int(route.get("passenger_boardings", 0)) + maxi(0, passengers)
	_routes[route_id] = route

func report_vehicle_active(route_id: String, active: bool) -> void:
	if not _routes.has(route_id):
		return
	var route: Dictionary = _routes[route_id]
	route["vehicles_serving"] = maxi(0, int(route.get("vehicles_serving", 0)) + (1 if active else -1))
	_routes[route_id] = route

func get_route_snapshot(route_id: String) -> Dictionary:
	if not _routes.has(route_id):
		return {}
	return _routes[route_id].duplicate(true)


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
	return {"stops": _stops.size(), "routes": _routes.size(), "active_routes": active_routes, "passengers_waiting": get_passenger_statistics().get("waiting", 0), "total_boardings": _total_boardings}
