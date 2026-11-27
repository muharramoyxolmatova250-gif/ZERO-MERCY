extends RefCounted
## Reach validation and soft contact response for hand interaction targets.
static func evaluate_reach(root: Vector3, target: Vector3, reach: float, tolerance: float = 0.12) -> Dictionary:
	var distance := root.distance_to(target)
	var maximum := maxf(0.01, reach)
	return {"distance":distance,"weight":1.0 - smoothstep(maximum - tolerance, maximum + tolerance, distance),"in_range":distance <= maximum}
static func soften_target(root: Vector3, target: Vector3, reach: float, margin: float = 0.04) -> Vector3:
	var offset := target - root
	var limit := maxf(0.01, reach - maxf(0.0, margin))
	return root + offset.normalized() * minf(offset.length(), limit)
