extends CharacterBody3D
## Core third-person controller for ZERO MERCY.
## Input actions are configured in project.godot; gameplay systems can listen to the signals below.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal ammo_changed(magazine: int, reserve: int)
signal player_died

@export_group("Movement")
@export var walk_speed := 5.5
@export var sprint_speed := 9.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025
@export var stamina_max := 100.0
@export var stamina_drain_per_second := 24.0
@export var stamina_regen_per_second := 18.0
@export var stamina_regen_delay := 0.8

@export_group("Combat")
@export var max_health := 100.0
@export var weapon_damage := 34.0
@export var weapon_range := 100.0
@export var magazine_size := 12
@export var reserve_ammo := 60
@export var shot_interval := 0.18
@export var melee_damage := 42.0
@export var melee_range := 2.4
@export var melee_cooldown := 0.55

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch := 0.0
var health: float
var stamina: float
var ammo_in_magazine: int
var shot_cooldown := 0.0
var melee_cooldown_timer := 0.0
var _melee_animation := 0.0
var stamina_regen_timer := 0.0
var is_dead := false
var _held_item: Node3D
var _hand_anchor: Marker3D
var _muzzle_flash: MeshInstance3D
var _muzzle_light: OmniLight3D
var _muzzle_flash_timer := 0.0
var _spawn_transform: Transform3D
var _dara_animation_time := 0.0
var _dara_visual_nodes: Dictionary = {}
var _dara_was_airborne := false
var _landing_compression := 0.0
var _damage_reaction_timer := 0.0
var _damage_reaction_strength := 0.0
var _aiming := false
var _weapon_tween: Tween
var _hand_anchor_home := Vector3(0.48, -0.38, -1.15)


