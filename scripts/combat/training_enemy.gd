extends CharacterBody3D
## First hostile combatant: detects Dara, pursues her and attacks at close range.

@export var max_health: float = 120.0
@export var move_speed: float = 3.8
@export var detection_range: float = 28.0
@export var attack_range: float = 1.9
@export var attack_damage: float = 12.0
@export var attack_interval: float = 1.25
@export var turn_speed: float = 7.0

var health: float
var _attack_cooldown := 0.0
var _target: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body_mesh: MeshInstance3D
var _base_material: StandardMaterial3D
var _flash_time := 0.0
var _attack_windup_remaining := 0.0
var _attack_pending := false
var _visor_material: StandardMaterial3D
var _animation_time := 0.0
var _visual_parts: Dictionary = {}


func _ready() -> void:
	health = max_health
	add_to_group("damageable")
	_body_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _body_mesh != null:
		_base_material = StandardMaterial3D.new()
		_base_material.albedo_color = Color(0.16, 0.055, 0.09)
		_base_material.metallic = 0.62
		_base_material.roughness = 0.3
		_base_material.emission_enabled = true
		_base_material.emission = Color(0.65, 0.025, 0.12)
		_base_material.emission_energy_multiplier = 0.35
		_body_mesh.material_override = _base_material
	_build_enemy_visual()
	_find_target()


func _build_enemy_visual() -> void:
	# Layered 3D hostile armor silhouette with emissive cybernetic details.
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.035, 0.018, 0.03)
	armor.metallic = 0.88
	armor.roughness = 0.22
	armor.clearcoat_enabled = true
	armor.clearcoat = 0.9
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color(0.055, 0.045, 0.06)
	fabric.roughness = 0.82
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.95, 0.025, 0.08)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.015, 0.045)
	red.emission_energy_multiplier = 2.0
	_visor_material = red
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(1.0, 0.28, 0.035)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.12, 0.01)
	amber.emission_energy_multiplier = 1.1
	_add_armor_capsule("Helmet", Vector3(0.0, 1.73, 0.0), 0.27, 0.38, armor)
	_add_armor_box("FaceVisor", Vector3(0.0, 1.76, -0.245), Vector3(0.32, 0.075, 0.035), red)
	_add_armor_box("ChestPlate", Vector3(0.0, 1.22, -0.29), Vector3(0.62, 0.38, 0.12), armor)
	_add_armor_box("ChestEmblem", Vector3(0.0, 1.24, -0.36), Vector3(0.12, 0.22, 0.025), amber)
	_add_armor_box("BackPowerCell", Vector3(0.0, 1.26, 0.25), Vector3(0.34, 0.42, 0.16), armor)
	for side in [-1.0, 1.0]:
		_add_armor_capsule("Shoulder_%s" % side, Vector3(side * 0.43, 1.43, 0.0), 0.19, 0.34, armor)
		_add_armor_capsule("Arm_%s" % side, Vector3(side * 0.47, 1.04, 0.0), 0.13, 0.62, fabric)
		_add_armor_box("ForearmPlate_%s" % side, Vector3(side * 0.48, 0.84, -0.1), Vector3(0.2, 0.32, 0.18), armor)
		_add_armor_capsule("Leg_%s" % side, Vector3(side * 0.17, 0.31, 0.0), 0.15, 0.58, fabric)
		_add_armor_box("Knee_%s" % side, Vector3(side * 0.17, 0.39, -0.13), Vector3(0.22, 0.17, 0.08), red)
	_add_armor_box("ShoulderMark", Vector3(-0.44, 1.49, -0.13), Vector3(0.18, 0.1, 0.035), amber)


