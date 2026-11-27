extends RefCounted
## Two-bone reach solver for procedural carry support.
## Returns geometric targets; it does not replace a skinned-mesh IK rig.

static func clamp_reach_target(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, margin: float = 0.025) -> Vector3:
	var delta := target - shoulder
	var distance := delta.length()
	var minimum_distance := absf(upper_length - lower_length) + margin
	var maximum_distance := maxf(minimum_distance, upper_length + lower_length - margin)
	if distance < 0.0001:
		return shoulder + Vector3.DOWN * minimum_distance
	return shoulder + delta / distance * clampf(distance, minimum_distance, maximum_distance)

static func solve_elbow(shoulder: Vector3, wrist: Vector3, upper_length: float, lower_length: float, bend_normal: Vector3) -> Vector3:
	var target := clamp_reach_target(shoulder, wrist, upper_length, lower_length)
	var axis := target - shoulder
	var distance := axis.length()
	if distance < 0.0001:
		return shoulder
	var direction := axis / distance
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var normal := bend_normal - direction * bend_normal.dot(direction)
	if normal.length_squared() < 0.0001:
		normal = direction.cross(Vector3.FORWARD)
	if normal.length_squared() < 0.0001:
		normal = direction.cross(Vector3.RIGHT)
	normal = normal.normalized()
	return shoulder + direction * along + normal * height

static func get_reach_weight(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float) -> float:
	var distance := shoulder.distance_to(target)
	var reach := upper_length + lower_length
	return clampf(distance / maxf(reach, 0.001), 0.0, 1.0)

static func get_elbow_flex(shoulder: Vector3, elbow: Vector3, wrist: Vector3, upper_length: float, lower_length: float) -> float:
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var c := shoulder.distance_to(wrist)
	if a < 0.001 or b < 0.001:
		return 0.0
	var cosine := clampf((a * a + b * b - c * c) / (2.0 * a * b), -1.0, 1.0)
	return PI - acos(cosine)

static func make_debug_solution(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, bend_normal: Vector3) -> Dictionary:
	var wrist := clamp_reach_target(shoulder, target, upper_length, lower_length)
	var elbow := solve_elbow(shoulder, wrist, upper_length, lower_length, bend_normal)
	return {
		"shoulder": shoulder,
		"elbow": elbow,
		"wrist": wrist,
		"reach_weight": get_reach_weight(shoulder, target, upper_length, lower_length),
		"elbow_flex": get_elbow_flex(shoulder, elbow, wrist, upper_length, lower_length),
		"target_clamped": not wrist.is_equal_approx(target)
	}

static func validate_segment_lengths(upper_length: float, lower_length: float) -> bool:
	return upper_length > 0.001 and lower_length > 0.001

static func get_max_reach(upper_length: float, lower_length: float, margin: float = 0.025) -> float:
	return maxf(0.0, upper_length + lower_length - margin)

static func get_min_reach(upper_length: float, lower_length: float, margin: float = 0.025) -> float:
	return absf(upper_length - lower_length) + margin

static func get_reach_ratio(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float) -> float:
	return clampf(shoulder.distance_to(target) / maxf(upper_length + lower_length, 0.001), 0.0, 1.5)

static func get_endpoint_error(actual_wrist: Vector3, desired_target: Vector3) -> float:
	return actual_wrist.distance_to(desired_target)

static func mirror_bend_normal(normal: Vector3, mirror_axis: Vector3) -> Vector3:
	var axis := mirror_axis.normalized()
	if axis.length_squared() < 0.001:
		return normal
	return normal - 2.0 * normal.dot(axis) * axis

static func get_segment_direction(start: Vector3, finish: Vector3, fallback: Vector3 = Vector3.DOWN) -> Vector3:
	var delta := finish - start
	return delta.normalized() if delta.length_squared() > 0.000001 else fallback.normalized()
