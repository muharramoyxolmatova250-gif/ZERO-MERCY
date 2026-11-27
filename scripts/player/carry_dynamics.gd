extends Node
## Weight-aware carry controller for ZERO MERCY.
## Centralizes movement penalties, balance, secondary-hand targets and safe placement.

signal profile_changed(mass_kg: float, fragile: bool)
signal stability_changed(value: float)
signal carry_warning(message: String)

var actor: CharacterBody3D
var held_item: Node3D
var mass_kg := 0.0
var fragile := false
var careful := false
var stability := 1.0
var sway_phase := 0.0
var impact_load := 0.0
var turn_load := 0.0
var _last_horizontal_velocity := Vector3.ZERO
var _last_forward := Vector3.FORWARD
var _warning_cooldown := 0.0

@export_group("Carry tuning")
@export var sprint_mass_limit := 8.0
@export var heavy_mass_limit := 18.0
@export var max_mass_kg := 80.0
@export var minimum_speed_factor := 0.55
@export var balance_recovery := 0.42
@export var fragile_sway_factor := 0.42
@export var heavy_sway_factor := 0.58

func bind_actor(value: CharacterBody3D) -> void:
	actor = value
	_last_horizontal_velocity = Vector3.ZERO
	_last_forward = -actor.global_transform.basis.z

func set_profile(item: Node3D, mass: float, is_fragile: bool, needs_care: bool) -> void:
	held_item = item
	mass_kg = clampf(mass, 0.1, max_mass_kg)
	fragile = is_fragile
	careful = needs_care or is_fragile
	stability = 1.0
	impact_load = 0.0
	turn_load = 0.0
	profile_changed.emit(mass_kg, fragile)
	if mass_kg >= heavy_mass_limit:
		carry_warning.emit("Juda og‘ir buyum: sekin harakatlaning")
	elif fragile:
		carry_warning.emit("Nozik buyum: keskin harakatlardan saqlaning")

func clear_profile() -> void:
	held_item = null
	mass_kg = 0.0
	fragile = false
	careful = false
	stability = 1.0
	impact_load = 0.0
	turn_load = 0.0
	_last_horizontal_velocity = Vector3.ZERO
	profile_changed.emit(0.0, false)

func has_item() -> bool:
	return is_instance_valid(held_item) and mass_kg > 0.0

func get_speed_factor() -> float:
	return clampf(1.0 - mass_kg * 0.025, minimum_speed_factor, 1.0)

func can_sprint() -> bool:
	return mass_kg < sprint_mass_limit and not careful

func get_stamina_drain_factor() -> float:
	return 1.0 + minf(mass_kg * 0.035, 1.8)

func get_jump_factor() -> float:
	return 0.82 if mass_kg >= sprint_mass_limit else 1.0

func get_movement_response() -> float:
	if fragile:
		return 5.5
	if mass_kg >= sprint_mass_limit:
		return 8.0
	return 18.0

func get_sway_factor() -> float:
	if fragile:
		return fragile_sway_factor
	if mass_kg >= sprint_mass_limit:
		return heavy_sway_factor
	return 1.0

func get_secondary_grip_world() -> Vector3:
	if not is_instance_valid(held_item):
		return Vector3.ZERO
	var offset: Vector3 = held_item.get_meta("secondary_grip_offset", Vector3(-0.24, -0.05, -0.10))
	return held_item.global_transform * offset

func get_balance_lean(delta: float) -> Vector3:
	if actor == null:
		return Vector3.ZERO
	var horizontal := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var acceleration := (horizontal - _last_horizontal_velocity) / maxf(delta, 0.001)
	_last_horizontal_velocity = horizontal
	var local_accel := actor.global_transform.basis.inverse() * acceleration
	var target := Vector3(clampf(local_accel.z * 0.012, -0.16, 0.16), 0.0, clampf(-local_accel.x * 0.009, -0.12, 0.12))
	var weight := clampf(mass_kg / 24.0, 0.0, 1.0)
	return target * weight

