extends RefCounted
## Lightweight counters for profiling animation workloads.
var frames := 0
var updates := 0
var skipped := 0
var last_cost_ms := 0.0
func record_update(cost_ms: float) -> void:
	frames += 1
	updates += 1
	last_cost_ms = maxf(0.0,cost_ms)
func record_skip() -> void:
	frames += 1
	skipped += 1
func snapshot() -> Dictionary:
	return {"frames":frames,"updates":updates,"skipped":skipped,"last_cost_ms":last_cost_ms,"skip_ratio":float(skipped)/float(maxi(1,frames))}
func reset() -> void:
	frames = 0
	updates = 0
	skipped = 0
	last_cost_ms = 0.0
