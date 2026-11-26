extends Node3D
## Procedural cybernetic arms for Dara's current capsule prototype.
## Two gold fingers on the right hand are a visual story signature.

var _metal := StandardMaterial3D.new()
var _dark_metal := StandardMaterial3D.new()
var _gold := StandardMaterial3D.new()

func _ready() -> void:
	_metal.albedo_color = Color(0.28, 0.34, 0.42)
	_metal.metallic = 0.88
	_metal.roughness = 0.24
	_dark_metal.albedo_color = Color(0.035, 0.05, 0.075)
	_dark_metal.metallic = 0.72
	_dark_metal.roughness = 0.3
	_gold.albedo_color = Color(0.92, 0.62, 0.12)
	_gold.metallic = 0.95
	_gold.roughness = 0.18
	_build_arm(-1.0, false)
	_build_arm(1.0, true)

func _build_arm(side: float, right_hand: bool) -> void:
	var arm := Node3D.new()
	arm.name = "LeftCyberArm" if side < 0.0 else "RightCyberArm"
	add_child(arm)

	_add_box(arm, "UpperArm", Vector3(side * 0.48, 1.28, 0.0), Vector3(0.34, 0.22, 0.25), _dark_metal)
	_add_box(arm, "Forearm", Vector3(side * 0.72, 1.12, -0.015), Vector3(0.42, 0.19, 0.23), _metal)
	_add_box(arm, "WristJoint", Vector3(side * 0.94, 1.08, -0.015), Vector3(0.12, 0.22, 0.24), _dark_metal)
	_add_box(arm, "Palm", Vector3(side * 1.08, 0.98, -0.025), Vector3(0.25, 0.28, 0.23), _metal)

	# Four articulated fingers. On Dara's right hand, index and middle are gold.
	for finger in range(4):
		var x_offset := (float(finger) - 1.5) * 0.065
		var is_gold := right_hand and (finger == 1 or finger == 2)
		var finger_material: Material = _gold if is_gold else _metal
		var base := Vector3(side * 1.08 + x_offset, 0.80, -0.025)
		_add_box(arm, "Finger_%d_Base" % finger, base, Vector3(0.052, 0.13, 0.075), finger_material)
		_add_box(arm, "Finger_%d_Middle" % finger, base + Vector3(0.0, -0.105, -0.005), Vector3(0.047, 0.085, 0.068), finger_material)
		_add_box(arm, "Finger_%d_Tip" % finger, base + Vector3(0.0, -0.18, -0.008), Vector3(0.043, 0.065, 0.06), finger_material)

	# Opposing thumb and a small illuminated wrist status strip.
	_add_box(arm, "Thumb_Base", Vector3(side * 0.94, 0.91, -0.015), Vector3(0.13, 0.075, 0.08), _metal)
	_add_box(arm, "Thumb_Tip", Vector3(side * 0.89, 0.84, -0.025), Vector3(0.09, 0.065, 0.07), _metal)
	var status := StandardMaterial3D.new()
	status.albedo_color = Color(0.0, 0.82, 1.0)
	status.emission_enabled = true
	status.emission = Color(0.0, 0.65, 1.0)
	status.emission_energy_multiplier = 1.6
	_add_box(arm, "WristStatusLight", Vector3(side * 0.94, 1.08, 0.11), Vector3(0.055, 0.035, 0.018), status)

func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	instance.mesh = box
	instance.material_override = material
	instance.position = local_position
	parent.add_child(instance)
