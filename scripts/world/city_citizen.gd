extends Node3D
## Lightweight ambient pedestrian that loops a local sidewalk route.
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(0.2, 5.0, 0.1) var walk_speed := 1.25
@export var pause_at_waypoints := false
var _target_index := 0
var _body: MeshInstance3D
var _phone: MeshInstance3D
var _pause_remaining := 0.0
var is_using_phone := false
var phone_interaction_count := 0
var _rng := RandomNumberGenerator.new()
var _energy := 0.8
var _hunger := 0.2
var _social_need := 0.4
var _curiosity := 0.5
var _decision_timer := 0.0
var _social_scan_timer := 0.0
var _social_target: Node3D
var _stress := 0.15
var personality := 3
var _memory: Array[String] = []
var ai_decision_count := 0
var current_goal := "commute"
var relationship_score := 0.0
var life_profile: Dictionary = {}
@export var citizen_id := ""
@export var occupation := "resident"

func _ready() -> void:
	_rng.seed = int(absf(position.x * 97.0 + position.z * 131.0)) + 20261122
	_build_appearance()
	if citizen_id.is_empty():
		citizen_id = "citizen_" + str(abs(hash(str(position))))
	if route.size() < 2:
		route = PackedVector3Array([Vector3(-5,0,-5), Vector3(5,0,-5), Vector3(5,0,5), Vector3(-5,0,5)])
	_target_index = 1
	personality = _rng.randi_range(1, 5)
	_decide_goal()

func _physics_process(delta: float) -> void:
	_decision_timer += delta
	if _decision_timer >= 2.5:
		_decision_timer = 0.0
		_update_needs()
		_decide_goal()
	_social_scan_timer += delta
	if _social_scan_timer >= 5.0:
		_social_scan_timer = 0.0
		_scan_social_context()
	if route.size() < 2:
		return
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		if _pause_remaining == 0.0:
			is_using_phone = false
			if _phone != null: _phone.visible = false
		return
	var target := route[_target_index]
	if current_goal == "social" and is_instance_valid(_social_target):
		target = _social_target.global_position
	var direction := target - position
	direction.y = 0.0
	if direction.length() < (1.8 if current_goal == "social" else 0.35):
		if current_goal == "social" and is_instance_valid(_social_target):
			_social_target.call("remember_event", "met:" + citizen_id)
			remember_event("conversation:" + str(_social_target.get("citizen_id")))
			_social_target = null
			_pause_remaining = _rng.randf_range(2.0, 5.0)
			return
		_choose_next_waypoint()
		_pause_remaining = _pause_for_goal()
		is_using_phone = current_goal in ["social", "commute", "explore"] and _rng.randf() < 0.68
		if is_using_phone: phone_interaction_count += 1
		if _phone != null: _phone.visible = is_using_phone
		return
	var speed_factor := 1.3 if current_goal == "commute" else (0.65 if current_goal == "rest" else 1.0)
	position += direction.normalized() * walk_speed * speed_factor * delta
	if direction.length_squared() > 0.001: look_at(position + direction, Vector3.UP)

func _update_needs() -> void:
	_energy = clampf(_energy - 0.002, 0.0, 1.0)
	_hunger = clampf(_hunger + 0.003, 0.0, 1.0)
	_social_need = clampf(_social_need + 0.002, 0.0, 1.0)
	_curiosity = clampf(_curiosity + 0.0015, 0.0, 1.0)
	_stress = clampf(_stress + (0.001 if current_goal == "work" else -0.0015), 0.0, 1.0)

