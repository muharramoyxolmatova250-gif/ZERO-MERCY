extends Node
## Persistent-style skill XP and level progression.
signal skill_levelled_up(skill_id: String, new_level: int)
var _skills: Dictionary = {}

func register_skill(skill_id: String, starting_level: int = 1) -> bool:
	if skill_id.is_empty() or _skills.has(skill_id):
		return false
	_skills[skill_id] = {"level": maxi(1, starting_level), "xp": 0.0}
	return true

func add_xp(skill_id: String, amount: float) -> int:
	if not _skills.has(skill_id) or amount <= 0.0:
		return 0
	var skill: Dictionary = _skills[skill_id]
	skill["xp"] = float(skill["xp"]) + amount
	var gained := 0
	while float(skill["xp"]) >= _xp_to_next(int(skill["level"])):
		skill["xp"] = float(skill["xp"]) - _xp_to_next(int(skill["level"]))
		skill["level"] = int(skill["level"]) + 1
		gained += 1
		skill_levelled_up.emit(skill_id, int(skill["level"]))
	_skills[skill_id] = skill
	return gained

func _xp_to_next(level: int) -> float:
	return 100.0 * pow(float(maxi(1, level)), 1.35)

func get_skill(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {}).duplicate(true)

func get_snapshot() -> Dictionary:
	return _skills.duplicate(true)
