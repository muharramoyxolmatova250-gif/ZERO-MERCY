extends Node3D
## Procedural cybernetic arms with shoulder pivots and gait-synchronised motion.
## Dara's two gold fingers remain on her right hand.

var _metal := StandardMaterial3D.new()
var _dark_metal := StandardMaterial3D.new()
var _gold := StandardMaterial3D.new()
var _arm_pivots: Array[Node3D] = []
var _finger_hinges: Array[Node3D] = []
var _thumb_hinges: Array[Node3D] = []
var _right_arm: Node3D
var _left_arm: Node3D
var _grip_anchor: Marker3D
var _carry_object: Node3D
var _reach_rotation := Vector3.ZERO
var _reach_weight := 0.0
var _is_gripping := false
var _carry_mass_kg := 0.0
var _carry_fragile := false
var _secondary_grip_weight := 0.0
var _carry_sway := 0.0
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
		if _is_gripping and _carry_mass_kg > 0.0:
			if side > 0.0:
				target = Vector3(-0.24 - minf(_carry_mass_kg * 0.006, 0.16), 0.0, 0.045)
			else:
				target = Vector3(-0.16 - minf(_carry_mass_kg * 0.004, 0.10), 0.0, -0.025)
				if _carry_mass_kg >= 8.0 and is_instance_valid(_carry_object):
					var grip_offset: Vector3 = _carry_object.get_meta("secondary_grip_offset", Vector3(-0.24, -0.05, -0.10))
					var grip_world: Vector3 = _carry_object.global_transform * grip_offset
					var target_local := to_local(grip_world) - pivot.position
					_secondary_grip_weight = move_toward(_secondary_grip_weight, 1.0, delta * 3.0)
					var target_horizontal := Vector2(target_local.x, target_local.z).length()
					target.x = clampf(atan2(target_local.y, maxf(0.001, target_horizontal)) + 0.45, -0.8, 0.55)
					target.x += sin(_clock * 1.8) * 0.018 * (1.0 - _secondary_grip_weight)
					target.y = clampf(atan2(-target_local.z, target_local.x), -0.95, 0.95)
					target.z = -0.04 if _carry_fragile else 0.0
		else:
			if side > 0.0:
				target += _reach_rotation * _reach_weight
		pivot.rotation = pivot.rotation.lerp(target, clampf(delta * (16.0 if _reach_weight > 0.01 else 12.0), 0.0, 1.0))
	for hinge_index in range(_finger_hinges.size()):
		var curl := 0.08 + sprint_weight * 0.22 + sin(_clock * 3.0 + float(hinge_index) * 0.45) * 0.025
		if hinge_index >= 4 and _reach_weight > 0.01:
			curl = lerpf(curl, 0.92 if _is_gripping else 0.015, _reach_weight)
		var hinge := _finger_hinges[hinge_index]
		hinge.rotation.x = lerpf(hinge.rotation.x, curl, clampf(delta * 12.0, 0.0, 1.0))
	for thumb in _thumb_hinges:
		thumb.rotation.z = lerpf(thumb.rotation.z, -0.62 if _is_gripping else (0.0 if _reach_weight > 0.01 else -0.12), clampf(delta * 12.0, 0.0, 1.0))

func _build_arm(side: float, right_hand: bool) -> void:
	var arm := Node3D.new()
	arm.name = "LeftCyberArm" if side < 0.0 else "RightCyberArm"
	arm.position = Vector3(side * 0.39, 1.42, 0.0)
	add_child(arm)
	if right_hand:
		_right_arm = arm
		_grip_anchor = Marker3D.new()
		_grip_anchor.name = "ObjectGripAnchor"
		_grip_anchor.position = Vector3(side * 0.69, -0.47, -0.11)
		arm.add_child(_grip_anchor)
	else:
		_left_arm = arm
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

	var thumb_hinge := Node3D.new()
	thumb_hinge.name = "Thumb_Hinge"
	thumb_hinge.position = Vector3(side * 0.55, -0.51, -0.015)
	arm.add_child(thumb_hinge)
	_thumb_hinges.append(thumb_hinge)
	_add_box(thumb_hinge, "Thumb_Base", Vector3(side * -0.025, -0.035, 0.0), Vector3(0.13, 0.075, 0.08), _metal)
	_add_box(thumb_hinge, "Thumb_Tip", Vector3(side * -0.075, -0.075, -0.01), Vector3(0.09, 0.065, 0.07), _metal)
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


func begin_pickup(target_world_position: Vector3) -> void:
	if not is_instance_valid(_right_arm): return
	var local_target := to_local(target_world_position)
	var direction := local_target - _right_arm.position
	if direction.length_squared() < 0.001: return
	var horizontal := Vector2(direction.x, direction.z).length()
	_reach_rotation = Vector3(atan2(direction.y, maxf(0.001, horizontal)) - -0.55, atan2(-direction.z, direction.x), 0.0)
	_reach_rotation.x = clampf(_reach_rotation.x, -0.9, 0.65)
	_reach_rotation.y = clampf(_reach_rotation.y, -0.8, 0.8)
	_reach_weight = 1.0
	_is_gripping = false

func close_grip() -> void:
	_is_gripping = true
	_reach_weight = 1.0

func set_carry_profile(mass_kg: float, fragile: bool = false) -> void:
	_carry_mass_kg = maxf(0.0, mass_kg)
	_carry_fragile = fragile

func set_carry_object(item: Node3D) -> void:
	_carry_object = item

func release_object() -> void:
	_is_gripping = false
	_carry_mass_kg = 0.0
	_carry_fragile = false
	_carry_object = null
	_secondary_grip_weight = 0.0
	_carry_sway = 0.0
	_reach_weight = 0.0
	_reach_rotation = Vector3.ZERO

func get_grip_anchor() -> Marker3D:
	return _grip_anchor
