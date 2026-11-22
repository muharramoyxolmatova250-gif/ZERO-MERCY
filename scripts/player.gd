extends CharacterBody3D

@export var walk_speed := 5.5
@export var sprint_speed := 9.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0025
@export var weapon_damage := 34.0
@export var weapon_range := 100.0
@export var magazine_size := 12
@export var reserve_ammo := 60
@export var shot_interval := 0.18

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch := 0.0
var ammo_in_magazine: int
var shot_cooldown := 0.0

func _ready() -> void:
	add_to_group("player")
	ammo_in_magazine = magazine_size
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
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
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 7.0 * delta)
	move_and_slide()

func _fire_weapon() -> void:
	if shot_cooldown > 0.0:
		return
	if ammo_in_magazine <= 0:
		print("MAGAZINE EMPTY — press R to reload.")
		return
	shot_cooldown = shot_interval
	ammo_in_magazine -= 1

	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * weapon_range)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node and collider.is_in_group("damageable"):
			collider.call("take_damage", weapon_damage, self)
			print("HIT — ammo: ", ammo_in_magazine, "/", reserve_ammo)
		else:
			print("SHOT — ammo: ", ammo_in_magazine, "/", reserve_ammo)
	else:
		print("SHOT — ammo: ", ammo_in_magazine, "/", reserve_ammo)

func _reload_weapon() -> void:
	if ammo_in_magazine >= magazine_size or reserve_ammo <= 0:
		return
	var needed := magazine_size - ammo_in_magazine
	var loaded := mini(needed, reserve_ammo)
	ammo_in_magazine += loaded
	reserve_ammo -= loaded
	print("RELOADED — ammo: ", ammo_in_magazine, "/", reserve_ammo)
