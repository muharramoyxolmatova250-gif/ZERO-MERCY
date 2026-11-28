extends SceneTree

const NPCProceduralAnimation = preload("res://scripts/world/npc_procedural_animation.gd")

func _initialize() -> void:
	_test_delayed_reaction_event()
	_test_queued_gesture_survives_director_pose()
	print("PASS NPC animation events: delayed dispatch and timed gesture override.")
	quit(0)

func _test_delayed_reaction_event() -> void:
	var animation = NPCProceduralAnimation.new()
	animation.queue_animation_event("reaction", {"reaction":"startled", "intensity":0.9}, 0.5)
	animation.call("_dispatch_animation_events", 0.2)
	assert(str(animation.reaction_name) == "")
	animation.call("_dispatch_animation_events", 0.3)
	assert(str(animation.reaction_name) == "startled")
	assert(float(animation.reaction_remaining) > 0.0)

func _test_queued_gesture_survives_director_pose() -> void:
	var animation = NPCProceduralAnimation.new()
	animation.queue_animation_event("gesture", {"gesture":"check_surroundings", "duration":0.8})
	animation.update_pose(0.1, 0.0, "idle", "idle", false, 0.0, "idle", {})
	assert(str(animation.idle_gesture) == "check_surroundings")
	assert(float(animation.queued_gesture_remaining) > 0.0)
	animation.update_pose(0.1, 0.0, "idle", "idle", false, 0.0, "idle", {})
	assert(str(animation.idle_gesture) == "check_surroundings")
