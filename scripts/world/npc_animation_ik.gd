extends RefCounted
## Two-bone planar helper for future hand/foot targets on a humanoid rig.
static func solve_two_bone(root: Vector2, target: Vector2, upper_length: float, lower_length: float, bend_sign: float = 1.0) -> Dictionary:
	var a := maxf(0.001, upper_length)
	var b := maxf(0.001, lower_length)
	var offset := target - root
	var distance := clampf(offset.length(), absf(a - b) + 0.001, a + b - 0.001)
	var base_angle := offset.angle()
	var root_cos := clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0)
	var joint_cos := clampf((a * a + b * b - distance * distance) / (2.0 * a * b), -1.0, 1.0)
	return {"root_angle":base_angle + acos(root_cos) * signf(bend_sign),"joint_angle":PI - acos(joint_cos),"reach":distance,"target_clamped":not is_equal_approx(distance, offset.length())}
