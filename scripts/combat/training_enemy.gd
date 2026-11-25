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
	_find_target()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	if _body_mesh != null and _base_material != null:
		_body_mesh.material_override = _base_material
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not is_instance_valid(_target):
		_find_target()
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
		if _attack_cooldown <= 0.0:
			_attack()
	move_and_slide()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node3D:
		_target = players[0] as Node3D


func _attack() -> void:
	_attack_cooldown = attack_interval
	if not is_instance_valid(_target) or not _target.has_method("take_damage"):
		return
	var distance := global_position.distance_to(_target.global_position)
	if distance <= attack_range + 0.5:
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
