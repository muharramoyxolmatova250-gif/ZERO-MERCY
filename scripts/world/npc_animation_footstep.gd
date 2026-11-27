extends RefCounted
## Emits one footstep event per gait half-cycle without duplicate frame triggers.
var last_left_cycle := -1
var last_right_cycle := -1
func update_phase(phase: float, moving: bool, speed: float) -> Array[String]:
	var events: Array[String] = []
	if not moving or speed < 0.12: return events
	var cycle := int(floor(phase / TAU))
	var local_phase := fposmod(phase,TAU)
	if local_phase < PI and cycle != last_left_cycle:
		last_left_cycle = cycle
		events.append("left_footstep")
	elif local_phase >= PI and cycle != last_right_cycle:
		last_right_cycle = cycle
		events.append("right_footstep")
	return events
