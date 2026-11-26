extends Node
## Central lookup for interactable world objects and contextual actions.
var _objects: Dictionary = {}

func register_object(object_id: String, world_position: Vector3, actions: Array[String], metadata: Dictionary = {}) -> bool:
	if object_id.is_empty() or actions.is_empty():
		return false
	_objects[object_id] = {"id": object_id, "position": world_position, "actions": actions.duplicate(), "metadata": metadata.duplicate(true), "enabled": true}
	return true

func unregister_object(object_id: String) -> void:
	_objects.erase(object_id)

func set_enabled(object_id: String, enabled: bool) -> void:
	if _objects.has(object_id):
		var item: Dictionary = _objects[object_id]
		item["enabled"] = enabled
		_objects[object_id] = item

func find_nearest_interactable(world_position: Vector3, max_distance: float = 3.0) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := max_distance
	for object_id in _objects:
		var item: Dictionary = _objects[object_id]
		if not bool(item.get("enabled", true)):
			continue
		var distance: float = world_position.distance_to(item["position"])
		if distance <= best_distance:
			best_distance = distance
			best = item.duplicate(true)
			best["distance"] = distance
	return best

func get_available_actions(object_id: String) -> Array[String]:
	if not _objects.has(object_id) or not bool(_objects[object_id].get("enabled", true)):
		return []
	var actions: Array[String] = []
	for action in _objects[object_id].get("actions", []):
		actions.append(str(action))
	return actions

func get_registry_snapshot() -> Dictionary:
	var enabled_count := 0
	for item in _objects.values():
		if bool(item.get("enabled", true)):
			enabled_count += 1
	return {"registered_objects": _objects.size(), "enabled_objects": enabled_count}
