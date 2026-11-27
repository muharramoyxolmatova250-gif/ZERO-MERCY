extends SceneTree

const NPCSelfDirection = preload("res://scripts/world/npc_self_direction.gd")

func _initialize() -> void:
	_test_failed_goal_learning()
	_test_personal_boundaries()
	_test_activity_preference_learning()
	_test_agency_state_round_trip()
	print("PASS NPC self-direction: failure learning, personal boundaries, activity preferences and state persistence.")
	quit()

func _make_agent():
	var agent = NPCSelfDirection.new()
	agent.initialize("resident_test_001", {"curiosity":0.8,"discipline":0.7,"ambition":0.6,"risk_tolerance":0.4})
	return agent

func _test_failed_goal_learning() -> void:
	var agent = _make_agent()
	agent.record_goal_outcome("learn_skill", 0.1, false)
	assert(agent.goal_failure_penalty("learn_skill") > 0.0)
	agent.record_goal_outcome("learn_skill", 0.9, true)
	assert(is_equal_approx(agent.goal_failure_penalty("learn_skill"), 0.0))

func _test_personal_boundaries() -> void:
	var agent = _make_agent()
	agent.set_personal_boundary("discovery", true)
	var blocked: Dictionary = agent.choose_from_candidates([
		{"id":"explore_test","activity":"explore","drive":"curiosity","weight":1.0,"need":"discovery"}
	], {"available_time":1.0})
	assert(blocked.is_empty())
	agent.set_personal_boundary("discovery", false)
	var allowed: Dictionary = agent.choose_from_candidates([
		{"id":"explore_test","activity":"explore","drive":"curiosity","weight":1.0,"need":"discovery"}
	], {"available_time":1.0})
	assert(not allowed.is_empty())

func _test_activity_preference_learning() -> void:
	var agent = _make_agent()
	var before := agent.score_goal_candidate({"id":"work_test","activity":"work","drive":"ambition","weight":0.5})
	agent.update_personal_interest_from_activity("work", 1.0)
	var after := agent.score_goal_candidate({"id":"work_test","activity":"work","drive":"ambition","weight":0.5})
	assert(after > before)

func _test_agency_state_round_trip() -> void:
	var original = _make_agent()
	original.record_goal_outcome("practice_hobby", 0.85, true)
	original.create_long_term_ambition("become a skilled engineer", "work")
	var state: Dictionary = original.serialize_agency_state()
	var restored = _make_agent()
	restored.restore_agency_state(state)
	assert(restored.get_snapshot().get("completed_goal_count", 0) == 1)
	assert(restored.aspirations.size() == original.aspirations.size())
	assert(restored.preferences.has("practice_hobby"))
