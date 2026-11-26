extends Node
## Computes whether observers can notice a moving actor from light, distance and noise.
static func calculate_detection(observer_position: Vector3, actor_position: Vector3, observer_forward: Vector3, actor_noise: float, ambient_light: float, actor_visibility: float, max_distance: float = 32.0) -> float:
	var distance := observer_position.distance_to(actor_position)
	if distance >= max_distance or max_distance <= 0.0:
		return 0.0
	var to_actor := actor_position - observer_position
	to_actor.y = 0.0
	var forward := observer_forward
	forward.y = 0.0
	if to_actor.length_squared() > 0.001 and forward.length_squared() > 0.001:
		var facing := forward.normalized().dot(to_actor.normalized())
		if facing < -0.35:
			return clampf(actor_noise * 0.75, 0.0, 1.0)
		var cone_factor := remap(facing, -0.35, 1.0, 0.2, 1.0)
		var visual := (1.0 - distance / max_distance) * clampf(ambient_light, 0.0, 1.0) * clampf(actor_visibility, 0.0, 1.0) * cone_factor
		return clampf(maxf(visual, actor_noise * (1.0 - distance / max_distance)), 0.0, 1.0)
	return clampf(actor_noise * (1.0 - distance / max_distance), 0.0, 1.0)

static func is_detected(detection_score: float, threshold: float = 0.42) -> bool:
	return detection_score >= threshold
