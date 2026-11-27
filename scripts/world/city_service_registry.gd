extends Node
## Registry for hospitals, police, repair shops, transit stops and other services.
var _services: Dictionary = {}
var _next_service_id := 1

func register_service(service_type: String, world_position: Vector3, capacity: int = 1, metadata: Dictionary = {}) -> String:
	if service_type.is_empty():
		return ""
	var service_id := "service_" + str(_next_service_id)
	_next_service_id += 1
	_services[service_id] = {"id": service_id, "type": service_type, "position": world_position, "capacity": maxi(1, capacity), "load": 0, "active": true, "metadata": metadata.duplicate(true), "completed_visits": 0}
	return service_id

func unregister_service(service_id: String) -> void:
	_services.erase(service_id)

func set_service_active(service_id: String, active: bool) -> void:
	if _services.has(service_id):
		var service: Dictionary = _services[service_id]
		service["active"] = active
		_services[service_id] = service

func find_nearest_service(service_type: String, from_position: Vector3, max_distance: float = INF) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := max_distance
	for service_id in _services:
		var service: Dictionary = _services[service_id]
		if not bool(service.get("active", false)) or str(service.get("type", "")) != service_type:
			continue
		if int(service.get("load", 0)) >= int(service.get("capacity", 1)):
			continue
		var distance: float = from_position.distance_to(service["position"])
		var utilization := float(service.get("load", 0)) / float(maxi(1, int(service.get("capacity", 1))))
		var score := distance * (1.0 + utilization * 0.65)
		if score < best_distance:
			best_distance = score
			best = service.duplicate(true)
			best["distance"] = distance
			best["selection_score"] = score
	return best

func get_service_snapshot() -> Dictionary:
	var counts: Dictionary = {}
	for service in _services.values():
		var service_type := str(service.get("type", "unknown"))
		counts[service_type] = int(counts.get(service_type, 0)) + 1
	return {"total": _services.size(), "by_type": counts}

 
func reserve_service(service_id: String) -> bool:
	if not _services.has(service_id):
		return false
	var service: Dictionary = _services[service_id]
	if not bool(service.get("active", false)) or int(service.get("load", 0)) >= int(service.get("capacity", 1)):
		return false
	service["load"] = int(service.get("load", 0)) + 1
	_services[service_id] = service
	return true

func release_service(service_id: String, completed: bool = true) -> void:
	if not _services.has(service_id):
		return
	var service: Dictionary = _services[service_id]
	service["load"] = maxi(0, int(service.get("load", 0)) - 1)
	if completed:
		service["completed_visits"] = int(service.get("completed_visits", 0)) + 1
	_services[service_id] = service

func get_service_details(service_id: String) -> Dictionary:
	if not _services.has(service_id):
		return {}
	return _services[service_id].duplicate(true)
