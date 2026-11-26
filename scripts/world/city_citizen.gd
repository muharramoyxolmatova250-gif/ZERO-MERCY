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
var _crime_flee_timer := 0.0
var _crime_flee_direction := Vector3.ZERO
var _last_crime_id := ""
var personality := 3
var _memory: Array[String] = []
var ai_decision_count := 0
var current_goal := "commute"
var relationship_score := 0.0
var life_profile: Dictionary = {}
var _last_visual_age := -1
var _age_refresh_timer := 0.0
var _spatial_update_timer := 0.0
var _last_routed_goal := ""
@export var citizen_id := ""
@export var city_id := ""
@export var occupation := "resident"

func _ready() -> void:
	add_to_group("city_citizen")
	_rng.seed = int(absf(position.x * 97.0 + position.z * 131.0)) + 20261122
	_build_appearance()
	if citizen_id.is_empty():
		citizen_id = "citizen_" + str(abs(hash(str(position) + ":" + city_id)))
	_register_life_profile()
	var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
	if spatial_index != null:
		spatial_index.call("register_citizen", self)
	if has_node("/root/GameSession"):
		GameSession.crime_reported.connect(_on_crime_reported)
	if route.size() < 2:
		route = PackedVector3Array([Vector3(-5,0,-5), Vector3(5,0,-5), Vector3(5,0,5), Vector3(-5,0,5)])
	_target_index = 1
	personality = _rng.randi_range(1, 5)
	_decide_goal()

func _register_life_profile() -> void:
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim == null or not life_sim.has_method("register_citizen"):
		return
	var resolved_city := city_id if not city_id.is_empty() else "UnmappedSettlement"
	life_profile = life_sim.call("register_citizen", citizen_id, resolved_city, occupation)
	occupation = str(life_profile.get("occupation", occupation))
	_last_visual_age = -1


func _on_crime_reported(crime_id: String, crime_position: Vector3, severity: int) -> void:
	var distance := global_position.distance_to(crime_position)
	if distance > 55.0:
		return
	_last_crime_id = crime_id
	_crime_flee_timer = maxf(_crime_flee_timer, 5.0 + float(severity) * 2.0)
	_crime_flee_direction = global_position - crime_position
	_crime_flee_direction.y = 0.0
	if _crime_flee_direction.length_squared() < 0.01:
		_crime_flee_direction = Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(-PI, PI))
	_crime_flee_direction = _crime_flee_direction.normalized()
	_stress = clampf(_stress + 0.35, 0.0, 1.0)
	current_goal = "flee"
	remember_event("witnessed_crime:" + crime_id)

func _physics_process(delta: float) -> void:
	_spatial_update_timer += delta
	if _spatial_update_timer >= 0.2:
		_spatial_update_timer = 0.0
		var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
		if spatial_index != null:
			spatial_index.call("update_citizen", self)
	if _crime_flee_timer > 0.0:
		_crime_flee_timer = maxf(0.0, _crime_flee_timer - delta)
		position += _crime_flee_direction * walk_speed * 2.1 * delta
		if _crime_flee_direction.length_squared() > 0.001:
			look_at(position + _crime_flee_direction, Vector3.UP)
		if _crime_flee_timer <= 0.0:
			current_goal = "avoid_crowd"
			_pause_remaining = 1.5
		return
	_age_refresh_timer += delta
	if _age_refresh_timer >= 10.0:
		_age_refresh_timer = 0.0
		var current_age := int(life_profile.get("age_years", _last_visual_age))
		if current_age != _last_visual_age:
			_last_visual_age = current_age
			var body_scale := 0.55 if current_age < 6 else (0.76 if current_age < 18 else (0.94 if current_age >= 65 else 1.0))
			scale = Vector3.ONE * body_scale
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
	var speed_factor := 1.3 if current_goal == "commute" else (0.65 if current_goal in ["rest", "leisure", "family"] else (1.12 if current_goal in ["food", "school", "play"] else 1.0))
	var steering := direction.normalized() + _get_crowd_separation() * 1.25
	if steering.length_squared() > 0.001:
		steering = steering.normalized()
		position += steering * walk_speed * speed_factor * delta
		look_at(position + steering, Vector3.UP)

func _get_nearby_citizens(radius: float) -> Array:
	var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
	if spatial_index != null:
		return spatial_index.call("get_nearby_citizens", global_position, radius)
	var nearby: Array = []
	for candidate in get_tree().get_nodes_in_group("city_citizen"):
		if candidate != self and is_instance_valid(candidate) and global_position.distance_to(candidate.global_position) <= radius:
			nearby.append(candidate)
	return nearby

func _get_crowd_separation() -> Vector3:
	var separation := Vector3.ZERO
	var nearby_count := 0
	for candidate in _get_nearby_citizens(1.6):
		if candidate == self:
			continue
		var offset: Vector3 = global_position - candidate.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.01:
			separation += offset.normalized() / distance
			nearby_count += 1
	if nearby_count > 0:
		separation /= float(nearby_count)
	return separation

func _update_needs() -> void:
	_energy = clampf(_energy - 0.002, 0.0, 1.0)
	_hunger = clampf(_hunger + 0.003, 0.0, 1.0)
	_social_need = clampf(_social_need + 0.002, 0.0, 1.0)
	_curiosity = clampf(_curiosity + 0.0015, 0.0, 1.0)
	_stress = clampf(_stress + (0.001 if current_goal == "work" else -0.0015), 0.0, 1.0)

func _decide_goal() -> void:
	ai_decision_count += 1
	var hour := int(Time.get_time_dict_from_system().get("hour", 12))
	var society_clock := get_tree().get_first_node_in_group("world_society_sim")
	if society_clock != null:
		hour = int(society_clock.get("simulation_hour"))
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
	if _last_routed_goal != best:
		var route_network := get_tree().get_first_node_in_group("pedestrian_route_network")
		if route_network != null:
			var planned_route: PackedVector3Array = route_network.call("request_activity_route", global_position, best, citizen_id)
			if planned_route.size() > 1:
				route = planned_route
				_target_index = 1
				_last_routed_goal = best
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
	if not _last_routed_goal.is_empty() and _target_index >= route.size() - 1:
		_last_routed_goal = ""
		_target_index = 0
		return
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
	for candidate in _get_nearby_citizens(nearest_distance):
		if candidate == self: continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_social_target = candidate

func get_ai_snapshot() -> Dictionary:
	return {"id":citizen_id,"goal":current_goal,"energy":_energy,"hunger":_hunger,"social":_social_need,"stress":_stress,"flee_timer":_crime_flee_timer,"last_crime_id":_last_crime_id,"crowd_avoidance":true,"memories":_memory.size(),"decisions":ai_decision_count,"name":str(life_profile.get("name",citizen_id)),"age_years":int(life_profile.get("age_years",30)),"life_stage":str(life_profile.get("life_stage","adult")),"occupation":occupation,"marital_status":str(life_profile.get("marital_status","single")),"children":int(life_profile.get("children_count",0))}

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
	var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
	if spatial_index != null:
		spatial_index.call("unregister_citizen", self)
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and not citizen_id.is_empty():
		life_sim.call("unregister_citizen", citizen_id)
