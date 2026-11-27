extends RefCounted
## Small deterministic blending helpers shared by animation layers.
static func weight(current: float, target: float, rate: float, delta: float) -> float:
	return move_toward(current, target, maxf(0.0, rate) * clampf(delta, 0.0, 0.1))
static func smooth_weight(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
static func envelope(elapsed: float, duration: float, fade_in: float, fade_out: float) -> float:
	if duration <= 0.0 or elapsed < 0.0 or elapsed >= duration:
		return 0.0
	return minf(smooth_weight(elapsed / maxf(0.001, fade_in)), smooth_weight((duration - elapsed) / maxf(0.001, fade_out)))
static func shortest_angle(from_angle: float, to_angle: float, amount: float) -> float:
	return lerp_angle(from_angle, to_angle, clampf(amount, 0.0, 1.0))
