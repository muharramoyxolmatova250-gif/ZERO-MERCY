extends SceneTree
## Runs the real campaign manager in isolation, without reading or changing player save data.

const MissionManagerScript = preload("res://scripts/story/mission_manager.gd")

func _initialize() -> void:
	var manager = MissionManagerScript.new()
	manager.load_definitions("res://data/story/missions.json")
	manager.load_campaign("res://data/story/campaign_structure.json")
	if manager.definitions.is_empty() or manager.campaign_order.is_empty():
		_fail("Campaign data failed to load.")
		return
	if manager.campaign_order.size() != 38 or manager.side_mission_ids.size() != 25:
		_fail("Expected 38 main missions and 25 side missions; got %d and %d." % [manager.campaign_order.size(), manager.side_mission_ids.size()])
		return
	for mission_id in manager.campaign_order + manager.side_mission_ids:
		if not manager.definitions.has(mission_id):
			_fail("Campaign references missing mission: " + mission_id)
			return
	var initial_credits: int = int(manager.credits)
	if not manager.start_mission("prologue_signal"):
		var first_definition: Dictionary = manager.definitions.get("prologue_signal", {})
		var prerequisites_ok: bool = bool(manager.call("_prerequisites_met", first_definition))
		_fail("The first campaign mission could not be started (definition=%s, active=%s, prerequisites=%s)." % [str(not first_definition.is_empty()), str(manager.active_mission_id), str(prerequisites_ok)])
		return
	for event_id in ["enter_old_market", "interact_beacon", "escort_family_safe"]:
		manager.report_event(event_id)
	if manager.active_mission_id != "":
		_fail("The first mission did not complete after its three objective events.")
		return
	if not manager.completed_missions.has("prologue_signal"):
		_fail("Completed mission was not recorded.")
		return
	if not bool(manager.get_story_flag("family_saved", false)):
		_fail("Mission reward story flag was not applied.")
		return
	if manager.credits != initial_credits + 250:
		_fail("The 250-credit mission reward was not applied.")
		return
	var snapshot: Dictionary = manager.get_campaign_snapshot()
	if int(snapshot.get("main_completed", 0)) != 1 or int(snapshot.get("main_total", 0)) != 38:
		_fail("Campaign snapshot did not record first-mission progress.")
		return
	if not manager.has_next_campaign_mission() or not manager.start_next_campaign_mission():
		_fail("The campaign did not advance to its next available main mission.")
		return
	if manager.active_mission_id != "prologue_aftershock":
		_fail("Campaign order advanced to the wrong mission: " + manager.active_mission_id)
		return
	if str(manager.get_current_objective().get("event", "")) != "reach_safehouse":
		_fail("The second mission did not expose its first objective.")
		return
	manager.report_event("disable_pursuit_drone")
	if str(manager.get_current_objective().get("event", "")) != "reach_safehouse":
		_fail("An out-of-order event incorrectly advanced the mission.")
		return
	print("PASS campaign integration: mission catalog, objective order, rewards, snapshot progress and next-mission unlock.")
	quit(0)

func _fail(message: String) -> void:
	push_error("FAIL campaign integration: " + message)
	quit(1)
