extends Node3D
## Simple autonomous response vehicle that travels to a dispatched incident.
@export var responder_id := "unit_01"
@export var service_type := "police"
@export var response_speed := 15.0
var _dispatch: Node
var _incident_id := ""
var _target := Vector3.ZERO
var _active := false
var _arrival_timer := 0.0

func _ready() -> void:
	add_to_group("emergency_response_units")
	_build_vehicle()
	_dispatch = get_tree().get_first_node_in_group("emergency_dispatch_ai")
	if _dispatch != null:
		_dispatch.call("register_responder", responder_id, service_type, self, 1.0)

func respond_to_incident(incident_id: String, target: Vector3, severity: float) -> void:
	_incident_id = incident_id
	_target = target
	_active = true
	_arrival_timer = 0.0
	visible = true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	var offset := _target - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 2.5:
		var direction := offset.normalized()
		global_position += direction * response_speed * delta
		look_at(global_position + direction, Vector3.UP)
		return
	_arrival_timer += delta
	if _arrival_timer >= 4.0:
		_active = false
		visible = false
		if _dispatch != null and _dispatch.has_method("release_responder"):
			_dispatch.call("release_responder", responder_id, _incident_id)
		_incident_id = ""

func get_unit_snapshot() -> Dictionary:
	return {"id": responder_id, "service": service_type, "active": _active, "incident": _incident_id, "position": global_position}

func _build_vehicle() -> void:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.8, 4.0)
	body.mesh = mesh
	body.position.y = 0.65
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.055, 0.09) if service_type == "police" else (Color(0.72, 0.08, 0.04) if service_type == "fire" else Color(0.88, 0.88, 0.82))
	material.metallic = 0.65
	body.material_override = material
	add_child(body)
	var light := MeshInstance3D.new()
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(1.0, 0.18, 0.3)
	light.mesh = light_mesh
	light.position.y = 1.15
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.0, 0.55, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.0, 0.3, 1.0)
	light.material_override = glow
	add_child(light)

func _exit_tree() -> void:
	if _dispatch != null and is_instance_valid(_dispatch):
		_dispatch.call("unregister_responder", responder_id)
