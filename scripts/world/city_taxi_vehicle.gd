extends Node3D
class_name CityTaxiVehicle
## Autonomous dispatch taxi: drives to pickup, waits, then completes the passenger trip.
@export_range(5.0, 22.0, 0.5) var cruise_speed := 12.0
@export var taxi_color := Color(0.92, 0.68, 0.08)
var taxi_id := ""
var dispatch_service: Node
var _request_id := ""
var _pickup := Vector3.ZERO
var _destination := Vector3.ZERO
var _phase := "idle"
var _speed := 0.0
var _wait_timer := 0.0

func _ready() -> void:
	add_to_group("city_taxis")
	_build_taxi()
	_speed = cruise_speed
	if dispatch_service != null and not taxi_id.is_empty():
		dispatch_service.call("register_taxi", taxi_id, self)

func assign_trip(request_id: String, pickup: Vector3, destination: Vector3, service: Node) -> void:
	_request_id = request_id
	_pickup = pickup
	_destination = destination
	dispatch_service = service
	_phase = "to_pickup"
	_wait_timer = 0.0

func _physics_process(delta: float) -> void:
	if _phase == "idle":
		_speed = move_toward(_speed, 0.0, 5.0 * delta)
		return
	if _phase == "waiting":
		_wait_timer = maxf(0.0, _wait_timer - delta)
		if _wait_timer <= 0.0:
			_phase = "to_destination"
		return
	var target := _pickup if _phase == "to_pickup" else _destination
	var offset := target - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 2.5:
		_speed = 0.0
		if _phase == "to_pickup":
			_phase = "waiting"
			_wait_timer = 1.8
			if dispatch_service != null:
				dispatch_service.call("report_pickup", _request_id)
		else:
			if dispatch_service != null:
				dispatch_service.call("report_trip_complete", _request_id)
			_phase = "idle"
			_request_id = ""
		return
	var direction := offset / maxf(distance, 0.001)
	var desired := cruise_speed * clampf(distance / 10.0, 0.25, 1.0)
	if not _has_green_path(direction):
		desired = 0.0
	desired = minf(desired, _safe_follow_speed(direction))
	_speed = move_toward(_speed, desired, 4.0 * delta)
	global_position += direction * _speed * delta
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _has_green_path(direction: Vector3) -> bool:
	for signal_node in get_tree().get_nodes_in_group("traffic_signals"):
		if not is_instance_valid(signal_node) or not signal_node.has_method("is_green_for"):
			continue
		var offset: Vector3 = signal_node.global_position - global_position
		offset.y = 0.0
		if offset.length() <= 8.0 and offset.length_squared() > 0.01 and direction.dot(offset.normalized()) > 0.55:
			if not bool(signal_node.call("is_green_for", direction)):
				return false
	return true

func _safe_follow_speed(direction: Vector3) -> float:
	var safe_speed := cruise_speed
	for group_name in ["city_traffic", "city_transit_vehicles", "city_taxis"]:
		for other in get_tree().get_nodes_in_group(group_name):
			if other == self or not is_instance_valid(other):
				continue
			var offset: Vector3 = other.global_position - global_position
			offset.y = 0.0
			var distance := offset.length()
			if distance < 5.5 and distance > 0.01 and direction.dot(offset.normalized()) > 0.7:
				safe_speed = minf(safe_speed, cruise_speed * clampf((distance - 1.5) / 4.0, 0.0, 1.0))
	return safe_speed

func get_taxi_snapshot() -> Dictionary:
	return {"id": taxi_id, "phase": _phase, "request_id": _request_id, "speed": _speed, "available": _phase == "idle"}

func _build_taxi() -> void:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.72, 4.0)
	body.mesh = mesh
	body.position.y = 0.68
	var paint := StandardMaterial3D.new()
	paint.albedo_color = taxi_color
	paint.metallic = 0.72
	paint.roughness = 0.23
	body.material_override = paint
	add_child(body)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.35, 0.28, 1.45)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 1.18, 0.0)
	roof.material_override = paint
	add_child(roof)
	var sign := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(0.65, 0.18, 0.28)
	sign.mesh = sign_mesh
	sign.position = Vector3(0.0, 1.42, 0.0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.82, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.65, 0.05)
	sign.material_override = glow
	add_child(sign)

func _exit_tree() -> void:
	if dispatch_service != null and not taxi_id.is_empty():
		dispatch_service.call("unregister_taxi", taxi_id)
