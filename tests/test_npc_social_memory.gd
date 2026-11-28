extends SceneTree

const NPCCognition = preload("res://scripts/world/npc_cognition.gd")

func _initialize() -> void:
	_test_help_builds_trust()
	_test_hostility_creates_conflict()
	_test_relationship_history_is_bounded()
	_test_snapshots_are_isolated()
	_test_promises_change_relationships()
	_test_pending_promises_are_filtered()
	print("PASS NPC social memory: trust, conflict, relationship tiers, promises and bounded history.")
	quit()

func _make_mind(identity: String):
	var mind = NPCCognition.new()
	mind.initialize(identity)
	return mind

func _test_help_builds_trust() -> void:
	var mind = _make_mind("social_helper")
	for index in range(8):
		mind.update_social_impression("neighbor_1", "help", 1.0)
	var relation: Dictionary = mind.get_relationship_snapshot("neighbor_1")
	assert(float(relation.get("trust", 0.0)) > 0.8)
	assert(float(relation.get("warmth", 0.0)) > 0.8)
	assert(str(relation.get("relationship", "")) == "close_friend")

func _test_hostility_creates_conflict() -> void:
	var mind = _make_mind("social_conflict")
	mind.update_social_impression("stranger_2", "betray", 0.0)
	var relation: Dictionary = mind.get_relationship_snapshot("stranger_2")
	assert(float(relation.get("trust", 1.0)) < 0.2)
	assert(float(relation.get("conflict", 0.0)) > 0.3)
	assert(str(relation.get("relationship", "")) == "distrustful")

func _test_relationship_history_is_bounded() -> void:
	var mind = _make_mind("social_history")
	for index in range(20):
		mind.update_social_impression("person_3", "conversation", 0.6)
	var relation: Dictionary = mind.get_relationship_snapshot("person_3")
	assert((relation.get("history", []) as Array).size() == 12)
	assert(int(relation.get("interactions", 0)) == 20)

func _test_snapshots_are_isolated() -> void:
	var mind = _make_mind("social_snapshot")
	mind.update_social_impression("person_4", "help", 1.0)
	var snapshot: Dictionary = mind.get_relationship_snapshot("person_4")
	snapshot["trust"] = 0.0
	assert(float(mind.get_relationship_snapshot("person_4").get("trust", 0.0)) > 0.0)

func _test_promises_change_relationships() -> void:
	var mind = _make_mind("promise_keeper")
	var promise: Dictionary = mind.make_personal_promise("friend_5", "Return the borrowed toolkit", 12, 0.9)
	assert(not promise.is_empty())
	assert(str(promise.get("status", "")) == "pending")
	var resolved: Dictionary = mind.resolve_personal_promise(str(promise.get("id", "")), true, 10)
	assert(str(resolved.get("status", "")) == "fulfilled")
	assert(float(mind.get_relationship_snapshot("friend_5").get("trust", 0.0)) > 0.5)
	var broken: Dictionary = mind.make_personal_promise("friend_5", "Attend the meeting", 14, 0.8)
	mind.resolve_personal_promise(str(broken.get("id", "")), false, 15)
	assert(str(mind.get_relationship_snapshot("friend_5").get("last_promise", {}).get("status", "")) == "broken")
	assert(float(mind.get_relationship_snapshot("friend_5").get("trust", 1.0)) < 0.5)

func _test_pending_promises_are_filtered() -> void:
	var mind = _make_mind("promise_filter")
	var first: Dictionary = mind.make_personal_promise("friend_a", "Bring food", 8)
	mind.make_personal_promise("friend_b", "Repair bike", 4)
	var pending: Array[Dictionary] = mind.get_pending_promises("friend_a")
	assert(pending.size() == 1)
	assert(str(pending[0].get("id", "")) == str(first.get("id", "")))
	mind.resolve_personal_promise(str(first.get("id", "")), true, 7)
	assert(mind.get_pending_promises("friend_a").is_empty())
