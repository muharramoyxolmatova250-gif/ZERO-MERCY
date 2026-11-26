extends Node
## Floor-and-vertical-link graph used by building interiors.
var _links: Dictionary = {}

func register_floor(floor_index: int, local_position: Vector3) -> void:
	_links[floor_index] = {"position": local_position, "connections": []}

func connect_floors(from_floor: int, to_floor: int, connector: String = "stairs") -> bool:
	if not _links.has(from_floor) or not _links.has(to_floor) or from_floor == to_floor:
		return false
	var from_data: Dictionary = _links[from_floor]
	var to_data: Dictionary = _links[to_floor]
	var from_connections: Array = from_data.get("connections", [])
	var to_connections: Array = to_data.get("connections", [])
	if not _has_connection(from_connections, to_floor):
		from_connections.append({"floor": to_floor, "type": connector})
	if not _has_connection(to_connections, from_floor):
		to_connections.append({"floor": from_floor, "type": connector})
	from_data["connections"] = from_connections
	to_data["connections"] = to_connections
	_links[from_floor] = from_data
	_links[to_floor] = to_data
	return true

func find_floor_route(start_floor: int, destination_floor: int) -> Array[int]:
	if not _links.has(start_floor) or not _links.has(destination_floor):
		return []
	var queue: Array[int] = [start_floor]
	var previous: Dictionary = {start_floor: -1}
	var cursor := 0
	while cursor < queue.size():
		var floor_id := queue[cursor]
		cursor += 1
		if floor_id == destination_floor:
			break
		var data: Dictionary = _links[floor_id]
		for connection in data.get("connections", []):
			var next_floor := int(connection.get("floor", -1))
			if next_floor >= 0 and not previous.has(next_floor):
				previous[next_floor] = floor_id
				queue.append(next_floor)
	if not previous.has(destination_floor):
		return []
	var route: Array[int] = []
	var step := destination_floor
	while step >= 0:
		route.append(step)
		step = int(previous[step])
	route.reverse()
	return route

func _has_connection(connections: Array, floor_index: int) -> bool:
	for connection in connections:
		if int(connection.get("floor", -1)) == floor_index:
			return true
	return false

func get_floor_count() -> int:
	return _links.size()
