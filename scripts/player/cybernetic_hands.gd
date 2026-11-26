extends Node3D
## Procedural cybernetic arms with shoulder pivots and gait-synchronised motion.
## Dara's two gold fingers remain on her right hand.

var _metal := StandardMaterial3D.new()
var _dark_metal := StandardMaterial3D.new()
var _gold := StandardMaterial3D.new()
var _arm_pivots: Array[Node3D] = []
var _finger_hinges: Array[Node3D] = []
var _clock := 0.0

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

func _process(delta: float) -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null:
		return
	var horizontal_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var gait_weight := clampf(horizontal_speed / 9.0, 0.0, 1.0)
	var sprint_weight := clampf((horizontal_speed - 5.5) / 3.5, 0.0, 1.0)
	_clock += delta * lerpf(1.0, 1.65, sprint_weight)
	var gait := sin(_clock * lerpf(7.2, 10.2, sprint_weight))
	var breathing := sin(_clock * 2.0) * 0.018
	for index in range(_arm_pivots.size()):
		var pivot := _arm_pivots[index]
		var side := -1.0 if index == 0 else 1.0
		var phase := gait * side
		var target := Vector3(-0.10 - phase * 0.34 * gait_weight + breathing, 0.0, side * 0.035 * gait_weight)
		pivot.rotation = pivot.rotation.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
\tfor hinge_index in range(_finger_hinges.size()):
\t\tvar curl := 0.08 + sprint_weight * 0.22 + sin(_clock * 3.0 + float(hinge_index) * 0.45) * 0.025
\t\tvar hinge := _finger_hinges[hinge_index]
\t\thinge.rotation.x = lerpf(hinge.rotation.x, curl, clampf(delta * 9.0, 0.0, 1.0))

func _build_arm(side: float, right_hand: bool) -> void:
	var arm := Node3D.new()
	arm.name = "LeftCyberArm" if side < 0.0 else "RightCyberArm"
	arm.position = Vector3(side * 0.39, 1.42, 0.0)
	add_child(arm)
	_arm_pivots.append(arm)

	# Every part is positioned relative to the shoulder pivot.
	_add_box(arm, "UpperArm", Vector3(side * 0.09, -0.14, 0.0), Vector3(0.34, 0.22, 0.25), _dark_metal)
	_add_box(arm, "Forearm", Vector3(side * 0.33, -0.30, -0.015), Vector3(0.42, 0.19, 0.23), _metal)
	_add_box(arm, "WristJoint", Vector3(side * 0.55, -0.34, -0.015), Vector3(0.12, 0.22, 0.24), _dark_metal)
	_add_box(arm, "Palm", Vector3(side * 0.69, -0.44, -0.025), Vector3(0.25, 0.28, 0.23), _metal)

	# Four fingers; index and middle on the right hand are gold.
	for finger in range(4):
		var x_offset := (float(finger) - 1.5) * 0.065
		var is_gold := right_hand and (finger == 1 or finger == 2)
		var finger_material: Material = _gold if is_gold else _metal
		var base := Vector3(side * 0.69 + x_offset, -0.62, -0.025)
		var finger_root := Node3D.new()
		finger_root.name = "Finger_%d_Hinge" % finger
		finger_root.position = base
		arm.add_child(finger_root)
		_finger_hinges.append(finger_root)
		_add_box(finger_root, "Finger_%d_Base" % finger, Vector3(0.0, -0.065, 0.0), Vector3(0.052, 0.13, 0.075), finger_material)
		var middle_hinge := Node3D.new()
		middle_hinge.position = Vector3(0.0, -0.13, 0.0)
		finger_root.add_child(middle_hinge)
		_add_box(middle_hinge, "Finger_%d_Middle" % finger, Vector3(0.0, -0.0425, -0.005), Vector3(0.047, 0.085, 0.068), finger_material)
		var tip_hinge := Node3D.new()
		tip_hinge.position = Vector3(0.0, -0.085, -0.005)
		middle_hinge.add_child(tip_hinge)
		_add_box(tip_hinge, "Finger_%d_Tip" % finger, Vector3(0.0, -0.0325, -0.003), Vector3(0.043, 0.065, 0.06), finger_material)

	_add_box(arm, "Thumb_Base", Vector3(side * 0.55, -0.51, -0.015), Vector3(0.13, 0.075, 0.08), _metal)
	_add_box(arm, "Thumb_Tip", Vector3(side * 0.50, -0.58, -0.025), Vector3(0.09, 0.065, 0.07), _metal)
	var status := StandardMaterial3D.new()
	status.albedo_color = Color(0.0, 0.82, 1.0)
	status.emission_enabled = true
	status.emission = Color(0.0, 0.65, 1.0)
	status.emission_energy_multiplier = 1.6
	_add_box(arm, "WristStatusLight", Vector3(side * 0.55, -0.34, 0.11), Vector3(0.055, 0.035, 0.018), status)

func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	instance.mesh = box
	instance.material_override = material
	instance.position = local_position
	parent.add_child(instance)
