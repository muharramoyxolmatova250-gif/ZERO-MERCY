extends Node3D
## Ambient electric vehicle following a closed road loop and obeying nearby signals.
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(2.0, 30.0, 0.5) var speed := 8.0
@export var vehicle_color := Color(0.02, 0.12, 0.2)
@export_range(2.0, 12.0, 0.5) var braking_distance := 7.0
@export_range(1.0, 8.0, 0.5) var acceleration := 3.0
@export_range(2.0, 14.0, 0.5) var following_distance := 6.5
var _target_index := 0
var _current_speed := 0.0
@export var traffic_segment_id := "city_loop"
var _traffic_manager: Node

func _ready() -> void:
    _build_vehicle()
    _current_speed = speed
    _traffic_manager = get_tree().get_first_node_in_group("road_traffic_manager")
    if _traffic_manager != null and _traffic_manager.has_method("register_segment"):
        _traffic_manager.call("register_segment", traffic_segment_id, speed, 18)
        _traffic_manager.call("report_vehicle", traffic_segment_id, str(get_instance_id()), true)
    if route.size() < 2:
        route = PackedVector3Array([Vector3(-30,0,-30), Vector3(30,0,-30), Vector3(30,0,30), Vector3(-30,0,30)])

func _process(delta: float) -> void:
    if route.size() < 2:
        return
    var target := route[_target_index]
    var direction := target - position
    direction.y = 0.0
    if direction.length() < 1.5:
        _target_index = (_target_index + 1) % route.size()
        return
    var desired_speed := speed if _has_green_path(direction) else 0.0
    desired_speed = minf(desired_speed, _safe_follow_speed(direction))
    if _traffic_manager != null and _traffic_manager.has_method("get_recommended_speed"):
        desired_speed = minf(desired_speed, float(_traffic_manager.call("get_recommended_speed", traffic_segment_id)))
    if direction.length() < braking_distance:
        desired_speed *= clampf(direction.length() / braking_distance, 0.15, 1.0)
    _current_speed = move_toward(_current_speed, desired_speed, acceleration * delta)
    position += direction.normalized() * _current_speed * delta
    if direction.length_squared() > 0.001:
        look_at(position + direction, Vector3.UP)

func _safe_follow_speed(direction: Vector3) -> float:
    var safe_speed := speed
    for group_name in ["city_traffic", "city_transit_vehicles"]:
        for other in get_tree().get_nodes_in_group(group_name):
            if other == self or not is_instance_valid(other):
                continue
            var offset: Vector3 = other.global_position - global_position
            offset.y = 0.0
            var distance := offset.length()
            if distance < following_distance and distance > 0.01:
                if direction.normalized().dot(offset.normalized()) > 0.72:
                    safe_speed = minf(safe_speed, speed * clampf((distance - 1.8) / maxf(1.0, following_distance - 1.8), 0.0, 1.0))
    return safe_speed


func _has_green_path(direction: Vector3) -> bool:
    var signals := get_tree().get_nodes_in_group("traffic_signals")
    for signal_node in signals:
        if not is_instance_valid(signal_node) or not signal_node.has_method("is_green_for"):
            continue
        var to_signal: Vector3 = signal_node.global_position - global_position
        to_signal.y = 0.0
        if to_signal.length() > braking_distance:
            continue
        if direction.normalized().dot(to_signal.normalized()) < 0.35:
            continue
        if not bool(signal_node.call("is_green_for", direction)):
            return false
    return true

func _build_vehicle() -> void:
    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(2.1, 0.75, 4.1)
    body.mesh = body_mesh
    body.position.y = 0.65
    var paint := StandardMaterial3D.new()
    paint.albedo_color = vehicle_color
    paint.metallic = 0.88
    paint.roughness = 0.2
    body.material_override = paint
    add_child(body)
    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(1.65, 0.65, 1.8)
    roof.mesh = roof_mesh
    roof.position = Vector3(0, 1.25, -0.2)
    roof.material_override = paint
    add_child(roof)
    for x in [-0.72, 0.72]:
        var lamp := MeshInstance3D.new()
        var lamp_mesh := BoxMesh.new()
        lamp_mesh.size = Vector3(0.32, 0.18, 0.08)
        lamp.mesh = lamp_mesh
        lamp.position = Vector3(x, 0.72, -2.08)
        var light := StandardMaterial3D.new()
        light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        light.albedo_color = Color(0.0, 0.8, 1.0)
        light.emission_enabled = true
        light.emission = Color(0.0, 0.8, 1.0)
        light.emission_energy_multiplier = 2.0
        lamp.material_override = light
        add_child(lamp)

 
func _exit_tree() -> void:
    if _traffic_manager != null and is_instance_valid(_traffic_manager) and _traffic_manager.has_method("report_vehicle"):
        _traffic_manager.call("report_vehicle", traffic_segment_id, str(get_instance_id()), false)