func _add_armor_capsule(part_name: String, part_position: Vector3, radius: float, height: float, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 10
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	add_child(part)
	_visual_parts[part_name] = part


func _add_armor_box(part_name: String, part_position: Vector3, part_size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	add_child(part)
	_visual_parts[part_name] = part


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	if _body_mesh != null and _base_material != null and _flash_time <= 0.0:
		_body_mesh.material_override = _base_material
	if _attack_pending:
		_attack_windup_remaining = maxf(0.0, _attack_windup_remaining - delta)
		if _visor_material != null:
			_visor_material.emission_energy_multiplier = 3.8 if fmod(_attack_windup_remaining * 8.0, 1.0) > 0.5 else 1.4
		if _attack_windup_remaining <= 0.0:
			_attack_pending = false
			if _visor_material != null:
				_visor_material.emission_energy_multiplier = 2.0
			_resolve_attack()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not is_instance_valid(_target):
		_find_target()
	if is_instance_valid(_target) and bool(_target.get("is_dead")):
		_target = null
	if not is_instance_valid(_target):
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 3.0)
		move_and_slide()
		return

	var offset := _target.global_position - global_position
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	var distance := flat_offset.length()
	if distance > detection_range:
		_target = null
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 3.0)
		move_and_slide()
		return

	if distance > 0.08:
		var desired_yaw := atan2(-flat_offset.x, -flat_offset.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	if distance > attack_range:
		var direction := flat_offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		if _attack_cooldown <= 0.0 and not _attack_pending:
			_start_attack()
	_animate_enemy(delta)
	move_and_slide()


func _animate_enemy(delta: float) -> void:
	_animation_time += delta
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var gait := _animation_time * 8.5
	var moving_weight := clampf(planar_speed / maxf(move_speed, 0.01), 0.0, 1.0)
	var attack_weight := 1.0 if _attack_pending else 0.0
	for side in [-1.0, 1.0]:
		var arm_name := "Arm_%s" % side
		var leg_name := "Leg_%s" % side
		var arm := _visual_parts.get(arm_name) as MeshInstance3D
		var leg := _visual_parts.get(leg_name) as MeshInstance3D
		var phase := sin(gait + (PI if side > 0.0 else 0.0))
		if arm != null:
			arm.rotation.x = phase * 0.48 * moving_weight - attack_weight * 0.72
		if leg != null:
			leg.rotation.x = -phase * 0.62 * moving_weight
	var chest := _visual_parts.get("ChestPlate") as MeshInstance3D
	if chest != null:
		chest.rotation.x = -0.12 * moving_weight + 0.22 * attack_weight
	var helmet := _visual_parts.get("Helmet") as MeshInstance3D
	if helmet != null:
		helmet.rotation.z = sin(_animation_time * 1.7) * 0.025


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node3D:
		_target = players[0] as Node3D


func _start_attack() -> void:
	# A short readable wind-up gives the player time to dodge or interrupt.
	_attack_pending = true
	_attack_windup_remaining = 0.42
	_attack_cooldown = attack_interval


func _resolve_attack() -> void:
	if not is_instance_valid(_target) or not _target.has_method("take_damage"):
		return
	if bool(_target.get("is_dead")):
		return
	var target_position := _target.global_position + Vector3.UP * 0.9
	var attack_origin := global_position + Vector3.UP * 1.0
	var distance := global_position.distance_to(_target.global_position)
	if distance > attack_range + 0.5:
		return
	# Do not damage Dara through solid architecture.
	var query := PhysicsRayQueryParameters3D.create(attack_origin, target_position)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_collider: Object = hit.get("collider")
	if hit_collider == _target:
		_target.call("take_damage", attack_damage, self)

func take_damage(amount: float, _source: Node = null) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if _body_mesh != null:
		var hit_material := StandardMaterial3D.new()
		hit_material.albedo_color = Color(1.0, 0.12, 0.2)
		hit_material.emission_enabled = true
		hit_material.emission = Color(1.0, 0.02, 0.08)
		hit_material.emission_energy_multiplier = 2.0
		_body_mesh.material_override = hit_material
		_flash_time = 0.12
	print("HOSTILE HP: ", int(health), "/", int(max_health))
	if health <= 0.0:
		print("Hostile eliminated.")
		queue_free()
