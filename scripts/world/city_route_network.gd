extends Node
## Walkable sidewalk graph for the procedural district.
## Routes are returned in the parent settlement's local coordinates.
var _points: Array[Vector3] = []
var _adjacency: Array[Array] = []
var _destinations: Dictionary = {}

func _ready() -> void:
	add_to_group("pedestrian_route_network")

func build_grid(blocks_per_side: int, spacing: float, road_width: float) -> void:
	_points.clear()
	_adjacency.clear()
	_destinations.clear()
	var side_offset := road_width * 0.5 + 1.8
	var first := -float(blocks_per_side) * spacing * 0.5
	var grid_size := blocks_per_side + 1
	for x in range(grid_size):
		for z in range(grid_size):
			var base := Vector3(first + float(x) * spacing, 0.0, first + float(z) * spacing)
			var node_id := _add_point(base + Vector3(-side_offset, 0.0, -side_offset))
			if x > 0:
				_connect(node_id, node_id - grid_size * 2)
			if z > 0:
				_connect(node_id, node_id - 2)
			var opposite := _add_point(base + Vector3(side_offset, 0.0, side_offset))
			if x > 0:
				_connect(opposite, opposite - grid_size * 2)
			if z > 0:
				_connect(opposite, opposite - 2)
	var categories := ["home", "work", "food", "school", "play", "leisure", "family", "explore", "commute", "rest"]
	for category in categories:
		var pool: Array[int] = []
		for index in range(_points.size()):
			if _is_category_node(index, str(category)):
				pool.append(index)
		if pool.is_empty():
			for index in range(_points.size()):
				pool.append(index)
		_destinations[category] = pool

func register_destination(category: String, position: Vector3) -> void:
	if _points.is_empty():
		return
	var node_id := _nearest_point(position)
	var pool: Array = _destinations.get(category, [])
	if pool.is_empty():
		pool = []
		_destinations[category] = pool
	if not pool.has(node_id):
		pool.append(node_id)
	_destinations[category] = pool

func request_activity_route(start_world: Vector3, activity: String, citizen_id: String) -> PackedVector3Array:
	if _points.is_empty():
		return PackedVector3Array()
	var start_id := _nearest_point(start_world)
	var pool: Array = _destinations.get(_activity_category(activity), [])
	if pool.is_empty():
		return PackedVector3Array()
	var seed := absi(hash(citizen_id + ":" + activity))
	var goal_id := int(pool[seed % pool.size()])
	if goal_id == start_id and pool.size() > 1:
		goal_id = int(pool[(seed + 1) % pool.size()])
	var path_ids := _find_path(start_id, goal_id)
	var result := PackedVector3Array()
	for point_id in path_ids:
		result.append(_points[int(point_id)])
	return result

func get_network_snapshot() -> Dictionary:
	return {"nodes": _points.size(), "edges": _count_edges(), "destination_categories": _destinations.size()}

func _add_point(point: Vector3) -> int:
	var index := _points.size()
	_points.append(point)
	_adjacency.append([])
	return index

func _connect(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= _adjacency.size() or b >= _adjacency.size():
		return
	if not _adjacency[a].has(b):
		_adjacency[a].append(b)
	if not _adjacency[b].has(a):
		_adjacency[b].append(a)

func _nearest_point(position: Vector3) -> int:
	var best_id := 0
	var best_distance := INF
	for index in range(_points.size()):
		var distance := _points[index].distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_id = index
	return best_id

func _find_path(start_id: int, goal_id: int) -> Array[int]:
	var frontier: Array[int] = [start_id]
	var came_from: Dictionary = {start_id: -1}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal_id:
			break
		for neighbor in _adjacency[current]:
			if came_from.has(neighbor):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)
	if not came_from.has(goal_id):
		return [start_id]
	var reversed_path: Array[int] = []
	var step := goal_id
	while step >= 0:
		reversed_path.append(step)
		step = int(came_from[step])
	reversed_path.reverse()
	return reversed_path

func _activity_category(activity: String) -> String:
	match activity:
		"work": return "work"
		"food": return "food"
		"school": return "school"
		"play": return "play"
		"leisure", "social": return "leisure"
		"family", "rest", "avoid_crowd": return "home"
		"commute": return "work"
		_: return "explore"

func _is_category_node(index: int, category: String) -> bool:
	var point := _points[index]
	var hash_value := absi(hash(str(roundi(point.x)) + ":" + str(roundi(point.z))))
	match category:
		"home": return hash_value % 5 == 0
		"work": return hash_value % 5 == 1
		"food": return hash_value % 5 == 2
		"school": return hash_value % 5 == 3
		"play", "leisure", "family": return hash_value % 5 == 4
		_: return true

func _count_edges() -> int:
	var total := 0
	for links in _adjacency:
		total += links.size()
	return int(total / 2)
