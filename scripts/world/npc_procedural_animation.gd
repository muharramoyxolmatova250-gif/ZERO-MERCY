extends RefCounted
const NPCAnimationDirector = preload("res://scripts/world/npc_animation_director.gd")
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
var director = NPCAnimationDirector.new()
var last_director_pose: Dictionary = {}

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
	director.initialize(str(seed_value), {})
	if is_instance_valid(body):
		body_rest = body.position
	if is_instance_valid(head):
		head_rest = head.rotation

func configure_profile(identity: String, traits: Dictionary) -> void:
	director.configure(identity, traits)

func trigger_reaction(kind: String, intensity: float = 0.7) -> void:
	reaction_name = kind
	reaction_intensity = clampf(intensity, 0.0, 1.0)
	reaction_remaining = 0.45 + reaction_intensity * 0.75

func update_pose(delta: float, speed: float, motion_state: String, activity: String, using_phone: bool, stress: float, goal: String, traits: Dictionary, preferred_speed: float = 1.25, urgent: bool = false) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	last_director_pose = director.update(dt, speed, motion_state, activity, using_phone, stress, goal, traits, preferred_speed, urgent)
	idle_gesture = str(last_director_pose.get("gesture", ""))
	idle_gesture_remaining = float(last_director_pose.get("gesture_state", {}).get("remaining", 0.0))
	phase = float(last_director_pose.get("gait", {}).get("phase", phase))
	idle_phase = fposmod(idle_phase + dt * (0.8 + variation_seed * 0.08), TAU)
	gesture_phase = fposmod(gesture_phase + dt * 1.7, TAU)
	var moving := motion_state == "moving" or motion_state == "slowing"
	var gait_weight := float(last_director_pose.get("gait", {}).get("weight", 0.0)) if moving else 0.0
	var stride := float(last_director_pose.get("gait", {}).get("stride", 0.0))
	var profile: Dictionary = last_director_pose.get("profile", {})
	var arm_swing := 0.58 * stride * float(profile.get("arm_swing_scale", 1.0))
	var leg_swing := 0.72 * stride * float(profile.get("stride_scale", 1.0))
	var breathing := sin(idle_phase * 1.8 + variation_seed) * 0.012
	var sway := sin(idle_phase + variation_seed) * 0.018 * (1.0 - gait_weight)
	var caution := clampf(stress, 0.0, 1.0)
	if is_instance_valid(body):
		body.position = body_rest + Vector3(0.0, absf(stride) * 0.025 + breathing, sway)
		body.rotation = Vector3(0.025 * caution + sin(phase * 2.0) * 0.018 * gait_weight, sway * 0.7, sin(phase) * 0.025 * gait_weight)
	if is_instance_valid(head):
		head.rotation = head_rest
		head.rotation.x = -0.025 * caution + sin(idle_phase * 0.7 + variation_seed) * 0.025
		head.rotation.y = sin(idle_phase * 0.55 + variation_seed) * 0.11 * float(profile.get("head_motion_scale", 1.0)) + sin(phase * 0.5) * 0.025 * gait_weight
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
	if not idle_gesture.is_empty():
		var gesture_weight := sin(clampf(float(last_director_pose.get("gesture_state", {}).get("remaining", 0.0)) / 1.7, 0.0, 1.0) * PI * 0.5)
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
		elif idle_gesture == "hand_fidget" and is_instance_valid(right_arm):
			right_arm.rotation.x += sin(gesture_phase * 7.0) * 0.09 * gesture_weight
		elif idle_gesture == "shoulder_roll" and is_instance_valid(body):
			body.rotation.z += sin(gesture_phase * 2.0) * 0.055 * gesture_weight
		elif idle_gesture == "check_surroundings" and is_instance_valid(head):
			head.rotation.y += sin(gesture_phase * 1.4) * 0.2 * gesture_weight
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
	return {"gait_phase":phase,"idle_phase":idle_phase,"gesture_phase":gesture_phase,"idle_gesture":idle_gesture,"reaction":reaction_name if reaction_remaining > 0.0 else "","reaction_remaining":reaction_remaining,"director":director.get_snapshot(),"style":director.profile.style}
