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
var reaction_name := ""
var reaction_remaining := 0.0
var reaction_intensity := 0.0
var idle_gesture := ""
var idle_gesture_remaining := 0.0
var idle_gesture_cooldown := 3.0
var rng := RandomNumberGenerator.new()

func setup(body_node: Node3D, head_node: Node3D, left_arm_node: Node3D, right_arm_node: Node3D, left_leg_node: Node3D, right_leg_node: Node3D, phone_node: Node3D, seed_value: int = 1) -> void:
	body = body_node
	head = head_node
	left_arm = left_arm_node
	right_arm = right_arm_node
	left_leg = left_leg_node
	right_leg = right_leg_node
	phone = phone_node
	variation_seed = float(abs(seed_value) % 1000) * 0.013
	rng.seed = abs(seed_value) + 9137
	if is_instance_valid(body):
		body_rest = body.position
	if is_instance_valid(head):
		head_rest = head.rotation

func trigger_reaction(kind: String, intensity: float = 0.7) -> void:
	reaction_name = kind
	reaction_intensity = clampf(intensity, 0.0, 1.0)
	reaction_remaining = 0.45 + reaction_intensity * 0.75

func update_pose(delta: float, speed: float, motion_state: String, activity: String, using_phone: bool, stress: float, goal: String, traits: Dictionary) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	idle_gesture_cooldown = maxf(0.0, idle_gesture_cooldown - dt)
	if idle_gesture_remaining > 0.0:
		idle_gesture_remaining = maxf(0.0, idle_gesture_remaining - dt)
		if idle_gesture_remaining == 0.0:
			idle_gesture = ""
	if idle_gesture_cooldown == 0.0 and speed < 0.08 and activity.is_empty() and not using_phone and reaction_remaining <= 0.0:
		var curiosity := float(traits.get("curiosity", 0.5))
		if rng.randf() < 0.18 + curiosity * 0.16:
			var gestures := ["look_around", "weight_shift", "adjust_sleeve", "brief_stretch", "head_tilt"]
			idle_gesture = gestures[rng.randi_range(0, gestures.size() - 1)]
			idle_gesture_remaining = rng.randf_range(0.7, 1.8)
		idle_gesture_cooldown = rng.randf_range(3.5, 8.5)
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
	if idle_gesture_remaining > 0.0:
		var gesture_weight := sin((1.0 - idle_gesture_remaining / 1.8) * PI)
		if idle_gesture == "look_around" and is_instance_valid(head):
			head.rotation.y += sin(gesture_phase * 0.7) * 0.24 * gesture_weight
		elif idle_gesture == "weight_shift" and is_instance_valid(body):
			body.rotation.z += 0.07 * gesture_weight
		elif idle_gesture == "adjust_sleeve" and is_instance_valid(left_arm):
			left_arm.rotation.x = -0.72 * gesture_weight
		elif idle_gesture == "brief_stretch":
			if is_instance_valid(left_arm): left_arm.rotation.z -= 0.28 * gesture_weight
			if is_instance_valid(right_arm): right_arm.rotation.z += 0.28 * gesture_weight
		elif idle_gesture == "head_tilt" and is_instance_valid(head):
			head.rotation.z += 0.12 * gesture_weight
	if reaction_remaining > 0.0:
		reaction_remaining = maxf(0.0, reaction_remaining - dt)
		var reaction_weight := sin(clampf(reaction_remaining / 1.2, 0.0, 1.0) * PI * 0.5) * reaction_intensity
		match reaction_name:
			"startled", "curious":
				if is_instance_valid(head): head.rotation.x -= 0.18 * reaction_weight
				if is_instance_valid(left_arm): left_arm.rotation.x -= 0.2 * reaction_weight
				if is_instance_valid(right_arm): right_arm.rotation.x -= 0.2 * reaction_weight
			"scared":
				if is_instance_valid(body): body.rotation.x += 0.1 * reaction_weight
				if is_instance_valid(head): head.rotation.x -= 0.12 * reaction_weight
			"angry":
				if is_instance_valid(body): body.rotation.x -= 0.08 * reaction_weight
				if is_instance_valid(left_arm): left_arm.rotation.z -= 0.14 * reaction_weight
			"relieved":
				if is_instance_valid(body): body.position.y += 0.025 * reaction_weight
	if is_instance_valid(phone):
		phone.rotation.x = -0.08 if using_phone else 0.0

func get_pose_snapshot() -> Dictionary:
	return {"gait_phase":phase,"idle_phase":idle_phase,"gesture_phase":gesture_phase}
