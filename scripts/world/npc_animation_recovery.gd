extends RefCounted
## Timed get-up/recovery phase planner; caller applies the returned pose channels.
static func get_recovery_pose(elapsed: float, duration: float = 1.8) -> Dictionary:
	var t := clampf(elapsed/maxf(0.1,duration),0.0,1.0)
	if t < 0.28:
		var w := smoothstep(0.0,0.28,t)
		return {"phase":"brace","torso":0.55*w,"left_arm":-0.7*w,"right_arm":-0.7*w,"height":0.0}
	if t < 0.72:
		var w := smoothstep(0.28,0.72,t)
		return {"phase":"rise","torso":lerpf(0.55,0.08,w),"left_arm":lerpf(-0.7,0.15,w),"right_arm":lerpf(-0.7,0.15,w),"height":0.72*w}
	var w := smoothstep(0.72,1.0,t)
	return {"phase":"settle","torso":lerpf(0.08,0.0,w),"left_arm":lerpf(0.15,0.0,w),"right_arm":lerpf(0.15,0.0,w),"height":lerpf(0.72,1.0,w)}
