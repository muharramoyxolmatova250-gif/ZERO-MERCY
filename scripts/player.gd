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

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch := 0.0
var health: float
var stamina: float
var ammo_in_magazine: int
var shot_cooldown := 0.0
var stamina_regen_timer := 0.0
var is_dead := false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = stamina_max
	ammo_in_magazine = magazine_size
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, stamina_max)
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -1.0, 0.65)
		camera_pivot.rotation.x = camera_pitch
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire_weapon()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload_weapon()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
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


func _fire_weapon() -> void:
	if is_dead or shot_cooldown > 0.0:
		return
	if ammo_in_magazine <= 0:
		return
	shot_cooldown = shot_interval
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
	ammo_in_magazine += loaded
	reserve_ammo -= loaded
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
