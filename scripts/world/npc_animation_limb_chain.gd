extends RefCounted
## Converts a 2D two-bone solution into pivot rotations for a segmented limb.
static func solve(root: Vector2, target: Vector2, upper_length: float, lower_length: float, bend_sign: float = 1.0) -> Dictionary:
	var result: Dictionary = NPCAnimationIK.solve_two_bone(root,target,upper_length,lower_length,bend_sign)
	return {"upper_rotation":float(result.get("root_angle",0.0)),"lower_rotation":float(result.get("joint_angle",0.0)),"reach":float(result.get("reach",0.0)),"clamped":bool(result.get("target_clamped",false))}
