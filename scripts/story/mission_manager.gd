extends Node
## Persistent, data-driven ZERO MERCY campaign, objectives, choices and side missions.
signal mission_started(mission_id: String, title: String)
signal objective_updated(mission_id: String, objective_id: String, current: int, target: int)
signal objective_completed(mission_id: String, objective_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal story_flag_changed(flag_id: String, value: Variant)
signal choice_recorded(choice_id: String, value: String)
signal campaign_advanced(mission_id: String)

const MISSIONS_PATH := "res://data/story/missions.json"
const CAMPAIGN_PATH := "res://data/story/campaign_structure.json"
var definitions: Dictionary = {}
var campaign: Dictionary = {}
var campaign_order: Array[String] = []
var side_mission_ids: Array[String] = []
var active_mission_id := ""
var active_objective_index := 0
var objective_progress: Dictionary = {}
var completed_missions: Array[String] = []
var story_flags: Dictionary = {}
var story_choices: Dictionary = {}
var credits := 0

func _ready() -> void:
    load_definitions(MISSIONS_PATH)
    load_campaign(CAMPAIGN_PATH)
    _restore_progress()

func load_definitions(path: String) -> void:
    if not FileAccess.file_exists(path):
        push_warning("Mission definitions not found: " + path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot read mission definitions: " + path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Mission definitions must be a JSON object.")
        return
    definitions = parsed

func load_campaign(path: String) -> void:
    if not FileAccess.file_exists(path):
        push_warning("Campaign structure not found: " + path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Campaign structure must be a JSON object.")
        return
    campaign = parsed
    campaign_order.clear()
    side_mission_ids.clear()
    for mission_id in campaign.get("main_order", []):
        campaign_order.append(str(mission_id))
    for mission_id in campaign.get("side_missions", []):
        side_mission_ids.append(str(mission_id))

func start_mission(mission_id: String) -> bool:
    if not definitions.has(mission_id) or active_mission_id != "":
        return false
    var data: Dictionary = definitions[mission_id]
    if not _prerequisites_met(data):
        return false
    active_mission_id = mission_id
    active_objective_index = 0
    objective_progress.clear()
    for objective in data.get("objectives", []):
        objective_progress[str(objective.get("id", ""))] = 0
    mission_started.emit(mission_id, str(data.get("title", mission_id)))
    _emit_current_objective()
    _save_progress()
    return true

func start_next_campaign_mission() -> bool:
    if active_mission_id != "":
        return false
    for mission_id in campaign_order:
        if completed_missions.has(mission_id) or not definitions.has(mission_id):
            continue
        var data: Dictionary = definitions[mission_id]
        if _prerequisites_met(data):
            return start_mission(mission_id)
    return false

func has_next_campaign_mission() -> bool:
    if active_mission_id != "":
        return false
    for mission_id in campaign_order:
        if not completed_missions.has(mission_id) and definitions.has(mission_id):
            if _prerequisites_met(definitions[mission_id]):
                return true
    return false

func start_side_mission(mission_id: String) -> bool:
    if not side_mission_ids.has(mission_id):
        return false
    if completed_missions.has(mission_id):
        return false
    return start_mission(mission_id)

func get_available_side_missions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for mission_id in side_mission_ids:
        if completed_missions.has(mission_id) or not definitions.has(mission_id):
            continue
        var data: Dictionary = definitions[mission_id]
        if _prerequisites_met(data):
            result.append({
                "id": mission_id,
                "title": str(data.get("title", mission_id)),
                "description": str(data.get("description", "")),
                "estimated_minutes": int(data.get("estimated_minutes", 30))
            })
    return result

func report_event(event_id: String, amount: int = 1) -> void:
    if active_mission_id == "" or amount <= 0:
        return
    var objectives: Array = definitions[active_mission_id].get("objectives", [])
    if active_objective_index >= objectives.size():
        return
    var objective: Dictionary = objectives[active_objective_index]
    if str(objective.get("event", "")) != event_id:
        return
    var objective_id := str(objective.get("id", ""))
    var target := maxi(1, int(objective.get("target", 1)))
    var current := mini(target, int(objective_progress.get(objective_id, 0)) + amount)
    objective_progress[objective_id] = current
    objective_updated.emit(active_mission_id, objective_id, current, target)
    if current >= target:
        objective_completed.emit(active_mission_id, objective_id)
        active_objective_index += 1
        if active_objective_index >= objectives.size():
            _complete_active_mission()
        else:
            _emit_current_objective()
    _save_progress()

func fail_active_mission() -> void:
    if active_mission_id == "":
        return
    var failed_id := active_mission_id
    active_mission_id = ""
    active_objective_index = 0
    objective_progress.clear()
    mission_failed.emit(failed_id)
    _save_progress()

func set_story_flag(flag_id: String, value: Variant = true) -> void:
    story_flags[flag_id] = value
    story_flag_changed.emit(flag_id, value)
    _save_progress()

func get_story_flag(flag_id: String, fallback: Variant = false) -> Variant:
    return story_flags.get(flag_id, fallback)

func record_choice(choice_id: String, value: String) -> void:
    story_choices[choice_id] = value
    choice_recorded.emit(choice_id, value)
    _save_progress()

func get_choice(choice_id: String, fallback: String = "") -> String:
    return str(story_choices.get(choice_id, fallback))

func get_current_mission_data() -> Dictionary:
    if active_mission_id == "" or not definitions.has(active_mission_id):
        return {}
    return definitions[active_mission_id]

func get_current_objective() -> Dictionary:
    var data := get_current_mission_data()
    if data.is_empty():
        return {}
    var objectives: Array = data.get("objectives", [])
    if active_objective_index < 0 or active_objective_index >= objectives.size():
        return {}
    var objective: Dictionary = objectives[active_objective_index]
    var objective_id := str(objective.get("id", ""))
    return {
        "id": objective_id,
        "title": str(objective.get("title", objective_id)),
        "event": str(objective.get("event", "")),
        "current": int(objective_progress.get(objective_id, 0)),
        "target": maxi(1, int(objective.get("target", 1)))
    }

func get_campaign_snapshot() -> Dictionary:
    var completed_main := 0
    var completed_side := 0
    for mission_id in completed_missions:
        if campaign_order.has(mission_id):
            completed_main += 1
        elif side_mission_ids.has(mission_id):
            completed_side += 1
    var chapter_progress := get_chapter_progress()
    return {
        "title": str(campaign.get("title", "ZERO MERCY")),
        "estimated_total_hours": int(campaign.get("estimated_total_hours", 70)),
        "playtime_breakdown": campaign.get("playtime_breakdown", {}).duplicate(true),
        "main_completed": completed_main,
        "main_total": campaign_order.size(),
        "side_completed": completed_side,
        "side_total": side_mission_ids.size(),
        "chapter_progress": chapter_progress,
        "current_chapter": str(chapter_progress.get("current_chapter_id", "")),
        "credits": credits,
        "active_mission_id": active_mission_id,
        "ending_id": resolve_campaign_ending(),
        "story_flags": story_flags.duplicate(true),
        "choices": story_choices.duplicate(true)
    }


func get_chapter_progress() -> Dictionary:
    var chapters: Array = campaign.get("chapters", [])
    var result: Array[Dictionary] = []
    var current_chapter_id := ""
    var current_chapter_title := ""
    for chapter_value in chapters:
        if typeof(chapter_value) != TYPE_DICTIONARY:
            continue
        var chapter: Dictionary = chapter_value
        var chapter_missions: Array = chapter.get("missions", [])
        var completed := 0
        for mission_value in chapter_missions:
            if completed_missions.has(str(mission_value)):
                completed += 1
        var total := chapter_missions.size()
        var is_complete := total > 0 and completed >= total
        result.append({
            "id": str(chapter.get("id", "")),
            "title": str(chapter.get("title", "")),
            "completed": completed,
            "total": total,
            "is_complete": is_complete
        })
        if current_chapter_id.is_empty() and not is_complete:
            current_chapter_id = str(chapter.get("id", ""))
            current_chapter_title = str(chapter.get("title", ""))
    return {
        "chapters": result,
        "current_chapter_id": current_chapter_id,
        "current_chapter_title": current_chapter_title,
        "completed_chapters": result.filter(func(item: Dictionary) -> bool: return bool(item.get("is_complete", false))).size(),
        "total_chapters": result.size()
    }


func resolve_campaign_ending() -> String:
    if bool(story_flags.get("throne_rejected", false)) and bool(story_flags.get("control_system_destroyed", false)):
        return "no_crown"
    if not bool(story_flags.get("throne_rejected", false)) and bool(story_flags.get("global_protocol_revealed", false)):
        return "sovereign"
    if not bool(story_flags.get("world_protocol_activated", false)) or not bool(story_flags.get("network_stabilized", false)):
        return "fractured_world"
    return ""

func _prerequisites_met(data: Dictionary) -> bool:
    for flag_id in data.get("required_flags", []):
        if not bool(story_flags.get(str(flag_id), false)):
            return false
    for mission_id in data.get("required_missions", []):
        if not completed_missions.has(str(mission_id)):
            return false
    return true

func _emit_current_objective() -> void:
    if active_mission_id == "":
        return
    var objectives: Array = definitions[active_mission_id].get("objectives", [])
    if active_objective_index >= objectives.size():
        _complete_active_mission()
        return
    var objective: Dictionary = objectives[active_objective_index]
    var objective_id := str(objective.get("id", ""))
    objective_updated.emit(
        active_mission_id,
        objective_id,
        int(objective_progress.get(objective_id, 0)),
        maxi(1, int(objective.get("target", 1)))
    )

func _complete_active_mission() -> void:
    var completed_id := active_mission_id
    var data: Dictionary = definitions.get(completed_id, {})
    var reward: Dictionary = data.get("reward", {})
    active_mission_id = ""
    active_objective_index = 0
    objective_progress.clear()
    if not completed_missions.has(completed_id):
        completed_missions.append(completed_id)
    credits += int(reward.get("credits", 0))
    var reward_flag := str(reward.get("story_flag", ""))
    if not reward_flag.is_empty():
        story_flags[reward_flag] = true
        story_flag_changed.emit(reward_flag, true)
    mission_completed.emit(completed_id)
    campaign_advanced.emit(completed_id)
    _save_progress()

func _restore_progress() -> void:
    if not has_node("/root/SaveManager"):
        return
    var payload: Dictionary = SaveManager.load_game()
    completed_missions.clear()
    for mission_id in payload.get("completed_missions", []):
        completed_missions.append(str(mission_id))
    story_flags = payload.get("story_flags", {})
    story_choices = payload.get("story_choices", {})
    credits = int(payload.get("credits", 0))
    var saved_active := str(payload.get("active_mission_id", ""))
    if saved_active != "" and definitions.has(saved_active) and not completed_missions.has(saved_active):
        active_mission_id = saved_active
        active_objective_index = int(payload.get("active_objective_index", 0))
        objective_progress = payload.get("objective_progress", {})
        var objectives: Array = definitions[saved_active].get("objectives", [])
        active_objective_index = clampi(active_objective_index, 0, maxi(0, objectives.size() - 1))

func _save_progress() -> void:
    if not has_node("/root/SaveManager"):
        return
    var payload: Dictionary = SaveManager.load_game()
    payload["completed_missions"] = completed_missions
    payload["story_flags"] = story_flags
    payload["story_choices"] = story_choices
    payload["credits"] = credits
    payload["active_mission_id"] = active_mission_id
    payload["active_objective_index"] = active_objective_index
    payload["objective_progress"] = objective_progress
    SaveManager.save_game(payload)
