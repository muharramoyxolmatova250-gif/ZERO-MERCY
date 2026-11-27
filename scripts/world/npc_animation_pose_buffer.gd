extends RefCounted
## Bounded pose history for continuity checks and future animation debugging.
var samples: Array[Dictionary] = []
var max_samples := 12
func record(pose: Dictionary) -> void:
	samples.append(pose.duplicate(true))
	while samples.size() > max_samples:
		samples.pop_front()
func latest() -> Dictionary:
	return samples.back().duplicate(true) if not samples.is_empty() else {}
func clear() -> void:
	samples.clear()
func snapshot() -> Dictionary:
	return {"sample_count":samples.size(),"latest":latest()}
