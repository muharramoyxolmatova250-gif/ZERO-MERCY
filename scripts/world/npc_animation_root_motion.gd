extends RefCounted
## Converts authored-style local root deltas into world-space movement requests.
static func to_world_delta(local_delta: Vector3, facing: Basis, weight: float = 1.0) -> Vector3:
	return facing * local_delta * clampf(weight, 0.0, 1.0)
static func clamp_planar_delta(delta: Vector3, max_distance: float) -> Vector3:
	var planar := Vector3(delta.x, 0.0, delta.z)
	var limit := maxf(0.0, max_distance)
	if planar.length() > limit and limit > 0.0: planar = planar.normalized() * limit
	return Vector3(planar.x, delta.y, planar.z)
