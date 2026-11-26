extends StaticBody3D
## Temporary police roadblock with illuminated warning bar.
func _ready() -> void:
 add_to_group("police_roadblock")
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(7.0, 1.1, 0.65)
 shape.shape = box
 shape.position.y = 0.65
 add_child(shape)
 var barrier := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = Vector3(7.0, 0.9, 0.45)
 barrier.mesh = mesh
 barrier.position.y = 0.65
 var paint := StandardMaterial3D.new()
 paint.albedo_color = Color(0.035, 0.045, 0.06)
 paint.metallic = 0.8
 barrier.material_override = paint
 add_child(barrier)
 for index in range(7):
  var stripe := MeshInstance3D.new()
  var stripe_mesh := BoxMesh.new()
  stripe_mesh.size = Vector3(0.34, 0.92, 0.47)
  stripe.mesh = stripe_mesh
  stripe.position = Vector3(-2.85 + index * 0.95, 0.65, -0.02)
  var stripe_material := StandardMaterial3D.new()
  stripe_material.albedo_color = Color(1.0, 0.55, 0.025)
  stripe_material.emission_enabled = true
  stripe_material.emission = Color(1.0, 0.22, 0.005)
  stripe_material.emission_energy_multiplier = 1.5
  stripe.material_override = stripe_material
  add_child(stripe)
