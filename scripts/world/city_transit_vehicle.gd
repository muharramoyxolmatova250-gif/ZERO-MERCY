extends Node3D
class_name CityTransitVehicle
## Autonomous city bus that follows a stop loop, obeys traffic signals and dwells for boarding.
signal stop_reached(stop_index: int)
signal route_loop_completed
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(3.0, 18.0, 0.5) var cruise_speed := 9.0
@export_range(2.0, 12.0, 0.5) var braking_distance := 8.0
@export_range(2.0, 12.0, 0.5) var dwell_seconds := 5.0
@export var bus_color := Color(0.02, 0.18, 0.24)
@export_range(8, 80, 1) var passenger_capacity := 32
var passenger_count := 0
var passenger_destinations: Array[String] = []
var total_alighted := 0
var completed_stops := 0
var _target_index := 0
var _current_speed := 0.0
var _dwell_remaining := 0.0
var _door_open := false
var _door_mesh: MeshInstance3D
var route_id := ""
var stop_ids: Array[String] = []
var transit_network: Node
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    add_to_group("city_transit_vehicles")
    _rng.randomize()
    _build_bus()
    if transit_network != null and not route_id.is_empty() and transit_network.has_method("report_vehicle_active"):
        transit_network.call("report_vehicle_active", route_id, true)
    if route.size() >= 2:
        _target_index = 1
        global_position = route[0]
    _current_speed = cruise_speed

func _physics_process(delta: float) -> void:
    if route.size() < 2:
        return
    if _dwell_remaining > 0.0:
        _dwell_remaining = maxf(0.0, _dwell_remaining - delta)
        _current_speed = move_toward(_current_speed, 0.0, 8.0 * delta)
        if _dwell_remaining <= 0.0:
            _door_open = false
            if _door_mesh != null:
                _door_mesh.visible = false
        return
    var target := route[_target_index]
    var offset := target - global_position
    offset.y = 0.0
    var distance := offset.length()
    if distance <= 2.4:
        _arrive_at_stop()
        return
    var direction := offset / maxf(distance, 0.001)
    var desired_speed := cruise_speed
    if distance < braking_distance:
        desired_speed *= clampf(distance / braking_distance, 0.18, 1.0)
    if not _has_green_path(direction):
        desired_speed = 0.0
    desired_speed = minf(desired_speed, _safe_follow_speed())
    _current_speed = move_toward(_current_speed, desired_speed, 3.2 * delta)
    global_position += direction * _current_speed * delta
    if direction.length_squared() > 0.001:
        look_at(global_position + direction, Vector3.UP)

func _arrive_at_stop() -> void:
    global_position = route[_target_index]
    _current_speed = 0.0
    _door_open = true
    var stop_id := stop_ids[_target_index] if _target_index < stop_ids.size() else ""
    var alighted := _rng.randi_range(0, mini(passenger_count, maxi(1, int(round(float(passenger_count) * 0.22))))) if passenger_count > 0 else 0
    passenger_count -= alighted
    var boarded := 0
    if transit_network != null and not stop_id.is_empty() and transit_network.has_method("board_waiting_passengers"):
        boarded = int(transit_network.call("board_waiting_passengers", stop_id, passenger_capacity - passenger_count))
        passenger_count += boarded
        if transit_network.has_method("report_vehicle_stop"):
            transit_network.call("report_vehicle_stop", route_id, stop_id, boarded)
    if _door_mesh != null:
        _door_mesh.visible = true
    _dwell_remaining = dwell_seconds
    completed_stops += 1
    stop_reached.emit(_target_index)
    _target_index += 1
    if _target_index >= route.size():
        _target_index = 0
        route_loop_completed.emit()

func _has_green_path(direction: Vector3) -> bool:
    for signal_node in get_tree().get_nodes_in_group("traffic_signals"):
        if not is_instance_valid(signal_node) or not signal_node.has_method("is_green_for"):
            continue
        var to_signal: Vector3 = signal_node.global_position - global_position
        to_signal.y = 0.0
        if to_signal.length() > braking_distance or to_signal.length_squared() < 0.01:
            continue
        if direction.dot(to_signal.normalized()) > 0.55 and not bool(signal_node.call("is_green_for", direction)):
            return false
    return true

func _safe_follow_speed() -> float:
    var safe_speed := cruise_speed
    for group_name in ["city_traffic", "city_transit_vehicles"]:
        for other in get_tree().get_nodes_in_group(group_name):
            if other == self or not is_instance_valid(other):
                continue
            var offset: Vector3 = other.global_position - global_position
            offset.y = 0.0
            var distance := offset.length()
            if distance < 5.5 and distance > 0.01:
                var ahead := global_transform.basis.z.dot(offset.normalized())
                if ahead < -0.25:
                    safe_speed = minf(safe_speed, cruise_speed * clampf(distance / 5.5, 0.0, 1.0))
    return safe_speed

func set_passenger_count(value: int) -> void:
    passenger_count = clampi(value, 0, passenger_capacity)
	passenger_destinations.clear()
	for index in range(passenger_count):
		passenger_destinations.append("")

func get_vehicle_snapshot() -> Dictionary:
    return {"passengers": passenger_count, "capacity": passenger_capacity, "alighted_total": total_alighted, "completed_stops": completed_stops, "speed": _current_speed, "dwelling": _dwell_remaining > 0.0, "doors_open": _door_open, "route_id": route_id}

func _build_bus() -> void:
    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(2.5, 2.6, 8.2)
    body.mesh = body_mesh
    body.position.y = 1.55
    var paint := StandardMaterial3D.new()
    paint.albedo_color = bus_color
    paint.metallic = 0.68
    paint.roughness = 0.24
    body.material_override = paint
    add_child(body)
    var windows := MeshInstance3D.new()
    var window_mesh := BoxMesh.new()
    window_mesh.size = Vector3(2.54, 0.9, 6.7)
    windows.mesh = window_mesh
    windows.position.y = 2.2
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color(0.015, 0.12, 0.19, 0.82)
    glass.metallic = 0.82
    glass.roughness = 0.12
    windows.material_override = glass
    add_child(windows)
    _door_mesh = MeshInstance3D.new()
    var door_mesh := BoxMesh.new()
    door_mesh.size = Vector3(0.08, 1.75, 1.0)
    _door_mesh.mesh = door_mesh
    _door_mesh.position = Vector3(1.29, 1.55, 1.7)
    _door_mesh.visible = false
    var door_mat := StandardMaterial3D.new()
    door_mat.albedo_color = Color(0.0, 0.85, 0.95)
    door_mat.emission_enabled = true
    door_mat.emission = Color(0.0, 0.65, 0.9)
    _door_mesh.material_override = door_mat
    add_child(_door_mesh)

func _exit_tree() -> void:
    if transit_network != null and not route_id.is_empty() and transit_network.has_method("report_vehicle_active"):
        transit_network.call("report_vehicle_active", route_id, false)
