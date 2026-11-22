extends Node3D
## Basic configurable hitscan weapon component.
## Attach under a player camera. Input action "fire" must be defined.
## Targets should expose a HealthComponent child or implement apply_damage(amount).

signal shot_fired
signal hit_confirmed(target: Node, damage: float)
signal ammo_changed(current: int, reserve: int)
signal dry_fire

@export var damage := 25.0
@export var range_m := 120.0
@export var fire_interval := 0.18
@export var magazine_size := 24
@export var reserve_ammo := 120
@export var automatic := true
@export var collision_mask := 1
@export var camera_path: NodePath

var magazine_ammo := 24
var _cooldown := 0.0
var _camera: Camera3D


func _ready() -> void:
	magazine_ammo = magazine_size
	_camera = get_node_or_null(camera_path) as Camera3D
	ammo_changed.emit(magazine_ammo, reserve_ammo)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if automatic and Input.is_action_pressed("fire"):
		try_fire()


func _unhandled_input(event: InputEvent) -> void:
	if not automatic and event.is_action_pressed("fire"):
		try_fire()
	if event.is_action_pressed("reload"):
		reload()


func try_fire() -> void:
	if _cooldown > 0.0:
		return
	if magazine_ammo <= 0:
		dry_fire.emit()
		return
	if _camera == null:
		push_warning("HitscanWeapon: assign camera_path to a Camera3D.")
		return
	_cooldown = fire_interval
	magazine_ammo -= 1
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	shot_fired.emit()
	var origin := _camera.global_position
	var direction := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_m)
	query.collision_mask = collision_mask
	query.exclude = [get_parent().get_rid()] if get_parent() is CollisionObject3D else []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target := hit.get("collider") as Node
	if target == null:
		return
	var health := target.get_node_or_null("HealthComponent")
	if health != null and health.has_method("apply_damage"):
		health.apply_damage(damage)
	elif target.has_method("apply_damage"):
		target.apply_damage(damage)
	else:
		return
	hit_confirmed.emit(target, damage)


func reload() -> void:
	if magazine_ammo >= magazine_size or reserve_ammo <= 0:
		return
	var needed := magazine_size - magazine_ammo
	var loaded := mini(needed, reserve_ammo)
	magazine_ammo += loaded
	reserve_ammo -= loaded
	ammo_changed.emit(magazine_ammo, reserve_ammo)
