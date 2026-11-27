extends Node
## Coordinates city emergency calls, responder assignment and incident lifecycle.
signal incident_created(incident_id: String, payload: Dictionary)
signal responder_assigned(incident_id: String, responder_id: String)
signal incident_resolved(incident_id: String)
var _responders: Dictionary = {}
var _incidents: Dictionary = {}
var _next_incident := 1

func _ready() -> void:
	add_to_group("emergency_dispatch_ai")

func register_responder(responder_id: String, service_type: String, node: Node3D, response_speed: float = 1.0) -> bool:
	if responder_id.is_empty() or service_type.is_empty() or not is_instance_valid(node):
		return false
	_responders[responder_id] = {"id": responder_id, "type": service_type, "node": node, "available": true, "speed": clampf(response_speed, 0.25, 3.0), "calls": 0}
	_retry_waiting_incidents()
	return true

func unregister_responder(responder_id: String) -> void:
	_responders.erase(responder_id)

func report_incident(kind: String, position: Vector3, severity: float = 0.5, reporter_id: String = "", details: Dictionary = {}) -> Dictionary:
	if kind.is_empty():
		return {}
	for existing_id in _incidents:
		var existing: Dictionary = _incidents[existing_id]
		if str(existing.get("status", "")) != "resolved" and str(existing.get("kind", "")) == kind and existing.position.distance_to(position) < 35.0:
			existing["severity"] = maxf(float(existing.get("severity", 0.0)), clampf(severity, 0.0, 1.0))
			var witnesses: Array = existing.get("witnesses", [])
			if not reporter_id.is_empty() and not witnesses.has(reporter_id):
				witnesses.append(reporter_id)
			existing["witnesses"] = witnesses
			_incidents[existing_id] = existing
			return existing.duplicate(true)
	var incident_id := "city_incident_" + str(_next_incident)
	_next_incident += 1
	var incident := {"id": incident_id, "kind": kind, "position": position, "severity": clampf(severity, 0.0, 1.0), "reporter_id": reporter_id, "details": details.duplicate(true), "status": "reported", "created_msec": Time.get_ticks_msec(), "assigned": [], "witnesses": [reporter_id] if not reporter_id.is_empty() else []}
	_incidents[incident_id] = incident
	incident_created.emit(incident_id, incident.duplicate(true))
	_dispatch_for_incident(incident_id)
	return incident.duplicate(true)

func _dispatch_for_incident(incident_id: String) -> void:
	if not _incidents.has(incident_id):
		return
	var incident: Dictionary = _incidents[incident_id]
	var requested_types: Array[String] = _required_services(str(incident.get("kind", "")), float(incident.get("severity", 0.5)))
	var assigned: Array = []
	for service_type in requested_types:
		var responder_id := _find_best_responder(service_type, incident.position)
		if responder_id.is_empty():
			continue
		var responder: Dictionary = _responders[responder_id]
		responder["available"] = false
		responder["calls"] = int(responder.get("calls", 0)) + 1
		_responders[responder_id] = responder
		assigned.append(responder_id)
		var node: Node3D = responder.get("node")
		if is_instance_valid(node) and node.has_method("respond_to_incident"):
			node.call("respond_to_incident", incident_id, incident.position, float(incident.get("severity", 0.5)))
		responder_assigned.emit(incident_id, responder_id)
	incident["assigned"] = assigned
	incident["status"] = "dispatched" if not assigned.is_empty() else "awaiting_units"
	_incidents[incident_id] = incident

func _required_services(kind: String, severity: float) -> Array[String]:
	var result: Array[String] = []
	match kind:
		"crime", "assault", "robbery", "weapon":
			result.append("police")
			if severity >= 0.65:
				result.append("medical")
		"fire":
			result.append("fire")
			if severity >= 0.55:
				result.append("medical")
		"medical", "injury", "collapse":
			result.append("medical")
		"traffic_collision":
			result.append("police")
			result.append("medical")
			if severity >= 0.7:
				result.append("fire")
		"road_block":
			result.append("road_service")
	return result

func _find_best_responder(service_type: String, target: Vector3) -> String:
	var best_id := ""
	var best_cost := INF
	for responder_id in _responders:
		var responder: Dictionary = _responders[responder_id]
		var node: Node3D = responder.get("node")
		if not bool(responder.get("available", false)) or str(responder.get("type", "")) != service_type or not is_instance_valid(node):
			continue
		var distance := node.global_position.distance_to(target)
		var cost := distance / maxf(0.25, float(responder.get("speed", 1.0)))
		if cost < best_cost:
			best_cost = cost
			best_id = str(responder_id)
	return best_id

func release_responder(responder_id: String, incident_id: String) -> void:
	if not _responders.has(responder_id):
		return
	var responder: Dictionary = _responders[responder_id]
	responder["available"] = true
	_responders[responder_id] = responder
	if _incidents.has(incident_id):
		var incident: Dictionary = _incidents[incident_id]
		var assigned: Array = incident.get("assigned", [])
		assigned.erase(responder_id)
		incident["assigned"] = assigned
		if assigned.is_empty() and str(incident.get("status", "")) != "resolved":
			incident["status"] = "awaiting_units"
		_incidents[incident_id] = incident

func resolve_incident(incident_id: String) -> bool:
	if not _incidents.has(incident_id):
		return false
	var incident: Dictionary = _incidents[incident_id]
	for responder_id in incident.get("assigned", []):
		if _responders.has(str(responder_id)):
			var responder: Dictionary = _responders[str(responder_id)]
			responder["available"] = true
			_responders[str(responder_id)] = responder
	incident["assigned"] = []
	incident["status"] = "resolved"
	incident["resolved_msec"] = Time.get_ticks_msec()
	_incidents[incident_id] = incident
	incident_resolved.emit(incident_id)
	return true

func get_incident(incident_id: String) -> Dictionary:
	return _incidents.get(incident_id, {}).duplicate(true)

func get_dispatch_snapshot() -> Dictionary:
	var available := 0
	for responder in _responders.values():
		if bool(responder.get("available", false)):
			available += 1
	return {"responders": _responders.size(), "available": available, "incidents": _incidents.size(), "active_incidents": _count_active_incidents()}

func _count_active_incidents() -> int:
	var count := 0
	for incident in _incidents.values():
		if str(incident.get("status", "")) != "resolved":
			count += 1
	return count

 
func _retry_waiting_incidents() -> void:
	var waiting: Array[String] = []
	for incident_id in _incidents:
		if str(_incidents[incident_id].get("status", "")) == "awaiting_units":
			waiting.append(str(incident_id))
	waiting.sort_custom(func(a: String, b: String) -> bool:
		return _incident_priority(_incidents[a]) > _incident_priority(_incidents[b])
	)
	for incident_id in waiting:
		_dispatch_for_incident(incident_id)

func _incident_priority(incident: Dictionary) -> float:
	var age := float(Time.get_ticks_msec() - int(incident.get("created_msec", 0))) / 1000.0
	return float(incident.get("severity", 0.0)) * 100.0 + minf(age, 120.0) * 0.15

func get_priority_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	for incident_id in _incidents:
		var incident: Dictionary = _incidents[incident_id]
		if str(incident.get("status", "")) == "resolved":
			continue
		var item := incident.duplicate(true)
		item["priority_score"] = _incident_priority(incident)
		queue.append(item)
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("priority_score", 0.0)) > float(b.get("priority_score", 0.0))
	)
	return queue
