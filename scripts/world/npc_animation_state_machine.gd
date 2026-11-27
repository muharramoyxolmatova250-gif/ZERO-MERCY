extends RefCounted
## Small deterministic state machine with cross-fade timing.
var state := "idle"
var previous_state := "idle"
var blend := 1.0
var blend_duration := 0.22
var elapsed := 0.0
func transition(next_state: String, duration: float = 0.22) -> bool:
	if next_state == state: return false
	previous_state = state
	state = next_state
	blend = 0.0
	elapsed = 0.0
	blend_duration = maxf(0.01, duration)
	return true
func update(delta: float) -> Dictionary:
	elapsed += clampf(delta, 0.0, 0.1)
	blend = clampf(elapsed / blend_duration, 0.0, 1.0)
	return {"from":previous_state,"to":state,"weight":blend,"finished":blend >= 1.0}
func snapshot() -> Dictionary:
	return {"state":state,"previous":previous_state,"blend":blend,"elapsed":elapsed}
