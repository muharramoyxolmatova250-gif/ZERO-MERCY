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
	var initial_credits := manager.credits
	if not manager.start_mission("prologue_signal"):
		_fail("The first campaign mission could not be started.")
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
	print("PASS campaign integration: 38 main + 25 side definitions, mission objectives, completion, story flag and reward.")
	quit(0)

func _fail(message: String) -> void:
	push_error("FAIL campaign integration: " + message)
	quit(1)
