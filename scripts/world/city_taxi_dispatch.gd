extends Node
## City taxi dispatch: nearest-car assignment, pickup, fare and trip accounting.
var _taxis: Dictionary = {}
var _requests: Dictionary = {}
var _next_request_id := 1
var _completed_trips := 0
var _cancelled_trips := 0
var _total_fares := 0.0

func register_taxi(taxi_id: String, vehicle: Node3D) -> bool:
	if taxi_id.is_empty() or not is_instance_valid(vehicle):
		return false
	_taxis[taxi_id] = {"id": taxi_id, "vehicle": vehicle, "available": true, "active_request": ""}
	return true

func unregister_taxi(taxi_id: String) -> void:
	_taxis.erase(taxi_id)

func request_taxi(passenger_id: String, pickup: Vector3, destination: Vector3) -> Dictionary:
	if passenger_id.is_empty() or pickup.distance_to(destination) < 5.0:
		return {}
	for request in _requests.values():
		if str(request.get("passenger_id", "")) == passenger_id and str(request.get("status", "")) in ["dispatched", "picked_up"]:
			return request.duplicate(true)
	var taxi_id := ""
	var best_distance := INF
	for candidate_id in _taxis:
		var taxi: Dictionary = _taxis[candidate_id]
		var vehicle: Node3D = taxi.get("vehicle")
		if not bool(taxi.get("available", false)) or not is_instance_valid(vehicle):
			continue
		var distance := vehicle.global_position.distance_to(pickup)
		if distance < best_distance:
			best_distance = distance
			taxi_id = str(candidate_id)
	if taxi_id.is_empty():
		return {"accepted": false, "reason": "no_taxi_available"}
	var request_id := "taxi_request_" + str(_next_request_id)
	_next_request_id += 1
	var distance_km := pickup.distance_to(destination) / 1000.0
	var fare := snappedf(2.5 + distance_km * 1.35, 0.1)
	var request := {"id": request_id, "passenger_id": passenger_id, "taxi_id": taxi_id, "pickup": pickup, "destination": destination, "status": "dispatched", "fare": fare, "pickup_distance": best_distance, "estimated_pickup_minutes": snappedf(best_distance / 180.0, 0.1), "created_at_msec": Time.get_ticks_msec()}
	_requests[request_id] = request
	var taxi_entry: Dictionary = _taxis[taxi_id]
	taxi_entry["available"] = false
	taxi_entry["active_request"] = request_id
	_taxis[taxi_id] = taxi_entry
	var vehicle: Node3D = taxi_entry["vehicle"]
	if vehicle.has_method("assign_trip"):
		vehicle.call("assign_trip", request_id, pickup, destination, self)
	return {"accepted": true, "request": request.duplicate(true)}

func report_pickup(request_id: String) -> void:
	if not _requests.has(request_id):
		return
	var request: Dictionary = _requests[request_id]
	request["status"] = "picked_up"
	_requests[request_id] = request
	var passenger := _find_passenger(str(request.get("passenger_id", "")))
	if passenger != null and passenger.has_method("begin_taxi_ride"):
		passenger.call("begin_taxi_ride", request_id)

func report_trip_complete(request_id: String) -> void:
	if not _requests.has(request_id):
		return
	var request: Dictionary = _requests[request_id]
	if str(request.get("status", "")) == "completed":
		return
	request["status"] = "completed"
	_requests[request_id] = request
	var passenger := _find_passenger(str(request.get("passenger_id", "")))
	if passenger != null and passenger.has_method("finish_taxi_ride"):
		passenger.call("finish_taxi_ride", request_id, request.get("destination", Vector3.ZERO))
	_completed_trips += 1
	_total_fares += float(request.get("fare", 0.0))
	var taxi_id := str(request.get("taxi_id", ""))
	if _taxis.has(taxi_id):
		var taxi: Dictionary = _taxis[taxi_id]
		taxi["available"] = true
		taxi["active_request"] = ""
		_taxis[taxi_id] = taxi

func report_trip_cancelled(request_id: String) -> void:
	if not _requests.has(request_id):
		return
	var request: Dictionary = _requests[request_id]
	request["status"] = "cancelled"
	_requests[request_id] = request
	_cancelled_trips += 1
	var taxi_id := str(request.get("taxi_id", ""))
	if _taxis.has(taxi_id):
		var taxi: Dictionary = _taxis[taxi_id]
		taxi["available"] = true
		taxi["active_request"] = ""
		_taxis[taxi_id] = taxi

func get_dispatch_snapshot() -> Dictionary:
	var available := 0
	for taxi in _taxis.values():
		if bool(taxi.get("available", false)):
			available += 1
	return {"fleet_size": _taxis.size(), "available_taxis": available, "active_requests": _requests.size() - _completed_trips - _cancelled_trips, "completed_trips": _completed_trips, "cancelled_trips": _cancelled_trips, "total_fares": snappedf(_total_fares, 0.01)}

func get_request_snapshot(request_id: String) -> Dictionary:
	if not _requests.has(request_id):
		return {}
	return _requests[request_id].duplicate(true)

func cancel_passenger_request(passenger_id: String) -> bool:
	for request_id in _requests:
		var request: Dictionary = _requests[request_id]
		if str(request.get("passenger_id", "")) != passenger_id:
			continue
		if str(request.get("status", "")) in ["completed", "cancelled"]:
			continue
		report_trip_cancelled(str(request_id))
		var taxi_id := str(request.get("taxi_id", ""))
		if _taxis.has(taxi_id):
			var taxi: Dictionary = _taxis[taxi_id]
			var vehicle: Node3D = taxi.get("vehicle")
			if is_instance_valid(vehicle) and vehicle.has_method("cancel_trip"):
				vehicle.call("cancel_trip")
		return true
	return false

func _find_passenger(passenger_id: String) -> Node:
	for citizen in get_tree().get_nodes_in_group("city_citizen"):
		if is_instance_valid(citizen) and str(citizen.get("citizen_id")) == passenger_id:
			return citizen
	return null