func _decide_goal() -> void:
	ai_decision_count += 1
	var hour := int(Time.get_time_dict_from_system().get("hour", 12))
	var scores := {"work": (1.0 if hour >= 8 and hour < 18 else 0.12) + (0.18 if occupation != "unemployed" else 0.0), "food": _hunger * 1.65, "social": _social_need * (1.0 + float(personality) * 0.12) + (0.25 if is_instance_valid(_social_target) else 0.0), "rest": (1.0 - _energy) * 1.5 + (0.35 if hour >= 21 or hour < 6 else 0.0), "explore": _curiosity * (0.75 + float(personality) * 0.08), "commute": 0.9 if hour in [7, 8, 17, 18] else 0.18, "avoid_crowd": _stress * 0.55}
	var life_stage := str(life_profile.get("life_stage", "adult"))
	if life_stage != "adult":
		scores["work"] = float(scores["work"]) * 0.2
	if life_stage == "student":
		scores["school"] = 1.25 if hour >= 7 and hour < 16 else 0.08
	elif life_stage == "child":
		scores["play"] = 1.0 if hour >= 8 and hour < 20 else 0.2
	elif life_stage == "retired":
		scores["leisure"] = 0.85
	if str(life_profile.get("marital_status", "single")) == "married":
		scores["family"] = 0.35 + _social_need * 0.2
	var previous_goal := current_goal
	var best := "commute"
	var best_score := -1.0
	for goal in scores:
		var score: float = float(scores[goal]) + _rng.randf_range(0.0, 0.15)
		if goal == current_goal: score *= 0.72
		if score > best_score:
			best_score = score
			best = goal
	current_goal = best
	if best != previous_goal:
		var life_sim := get_tree().get_first_node_in_group("world_life_sim")
		if life_sim != null:
			life_sim.call("record_activity", citizen_id, best)
	if best == "food": _hunger = maxf(0.0, _hunger - 0.12)
	elif best == "social": _social_need = maxf(0.0, _social_need - 0.1)
	elif best == "rest": _energy = minf(1.0, _energy + 0.08)
	elif best == "explore": _curiosity = maxf(0.0, _curiosity - 0.08)
	if best == "avoid_crowd": _stress = maxf(0.0, _stress - 0.08)
	_memory.append("decision:" + best)
	if _memory.size() > 24: _memory.pop_front()

func _choose_next_waypoint() -> void:
	if route.size() <= 2 or _rng.randf() < 0.75:
		_target_index = (_target_index + 1) % route.size()
	else:
		_target_index = _rng.randi_range(0, route.size() - 1)

func _pause_for_goal() -> float:
	match current_goal:
		"social": return _rng.randf_range(1.5, 4.0)
		"school": return _rng.randf_range(1.5, 3.5)
		"play": return _rng.randf_range(2.0, 5.0)
		"family": return _rng.randf_range(2.0, 4.5)
		"leisure": return _rng.randf_range(2.0, 5.0)
		"food": return _rng.randf_range(1.0, 2.8)
		"rest": return _rng.randf_range(2.0, 4.5)
		"explore": return _rng.randf_range(0.5, 1.8)
		_: return _rng.randf_range(0.25, 1.0)

func _scan_social_context() -> void:
	_social_target = null
	var nearest_distance := 11.0
	for candidate in get_tree().get_nodes_in_group("city_citizen"):
		if candidate == self or not is_instance_valid(candidate): continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_social_target = candidate

func get_ai_snapshot() -> Dictionary:
	return {"id":citizen_id,"goal":current_goal,"energy":_energy,"hunger":_hunger,"social":_social_need,"stress":_stress,"memories":_memory.size(),"decisions":ai_decision_count,"age_years":int(life_profile.get("age_years",30)),"life_stage":str(life_profile.get("life_stage","adult")),"occupation":occupation,"marital_status":str(life_profile.get("marital_status","single")),"children":int(life_profile.get("children_count",0))}

func remember_event(event_name: String) -> void:
	_memory.append(event_name)
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null:
		life_sim.call("record_event", citizen_id, event_name)
	relationship_score = clampf(relationship_score + 0.02, -1.0, 1.0)
	if _memory.size() > 24: _memory.pop_front()

func get_memory_snapshot() -> PackedStringArray:
	return PackedStringArray(_memory)

func _build_appearance() -> void:
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.025, 0.035, 0.065)
	coat.metallic = 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.0, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.0, 0.65, 1.0)
	glow.emission_energy_multiplier = 1.6
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.32
	torso_mesh.height = 1.35
	_body = MeshInstance3D.new()
	_body.mesh = torso_mesh
	_body.position.y = 0.95
	_body.material_override = coat
	add_child(_body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.78
	head.material_override = glow
	add_child(head)
	_phone = MeshInstance3D.new()
	_phone.name = "Phone"
	var phone_mesh := BoxMesh.new()
	phone_mesh.size = Vector3(0.12, 0.2, 0.035)
	_phone.mesh = phone_mesh
	_phone.position = Vector3(0.34, 1.05, -0.12)
	var phone_material := StandardMaterial3D.new()
	phone_material.albedo_color = Color(0.0, 0.8, 1.0)
	phone_material.emission_enabled = true
	phone_material.emission = Color(0.0, 0.55, 1.0)
	phone_material.emission_energy_multiplier = 2.0
	_phone.material_override = phone_material
	_phone.visible = false
	add_child(_phone)


func _exit_tree() -> void:
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and not citizen_id.is_empty():
		life_sim.call("unregister_citizen", citizen_id)
