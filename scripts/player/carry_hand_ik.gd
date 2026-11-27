extends RefCounted
## Two-bone reach solver for procedural carry support.
## Returns geometric targets; it does not replace a skinned-mesh IK rig.

static func clamp_reach_target(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float, margin: float = 0.025) -> Vector3:
	var upper := maxf(upper_length, 0.001)
	var lower := maxf(lower_length, 0.001)
	var safe_margin := clampf(margin, 0.0, minf(upper, lower) * 0.45)
	var delta := target - shoulder
	var distance := delta.length()
	var minimum_distance := absf(upper - lower) + safe_margin
	var maximum_distance := maxf(minimum_distance, upper + lower - safe_margin)
	if distance < 0.0001:
		return shoulder + Vector3.DOWN * minimum_distance
	return shoulder + delta / distance * clampf(distance, minimum_distance, maximum_distance)

static func solve_elbow(shoulder: Vector3, wrist: Vector3, upper_length: float, lower_length: float, bend_normal: Vector3) -> Vector3:
	var upper := maxf(upper_length, 0.001)
	var lower := maxf(lower_length, 0.001)
	var target := clamp_reach_target(shoulder, wrist, upper, lower)
	var axis := target - shoulder
	var distance := axis.length()
	if distance < 0.0001:
		return shoulder + Vector3.DOWN * upper
	var direction := axis / distance
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	along = clampf(along, 0.0, upper)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var normal := get_bend_normal(direction, bend_normal)
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

static func get_solution_bend_direction(solution: Dictionary) -> Vector3:
	return get_chain_bend_direction(get_solution_shoulder(solution), get_solution_elbow(solution), get_solution_endpoint(solution))

static func get_upper_segment_basis(shoulder: Vector3, elbow: Vector3, up_hint: Vector3 = Vector3.UP) -> Basis:
	var direction := safe_normalize(elbow - shoulder)
	var right := safe_normalize(direction.cross(up_hint), Vector3.RIGHT)
	var corrected_up := safe_normalize(right.cross(direction), Vector3.UP)
	return Basis(right, corrected_up, -direction).orthonormalized()

static func get_lower_segment_basis(elbow: Vector3, wrist: Vector3, up_hint: Vector3 = Vector3.UP) -> Basis:
	var direction := safe_normalize(wrist - elbow)
	var right := safe_normalize(direction.cross(up_hint), Vector3.RIGHT)
	var corrected_up := safe_normalize(right.cross(direction), Vector3.UP)
	return Basis(right, corrected_up, -direction).orthonormalized()

static func get_chain_orientation(shoulder: Vector3, wrist: Vector3, up_hint: Vector3 = Vector3.UP) -> Basis:
	var direction := safe_normalize(wrist - shoulder)
	var right := safe_normalize(direction.cross(up_hint), Vector3.RIGHT)
	var corrected_up := safe_normalize(right.cross(direction), Vector3.UP)
	return Basis(right, corrected_up, -direction).orthonormalized()

static func get_target_distance_weight(shoulder: Vector3, target: Vector3, start_distance: float, end_distance: float) -> float:
	var distance := shoulder.distance_to(target)
	return clampf(inverse_lerp(start_distance, maxf(end_distance, start_distance + 0.001), distance), 0.0, 1.0)

static func offset_target_along_direction(target: Vector3, direction: Vector3, distance: float) -> Vector3:
	return target + safe_normalize(direction) * distance

static func get_closest_reachable_point(shoulder: Vector3, target: Vector3, upper_length: float, lower_length: float) -> Vector3:
	return clamp_reach_target(shoulder, target, upper_length, lower_length)

static func get_joint_angle_limit(angle: float, minimum: float, maximum: float) -> Dictionary:
	var clamped := clamp_joint_angle(angle, minimum, maximum)
	return {"angle": clamped, "was_clamped": not is_equal_approx(angle, clamped), "limit_weight": get_joint_limit_weight(clamped, minimum, maximum)}

static func get_bend_plane_distance(point: Vector3, plane: Plane) -> float:
	return absf(plane.distance_to(point))

static func project_direction_on_plane(direction: Vector3, plane_normal: Vector3) -> Vector3:
	var normal := safe_normalize(plane_normal, Vector3.UP)
	return safe_normalize(direction - normal * direction.dot(normal), Vector3.FORWARD)

