extends Node3D
## Spawns a physical, interactable marker for each active campaign objective.
const TARGET_SCRIPT := preload("res://scripts/story/mission_objective_target.gd")
var _target: StaticBody3D
var _current_objective_id := ""
var _spawn_serial := 0

func _ready() -> void:
    MissionManager.mission_started.connect(_on_mission_started)
    MissionManager.objective_updated.connect(_on_objective_updated)
    MissionManager.objective_completed.connect(_on_objective_completed)
    MissionManager.mission_completed.connect(_on_mission_completed)
    if MissionManager.active_mission_id != "":
        _spawn_current_objective()

func _on_mission_started(_mission_id: String, _title: String) -> void:
    _current_objective_id = ""
    _spawn_current_objective()

func _on_objective_updated(_mission_id: String, objective_id: String, current: int, total: int) -> void:
    if objective_id != _current_objective_id:
        _spawn_current_objective()
    elif is_instance_valid(_target):
        _target.call("set_progress", current, total)

func _on_objective_completed(mission_id: String, objective_id: String) -> void:
    # MissionManager advances its objective index before emitting this signal.
    # Resolve the completed objective by ID instead of reading the now-current one.
    var completed_objective: Dictionary = {}
    var mission_data: Dictionary = MissionManager.definitions.get(mission_id, {})
    for objective_value in mission_data.get("objectives", []):
        if typeof(objective_value) == TYPE_DICTIONARY:
            var objective_data: Dictionary = objective_value
            if str(objective_data.get("id", "")) == objective_id:
                completed_objective = objective_data
                break
    var event_id := str(completed_objective.get("event", ""))
    var dialogue_routes := {
        "meet_unknown_contact": ["intro", "res://data/story/dialogue_intro.json"],
        "confront_denni": ["denni_betrayal", "res://data/story/dialogue_denni_betrayal.json"],
        "recover_yelena_message": ["yelena_last_light", "res://data/story/dialogue_yelena_last_light.json"],
        "confront_biological_father": ["father_reveal", "res://data/story/dialogue_father_reveal.json"],
        "make_throne_decision": ["throne_offer", "res://data/story/dialogue_throne_offer.json"],
        "choose_network_fate": ["final_choice", "res://data/story/dialogue_final_choice.json"],
        "watch_unknown_transmission": ["golden_finger", "res://data/story/dialogue_golden_finger.json"]
    }
    if dialogue_routes.has(event_id) and DialogueManager.dialogue_id == "":
        var route: Array = dialogue_routes[event_id]
        DialogueManager.start_dialogue(str(route[0]), str(route[1]))
    if is_instance_valid(_target):
        _target.queue_free()
    _target = null

func _on_mission_completed(_mission_id: String) -> void:
    if is_instance_valid(_target):
        _target.queue_free()
    _target = null
    _current_objective_id = ""

func _spawn_current_objective() -> void:
    var objective: Dictionary = MissionManager.get_current_objective()
    if objective.is_empty():
        return
    var objective_id := str(objective.get("id", ""))
    if objective_id == _current_objective_id and is_instance_valid(_target):
        _target.call("set_progress", int(objective.get("current", 0)), int(objective.get("target", 1)))
        return
    if is_instance_valid(_target):
        _target.queue_free()
    _target = null
    _current_objective_id = objective_id
    var player := get_parent().get_node_or_null("Dara") as Node3D
    if player == null:
        return
    var forward := -player.global_transform.basis.z.normalized()
    var right := player.global_transform.basis.x.normalized()
    var distance := 24.0 + float(_spawn_serial % 3) * 7.0
    var side_offset := float((_spawn_serial % 3) - 1) * 5.0
    _spawn_serial += 1
    var marker := TARGET_SCRIPT.new() as StaticBody3D
    marker.set("event_id", str(objective.get("event", "")))
    marker.set("display_title", str(objective.get("title", "MISSION OBJECTIVE")))
    marker.set("current", int(objective.get("current", 0)))
    marker.set("target", int(objective.get("target", 1)))
    add_child(marker)
    marker.global_position = player.global_position + forward * distance + right * side_offset + Vector3.UP * 0.4
    _target = marker
