extends RefCounted
## Named hand-shape channels for future articulated finger meshes.
static func get_pose(name: String) -> Dictionary:
	match name:
		"fist": return {"thumb":0.82,"index":1.0,"middle":1.0,"ring":1.0,"pinky":0.96}
		"point": return {"thumb":0.68,"index":0.05,"middle":0.92,"ring":0.95,"pinky":0.94}
		"open": return {"thumb":0.08,"index":0.04,"middle":0.04,"ring":0.05,"pinky":0.08}
		"phone": return {"thumb":0.28,"index":0.58,"middle":0.82,"ring":0.88,"pinky":0.9}
		"relaxed": return {"thumb":0.22,"index":0.18,"middle":0.2,"ring":0.24,"pinky":0.28}
	return get_pose("relaxed")
static func blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result := {}
	var w := clampf(weight,0.0,1.0)
	for key in ["thumb","index","middle","ring","pinky"]:
		result[key] = lerpf(float(a.get(key,0.2)),float(b.get(key,0.2)),w)
	return result
