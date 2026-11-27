extends RefCounted
## Abstract expression weights; requires a future facial rig to render visibly.
static func get_expression(emotion: String, intensity: float = 1.0) -> Dictionary:
	var w := clampf(intensity,0.0,1.0)
	match emotion:
		"happy": return {"brow":-0.12*w,"eyes":0.16*w,"mouth":0.72*w}
		"angry": return {"brow":0.72*w,"eyes":-0.22*w,"mouth":-0.18*w}
		"afraid": return {"brow":-0.58*w,"eyes":0.62*w,"mouth":-0.48*w}
		"sad": return {"brow":0.42*w,"eyes":-0.32*w,"mouth":-0.55*w}
		"curious": return {"brow":-0.25*w,"eyes":0.38*w,"mouth":0.08*w}
	return {"brow":0.0,"eyes":0.0,"mouth":0.0}
