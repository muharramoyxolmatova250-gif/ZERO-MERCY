extends Node
## Data-driven mission and objective manager for ZERO MERCY.
## Add this script as an Autoload named MissionManager in Project Settings.

signal mission_started(mission_id: String, title: String)
signal objective_updated(mission_id: String, objective_id: String, current: int, target: int)
signal objective_completed(mission_id: String, objective_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)

var definitions: Dictionary = {}
var active_mission_id := ""
var active_objective_index := 0
var objective_progress: Dictionary = {}
var completed_missions: Array[String] = []


func _ready() -> void:
	load_definitions("res://data/story/missions.json")


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


func start_mission(mission_id: String) -> bool:
	if not definitions.has(mission_id) or active_mission_id != "":
		return false
	var data: Dictionary = definitions[mission_id]
	active_mission_id = mission_id
	active_objective_index = 0
	objective_progress.clear()
	for objective in data.get("objectives", []):
		objective_progress[str(objective.get("id", ""))] = 0
	mission_started.emit(mission_id, str(data.get("title", mission_id)))
	_emit_current_objective()
	return true


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


func fail_active_mission() -> void:
	if active_mission_id == "":
		return
	var failed_id := active_mission_id
	active_mission_id = ""
	mission_failed.emit(failed_id)


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
	active_mission_id = ""
	if not completed_missions.has(completed_id):
		completed_missions.append(completed_id)
	mission_completed.emit(completed_id)
