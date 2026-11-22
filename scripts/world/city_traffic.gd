extends Node3D
## Simple ambient electric vehicle following a closed road loop.
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(2.0, 30.0, 0.5) var speed := 8.0
@export var vehicle_color := Color(0.02, 0.12, 0.2)
var _target_index := 0

func _ready() -> void:
	_build_vehicle()
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
	position += direction.normalized() * speed * delta
	if direction.length_squared() > 0.001:
		look_at(position + direction, Vector3.UP)

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
