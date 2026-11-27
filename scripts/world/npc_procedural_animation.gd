extends RefCounted
## Lightweight procedural pose layers for the current capsule-based resident rig.
## A future imported humanoid skeleton can consume the same motion/activity signals.
var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var phone: Node3D
var phase := 0.0
var idle_phase := 0.0
var gesture_phase := 0.0
var variation_seed := 0.0
var body_rest := Vector3.ZERO
var head_rest := Vector3.ZERO

func setup(body_node: Node3D, head_node: Node3D, left_arm_node: Node3D, right_arm_node: Node3D, left_leg_node: Node3D, right_leg_node: Node3D, phone_node: Node3D, seed_value: int = 1) -> void:
	body = body_node
	head = head_node
	left_arm = left_arm_node
	right_arm = right_arm_node
	left_leg = left_leg_node
	right_leg = right_leg_node
	phone = phone_node
	variation_seed = float(abs(seed_value) % 1000) * 0.013
	if is_instance_valid(body):
		body_rest = body.position
	if is_instance_valid(head):
		head_rest = head.rotation

func update_pose(delta: float, speed: float, motion_state: String, activity: String, using_phone: bool, stress: float, goal: String, traits: Dictionary) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	phase = fposmod(phase + dt * (3.2 + speed * 5.0), TAU)
	idle_phase = fposmod(idle_phase + dt * (0.8 + variation_seed * 0.08), TAU)
	gesture_phase = fposmod(gesture_phase + dt * 1.7, TAU)
	var moving := motion_state == "moving" or motion_state == "slowing"
	var gait_weight := clampf(speed / 1.5, 0.0, 1.0) if moving else 0.0
	var stride := sin(phase) * gait_weight
	var arm_swing := 0.58 * stride
	var leg_swing := 0.72 * stride
	var breathing := sin(idle_phase * 1.8 + variation_seed) * 0.012
	var sway := sin(idle_phase + variation_seed) * 0.018 * (1.0 - gait_weight)
	var caution := clampf(stress, 0.0, 1.0)
	if is_instance_valid(body):
		body.position = body_rest + Vector3(0.0, absf(stride) * 0.025 + breathing, sway)
		body.rotation = Vector3(0.025 * caution + sin(phase * 2.0) * 0.018 * gait_weight, sway * 0.7, sin(phase) * 0.025 * gait_weight)
	if is_instance_valid(head):
		head.rotation = head_rest
		head.rotation.x = -0.025 * caution + sin(idle_phase * 0.7 + variation_seed) * 0.025
		head.rotation.y = sin(idle_phase * 0.55 + variation_seed) * 0.11 + sin(phase * 0.5) * 0.025 * gait_weight
		head.rotation.z = sway * 0.65
	if is_instance_valid(left_arm):
		left_arm.rotation.x = arm_swing
		left_arm.rotation.z = -0.08 + sin(idle_phase + variation_seed) * 0.025
	if is_instance_valid(right_arm):
		right_arm.rotation.x = -arm_swing
		right_arm.rotation.z = 0.08 - sin(idle_phase + variation_seed) * 0.025
	if using_phone or activity == "browsing":
		if is_instance_valid(right_arm):
			right_arm.rotation.x = -1.05 + sin(gesture_phase) * 0.035
			right_arm.rotation.z = -0.22
		if is_instance_valid(head):
			head.rotation.x += 0.16
	elif activity == "eating":
		if is_instance_valid(right_arm):
			right_arm.rotation.x = -0.78 + absf(sin(gesture_phase)) * 0.18
	elif activity in ["working", "studying"]:
		if is_instance_valid(left_arm):
			left_arm.rotation.x = -0.48
		if is_instance_valid(right_arm):
			right_arm.rotation.x = -0.52 + sin(gesture_phase * 2.0) * 0.07
	elif activity == "socializing" or goal == "social":
		var talk_gesture := sin(gesture_phase * 1.6) * 0.12
		if is_instance_valid(right_arm):
			right_arm.rotation.x = -0.2 + talk_gesture
		if is_instance_valid(left_arm):
			left_arm.rotation.x = 0.12 - talk_gesture * 0.6
	elif activity == "resting" or goal == "rest":
		if is_instance_valid(body):
			body.rotation.x += 0.07
		if is_instance_valid(left_arm):
			left_arm.rotation.x = 0.18
		if is_instance_valid(right_arm):
			right_arm.rotation.x = 0.18
	if is_instance_valid(left_leg):
		left_leg.rotation.x = leg_swing if moving else sin(idle_phase + variation_seed) * 0.012
	if is_instance_valid(right_leg):
		right_leg.rotation.x = -leg_swing if moving else sin(idle_phase + variation_seed + 1.2) * 0.012
	if is_instance_valid(phone):
		phone.rotation.x = -0.08 if using_phone else 0.0

func get_pose_snapshot() -> Dictionary:
	return {"gait_phase":phase,"idle_phase":idle_phase,"gesture_phase":gesture_phase}
