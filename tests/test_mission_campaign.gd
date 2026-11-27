extends SceneTree
## Exercises the real autoloaded campaign manager from mission start through reward persistence.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := root.get_node_or_null("MissionManager")
	if manager == null:
		_fail("MissionManager autoload is missing.")
		return

	var definitions: Dictionary = manager.get("definitions")
	var main_order: Array = manager.get("campaign_order")
	var side_ids: Array = manager.get("side_mission_ids")
	if definitions.is_empty():
		_fail("Campaign mission definitions did not load.")
		return
	if main_order.size() != 38 or side_ids.size() != 25:
		_fail("Expected 38 main missions and 25 side missions; got %d and %d." % [main_order.size(), side_ids.size()])
		return

	for mission_id in main_order + side_ids:
		if not definitions.has(str(mission_id)):
			_fail("Campaign references a missing mission definition: " + str(mission_id))
			return

	var initial_credits := int(manager.get("credits"))
	if not manager.call("start_mission", "prologue_signal"):
		_fail("The first campaign mission could not be started.")
		return
	var expected_events := ["enter_old_market", "interact_beacon", "escort_family_safe"]
	for event_id in expected_events:
		manager.call("report_event", event_id)
	if str(manager.get("active_mission_id")) != "":
		_fail("The first mission did not complete after all three objective events.")
		return
	var completed: Array = manager.get("completed_missions")
	if not completed.has("prologue_signal"):
		_fail("The completed first mission was not recorded.")
		return
	if not bool(manager.call("get_story_flag", "family_saved", false)):
		_fail("The first mission reward story flag was not applied.")
		return
	if int(manager.get("credits")) != initial_credits + 250:
		_fail("The first mission credit reward was not applied.")
		return

	print("PASS campaign integration: 38 main + 25 side definitions, first mission objectives, completion, story flag and 250-credit reward.")
	quit(0)

func _fail(message: String) -> void:
	push_error("FAIL campaign integration: " + message)
	quit(1)
