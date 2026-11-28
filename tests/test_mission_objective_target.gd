extends SceneTree

const MissionManagerScript = preload("res://scripts/story/mission_manager.gd")
const ObjectiveTargetScript = preload("res://scripts/story/mission_objective_target.gd")

func _initialize() -> void:
	var manager = root.get_node_or_null("MissionManager")
	if manager == null:
		manager = MissionManagerScript.new()
		manager.name = "MissionManager"
		root.add_child(manager)
	manager.load_definitions("res://data/story/missions.json")
	manager.load_campaign("res://data/story/campaign_structure.json")
	manager.active_mission_id = ""
	manager.completed_missions.clear()
	manager.story_flags.clear()
	manager.story_choices.clear()
	manager.credits = 0
	if root.get_node_or_null("MissionManager") != manager:
		_fail("Test mission manager is not the root manager used by objective markers.")
		return
	if not manager.start_mission("prologue_signal"):
		_fail("Could not start the first mission.")
		return

	var first_marker = _make_marker("enter_old_market")
	var routed_manager = first_marker.get_tree().root.get_node_or_null("MissionManager")
	if routed_manager != manager:
		_fail("Objective marker resolved a different mission manager instance.")
		return
	first_marker.interact()
	if str(manager.get_current_objective().get("event", "")) != "interact_beacon":
		_fail("First physical marker did not advance to the beacon objective.")
		return

	var out_of_order_marker = _make_marker("escort_family_safe")
	out_of_order_marker.interact()
	if str(manager.get_current_objective().get("event", "")) != "interact_beacon":
		_fail("An out-of-order marker advanced the mission.")
		return

	var second_marker = _make_marker("interact_beacon")
	second_marker.interact()
	if str(manager.get_current_objective().get("event", "")) != "escort_family_safe":
		_fail("Beacon marker did not advance to the escort objective.")
		return

	var final_marker = _make_marker("escort_family_safe")
	final_marker.interact()
	if manager.active_mission_id != "" or not manager.completed_missions.has("prologue_signal"):
		_fail("Final physical marker did not complete the mission.")
		return

	print("PASS objective marker integration: physical interactions advance the correct mission objectives and reject out-of-order events.")
	quit(0)

func _make_marker(event_name: String):
	var marker = ObjectiveTargetScript.new()
	marker.event_id = event_name
	root.add_child(marker)
	return marker

func _fail(message: String) -> void:
	push_error("FAIL objective marker integration: " + message)
	quit(1)
