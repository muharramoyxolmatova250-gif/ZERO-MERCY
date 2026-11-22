extends Node3D
## Lightweight ambient pedestrian that loops a local sidewalk route.
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(0.2, 5.0, 0.1) var walk_speed := 1.25
@export var pause_at_waypoints := false
var _target_index := 0
var _body: MeshInstance3D
var _phone: MeshInstance3D
var _pause_remaining := 0.0
var is_using_phone := false
var phone_interaction_count := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = int(absf(position.x * 97.0 + position.z * 131.0)) + 20261122
	_build_appearance()
	if route.size() < 2:
		route = PackedVector3Array([Vector3(-5,0,-5), Vector3(5,0,-5), Vector3(5,0,5), Vector3(-5,0,5)])

func _process(delta: float) -> void:
	if route.size() < 2:
		return
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		if _pause_remaining == 0.0:
			is_using_phone = false
			if _phone != null:
				_phone.visible = false
		return
	var target := route[_target_index]
	var direction := target - position
	direction.y = 0.0
	if direction.length() < 0.35:
		_target_index = (_target_index + 1) % route.size()
		_pause_remaining = _rng.randf_range(0.35, 1.4)
		is_using_phone = _rng.randf() < 0.72
		if is_using_phone:
			phone_interaction_count += 1
		if _phone != null:
			_phone.visible = is_using_phone
		return
	position += direction.normalized() * walk_speed * delta
	if direction.length_squared() > 0.001:
		look_at(position + direction, Vector3.UP)

func _build_appearance() -> void:
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.025, 0.035, 0.065)
	coat.metallic = 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.0, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.0, 0.65, 1.0)
	glow.emission_energy_multiplier = 1.6
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.32
	torso_mesh.height = 1.35
	_body = MeshInstance3D.new()
	_body.mesh = torso_mesh
	_body.position.y = 0.95
	_body.material_override = coat
	add_child(_body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.78
	head.material_override = glow
	add_child(head)
	_phone = MeshInstance3D.new()
	_phone.name = "Phone"
	var phone_mesh := BoxMesh.new()
	phone_mesh.size = Vector3(0.12, 0.2, 0.035)
	_phone.mesh = phone_mesh
	_phone.position = Vector3(0.34, 1.05, -0.12)
	var phone_material := StandardMaterial3D.new()
	phone_material.albedo_color = Color(0.0, 0.8, 1.0)
	phone_material.emission_enabled = true
	phone_material.emission = Color(0.0, 0.55, 1.0)
	phone_material.emission_energy_multiplier = 2.0
	_phone.material_override = phone_material
	_phone.visible = false
	add_child(_phone)
