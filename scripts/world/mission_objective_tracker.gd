extends Node
## Tracks objective progress and mission completion without hard-coding story content.
signal objective_progress(objective_id: String, current: int, required: int)
signal mission_completed(mission_id: String)
var _missions: Dictionary = {}

func create_mission(mission_id: String, objectives: Array[Dictionary]) -> bool:
	if mission_id.is_empty() or objectives.is_empty() or _missions.has(mission_id):
		return false
	var normalized: Array[Dictionary] = []
	for objective in objectives:
		var objective_id := str(objective.get("id", ""))
		if objective_id.is_empty():
			return false
		normalized.append({"id": objective_id, "description": str(objective.get("description", "")), "required": maxi(1, int(objective.get("required", 1))), "current": 0, "complete": false})
	_missions[mission_id] = {"objectives": normalized, "complete": false}
	return true

func add_progress(mission_id: String, objective_id: String, amount: int = 1) -> bool:
	if not _missions.has(mission_id) or amount <= 0:
		return false
	var mission: Dictionary = _missions[mission_id]
	var objectives: Array = mission.get("objectives", [])
	var found := false
	for index in range(objectives.size()):
		var objective: Dictionary = objectives[index]
		if str(objective.get("id", "")) != objective_id:
			continue
		found = true
		objective["current"] = mini(int(objective.get("required", 1)), int(objective.get("current", 0)) + amount)
		objective["complete"] = int(objective["current"]) >= int(objective["required"])
		objectives[index] = objective
		objective_progress.emit(objective_id, int(objective["current"]), int(objective["required"]))
		break
	if not found:
		return false
	mission["objectives"] = objectives
	var all_complete := true
	for objective in objectives:
		if not bool(objective.get("complete", false)):
			all_complete = false
			break
	if all_complete and not bool(mission.get("complete", false)):
		mission["complete"] = true
		mission_completed.emit(mission_id)
	_missions[mission_id] = mission
	return true

func get_mission(mission_id: String) -> Dictionary:
	return (_missions.get(mission_id, {}) as Dictionary).duplicate(true)

func get_mission_snapshot() -> Dictionary:
	var completed := 0
	for mission in _missions.values():
		if bool(mission.get("complete", false)):
			completed += 1
	return {"missions": _missions.size(), "completed": completed}