static func get_solution_quality(solution: Dictionary, desired_target: Vector3) -> float:
	if not get_solution_is_valid(solution):
		return 0.0
	var shoulder := get_solution_shoulder(solution)
	var elbow := get_solution_elbow(solution)
	var wrist := get_solution_endpoint(solution)
	return get_pose_quality(shoulder, elbow, wrist, desired_target)

static func get_segment_transform(start: Vector3, finish: Vector3, up_hint: Vector3 = Vector3.UP) -> Transform3D:
	var basis := get_chain_orientation(start, finish, up_hint)
	return Transform3D(basis, get_segment_midpoint(start, finish))

static func get_joint_transform(position: Vector3, forward: Vector3, up_hint: Vector3 = Vector3.UP) -> Transform3D:
	var direction := safe_normalize(forward)
	var right := safe_normalize(direction.cross(up_hint), Vector3.RIGHT)
	var up := safe_normalize(right.cross(direction), Vector3.UP)
	return Transform3D(Basis(right, up, -direction).orthonormalized(), position)

static func get_solution_transforms(solution: Dictionary) -> Dictionary:
	var shoulder := get_solution_shoulder(solution)
	var elbow := get_solution_elbow(solution)
	var wrist := get_solution_endpoint(solution)
	return {"upper": get_segment_transform(shoulder, elbow), "lower": get_segment_transform(elbow, wrist)}

static func get_solution_center(solution: Dictionary) -> Vector3:
	return get_chain_midpoint(get_solution_shoulder(solution), get_solution_elbow(solution), get_solution_endpoint(solution))

static func get_solution_total_length(solution: Dictionary) -> float:
	var lengths := get_solution_segment_lengths(solution)
	return lengths.x + lengths.y

static func get_solution_validity_report(solution: Dictionary) -> Dictionary:
	var valid := get_solution_is_valid(solution)
	return {"valid": valid, "has_shoulder": solution.has("shoulder"), "has_elbow": solution.has("elbow"), "has_wrist": solution.has("wrist")}

static func get_solution_error_report(solution: Dictionary, target: Vector3) -> Dictionary:
	var wrist := get_solution_endpoint(solution)
	return {"endpoint_error": wrist.distance_to(target), "target_clamped": bool(solution.get("target_clamped", false)), "valid": get_solution_is_valid(solution)}

static func get_solution_bend_sign(solution: Dictionary) -> float:
	var shoulder := get_solution_shoulder(solution)
	var elbow := get_solution_elbow(solution)
	var wrist := get_solution_endpoint(solution)
	return signf((elbow - project_point_on_segment(elbow, shoulder, wrist)).dot(Vector3.UP))

static func get_solution_bounds(solution: Dictionary) -> AABB:
	var points := get_joint_positions(solution)
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

static func get_solution_is_stable(solution: Dictionary, maximum_error: float = 0.08) -> bool:
	if not get_solution_is_valid(solution):
		return false
	var lengths := get_solution_segment_lengths(solution)
	var shoulder := get_solution_shoulder(solution)
	var elbow := get_solution_elbow(solution)
	var wrist := get_solution_endpoint(solution)
	return get_chain_straightness(shoulder, elbow, wrist) < 0.995 and get_chain_error(shoulder, elbow, wrist, lengths.x, lengths.y) <= maximum_error

static func get_solution_lerp(from_solution: Dictionary, to_solution: Dictionary, weight: float) -> Dictionary:
	return blend_solution(from_solution, to_solution, weight)

static func get_solution_world(solution: Dictionary, transform: Transform3D) -> Dictionary:
	var result := solution.duplicate(true)
	for key in ["shoulder", "elbow", "wrist"]:
		if result.has(key):
			var point: Vector3 = result[key]
			result[key] = transform * point
	return result

static func get_solution_local(solution: Dictionary, transform: Transform3D) -> Dictionary:
	var result := solution.duplicate(true)
	var inverse := transform.affine_inverse()
	for key in ["shoulder", "elbow", "wrist"]:
		if result.has(key):
			var point: Vector3 = result[key]
			result[key] = inverse * point
	return result

static func get_solution_reach_margin(solution: Dictionary, upper_length: float, lower_length: float) -> float:
	return get_reach_margin(get_solution_shoulder(solution), get_solution_endpoint(solution), upper_length, lower_length)

static func get_solution_fold_margin(solution: Dictionary, upper_length: float, lower_length: float) -> float:
	return get_fold_margin(upper_length, lower_length, get_solution_endpoint(solution), get_solution_shoulder(solution))