func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	_hand_anchor = Marker3D.new()
	_hand_anchor.name = "HeldItemAnchor"
	camera.add_child(_hand_anchor)
	_hand_anchor.position = _hand_anchor_home
	_build_dara_visual()
	_build_weapon_visual()
	health = max_health
	stamina = stamina_max
	ammo_in_magazine = magazine_size
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, stamina_max)
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _build_dara_visual() -> void:
	# Detailed real-time 3D cyberpunk character proxy. Replace with the final
	# scanned/sculpted hero asset when the licensed character art is integrated.
	var old_body := get_node_or_null("BodyMesh") as MeshInstance3D
	if old_body != null:
		old_body.visible = false
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.018, 0.027, 0.045)
	armor.metallic = 0.82
	armor.roughness = 0.24
	armor.clearcoat_enabled = true
	armor.clearcoat = 0.8
	var dark_fabric := StandardMaterial3D.new()
	dark_fabric.albedo_color = Color(0.035, 0.045, 0.065)
	dark_fabric.roughness = 0.88
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color(0.0, 0.72, 0.95)
	cyan.metallic = 0.25
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	cyan.emission_enabled = true
	cyan.emission = Color(0.0, 0.52, 1.0)
	cyan.emission_energy_multiplier = 1.5
	var magenta := StandardMaterial3D.new()
	magenta.albedo_color = Color(0.9, 0.035, 0.24)
	magenta.emission_enabled = true
	magenta.emission = Color(0.8, 0.015, 0.12)
	magenta.emission_energy_multiplier = 0.8
	_add_dara_capsule("TorsoArmor", Vector3(0.0, 1.05, 0.0), 0.34, 0.78, armor)
	_add_dara_box("ChestPlate", Vector3(0.0, 1.22, -0.285), Vector3(0.43, 0.34, 0.12), armor)
	_add_dara_box("ChestCore", Vector3(0.0, 1.24, -0.354), Vector3(0.12, 0.19, 0.025), cyan)
	_add_dara_capsule("Neck", Vector3(0.0, 1.55, 0.0), 0.105, 0.2, dark_fabric)
	_add_dara_sphere("Head", Vector3(0.0, 1.78, 0.0), Vector3(0.235, 0.29, 0.22), dark_fabric)
	_add_dara_box("FacePlate", Vector3(0.0, 1.755, -0.194), Vector3(0.285, 0.19, 0.055), armor)
	_add_dara_box("Visor", Vector3(0.0, 1.84, -0.226), Vector3(0.31, 0.065, 0.035), cyan)
	for eye_side in [-1.0, 1.0]:
		_add_dara_sphere("Eye_%s" % eye_side, Vector3(eye_side * 0.078, 1.805, -0.229), Vector3(0.026, 0.014, 0.012), cyan)
		_add_dara_box("Brow_%s" % eye_side, Vector3(eye_side * 0.078, 1.835, -0.222), Vector3(0.075, 0.012, 0.018), armor)
	_add_dara_box("JawSeam", Vector3(0.0, 1.685, -0.222), Vector3(0.13, 0.012, 0.018), magenta)
	_add_dara_box("CheekLight_L", Vector3(-0.15, 1.755, -0.19), Vector3(0.035, 0.018, 0.02), cyan)
	_add_dara_box("CheekLight_R", Vector3(0.15, 1.755, -0.19), Vector3(0.035, 0.018, 0.02), cyan)
	for side in [-1.0, 1.0]:
		_add_dara_capsule("Shoulder_%s" % side, Vector3(side * 0.39, 1.42, 0.0), 0.17, 0.32, armor)
		_add_dara_capsule("UpperArm_%s" % side, Vector3(side * 0.43, 1.12, 0.0), 0.115, 0.48, dark_fabric)
		_add_dara_capsule("Forearm_%s" % side, Vector3(side * 0.46, 0.78, -0.025), 0.105, 0.38, armor)
		_add_dara_box("WristLight_%s" % side, Vector3(side * 0.46, 0.63, -0.12), Vector3(0.19, 0.045, 0.08), cyan)
		_add_dara_capsule("Thigh_%s" % side, Vector3(side * 0.17, 0.48, 0.0), 0.16, 0.52, dark_fabric)
		_add_dara_capsule("Shin_%s" % side, Vector3(side * 0.17, 0.16, -0.025), 0.115, 0.38, armor)
		_add_dara_box("KneePlate_%s" % side, Vector3(side * 0.17, 0.34, -0.125), Vector3(0.22, 0.16, 0.07), magenta)
		_add_dara_box("Boot_%s" % side, Vector3(side * 0.17, 0.055, -0.09), Vector3(0.24, 0.13, 0.38), armor)
	_dara_visual_nodes["TorsoArmor"] = get_node_or_null("TorsoArmor")
	_dara_visual_nodes["Head"] = _create_visual_joint("Head", Vector3(0.0, 1.78, 0.0))
	var head_pivot := _dara_visual_nodes["Head"] as Node3D
	if head_pivot != null:
		for face_part in ["FacePlate", "Visor", "Eye_-1.0", "Eye_1.0", "Brow_-1.0", "Brow_1.0", "JawSeam", "CheekLight_L", "CheekLight_R"]:
			var feature := get_node_or_null(face_part) as Node3D
			if feature != null:
				feature.reparent(head_pivot, true)
	for side in [-1.0, 1.0]:
		var suffix := "-1.0" if side < 0.0 else "1.0"
		_dara_visual_nodes["Shoulder_%s" % suffix] = _create_visual_joint("Shoulder_%s" % suffix, Vector3(side * 0.39, 1.42, 0.0))
		_dara_visual_nodes["UpperArm_%s" % suffix] = _create_visual_joint("UpperArm_%s" % suffix, Vector3(side * 0.39, 1.36, 0.0))
		_dara_visual_nodes["Forearm_%s" % suffix] = _create_visual_joint("Forearm_%s" % suffix, Vector3(side * 0.46, 0.97, -0.025))
		_dara_visual_nodes["Thigh_%s" % suffix] = _create_visual_joint("Thigh_%s" % suffix, Vector3(side * 0.17, 0.74, 0.0))
		_dara_visual_nodes["Shin_%s" % suffix] = _create_visual_joint("Shin_%s" % suffix, Vector3(side * 0.17, 0.35, -0.025))
		_dara_visual_nodes["Boot_%s" % suffix] = _create_visual_joint("Boot_%s" % suffix, Vector3(side * 0.17, 0.12, -0.09))


