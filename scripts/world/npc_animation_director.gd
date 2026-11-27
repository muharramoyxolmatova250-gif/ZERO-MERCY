extends RefCounted
## Coordinates reusable animation layers and produces one bounded pose description.
const Gait = preload("res://scripts/world/npc_animation_locomotion.gd")
const Gesture = preload("res://scripts/world/npc_animation_gesture.gd")
const Profile = preload("res://scripts/world/npc_animation_profile.gd")
const Catalog = preload("res://scripts/world/npc_animation_catalog.gd")
const Activity = preload("res://scripts/world/npc_animation_activity.gd")
const Blend = preload("res://scripts/world/npc_animation_blend.gd")
const Reaction = preload("res://scripts/world/npc_animation_reaction.gd")
const Combat = preload("res://scripts/world/npc_animation_combat.gd")
const IK = preload("res://scripts/world/npc_animation_ik.gd")
const PoseBuffer = preload("res://scripts/world/npc_animation_pose_buffer.gd")
var gait = Gait.new()
var gesture = Gesture.new()
var profile = Profile.new()
var pose_buffer = PoseBuffer.new()
var last_pose: Dictionary = {}
var initialized := false

func initialize(identity: String, traits: Dictionary) -> void:
	profile.initialize(identity, traits)
	gesture.setup(abs(hash(identity + ":micro-gesture")))
	initialized = true

func update(delta: float, speed: float, motion_state: String, activity: String, using_phone: bool, stress: float, goal: String, traits: Dictionary, preferred_speed: float, urgent: bool = false) -> Dictionary:
	if not initialized:
		initialize("resident", traits)
	var gait_state: Dictionary = gait.update(delta, speed, preferred_speed, urgent)
	var gesture_name := gesture.update(delta, speed, activity, using_phone, float(traits.get("curiosity", 0.5)))
	var clip_name := "phone" if using_phone else ("run" if urgent else ("walk" if speed > 0.08 else "idle_relaxed"))
	if activity in ["working", "studying"]: clip_name = "work"
	elif activity == "socializing" or goal == "social": clip_name = "talk"
	var pose := {
		"clip":clip_name,
		"clip_data":Catalog.get_clip(clip_name),
		"gait":gait_state,
		"gesture":gesture_name,
		"gesture_state":gesture.snapshot(),
		"profile":profile.snapshot(),
		"activity_pose":Activity.get_pose(activity),
		"speed":speed,
		"stress":stress,
		"urgent":urgent
	}
	last_pose = pose.duplicate(true)
	pose_buffer.record(last_pose)
	return pose

func get_snapshot() -> Dictionary:
	return {"initialized":initialized,"last_pose":last_pose.duplicate(true),"gait":gait.snapshot(),"gesture":gesture.snapshot(),"profile":profile.snapshot(),"history":pose_buffer.snapshot()}

func solve_reach(root: Vector2, target: Vector2, upper_length: float, lower_length: float) -> Dictionary:
	return IK.solve_two_bone(root, target, upper_length, lower_length)

func get_reaction_pose(kind: String) -> Dictionary:
	return Reaction.get_pose(kind)

func get_combat_stance(kind: String) -> Dictionary:
	return Combat.get_stance(kind)

func blend(current: float, target: float, rate: float, delta: float) -> float:
	return Blend.weight(current, target, rate, delta)
