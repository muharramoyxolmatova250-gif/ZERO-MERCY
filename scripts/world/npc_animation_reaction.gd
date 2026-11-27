extends RefCounted
## Maps world events to short readable body-language reactions.
const REACTIONS := {
	"startled":{"head_pitch":-0.18,"arm_open":0.20,"body_lean":-0.025},
	"scared":{"head_pitch":-0.12,"arm_open":0.12,"body_lean":0.10},
	"angry":{"head_pitch":0.035,"arm_open":-0.14,"body_lean":-0.08},
	"curious":{"head_pitch":-0.10,"arm_open":0.06,"body_lean":-0.02},
	"relieved":{"head_pitch":0.04,"arm_open":0.08,"body_lean":-0.015},
	"sad":{"head_pitch":0.13,"arm_open":-0.04,"body_lean":0.06},
	"happy":{"head_pitch":-0.035,"arm_open":0.16,"body_lean":-0.02}
}
static func get_pose(kind: String) -> Dictionary:
	return REACTIONS.get(kind, {}).duplicate(true)
