extends Node3D
## Procedural cinematic witness: a compact cybernetic stranger who ambushes Dara.
## This is a lightweight placeholder character assembled from meshes, not a final art asset.

var _arm_pivot: Node3D
var _played := false

func _ready() -> void:
	_build_character()

func _build_character() -> void:
	var jacket := _material(Color(0.025, 0.045, 0.075), 0.82, 0.22)
	var skin := _material(Color(0.48, 0.38, 0.34), 0.0, 0.72)
	var implant := _material(Color(0.02, 0.72, 1.0), 0.55, 0.18, true)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.31
	torso_mesh.height = 1.0
	torso.mesh = torso_mesh
	torso.position.y = 1.0
	torso.material_override = jacket
	add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position = Vector3(0, 1.72, 0)
	head.material_override = skin
	add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.085, 1.76, -0.19)
		eye.material_override = implant
		add_child(eye)
		var cheek_line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.09, 0.025, 0.018)
		cheek_line.mesh = line_mesh
		cheek_line.position = Vector3(side * 0.115, 1.64, -0.195)
		cheek_line.material_override = implant
		add_child(cheek_line)
	var legs := MeshInstance3D.new()
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.13
	leg_mesh.height = 0.78
	legs.mesh = leg_mesh
	legs.position = Vector3(0, 0.35, 0)
	legs.material_override = jacket
	add_child(legs)
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(-0.37, 1.32, 0)
	add_child(_arm_pivot)
	var arm := MeshInstance3D.new()
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.105
	arm_mesh.height = 0.62
	arm.mesh = arm_mesh
	arm.position = Vector3(0, -0.28, -0.03)
	arm.rotation.x = -0.22
	arm.material_override = jacket
	_arm_pivot.add_child(arm)

func perform_ambush(target: Node3D) -> void:
	if _played or not is_instance_valid(target):
		return
	_played = true
	var forward := -target.global_transform.basis.z.normalized()
	global_position = target.global_position + forward * 2.15
	global_position.y = target.global_position.y
	look_at(Vector3(target.global_position.x, global_position.y + 1.0, target.global_position.z), Vector3.UP)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target.global_position + forward * 0.95, 0.28)
	tween.parallel().tween_property(_arm_pivot, "rotation:x", -1.45, 0.16)
	tween.tween_property(target, "global_position", target.global_position - forward * 0.42, 0.12)
	tween.parallel().tween_property(_arm_pivot, "rotation:x", 0.18, 0.13)
	tween.tween_interval(0.25)
	tween.tween_property(_arm_pivot, "rotation:x", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target):
			MissionManager.report_event("meet_simulation_witness")
	)

func _material(color: Color, metallic: float, roughness: float, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	return material
