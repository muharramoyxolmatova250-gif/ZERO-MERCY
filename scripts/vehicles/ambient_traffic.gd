extends Node3D
## Ambient boulevard: traffic lights, vehicle spacing and pedestrian walkers.
@export var vehicle_count := 5
@export var travel_speed := 7.5
@export var loop_length := 150.0
@export var signal_cycle_seconds := 18.0
var _traffic: Array[Node3D] = []
var _pedestrians: Array[Node3D] = []
var _signal_elapsed := 0.0
var _green_for_eastbound := true
var _signal_lamp: MeshInstance3D
var _signal_material: StandardMaterial3D

func _ready() -> void:
 _build_traffic_signal()
 for index in range(vehicle_count):
  var car := _make_traffic_car(index)
  car.position = Vector3(-loop_length * 0.5 + float(index) * (loop_length / vehicle_count), 0.08, -34.0)
  add_child(car)
  _traffic.append(car)
 for index in range(4):
  var pedestrian := _make_pedestrian(index)
  pedestrian.position = Vector3(-18.0 + float(index) * 11.0, 0.0, -25.0 if index % 2 == 0 else -43.0)
  pedestrian.set_meta("walk_direction", 1.0 if index % 2 == 0 else -1.0)
  add_child(pedestrian)
  _pedestrians.append(pedestrian)

func _build_traffic_signal() -> void:
 var pole_material := StandardMaterial3D.new()
 pole_material.albedo_color = Color(0.035, 0.045, 0.065)
 pole_material.metallic = 0.8
 var pole := MeshInstance3D.new()
 var pole_mesh := CylinderMesh.new()
 pole_mesh.top_radius = 0.09
 pole_mesh.bottom_radius = 0.12
 pole_mesh.height = 5.2
 pole.mesh = pole_mesh
 pole.position = Vector3(0, 2.6, -29.0)
 pole.material_override = pole_material
 add_child(pole)
 var housing := MeshInstance3D.new()
 var housing_mesh := BoxMesh.new()
 housing_mesh.size = Vector3(0.48, 1.25, 0.32)
 housing.mesh = housing_mesh
 housing.position = Vector3(0, 4.5, -29.0)
 housing.material_override = pole_material
 add_child(housing)
 _signal_material = StandardMaterial3D.new()
 _signal_material.albedo_color = Color(0.0, 1.0, 0.2)
 _signal_material.emission_enabled = true
 _signal_material.emission = Color(0.0, 1.0, 0.2)
 _signal_material.emission_energy_multiplier = 2.5
 _signal_lamp = MeshInstance3D.new()
 var lamp_mesh := SphereMesh.new()
 lamp_mesh.radius = 0.16
 lamp_mesh.height = 0.32
 _signal_lamp.mesh = lamp_mesh
 _signal_lamp.position = Vector3(0, 4.68, -28.78)
 _signal_lamp.material_override = _signal_material
 add_child(_signal_lamp)

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
 var traffic_body := StaticBody3D.new()
 traffic_body.name = "TrafficCollision"
 var traffic_shape := CollisionShape3D.new()
 var traffic_box := BoxShape3D.new()
 traffic_box.size = Vector3(1.8, 1.0, 3.6)
 traffic_shape.shape = traffic_box
 traffic_shape.position.y = 0.62
 traffic_body.add_child(traffic_shape)
 root.add_child(traffic_body)
 return root

func _make_pedestrian(index: int) -> Node3D:
 var root := Node3D.new()
 root.name = "StreetPedestrian_%02d" % index
 var outfit := StandardMaterial3D.new()
 outfit.albedo_color = [Color(0.035, 0.055, 0.09), Color(0.12, 0.035, 0.09), Color(0.06, 0.09, 0.1), Color(0.1, 0.08, 0.035)][index % 4]
 outfit.metallic = 0.25
 var skin := StandardMaterial3D.new()
 skin.albedo_color = Color(0.42, 0.25, 0.19)
 var torso := MeshInstance3D.new()
 var torso_mesh := CapsuleMesh.new()
 torso_mesh.radius = 0.22
 torso_mesh.height = 0.85
 torso.mesh = torso_mesh
 torso.position.y = 1.0
 torso.material_override = outfit
 root.add_child(torso)
 var head := MeshInstance3D.new()
 var head_mesh := SphereMesh.new()
 head_mesh.radius = 0.17
 head_mesh.height = 0.34
 head.mesh = head_mesh
 head.position.y = 1.57
 head.material_override = skin
 root.add_child(head)
 var leg_material := StandardMaterial3D.new()
 leg_material.albedo_color = Color(0.025, 0.035, 0.05)
 for side in [-1.0, 1.0]:
  var leg := MeshInstance3D.new()
  var leg_mesh := CapsuleMesh.new()
  leg_mesh.radius = 0.075
  leg_mesh.height = 0.72
  leg.mesh = leg_mesh
  leg.position = Vector3(side * 0.12, 0.42, 0.0)
  leg.material_override = leg_material
  leg.name = "Leg_%s" % side
  root.add_child(leg)
 var pedestrian_body := StaticBody3D.new()
 pedestrian_body.name = "PedestrianCollision"
 var pedestrian_shape := CollisionShape3D.new()
 var pedestrian_capsule := CapsuleShape3D.new()
 pedestrian_capsule.radius = 0.24
 pedestrian_capsule.height = 1.75
 pedestrian_shape.shape = pedestrian_capsule
 pedestrian_shape.position.y = 0.88
 pedestrian_body.add_child(pedestrian_shape)
 root.add_child(pedestrian_body)
 return root

func _process(delta: float) -> void:
 _signal_elapsed += delta
 if _signal_elapsed >= signal_cycle_seconds:
  _signal_elapsed = 0.0
  _green_for_eastbound = not _green_for_eastbound
 _signal_material.albedo_color = Color(0.0, 1.0, 0.2) if _green_for_eastbound else Color(1.0, 0.025, 0.035)
 _signal_material.emission = _signal_material.albedo_color
 for index in range(_traffic.size()):
  var car := _traffic[index]
  var next_x := car.position.x + travel_speed * delta
  # Red light stop line at the boulevard crossing.
  if not _green_for_eastbound and car.position.x < 0.0 and next_x >= -3.0:
   next_x = -3.0
  # Keep a safe gap behind the preceding vehicle in the same lane.
  for other_index in range(_traffic.size()):
   if other_index == index:
    continue
   var other := _traffic[other_index]
   if absf(other.position.z - car.position.z) < 0.2:
    var gap := other.position.x - car.position.x
    if gap > 0.0 and gap < 6.0:
     next_x = minf(next_x, other.position.x - 6.0)
  car.position.x = next_x
  if car.position.x > loop_length * 0.5:
   car.position.x = -loop_length * 0.5
 for pedestrian in _pedestrians:
  var direction := float(pedestrian.get_meta("walk_direction", 1.0))
  pedestrian.position.x += direction * 1.25 * delta
  if absf(pedestrian.position.x) > 24.0:
   pedestrian.set_meta("walk_direction", -direction)
  pedestrian.rotation.y = PI if direction < 0.0 else 0.0
  var gait := sin(Time.get_ticks_msec() * 0.008 + float(pedestrian.get_instance_id() % 17))
  var left_leg := pedestrian.get_node_or_null("Leg_-1.0") as Node3D
  var right_leg := pedestrian.get_node_or_null("Leg_1.0") as Node3D
  if left_leg != null:
   left_leg.rotation.x = gait * 0.35
  if right_leg != null:
   right_leg.rotation.x = -gait * 0.35
