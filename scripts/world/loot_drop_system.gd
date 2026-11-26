extends Node
## Weighted loot tables with deterministic optional random seed.
var _tables: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func register_table(table_id: String, entries: Array[Dictionary]) -> bool:
	if table_id.is_empty() or entries.is_empty():
		return false
	var total_weight := 0.0
	for entry in entries:
		if not entry.has("item_id") or float(entry.get("weight", 0.0)) <= 0.0:
			return false
		total_weight += float(entry["weight"])
	if total_weight <= 0.0:
		return false
	_tables[table_id] = entries.duplicate(true)
	return true

func roll(table_id: String, count: int = 1, seed_value: int = -1) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if not _tables.has(table_id) or count <= 0:
		return drops
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var entries: Array = _tables[table_id]
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry["weight"])
	for _i in range(count):
		var pick := rng.randf() * total_weight
		for entry in entries:
			pick -= float(entry["weight"])
			if pick <= 0.0:
				drops.append({"item_id": str(entry["item_id"]), "amount": int(entry.get("amount", 1))})
				break
	return drops
