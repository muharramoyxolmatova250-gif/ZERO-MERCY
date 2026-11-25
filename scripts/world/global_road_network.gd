extends Node
class_name GlobalRoadNetwork
## Directed, weighted road graph for navigation across streamed world regions.
## Feed this graph from licensed OSM/road data or procedural road generation.
## Node IDs must be stable across region loads; positions use the game's world coordinate system.

signal graph_changed

var _positions: Dictionary = {} # StringName -> Vector3
var _edges: Dictionary = {} # StringName -> Array[Dictionary]

func clear_network() -> void:
    _positions.clear()
    _edges.clear()
    graph_changed.emit()

func add_road_node(node_id: StringName, world_position: Vector3) -> bool:
    if node_id == &"":
        push_warning("Road node ID cannot be empty.")
        return false
    _positions[node_id] = world_position
    if not _edges.has(node_id):
        _edges[node_id] = []
    graph_changed.emit()
    return true

func add_road_segment(
    from_id: StringName,
    to_id: StringName,
    from_position: Vector3,
    to_position: Vector3,
    bidirectional: bool = true,
    speed_limit_kph: float = 50.0
) -> bool:
    if from_id == &"" or to_id == &"" or from_id == to_id:
        push_warning("Road segment requires two distinct, non-empty node IDs.")
        return false
    if speed_limit_kph <= 0.0:
        push_warning("Road speed limit must be positive.")
        return false

    add_road_node(from_id, from_position)
    add_road_node(to_id, to_position)
    _add_edge(from_id, to_id, speed_limit_kph)
    if bidirectional:
        _add_edge(to_id, from_id, speed_limit_kph)
    graph_changed.emit()
    return true

func remove_road_node(node_id: StringName) -> void:
    _positions.erase(node_id)
    _edges.erase(node_id)
    for origin in _edges.keys():
        var filtered: Array[Dictionary] = []
        for edge in _edges[origin]:
            if edge["to"] != node_id:
                filtered.append(edge)
        _edges[origin] = filtered
    graph_changed.emit()

func has_road_node(node_id: StringName) -> bool:
    return _positions.has(node_id)

func get_road_node_position(node_id: StringName) -> Vector3:
    return _positions.get(node_id, Vector3.ZERO)

func find_nearest_node(world_position: Vector3, max_distance: float = INF) -> StringName:
    var best_id: StringName = &""
    var best_distance := max_distance
    for candidate in _positions.keys():
        var distance: float = world_position.distance_to(_positions[candidate])
        if distance < best_distance:
            best_distance = distance
            best_id = candidate
    return best_id

## Returns an ordered world-space path. Empty means no route was found.
## Uses Dijkstra with travel-time weights, so faster roads are preferred.
func find_route(start_id: StringName, goal_id: StringName) -> PackedVector3Array:
    var result := PackedVector3Array()
    if not _positions.has(start_id) or not _positions.has(goal_id):
        return result
    if start_id == goal_id:
        result.append(_positions[start_id])
        return result

    var costs: Dictionary = {start_id: 0.0}
    var previous: Dictionary = {}
    var unvisited: Dictionary = {start_id: true}
    var visited: Dictionary = {}

    while not unvisited.is_empty():
        var current: StringName = &""
        var current_cost := INF
        for candidate in unvisited.keys():
            var candidate_cost: float = costs.get(candidate, INF)
            if candidate_cost < current_cost:
                current_cost = candidate_cost
                current = candidate

        if current == &"":
            break
        if current == goal_id:
            break

        unvisited.erase(current)
        visited[current] = true

        for edge in _edges.get(current, []):
            var neighbor: StringName = edge["to"]
            if visited.has(neighbor):
                continue
            var distance: float = _positions[current].distance_to(_positions[neighbor])
            var speed_mps: float = maxf(1.0, float(edge["speed_limit_kph"]) / 3.6)
            var travel_time: float = distance / speed_mps
            var new_cost: float = current_cost + travel_time
            if new_cost < float(costs.get(neighbor, INF)):
                costs[neighbor] = new_cost
                previous[neighbor] = current
                unvisited[neighbor] = true

    if not costs.has(goal_id):
        return result

    var reversed_ids: Array[StringName] = [goal_id]
    var cursor: StringName = goal_id
    while cursor != start_id:
        if not previous.has(cursor):
            return PackedVector3Array()
        cursor = previous[cursor]
        reversed_ids.append(cursor)

    reversed_ids.reverse()
    for node_id in reversed_ids:
        result.append(_positions[node_id])
    return result

func get_route_length(route: PackedVector3Array) -> float:
    var total := 0.0
    for index in range(1, route.size()):
        total += route[index - 1].distance_to(route[index])
    return total

func _add_edge(from_id: StringName, to_id: StringName, speed_limit_kph: float) -> void:
    var outgoing: Array = _edges.get(from_id, [])
    for edge in outgoing:
        if edge["to"] == to_id:
            edge["speed_limit_kph"] = speed_limit_kph
            _edges[from_id] = outgoing
            return
    outgoing.append({"to": to_id, "speed_limit_kph": speed_limit_kph})
    _edges[from_id] = outgoing
