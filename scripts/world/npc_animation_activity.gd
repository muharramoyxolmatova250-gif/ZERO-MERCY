extends RefCounted
## Activity-specific arm and torso pose presets.
const POSES := {
	"eating":{"left_arm":-0.18,"right_arm":-0.78,"torso":0.045},
	"working":{"left_arm":-0.48,"right_arm":-0.52,"torso":0.09},
	"studying":{"left_arm":-0.42,"right_arm":-0.50,"torso":0.11},
	"resting":{"left_arm":0.18,"right_arm":0.18,"torso":0.07},
	"socializing":{"left_arm":0.12,"right_arm":-0.20,"torso":0.0},
	"browsing":{"left_arm":0.0,"right_arm":-1.05,"torso":0.015},
	"playing":{"left_arm":-0.24,"right_arm":-0.24,"torso":-0.025}
}
static func get_pose(activity: String) -> Dictionary:
	return POSES.get(activity, {}).duplicate(true)
