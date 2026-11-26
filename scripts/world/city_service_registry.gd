extends Node
## Registry for hospitals, police, repair shops, transit stops and other services.
var _services: Dictionary = {}
var _next_service_id := 1

func register_service(service_type: String, world_position: Vector3, capacity: int = 1, metadata: Dictionary = {}) -> String:
	if service_type.is_empty():
		return ""
	var service_id := "service_" + str(_next_service_id)
	_next_service_id += 1
	_services[service_id] = {"id": service_id, "type": service_type, "position": world_position, "capacity": maxi(1, capacity), "load": 0, "active": true, "metadata": metadata.duplicate(true)}
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
		var distance: float = from_position.distance_to(service["position"])
		if distance < best_distance:
			best_distance = distance
			best = service.duplicate(true)
			best["distance"] = distance
	return best

func get_service_snapshot() -> Dictionary:
	var counts: Dictionary = {}
	for service in _services.values():
		var service_type := str(service.get("type", "unknown"))
		counts[service_type] = int(counts.get(service_type, 0)) + 1
	return {"total": _services.size(), "by_type": counts}
