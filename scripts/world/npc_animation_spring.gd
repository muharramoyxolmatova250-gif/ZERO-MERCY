extends RefCounted
## Stable critically damped scalar spring for secondary motion.
static func step(current: float, velocity: float, target: float, stiffness: float, delta: float, damping: float = 1.0) -> Dictionary:
	var dt := clampf(delta, 0.0, 0.05)
	var k := maxf(0.01, stiffness)
	var c := 2.0 * sqrt(k) * clampf(damping, 0.0, 2.0)
	var acceleration := (target - current) * k - velocity * c
	var next_velocity := velocity + acceleration * dt
	return {"value":current + next_velocity * dt,"velocity":next_velocity}
