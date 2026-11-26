extends Node3D
## Simple ambient traffic loop for distant city streets; these are visual traffic proxies.
@export var vehicle_count := 5
@export var lane_spacing := 4.2
@export var travel_speed := 7.5
@export var loop_length := 150.0
var _traffic: Array[Node3D] = []

func _ready() -> void:
 for index in range(vehicle_count):
  var car := _make_traffic_car(index)
  car.position = Vector3(-loop_length * 0.5 + float(index) * (loop_length / vehicle_count), 0.08, -34.0 + float(index % 2) * lane_spacing)
  add_child(car)
  _traffic.append(car)

func _make_traffic_car(index: int) -> Node3D:
 var root := Node3D.new()
 root.name = "AmbientTraffic_%02d" % index
 var paint := StandardMaterial3D.new()
 paint.albedo_color = [Color(0.025, 0.08, 0.12), Color(0.16, 0.025, 0.07), Color(0.12, 0.12, 0.15)][index % 3]
 paint.metallic = 0.78
 paint.roughness = 0.28
 var body := MeshInstance3D.new()
 var body_mesh := BoxMesh.new()
 body_mesh.size = Vector3(1.8, 0.62, 3.6)
 body.mesh = body_mesh
 body.position.y = 0.62
 body.material_override = paint
 root.add_child(body)
 var roof := MeshInstance3D.new()
 var roof_mesh := BoxMesh.new()
 roof_mesh.size = Vector3(1.35, 0.48, 1.7)
 roof.mesh = roof_mesh
 roof.position = Vector3(0, 1.12, 0.15)
 roof.material_override = paint
 root.add_child(roof)
 var lamp := StandardMaterial3D.new()
 lamp.albedo_color = Color(0.0, 0.65, 1.0)
 lamp.emission_enabled = true
 lamp.emission = Color(0.0, 0.55, 1.0)
 lamp.emission_energy_multiplier = 1.6
 var lights := MeshInstance3D.new()
 var light_mesh := BoxMesh.new()
 light_mesh.size = Vector3(1.1, 0.07, 0.04)
 lights.mesh = light_mesh
 lights.position = Vector3(0, 0.68, -1.82)
 lights.material_override = lamp
 root.add_child(lights)
 return root

func _process(delta: float) -> void:
 for car in _traffic:
  car.position.x += travel_speed * delta
  if car.position.x > loop_length * 0.5:
   car.position.x = -loop_length * 0.5
