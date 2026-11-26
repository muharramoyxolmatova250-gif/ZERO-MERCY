extends Node
## Tracks player standing with world factions and relationship thresholds.
signal reputation_changed(faction_id: String, value: int)
var _reputation: Dictionary = {}
var minimum_reputation := -100
var maximum_reputation := 100

func register_faction(faction_id: String, starting_reputation: int = 0) -> bool:
	if faction_id.is_empty() or _reputation.has(faction_id):
		return false
	_reputation[faction_id] = clampi(starting_reputation, minimum_reputation, maximum_reputation)
	return true

func change_reputation(faction_id: String, amount: int) -> int:
	if not _reputation.has(faction_id):
		return 0
	var value := clampi(int(_reputation[faction_id]) + amount, minimum_reputation, maximum_reputation)
	_reputation[faction_id] = value
	reputation_changed.emit(faction_id, value)
	return value

func get_reputation(faction_id: String) -> int:
	return int(_reputation.get(faction_id, 0))

func get_relationship_label(faction_id: String) -> String:
	var value := get_reputation(faction_id)
	if value >= 75: return "trusted_ally"
	if value >= 35: return "friendly"
	if value <= -75: return "hostile"
	if value <= -35: return "unfriendly"
	return "neutral"

func get_snapshot() -> Dictionary:
	return _reputation.duplicate(true)
