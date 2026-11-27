extends RefCounted
## Data-only motion vocabulary. Values are normalized pose hints, not mocap clips.
const CLIPS := {
	"idle_relaxed": {"speed":0.0,"arm_swing":0.0,"body_lean":0.0,"head_focus":0.0},
	"idle_alert": {"speed":0.0,"arm_swing":0.04,"body_lean":0.035,"head_focus":0.18},
	"walk": {"speed":1.0,"arm_swing":0.58,"body_lean":0.025,"head_focus":0.02},
	"run": {"speed":1.0,"arm_swing":0.88,"body_lean":0.13,"head_focus":0.04},
	"sneak": {"speed":0.55,"arm_swing":0.25,"body_lean":0.09,"head_focus":0.12},
	"phone": {"speed":0.0,"arm_swing":0.0,"body_lean":0.015,"head_focus":0.16},
	"talk": {"speed":0.0,"arm_swing":0.12,"body_lean":0.0,"head_focus":0.08},
	"work": {"speed":0.0,"arm_swing":0.05,"body_lean":0.08,"head_focus":0.11},
	"combat": {"speed":0.0,"arm_swing":0.18,"body_lean":0.12,"head_focus":0.14}
}
func get_clip(name: String) -> Dictionary:
	return CLIPS.get(name, CLIPS["idle_relaxed"]).duplicate(true)
func get_clip_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in CLIPS:
		names.append(key)
	return names
