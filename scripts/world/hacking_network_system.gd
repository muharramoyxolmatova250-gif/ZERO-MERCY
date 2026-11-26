extends Node
## Registry of hackable terminals, locks, cameras and network nodes.
signal hack_completed(node_id: String, access_level: int)
var _nodes: Dictionary = {}

func register_node(node_id: String, security_level: int, data: Dictionary = {}) -> bool:
	if node_id.is_empty() or _nodes.has(node_id):
		return false
	_nodes[node_id] = {"security": clampi(security_level, 1, 10), "access": 0, "data": data.duplicate(true), "locked": true}
	return true

func attempt_hack(node_id: String, player_skill: int, tool_bonus: int = 0) -> bool:
	if not _nodes.has(node_id):
		return false
	var node: Dictionary = _nodes[node_id]
	var score := maxi(0, player_skill + tool_bonus)
	if score < int(node["security"]):
		return false
	node["access"] = 1
	node["locked"] = false
	_nodes[node_id] = node
	hack_completed.emit(node_id, int(node["access"]))
	return true

func set_access_level(node_id: String, level: int) -> void:
	if not _nodes.has(node_id):
		return
	var node: Dictionary = _nodes[node_id]
	node["access"] = clampi(level, 0, 3)
	node["locked"] = int(node["access"]) == 0
	_nodes[node_id] = node

func has_access(node_id: String, required_level: int = 1) -> bool:
	return _nodes.has(node_id) and int(_nodes[node_id]["access"]) >= required_level

func get_node_snapshot(node_id: String) -> Dictionary:
	return _nodes.get(node_id, {}).duplicate(true)
