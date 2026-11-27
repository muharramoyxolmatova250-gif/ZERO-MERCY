extends RefCounted
## Stable per-resident animation style derived from identity and personality.
var style := "balanced"
var stride_scale := 1.0
var gesture_rate := 1.0
var head_motion_scale := 1.0
var arm_swing_scale := 1.0
func initialize(identity: String, traits: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(identity + ":animation-style"))
	var sociability := clampf(float(traits.get("sociability", 0.5)), 0.0, 1.0)
	var discipline := clampf(float(traits.get("discipline", 0.5)), 0.0, 1.0)
	var curiosity := clampf(float(traits.get("curiosity", 0.5)), 0.0, 1.0)
	stride_scale = rng.randf_range(0.94, 1.06) * (0.96 + discipline * 0.08)
	gesture_rate = 0.72 + sociability * 0.52
	head_motion_scale = 0.75 + curiosity * 0.55
	arm_swing_scale = rng.randf_range(0.88, 1.12)
	style = "expressive" if sociability > 0.72 else ("observant" if curiosity > 0.72 else ("measured" if discipline > 0.72 else "balanced"))
func snapshot() -> Dictionary:
	return {"style":style,"stride_scale":stride_scale,"gesture_rate":gesture_rate,"head_motion_scale":head_motion_scale,"arm_swing_scale":arm_swing_scale}