func update_dynamics(delta: float) -> void:
	if actor == null:
		return
	_warning_cooldown = maxf(0.0, _warning_cooldown - delta)
	sway_phase += delta * (2.2 + Vector2(actor.velocity.x, actor.velocity.z).length() * 0.45)
	var horizontal := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var acceleration := (horizontal - _last_horizontal_velocity) / maxf(delta, 0.001)
	_last_horizontal_velocity = horizontal
	impact_load = move_toward(impact_load, clampf(acceleration.length() / 24.0, 0.0, 1.0), delta * 2.5)
	var forward := -actor.global_transform.basis.z
	var turn_angle := absf(_last_forward.signed_angle_to(forward, Vector3.UP))
	turn_load = move_toward(turn_load, clampf(turn_angle * 1.8, 0.0, 1.0), delta * 3.0)
	_last_forward = forward
	var penalty := impact_load * 0.18 + turn_load * (0.12 if fragile else 0.06)
	stability = clampf(stability + balance_recovery * delta - penalty * delta * 2.0, 0.0, 1.0)
	if stability < 0.35 and _warning_cooldown <= 0.0:
		_warning_cooldown = 2.5
		carry_warning.emit("Muvozanat pasaydi — harakatni sekinlashtiring")
	stability_changed.emit(stability)

func get_secondary_grip_weight() -> float:
	if mass_kg >= sprint_mass_limit:
		return clampf((mass_kg - sprint_mass_limit) / 10.0, 0.35, 1.0)
	return 0.0

func get_safe_drop_position(origin: Vector3, direction: Vector3, exclude: RID) -> Vector3:
	if actor == null:
		return origin + direction.normalized() * 1.4
	var world := actor.get_world_3d()
	if world == null:
		return origin + direction.normalized() * 1.4
	var start := origin + Vector3.UP * 0.1
	var end := start + direction.normalized() * 2.0
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [exclude]
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return end
	return hit.position + Vector3.UP * 0.38

func get_carry_status() -> Dictionary:
	return {
		"mass_kg": mass_kg,
		"fragile": fragile,
		"careful": careful,
		"stability": stability,
		"heavy": mass_kg >= sprint_mass_limit,
		"very_heavy": mass_kg >= heavy_mass_limit
	}


func get_turn_sensitivity() -> float:
	var load := clampf(mass_kg / 30.0, 0.0, 1.0)
	var fragile_factor := 0.78 if fragile else 1.0
	return clampf((1.0 - load * 0.22) * fragile_factor * lerpf(0.82, 1.0, stability), 0.58, 1.0)


func get_acceleration_factor() -> float:
	return clampf(1.0 - mass_kg * 0.018, 0.48, 1.0)

func get_braking_factor() -> float:
	return clampf(1.0 - mass_kg * 0.012, 0.55, 1.0)


func get_gait_sway() -> Vector3:
	var speed := 0.0
	if actor != null:
		speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var amount := minf(speed / 8.0, 1.0) * get_sway_factor()
	return Vector3(sin(sway_phase) * 0.018, absf(cos(sway_phase)) * 0.012, sin(sway_phase * 0.5) * 0.014) * amount


func get_support_hand_profile() -> Dictionary:
	var weight := get_secondary_grip_weight()
	return {"weight": weight, "active": weight > 0.05, "reach_speed": lerpf(7.0, 12.0, weight), "wrist_stiffness": lerpf(0.35, 0.9, weight)}


func get_footstep_intensity() -> float:
	return clampf(0.35 + mass_kg * 0.035 + impact_load * 0.2, 0.0, 1.0)


func get_camera_motion_factor() -> float:
	var weight := clampf(mass_kg / 28.0, 0.0, 1.0)
	return clampf(1.0 - weight * 0.32 - (0.16 if fragile else 0.0), 0.48, 1.0)


func get_setdown_clearance() -> float:
	return 0.34 + clampf(mass_kg * 0.004, 0.0, 0.24)


func get_setdown_transform(position: Vector3, facing: Vector3) -> Transform3D:
	var forward := Vector3(facing.x, 0.0, facing.z).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var basis := Basis.looking_at(forward, Vector3.UP)
	return Transform3D(basis, position + Vector3.UP * get_setdown_clearance())


func get_handling_factor() -> float:
	if not is_instance_valid(held_item):
		return 1.0
	return clampf(float(held_item.get_meta("handling_sensitivity", 1.0)), 0.35, 2.0)


func get_pickup_reach_duration() -> float:
	return clampf(0.22 + mass_kg * 0.008, 0.22, 0.72)
