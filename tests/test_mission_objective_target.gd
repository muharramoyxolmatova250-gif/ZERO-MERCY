extends SceneTree

const MissionManagerScript = preload("res://scripts/story/mission_manager.gd")
const ObjectiveTargetScript = preload("res://scripts/story/mission_objective_target.gd")

func _initialize() -> void:
	var manager = MissionManagerScript.new()
	manager.name = "MissionManager"
	manager.load_definitions("res://data/story/missions.json")
	manager.load_campaign("res://data/story/campaign_structure.json")
	root.add_child(manager)
	if not manager.start_mission("prologue_signal"):
		_fail("Could not start the first mission.")
		return

	var first_marker = _make_marker("enter_old_market")
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
