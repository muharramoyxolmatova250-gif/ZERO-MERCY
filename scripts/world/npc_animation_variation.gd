extends RefCounted
## Stable per-resident variation without per-frame random-number noise.
static func make_profile(identity: String, personality: Dictionary = {}) -> Dictionary:
	var seed_value := abs(hash(identity))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var expressiveness := clampf(float(personality.get("expressiveness", 0.5)), 0.0, 1.0)
	return {"seed":seed_value,"idle_rate":rng.randf_range(0.88,1.14),"stride_scale":rng.randf_range(0.92,1.08),"gesture_scale":lerpf(0.75,1.3,expressiveness),"head_bias":rng.randf_range(-0.08,0.08),"arm_bias":rng.randf_range(-0.06,0.06)}
static func phase_offset(identity: String, channel: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(identity + ":" + channel))
	return rng.randf_range(0.0, TAU)
