extends RefCounted
## Distance-based animation update policy; keeps near actors responsive.
static func get_interval(distance: float, is_important: bool = false, is_visible: bool = true) -> float:
	if is_important: return 0.0
	if not is_visible: return 0.65 if distance > 90.0 else 0.32
	if distance < 12.0: return 0.0
	if distance < 35.0: return 0.08
	if distance < 75.0: return 0.18
	return 0.4
static func should_update(accumulator: float, delta: float, interval: float) -> Dictionary:
	var elapsed := maxf(0.0, accumulator) + maxf(0.0, delta)
	if interval <= 0.0: return {"update":true,"accumulator":0.0,"alpha":1.0}
	if elapsed >= interval: return {"update":true,"accumulator":fposmod(elapsed, interval),"alpha":clampf(elapsed / interval, 0.0, 1.0)}
	return {"update":false,"accumulator":elapsed,"alpha":clampf(elapsed / interval, 0.0, 1.0)}
