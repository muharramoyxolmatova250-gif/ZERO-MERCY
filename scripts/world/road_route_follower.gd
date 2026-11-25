extends Node3D
class_name RoadRouteFollower
## Lightweight route follower for cars, buses, taxis and service vehicles.
## Assign a PackedVector3Array from GlobalRoadNetwork.find_route().
signal route_completed
signal route_blocked

@export_range(1.0, 40.0, 0.5) var cruise_speed := 12.0
@export_range(0.5, 8.0, 0.1) var waypoint_radius := 2.0
@export_range(1.0, 10.0, 0.5) var acceleration := 4.0
@export var rotate_to_direction := true

var route: PackedVector3Array = PackedVector3Array()
var _target_index := 0
var _current_speed := 0.0
var _active := false

func set_route(new_route: PackedVector3Array) -> bool:
    if new_route.size() < 2:
        clear_route()
        route_blocked.emit()
        return false
    route = new_route.duplicate()
    _target_index = 1
    _current_speed = 0.0
    _active = true
    return true

func clear_route() -> void:
    route.clear()
    _target_index = 0
    _current_speed = 0.0
    _active = false

func _physics_process(delta: float) -> void:
    if not _active:
        return
    if _target_index >= route.size():
        _finish_route()
        return

    var target := route[_target_index]
    var offset := target - global_position
    offset.y = 0.0
    if offset.length() <= waypoint_radius:
        _target_index += 1
        if _target_index >= route.size():
            _finish_route()
        return

    _current_speed = move_toward(_current_speed, cruise_speed, acceleration * delta)
    var direction := offset.normalized()
    global_position += direction * _current_speed * delta
    if rotate_to_direction and direction.length_squared() > 0.001:
        look_at(global_position + direction, Vector3.UP)

func _finish_route() -> void:
    _active = false
    _current_speed = 0.0
    route_completed.emit()
