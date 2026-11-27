extends RefCounted
## Passenger/driver pose channels for seated vehicle states.
static func get_seated_pose(role: String, steering: float = 0.0) -> Dictionary:
	var turn := clampf(steering,-1.0,1.0)
	if role == "driver":
		return {"torso_pitch":0.08,"left_arm":-0.62-turn*0.12,"right_arm":-0.58+turn*0.12,"left_leg":0.18,"right_leg":0.24,"head_pitch":0.02}
	return {"torso_pitch":0.04,"left_arm":0.12,"right_arm":0.12,"left_leg":0.16,"right_leg":0.16,"head_pitch":0.0}