func _create_visual_joint(part_name: String, joint_position: Vector3) -> Node3D:
	var part := get_node_or_null(part_name) as Node3D
	if part == null:
		return null
	var joint := Node3D.new()
	joint.name = "%s_Pivot" % part_name
	joint.position = joint_position
	add_child(joint)
	part.reparent(joint, true)
	return joint


func _add_dara_capsule(part_name: String, part_position: Vector3, radius: float, height: float, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	add_child(part)


func _add_dara_sphere(part_name: String, part_position: Vector3, part_scale: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	part.mesh = mesh
	part.position = part_position
	part.scale = part_scale
	part.material_override = material
	add_child(part)


func _add_dara_box(part_name: String, part_position: Vector3, part_size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	add_child(part)


func _build_weapon_visual() -> void:
	var weapon := Node3D.new()
	weapon.name = "SovereignSidearm"
	_hand_anchor.add_child(weapon)
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.018, 0.028, 0.045)
	armor.metallic = 0.88
	armor.roughness = 0.22
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.12, 0.17, 0.22)
	edge.metallic = 0.95
	edge.roughness = 0.18
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color(0.0, 0.72, 1.0)
	cyan.emission_enabled = true
	cyan.emission = Color(0.0, 0.58, 1.0)
	cyan.emission_energy_multiplier = 1.8
	_add_weapon_box(weapon, "Slide", Vector3(0.0, 0.035, -0.22), Vector3(0.16, 0.14, 0.48), armor)
	_add_weapon_box(weapon, "UpperRail", Vector3(0.0, 0.115, -0.23), Vector3(0.11, 0.035, 0.36), edge)
	_add_weapon_box(weapon, "Grip", Vector3(0.0, -0.13, -0.02), Vector3(0.13, 0.29, 0.17), armor)
	_add_weapon_box(weapon, "GripCore", Vector3(0.0, -0.13, -0.11), Vector3(0.075, 0.17, 0.025), cyan)
	_add_weapon_box(weapon, "Barrel", Vector3(0.0, 0.035, -0.49), Vector3(0.085, 0.075, 0.16), edge)
	_add_weapon_box(weapon, "Muzzle", Vector3(0.0, 0.035, -0.58), Vector3(0.105, 0.09, 0.045), armor)
	_add_weapon_box(weapon, "SideDisplay", Vector3(0.086, 0.04, -0.24), Vector3(0.012, 0.055, 0.2), cyan)
	_add_weapon_box(weapon, "TriggerGuard", Vector3(0.0, -0.07, -0.16), Vector3(0.1, 0.025, 0.11), edge)
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.075
	flash_mesh.height = 0.15
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.position = Vector3(0.0, 0.035, -0.66)
	_muzzle_flash.material_override = cyan
	_muzzle_flash.visible = false
	weapon.add_child(_muzzle_flash)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.name = "MuzzleLight"
	_muzzle_light.position = _muzzle_flash.position
	_muzzle_light.light_color = Color(0.0, 0.72, 1.0)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 5.0
	_muzzle_light.visible = false
	weapon.add_child(_muzzle_light)


func _add_weapon_box(parent: Node3D, part_name: String, part_position: Vector3, part_size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	parent.add_child(part)


func _set_aiming(enabled: bool) -> void:
	if _aiming == enabled:
		return
	_aiming = enabled
	if _weapon_tween != null and _weapon_tween.is_running():
		_weapon_tween.kill()
	_weapon_tween = create_tween()
	_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_position := Vector3(0.22, -0.29, -0.92) if _aiming else _hand_anchor_home
	_weapon_tween.tween_property(_hand_anchor, "position", target_position, 0.18)
	_weapon_tween.parallel().tween_property(camera, "fov",  get_aim_camera_fov(), 0.18)


func get_aim_camera_fov() -> float:
	return 55.0 if _aiming else 75.0


func _play_weapon_recoil() -> void:
	if _weapon_tween != null and _weapon_tween.is_running():
		_weapon_tween.kill()
	var home := Vector3(0.22, -0.29, -0.92) if _aiming else _hand_anchor_home
	_weapon_tween = create_tween()
	_weapon_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(_hand_anchor, "position", home + Vector3(0.0, 0.025, 0.16), 0.045)
	_weapon_tween.parallel().tween_property(_hand_anchor, "rotation", Vector3(-0.11, 0.0, 0.0), 0.045)
	_weapon_tween.tween_property(_hand_anchor, "position", home, 0.13)
	_weapon_tween.parallel().tween_property(_hand_anchor, "rotation", Vector3.ZERO, 0.13)


func _play_reload_animation() -> void:
	if _weapon_tween != null and _weapon_tween.is_running():
		_weapon_tween.kill()
	var home := Vector3(0.22, -0.29, -0.92) if _aiming else _hand_anchor_home
	_weapon_tween = create_tween()
	_weapon_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_weapon_tween.tween_property(_hand_anchor, "position", home + Vector3(0.0, -0.19, 0.08), 0.24)
	_weapon_tween.parallel().tween_property(_hand_anchor, "rotation", Vector3(0.18, 0.0, 0.12), 0.24)
	_weapon_tween.tween_interval(0.18)
	_weapon_tween.tween_property(_hand_anchor, "position", home, 0.32)
	_weapon_tween.parallel().tween_property(_hand_anchor, "rotation", Vector3.ZERO, 0.32)


func _trigger_muzzle_flash() -> void:
	if _muzzle_flash == null or _muzzle_light == null:
		return
	_muzzle_flash.visible = true
	_muzzle_light.visible = true
	_muzzle_light.light_energy = 3.5
	_muzzle_flash_timer = 0.075



func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -1.0, 0.65)
		camera_pivot.rotation.x = camera_pitch
	if event.is_action_pressed("interact"):
		_interact_with_world()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_melee_attack()
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_set_aiming(event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire_weapon()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload_weapon()


func _process(delta: float) -> void:
	_animate_dara_visual(delta)
	if _muzzle_flash_timer <= 0.0:
		return
	_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - delta)
	if _muzzle_flash_timer <= 0.0:
		if _muzzle_flash != null:
			_muzzle_flash.visible = false
		if _muzzle_light != null:
			_muzzle_light.light_energy = 0.0
			_muzzle_light.visible = false


func _animate_dara_visual(delta: float) -> void:
	# Layered procedural locomotion: gait, upper-body counter-motion,
	# foot clearance, sprint posture and landing absorption.
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var movement_weight := clampf(horizontal_speed / maxf(sprint_speed, 0.01), 0.0, 1.0)
	var sprint_weight := clampf((horizontal_speed - walk_speed) / maxf(sprint_speed - walk_speed, 0.01), 0.0, 1.0)
	var airborne := not is_on_floor()
	if _dara_was_airborne and not airborne and velocity.y < -1.0:
		_landing_compression = clampf(absf(velocity.y) * 0.018, 0.0, 0.22)
	_dara_was_airborne = airborne
	_landing_compression = move_toward(_landing_compression, 0.0, delta * 1.7)
	_damage_reaction_timer = maxf(_damage_reaction_timer - delta, 0.0)
	_damage_reaction_strength = move_toward(_damage_reaction_strength, 0.0, delta * 2.8)

	if is_dead:
		movement_weight = 0.0
		sprint_weight = 0.0
	_dara_animation_time += delta * lerpf(1.0, 1.65, sprint_weight)
	var phase := _dara_animation_time * lerpf(7.2, 10.2, sprint_weight)
	var left_phase := sin(phase)
	var right_phase := sin(phase + PI)
	var left_lift := maxf(0.0, cos(phase)) * movement_weight
	var right_lift := maxf(0.0, cos(phase + PI)) * movement_weight
	var breath := sin(_dara_animation_time * 2.0) * 0.012
	var air_pose := 1.0 if airborne else 0.0
	var strafe := 0.0
	if horizontal_speed > 0.15:
		var local_velocity := global_transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		strafe = clampf(local_velocity.x / sprint_speed, -1.0, 1.0)

	var targets := {
		"TorsoArmor": Vector3(-0.10 * sprint_weight + breath + _landing_compression, 0.0, -strafe * 0.10),
		"Head": Vector3(0.035 * movement_weight - breath * 0.5 - air_pose * 0.06 + _damage_reaction_strength * 0.16, 0.0, strafe * 0.045 + _damage_reaction_strength * 0.12),
		"Shoulder_-1.0": Vector3(-left_phase * 0.22 * movement_weight, 0.0, 0.0),
		"Shoulder_1.0": Vector3(-right_phase * 0.22 * movement_weight, 0.0, 0.0),
		"UpperArm_-1.0": Vector3(-left_phase * 0.48 * movement_weight - 0.12 - (0.52 if _aiming else 0.0) - _melee_animation * 0.9, 0.0, -strafe * 0.08 - _melee_animation * 0.22),
		"UpperArm_1.0": Vector3(-right_phase * 0.48 * movement_weight - 0.12 - (0.52 if _aiming else 0.0), 0.0, -strafe * 0.08),
		"Forearm_-1.0": Vector3(-0.18 - maxf(0.0, left_phase) * 0.16 * movement_weight - (0.62 if _aiming else 0.0) - _melee_animation * 0.55, 0.0, 0.0),
		"Forearm_1.0": Vector3(-0.18 - maxf(0.0, right_phase) * 0.16 * movement_weight - (0.62 if _aiming else 0.0), 0.0, 0.0),
		"Thigh_-1.0": Vector3(left_phase * lerpf(0.42, 0.68, sprint_weight) * movement_weight - air_pose * 0.28, 0.0, 0.0),
		"Thigh_1.0": Vector3(right_phase * lerpf(0.42, 0.68, sprint_weight) * movement_weight - air_pose * 0.28, 0.0, 0.0),
		"Shin_-1.0": Vector3(maxf(0.0, -left_phase) * 0.72 * movement_weight + left_lift * 0.16, 0.0, 0.0),
		"Shin_1.0": Vector3(maxf(0.0, -right_phase) * 0.72 * movement_weight + right_lift * 0.16, 0.0, 0.0),
		"Boot_-1.0": Vector3(-left_lift * 0.28 + _landing_compression * 0.45, 0.0, 0.0),
		"Boot_1.0": Vector3(-right_lift * 0.28 + _landing_compression * 0.45, 0.0, 0.0)
	}
	for part_name in targets:
		var part: Node3D = _dara_visual_nodes.get(part_name) as Node3D
		if part != null:
			var blend := clampf(delta * (14.0 if movement_weight > 0.05 else 7.0), 0.0, 1.0)
			part.rotation = part.rotation.lerp(targets[part_name], blend)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	melee_cooldown_timer = maxf(melee_cooldown_timer - delta, 0.0)
	_melee_animation = move_toward(_melee_animation, 0.0, delta * 3.6)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := input_vector.length_squared() > 0.01
	var sprinting := moving and Input.is_action_pressed("sprint") and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - stamina_drain_per_second * delta, 0.0)
		stamina_regen_timer = stamina_regen_delay
	else:
		stamina_regen_timer = maxf(stamina_regen_timer - delta, 0.0)
		if stamina_regen_timer <= 0.0:
			stamina = minf(stamina + stamina_regen_per_second * delta, stamina_max)
	var speed := sprint_speed if sprinting else walk_speed
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	if direction.length_squared() > 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 7.0 * delta)
	move_and_slide()
	stamina_changed.emit(stamina, stamina_max)


