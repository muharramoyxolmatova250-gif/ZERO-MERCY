extends RefCounted
## Independent micro-gesture scheduler; each resident gets a seeded rhythm.
const GESTURES := ["look_around","weight_shift","adjust_sleeve","brief_stretch","head_tilt","hand_fidget","shoulder_roll","check_surroundings"]
var rng := RandomNumberGenerator.new()
var active := ""
var remaining := 0.0
var cooldown := 1.0
func setup(seed_value: int) -> void:
	rng.seed = abs(seed_value) + 22091
func update(delta: float, speed: float, activity: String, using_phone: bool, curiosity: float) -> String:
	var dt := clampf(delta, 0.0, 0.1)
	cooldown = maxf(0.0, cooldown - dt)
	remaining = maxf(0.0, remaining - dt)
	if remaining == 0.0:
		active = ""
	if cooldown == 0.0 and speed < 0.08 and activity.is_empty() and not using_phone:
		if rng.randf() < 0.10 + clampf(curiosity, 0.0, 1.0) * 0.22:
			active = GESTURES[rng.randi_range(0, GESTURES.size() - 1)]
			remaining = rng.randf_range(0.65, 1.7)
		cooldown = rng.randf_range(3.0, 8.0)
	return active
func snapshot() -> Dictionary:
	return {"active":active,"remaining":remaining,"cooldown":cooldown}
