extends Node
## Lightweight public transport route registry and stop-to-stop trip planner.
var _stops: Dictionary = {}
var _routes: Dictionary = {}
var _waiting_passengers: Dictionary = {}
var _waiting_manifests: Dictionary = {}
var _total_boardings := 0
var _total_generated_passengers := 0
var _demand_timer := 0.0
var _rng := RandomNumberGenerator.new()
@export_range(5.0, 120.0, 1.0) var demand_interval_seconds := 28.0

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	if _stops.is_empty():
		return
	_demand_timer += delta
	if _demand_timer < demand_interval_seconds:
		return
	_demand_timer = 0.0
	for stop_id in _stops:
		var stop: Dictionary = _stops[stop_id]
		var demand := _rng.randi_range(1, 4)
		if str(stop.get("name", "")).to_lower().contains("central"):
			demand += 2
		var destination_ids: Array[String] = []
		for candidate_id in _stops:
			if str(candidate_id) != str(stop_id):
				destination_ids.append(str(candidate_id))
		if not destination_ids.is_empty():
			for passenger_index in range(demand):
				var destination_id := destination_ids[_rng.randi_range(0, destination_ids.size() - 1)]
				add_waiting_trip(str(stop_id), destination_id, 1)
		else:
			add_waiting_passengers(str(stop_id), demand)

func register_stop(stop_id: String, position: Vector3, name: String = "") -> bool:
	if stop_id.is_empty():
		return false
	_stops[stop_id] = {"id": stop_id, "name": name if not name.is_empty() else stop_id, "position": position}
	_waiting_passengers[stop_id] = 0
	_waiting_manifests[stop_id] = []
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
			nearest["waiting_passengers"] = get_waiting_passengers(str(stop_id))
	return nearest

func get_stop_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stop_id in _stops:
		var stop: Dictionary = _stops[stop_id].duplicate(true)
		stop["waiting_passengers"] = get_waiting_passengers(str(stop_id))
		result.append(stop)
	return result

func add_waiting_passengers(stop_id: String, amount: int) -> int:
	if not _stops.has(stop_id):
		return 0
	var current := get_waiting_passengers(stop_id)
	var added := mini(maxi(0, amount), 60 - current)
	var manifest: Array = _waiting_manifests.get(stop_id, [])
	for index in range(added):
		manifest.append("")
	_waiting_manifests[stop_id] = manifest
	_waiting_passengers[stop_id] = manifest.size()
	_total_generated_passengers += added
	return added

func add_waiting_trip(stop_id: String, destination_stop: String, amount: int = 1) -> int:
	if not _stops.has(stop_id) or not _stops.has(destination_stop) or stop_id == destination_stop:
		return 0
	var manifest: Array = _waiting_manifests.get(stop_id, [])
	var added := mini(maxi(0, amount), 60 - manifest.size())
	for index in range(added):
		manifest.append(destination_stop)
	_waiting_manifests[stop_id] = manifest
	_waiting_passengers[stop_id] = manifest.size()
	_total_generated_passengers += added
	return added

func take_waiting_manifest(stop_id: String, available_seats: int) -> Array[String]:
	var boarded: Array[String] = []
	if not _stops.has(stop_id):
		return boarded
	var manifest: Array = _waiting_manifests.get(stop_id, [])
	var count := mini(manifest.size(), maxi(0, available_seats))
	for index in range(count):
		boarded.append(str(manifest.pop_front()))
	_waiting_manifests[stop_id] = manifest
	_waiting_passengers[stop_id] = manifest.size()
	_total_boardings += boarded.size()
	return boarded

func board_waiting_passengers(stop_id: String, available_seats: int) -> int:
	if not _stops.has(stop_id):
		return 0
	var manifest := take_waiting_manifest(stop_id, available_seats)
	return manifest.size()

func get_waiting_passengers(stop_id: String) -> int:
	return int(_waiting_manifests.get(stop_id, []).size())

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