func take_damage(amount: float, _source: Node = null) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_damage_reaction_timer = 0.22
	_damage_reaction_strength = minf(_damage_reaction_strength + 0.65, 1.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_dead = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func respawn() -> void:
	is_dead = false
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	health = max_health
	stamina = stamina_max
	ammo_in_magazine = magazine_size
	shot_cooldown = 0.0
	stamina_regen_timer = 0.0
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, stamina_max)
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _melee_attack() -> void:
	if is_dead or melee_cooldown_timer > 0.0:
		return
	melee_cooldown_timer = melee_cooldown
	_melee_animation = 1.0
	_aiming = false
	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * melee_range)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider is Node and collider.is_in_group("damageable") and collider.has_method("take_damage"):
		collider.call("take_damage", melee_damage, self)


func _fire_weapon() -> void:
	if is_dead or shot_cooldown > 0.0:
		return
	if ammo_in_magazine <= 0:
		return
	shot_cooldown = shot_interval
	_play_weapon_recoil()
	_trigger_muzzle_flash()
	ammo_in_magazine -= 1
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * weapon_range)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node and collider.is_in_group("damageable") and collider.has_method("take_damage"):
			collider.call("take_damage", weapon_damage, self)


func _reload_weapon() -> void:
	if is_dead or ammo_in_magazine >= magazine_size or reserve_ammo <= 0:
		return
	var needed := magazine_size - ammo_in_magazine
	var loaded := mini(needed, reserve_ammo)
	_play_reload_animation()
	ammo_in_magazine += loaded
	reserve_ammo -= loaded
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)

