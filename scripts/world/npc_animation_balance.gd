extends RefCounted
## Computes a conservative torso lean correction from projected support offset.
static func solve_balance(center_offset: Vector2, support_radius: float = 0.18, max_lean: float = 0.24) -> Dictionary:
	var radius := maxf(0.01,support_radius)
	var magnitude := center_offset.length()
	var excess := maxf(0.0,magnitude-radius)
	var direction := center_offset.normalized() if magnitude > 0.0001 else Vector2.ZERO
	var lean := clampf(excess/radius,0.0,1.0)*maxf(0.0,max_lean)
	return {"lean_x":-direction.y*lean,"lean_z":direction.x*lean,"stable":magnitude<=radius,"offset":magnitude}
