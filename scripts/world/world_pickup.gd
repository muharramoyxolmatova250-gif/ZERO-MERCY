extends StaticBody3D
## Small world prop that can be picked up and placed with smooth tweened motion.
@export var display_name := "World item"
@export var glow_color := Color(0.0,0.8,1.0)
@export var grip_offset := Vector3(0.0, -0.06, -0.13)
@export var grip_rotation := Vector3.ZERO
@export var secondary_grip_offset := Vector3(-0.24, -0.05, -0.10)
@export_range(0.1, 2.0, 0.05) var handling_sensitivity := 1.0
@export var can_be_two_hand_carried := true
@export_range(0.1, 1.2, 0.01) var secondary_arm_upper_length := 0.38
@export_range(0.1, 1.2, 0.01) var secondary_arm_lower_length := 0.43
@export_range(0.1, 80.0, 0.1) var carry_mass_kg := 2.0
@export var is_fragile := false
@export var requires_careful_carry := false
var being_held := false
func _ready() -> void:
 add_to_group("world_pickup")
 set_meta("grip_offset", grip_offset)
 set_meta("grip_rotation", grip_rotation)
 set_meta("secondary_grip_offset", secondary_grip_offset)
 set_meta("handling_sensitivity", handling_sensitivity)
 set_meta("can_be_two_hand_carried", can_be_two_hand_carried)
 set_meta("secondary_arm_upper_length", secondary_arm_upper_length)
 set_meta("secondary_arm_lower_length", secondary_arm_lower_length)
 set_meta("carry_mass_kg", carry_mass_kg)
 set_meta("is_fragile", is_fragile)
 set_meta("requires_careful_carry", requires_careful_carry)
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