func _interact_with_world() -> void:
	if is_instance_valid(_held_item):
		_drop_held_item()
		return
	# Mission markers are placed ahead of Dara while the third-person camera
	# sits behind her. Use a longer ray for objective interaction only.
	var origin := camera.global_position
	var objective_end := origin + (-camera.global_transform.basis.z * 12.0)
	var objective_query := PhysicsRayQueryParameters3D.create(origin, objective_end)
	objective_query.exclude = [get_rid()]
	objective_query.collide_with_areas = false
	var objective_hit := get_world_3d().direct_space_state.intersect_ray(objective_query)
	if not objective_hit.is_empty():
		var objective_collider: Object = objective_hit.get("collider")
		if objective_collider is StaticBody3D and objective_collider.is_in_group("mission_objective") and objective_collider.has_method("interact"):
			objective_collider.call("interact")
			return
	# Keep ordinary pickups close to the player.
	var pickup_end := origin + (-camera.global_transform.basis.z * 3.5)
	var pickup_query := PhysicsRayQueryParameters3D.create(origin, pickup_end)
	pickup_query.exclude = [get_rid()]
	pickup_query.collide_with_areas = false
	var pickup_hit := get_world_3d().direct_space_state.intersect_ray(pickup_query)
	if pickup_hit.is_empty():
		return
	var pickup_collider: Object = pickup_hit.get("collider")
	if pickup_collider is StaticBody3D and pickup_collider.is_in_group("world_pickup"):
		_pick_up_item(pickup_collider as Node3D)

func _pick_up_item(item: Node3D) -> void:
	if not is_instance_valid(item) or _held_item != null:
		return
	_held_item = item
	item.set_meta("original_collision_layer", item.collision_layer if item is CollisionObject3D else 1)
	if item is CollisionObject3D:
		item.collision_layer = 0
		item.collision_mask = 0
	item.reparent(_hand_anchor, true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "position", Vector3.ZERO, 0.28)
	tween.parallel().tween_property(item, "rotation", Vector3.ZERO, 0.28)
	if item.has_method("set_being_held"):
		item.call("set_being_held", true)


func _drop_held_item() -> void:
	if not is_instance_valid(_held_item):
		_held_item = null
		return
	var item := _held_item
	_held_item = null
	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * 2.2)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var destination := end
	if not hit.is_empty():
		destination = hit.position + Vector3.UP * 0.45
	var world_parent := get_tree().current_scene
	item.reparent(world_parent, true)
	if item is CollisionObject3D:
		item.collision_layer = int(item.get_meta("original_collision_layer", 1))
		item.collision_mask = 1
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", destination, 0.32)
	if item.has_method("set_being_held"):
		item.call("set_being_held", false)
