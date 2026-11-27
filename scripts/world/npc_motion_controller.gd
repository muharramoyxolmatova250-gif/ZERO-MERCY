extends RefCounted
## Per-resident smooth locomotion controller. Uses bounded local calculations only.
var citizen_id := ""
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var preferred_speed := 1.25
var acceleration_rate := 3.2
var braking_rate := 5.0
var turn_rate := 5.5
var personal_space := 0.82
var gait_phase := 0.0
var stuck_time := 0.0
var last_position := Vector3.ZERO
var sidestep_sign := 1.0
var motion_state := "idle"
var _noise_phase := 0.0
var _speed_bias := 1.0
var _initialized := false

func initialize(id: String, traits: Dictionary, base_speed: float) -> void:
	citizen_id = id
	preferred_speed = clampf(base_speed, 0.45, 2.8)
	var seed_value := int(abs(hash(id + ":locomotion")))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_speed_bias = rng.randf_range(0.92, 1.08)
	acceleration_rate = rng.randf_range(2.7, 3.8) * (0.9 + float(traits.get("discipline", 0.5)) * 0.15)
	turn_rate = rng.randf_range(4.0, 6.2)
	personal_space = rng.randf_range(0.72, 1.0)
	sidestep_sign = -1.0 if rng.randf() < 0.5 else 1.0
	_initialized = true

func move_toward(actor: Node3D, target: Vector3, delta: float, speed_factor: float, separation: Vector3 = Vector3.ZERO, urgent: bool = false) -> void:
	if not _initialized or not is_instance_valid(actor) or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	var offset := target - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	var desired_direction := Vector3.ZERO
	if distance > 0.015:
		desired_direction = offset / distance
	var desired_speed := preferred_speed * _speed_bias * maxf(0.0, speed_factor)
	if urgent:
		desired_speed *= 1.55
	var arrival_radius := 0.7 if urgent else 1.15
	if distance < arrival_radius:
		desired_speed *= clampf(distance / arrival_radius, 0.0, 1.0)
	var steering := desired_direction + separation * 1.1
	if steering.length_squared() > 0.0001:
		steering = steering.normalized()
	else:
		desired_speed = 0.0
	var desired_velocity := steering * desired_speed
	var rate := acceleration_rate if desired_velocity.length_squared() > velocity.length_squared() else braking_rate
	var next_velocity := velocity.move_toward(desired_velocity, rate * dt)
	acceleration = (next_velocity - velocity) / maxf(dt, 0.0001)
	velocity = next_velocity
	actor.global_position += velocity * dt
	if velocity.length_squared() > 0.0025:
		var facing := atan2(-velocity.x, -velocity.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, facing, clampf(turn_rate * dt, 0.0, 1.0))
		gait_phase = fposmod(gait_phase + velocity.length() * dt * 3.8, TAU)
		motion_state = "moving" if velocity.length() > 0.12 else "slowing"
	else:
		motion_state = "idle"
	_noise_phase = fposmod(_noise_phase + dt * 0.7, TAU)

func stop(actor: Node3D, delta: float) -> void:
	if delta <= 0.0:
		return
	velocity = velocity.move_toward(Vector3.ZERO, braking_rate * minf(delta, 0.05))
	acceleration = Vector3.ZERO
	if is_instance_valid(actor):
		actor.global_position += velocity * minf(delta, 0.05)
	motion_state = "idle"

func snapshot() -> Dictionary:
	return {
		"state": motion_state,
		"velocity": velocity,
		"speed": velocity.length(),
		"acceleration": acceleration,
		"gait_phase": gait_phase,
		"stuck_time": stuck_time
	}
func set_speed_profile(walk: float, run: float, cautious: float) -> void:
	preferred_speed = clampf(walk, 0.45, 2.8)
	acceleration_rate = clampf(2.4 + run * 1.1, 2.4, 4.2)
	braking_rate = clampf(4.2 + cautious * 1.8, 4.2, 6.2)
func get_personal_speed_factor() -> float:
	return _speed_bias
func arrival_speed(distance: float, radius: float, maximum: float) -> float:
	if radius <= 0.0:
		return maximum
	return maximum * smoothstep(0.0, radius, maxf(0.0, distance))
func get_turn_blend(delta: float) -> float:
	return clampf(turn_rate * minf(delta, 0.05), 0.0, 1.0)
