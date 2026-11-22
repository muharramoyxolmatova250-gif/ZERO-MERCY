extends StaticBody3D
## Small world prop that can be picked up and placed with smooth tweened motion.
@export var display_name := "World item"
@export var glow_color := Color(0.0,0.8,1.0)
var being_held := false
func _ready() -> void:
 add_to_group("world_pickup")
 var mesh := MeshInstance3D.new()
 var shape_mesh := BoxMesh.new()
 shape_mesh.size = Vector3(0.42,0.42,0.42)
 mesh.mesh = shape_mesh
 var material := StandardMaterial3D.new()
 material.albedo_color = glow_color.darkened(0.55)
 material.metallic = 0.7
 material.roughness = 0.22
 material.emission_enabled = true
 material.emission = glow_color
 material.emission_energy_multiplier = 1.8
 mesh.material_override = material
 add_child(mesh)
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(0.48,0.48,0.48)
 collision.shape = box
 add_child(collision)
func set_being_held(value: bool) -> void:
 being_held = value
