extends RefCounted
## Procedural foot target helper for uneven ground; caller supplies raycast height.
static func solve_foot_target(world_position: Vector3, ground_height: float, step_height: float = 0.22, lift: float = 0.08) -> Dictionary:
	var height_delta := ground_height - world_position.y
	var clamped_delta := clampf(height_delta, -absf(step_height), absf(step_height))
	return {"position":Vector3(world_position.x, world_position.y + clamped_delta + maxf(0.0, lift), world_position.z), "slope_offset":clamped_delta, "reachable":absf(height_delta) <= absf(step_height)}
static func gait_lift(phase: float, stride_weight: float, lift_height: float = 0.12) -> float:
	return maxf(0.0, sin(phase)) * maxf(0.0, lift_height) * clampf(stride_weight, 0.0, 1.0)
