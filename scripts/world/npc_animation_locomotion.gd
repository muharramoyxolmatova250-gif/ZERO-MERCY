extends RefCounted
## Gait phase and stride response separated from the presentation rig.
var phase := 0.0
var cadence := 0.0
var stride_weight := 0.0
func update(delta: float, speed: float, preferred_speed: float, urgent: bool) -> Dictionary:
	var dt := clampf(delta, 0.0, 0.1)
	var ratio := clampf(speed / maxf(0.1, preferred_speed), 0.0, 1.8)
	stride_weight = move_toward(stride_weight, clampf(ratio, 0.0, 1.0), dt * (5.0 if ratio > stride_weight else 7.0))
	cadence = lerpf(1.65, 3.25 if urgent else 2.65, clampf(ratio, 0.0, 1.0))
	phase = fposmod(phase + dt * cadence * TAU, TAU)
	return {"phase":phase,"weight":stride_weight,"cadence":cadence,"stride":sin(phase) * stride_weight}
func snapshot() -> Dictionary:
	return {"phase":phase,"cadence":cadence,"weight":stride_weight}
