extends RefCounted
## Converts a world-space attention point into clamped local head yaw/pitch.
static func solve_gaze(origin: Vector3, target: Vector3, body_basis: Basis, max_yaw: float = 0.85, max_pitch: float = 0.45) -> Dictionary:
	var direction := target - origin
	if direction.length_squared() < 0.0001:
		return {"yaw":0.0,"pitch":0.0,"valid":false}
	var local_direction := body_basis.inverse() * direction.normalized()
	var yaw := atan2(local_direction.x, -local_direction.z)
	var pitch := atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length())
	return {"yaw":clampf(yaw, -absf(max_yaw), absf(max_yaw)), "pitch":clampf(-pitch, -absf(max_pitch), absf(max_pitch)), "valid":true}
static func smooth_angles(current: Vector2, target: Vector2, weight: float) -> Vector2:
	return current.lerp(target, clampf(weight, 0.0, 1.0))
