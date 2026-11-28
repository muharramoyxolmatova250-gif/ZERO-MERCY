extends SceneTree
## Verifies active campaign objectives survive a real SaveManager JSON round trip.

const MissionManagerScript = preload("res://scripts/story/mission_manager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager = root.get_node_or_null("SaveManager")
	if save_manager == null:
		_fail("SaveManager autoload is missing.")
		return
	save_manager.call("delete_save")

	var original = MissionManagerScript.new()
	original.name = "MissionSaveRoundTripSource"
	root.add_child(original)
	if not original.start_mission("prologue_signal"):
		_fail("Could not start the prologue mission.")
		return
	original.report_event("enter_old_market")
	if str(original.get_current_objective().get("event", "")) != "interact_beacon":
		_fail("Source manager did not advance to the beacon objective.")
		return

	var restored = MissionManagerScript.new()
	restored.name = "MissionSaveRoundTripRestore"
	root.add_child(restored)
	if restored.active_mission_id != "prologue_signal":
		_fail("Active mission ID was not restored.")
		return
	if restored.active_objective_index != 1:
		_fail("Active objective index was not restored.")
		return
	if int(restored.objective_progress.get("obj_1", -1)) != 1:
		_fail("Completed objective progress was not restored.")
		return
	if str(restored.get_current_objective().get("event", "")) != "interact_beacon":
		_fail("Restored manager exposed the wrong current objective.")
		return

	restored.report_event("interact_beacon")
	if str(restored.get_current_objective().get("event", "")) != "escort_family_safe":
		_fail("Restored campaign could not continue from its saved objective.")
		return
	restored.report_event("escort_family_safe")
	if not restored.completed_missions.has("prologue_signal"):
		_fail("Completed mission was not recorded before saving.")
		return
	if restored.credits != 250 or not bool(restored.get_story_flag("family_saved", false)):
		_fail("Mission reward credits or story flag were not applied.")
		return

	var final_restore = MissionManagerScript.new()
	final_restore.name = "MissionSaveRoundTripFinalRestore"
	root.add_child(final_restore)
	if not final_restore.completed_missions.has("prologue_signal"):
		_fail("Completed mission state was not restored from the save file.")
		return
	if final_restore.credits != 250 or not bool(final_restore.get_story_flag("family_saved", false)):
		_fail("Completed mission rewards were not restored from the save file.")
		return

	save_manager.call("delete_save")
	print("PASS mission save round trip: active objective progress, continued play, completion, rewards and story flags persist.")
	quit(0)

func _fail(message: String) -> void:
	var save_manager = root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.call("delete_save")
	push_error("FAIL mission save round trip: " + message)
	quit(1)
