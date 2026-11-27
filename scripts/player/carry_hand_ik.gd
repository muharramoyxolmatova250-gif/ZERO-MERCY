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
	if not validate_segment_lengths(upper_length, lower_length):
		return 0.0
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

static func get_elbow_angle(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> float:
	var upper := (shoulder - elbow).normalized()
	var lower := (wrist - elbow).normalized()
	if upper.length_squared() < 0.001 or lower.length_squared() < 0.001:
		return 0.0
	return acos(clampf(upper.dot(lower), -1.0, 1.0))

static func get_wrist_distance(shoulder: Vector3, wrist: Vector3) -> float:
	return shoulder.distance_to(wrist)

static func get_stretch_warning(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, threshold: float = 0.92) -> bool:
	return get_reach_ratio(shoulder, target, upper_length, lower_length) >= threshold

static func get_pole_vector(shoulder: Vector3, wrist: Vector3, pole: Vector3) -> Vector3:
	var axis := get_segment_direction(shoulder, wrist)
	return get_bend_normal(axis, pole)

static func get_segment_midpoint(start: Vector3, finish: Vector3) -> Vector3:
	return start.lerp(finish, 0.5)

static func get_reach_margin(upper_length: float, lower_length: float, target: Vector3, shoulder: Vector3) -> float:
	return maxf(0.0, upper_length + lower_length - shoulder.distance_to(target))

static func get_fold_margin(upper_length: float, lower_length: float, target: Vector3, shoulder: Vector3) -> float:
	return maxf(0.0, absf(upper_length - lower_length) - shoulder.distance_to(target))

static func get_bend_side(direction: Vector3, normal: Vector3) -> float:
	return signf(direction.cross(normal).dot(Vector3.UP))

static func safe_normalize(value: Vector3, fallback: Vector3 = Vector3.DOWN) -> Vector3:
	return value.normalized() if value.length_squared() > 0.000001 else fallback.normalized()

static func get_joint_chain_length(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> float:
	return shoulder.distance_to(elbow) + elbow.distance_to(wrist)

static func is_chain_stretched(shoulder: Vector3, elbow: Vector3, wrist: Vector3, threshold: float = 0.96) -> bool:
	var chain := get_joint_chain_length(shoulder, elbow, wrist)
	return chain > 0.001 and shoulder.distance_to(wrist) / chain >= threshold

static func get_joint_balance(upper_length: float, lower_length: float) -> float:
	return clampf(minf(upper_length, lower_length) / maxf(maxf(upper_length, lower_length), 0.001), 0.0, 1.0)

static func get_target_direction_local(origin: Vector3, target: Vector3, basis: Basis) -> Vector3:
	return basis.inverse() * safe_normalize(target - origin)

static func project_point_on_segment(point: Vector3, start: Vector3, finish: Vector3) -> Vector3:
	var segment := finish - start
	var length_sq := segment.length_squared()
	if length_sq < 0.000001:
		return start
	var weight := clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return start + segment * weight

static func get_point_segment_distance(point: Vector3, start: Vector3, finish: Vector3) -> float:
	return point.distance_to(project_point_on_segment(point, start, finish))

static func get_chain_bend_direction(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	var axis := safe_normalize(wrist - shoulder)
	var offset := elbow - project_point_on_segment(elbow, shoulder, wrist)
	return safe_normalize(offset, Vector3.UP)

static func get_chain_straightness(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> float:
	var total := shoulder.distance_to(elbow) + elbow.distance_to(wrist)
	return clampf(shoulder.distance_to(wrist) / maxf(total, 0.001), 0.0, 1.0)

static func get_elbow_pole_weight(shoulder: Vector3, elbow: Vector3, wrist: Vector3, minimum: float = 0.03) -> float:
	var offset := get_point_segment_distance(elbow, shoulder, wrist)
	return clampf(offset / maxf(minimum, 0.001), 0.0, 1.0)

static func get_chain_midpoint(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	return (shoulder + elbow * 2.0 + wrist) * 0.25

static func get_target_clamp_amount(shoulder: Vector3, desired: Vector3, solved: Vector3) -> float:
	return desired.distance_to(solved)

static func get_reach_comfort(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, comfort_ratio: float = 0.82) -> float:
	var ratio := get_reach_ratio(shoulder, target, upper_length, lower_length)
	return 1.0 - clampf((ratio - comfort_ratio) / maxf(1.0 - comfort_ratio, 0.001), 0.0, 1.0)

static func get_elbow_plane_normal(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	return safe_normalize((elbow - shoulder).cross(wrist - elbow), Vector3.FORWARD)

static func get_wrist_to_target_direction(wrist: Vector3, target: Vector3) -> Vector3:
	return safe_normalize(target - wrist, Vector3.FORWARD)

static func smooth_weight(current: float, target: float, delta: float, speed: float) -> float:
	return move_toward(current, target, maxf(delta, 0.0) * maxf(speed, 0.0))

static func smooth_vector(current: Vector3, target: Vector3, delta: float, speed: float) -> Vector3:
	return current.lerp(target, clampf(maxf(delta, 0.0) * maxf(speed, 0.0), 0.0, 1.0))

static func clamp_joint_angle(angle: float, minimum: float, maximum: float) -> float:
	return clampf(angle, minf(minimum, maximum), maxf(minimum, maximum))

static func get_joint_limit_weight(angle: float, minimum: float, maximum: float, margin: float = 0.15) -> float:
	var span := maxf(absf(maximum - minimum), 0.001)
	var edge := minf(angle - minimum, maximum - angle)
	return clampf(edge / maxf(span * margin, 0.001), 0.0, 1.0)

static func get_chain_lengths(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector2:
	return Vector2(shoulder.distance_to(elbow), elbow.distance_to(wrist))

static func get_chain_error(shoulder: Vector3, elbow: Vector3, wrist: Vector3, upper_length: float, lower_length: float) -> float:
	var lengths := get_chain_lengths(shoulder, elbow, wrist)
	return absf(lengths.x - upper_length) + absf(lengths.y - lower_length)

static func get_target_direction(shoulder: Vector3, target: Vector3, fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	return safe_normalize(target - shoulder, fallback)

static func get_elbow_plane(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Plane:
	var normal := get_elbow_plane_normal(shoulder, elbow, wrist)
	return Plane(normal, elbow)

static func get_wrist_error_vector(actual: Vector3, desired: Vector3) -> Vector3:
	return desired - actual

static func get_wrist_error_weight(actual: Vector3, desired: Vector3, tolerance: float = 0.05) -> float:
	return clampf(actual.distance_to(desired) / maxf(tolerance, 0.001), 0.0, 1.0)

static func solve_with_constraints(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, bend_normal: Vector3, minimum_reach: float = 0.025) -> Dictionary:
	if not validate_segment_lengths(upper_length, lower_length):
		return {"shoulder": shoulder, "elbow": shoulder, "wrist": shoulder, "valid": false}
	var wrist := clamp_reach_target(shoulder, target, upper_length, lower_length, minimum_reach)
	var pole := get_bend_normal(wrist - shoulder, bend_normal)
	var elbow := solve_elbow(shoulder, wrist, upper_length, lower_length, pole)
	return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist, "valid": true, "target_clamped": not wrist.is_equal_approx(target)}

static func get_limb_directions(solution: Dictionary) -> Dictionary:
	var shoulder: Vector3 = solution.get("shoulder", Vector3.ZERO)
	var elbow: Vector3 = solution.get("elbow", Vector3.ZERO)
	var wrist: Vector3 = solution.get("wrist", Vector3.ZERO)
	return {"upper": safe_normalize(elbow - shoulder), "lower": safe_normalize(wrist - elbow)}

static func get_joint_positions(solution: Dictionary) -> PackedVector3Array:
	return PackedVector3Array([solution.get("shoulder", Vector3.ZERO), solution.get("elbow", Vector3.ZERO), solution.get("wrist", Vector3.ZERO)])

static func get_solution_is_valid(solution: Dictionary) -> bool:
	if not solution.has("shoulder") or not solution.has("elbow") or not solution.has("wrist"):
		return false
	return (solution["shoulder"] as Vector3).is_finite() and (solution["elbow"] as Vector3).is_finite() and (solution["wrist"] as Vector3).is_finite()

static func get_solution_endpoint(solution: Dictionary) -> Vector3:
	return solution.get("wrist", Vector3.ZERO)

static func get_solution_elbow(solution: Dictionary) -> Vector3:
	return solution.get("elbow", Vector3.ZERO)

static func get_solution_shoulder(solution: Dictionary) -> Vector3:
	return solution.get("shoulder", Vector3.ZERO)

static func get_solution_segment_lengths(solution: Dictionary) -> Vector2:
	var points := get_joint_positions(solution)
	if points.size() < 3:
		return Vector2.ZERO
	return Vector2(points[0].distance_to(points[1]), points[1].distance_to(points[2]))
