extends VehicleBody3D
## Arcade-style starter vehicle controller using Godot VehicleBody3D.
## Configure VehicleWheel3D children in the scene and tune suspension in Inspector.

@export var engine_force_forward := 1800.0
@export var engine_force_reverse := 900.0
@export var brake_force := 45.0
@export var steering_limit := 0.48
@export var steering_response := 4.0
@export var handbrake_force := 75.0
@export var max_speed_kmh := 220.0

var _steering_input := 0.0


func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("vehicle_accelerate") - Input.get_action_strength("vehicle_reverse")
	var steer := Input.get_action_strength("vehicle_right") - Input.get_action_strength("vehicle_left")
	_steering_input = move_toward(_steering_input, steer, steering_response * delta)
	steering = _steering_input * steering_limit

	var speed_kmh := linear_velocity.length() * 3.6
	if throttle > 0.0:
		engine_force = engine_force_forward * throttle if speed_kmh < max_speed_kmh else 0.0
	elif throttle < 0.0 and speed_kmh > 3.0:
		engine_force = 0.0
		brake = brake_force * absf(throttle)
	elif throttle < 0.0:
		engine_force = -engine_force_reverse * absf(throttle)
		brake = 0.0
	else:
		engine_force = 0.0
		brake = 0.0

	if Input.is_action_pressed("vehicle_handbrake"):
		brake = handbrake_force
