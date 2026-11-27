extends Node3D
const NPCCognition = preload("res://scripts/world/npc_cognition.gd")
const NPCDialogueAI = preload("res://scripts/world/npc_dialogue_ai.gd")
const NPCActionPlanner = preload("res://scripts/world/npc_action_planner.gd")
const NPCMotionController = preload("res://scripts/world/npc_motion_controller.gd")
const NPCSelfDirection = preload("res://scripts/world/npc_self_direction.gd")
const NPCCognitiveArchitecture = preload("res://scripts/world/npc_cognitive_architecture.gd")
const NPCSimulationAwareness = preload("res://scripts/world/npc_simulation_awareness.gd")
## Lightweight ambient pedestrian that loops a local sidewalk route.
@export var route: PackedVector3Array = PackedVector3Array()
@export_range(0.2, 5.0, 0.1) var walk_speed := 1.25
@export var pause_at_waypoints := false
var _target_index := 0
var _body: MeshInstance3D
var _head: MeshInstance3D
var _phone: MeshInstance3D
var _indoor_activity := ""
var _indoor_activity_time := 0.0
var _indoor_action_completed := false
var _indoor_action_token := ""
var _body_rest_position := Vector3.ZERO
var _head_rest_rotation := Vector3.ZERO
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
var _personality_traits: Dictionary = {}
var _long_term_goal := "build_a_stable_life"
var _decision_reason := "initializing"
var _building_visit_phase := ""
var _building_exit_position := Vector3.ZERO
var _transport_cooldown := 0.0
var _taxi_request_id := ""
var _taxi_riding := false
var _phone_brain_timer := 0.0
var _phone_action_cooldown := 0.0
var _phone_battery_visual := 1.0
var _last_browser_topic := ""
var _cognition = NPCCognition.new()
var _dialogue = NPCDialogueAI.new()
var _action_planner = NPCActionPlanner.new()
var _motion_controller = NPCMotionController.new()
var _self_direction = NPCSelfDirection.new()
var _independent_mind = NPCCognitiveArchitecture.new()
var _simulation_awareness = NPCSimulationAwareness.new()
var _simulation_scan_timer := 0.0
var _planned_action: Dictionary = {}
var _last_economic_goal_id := ""
var _cognitive_reflection_timer := 0.0
var _cognitive_plan_id := -1
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
	var emergency_dispatch := get_tree().get_first_node_in_group("emergency_dispatch_ai")
	if emergency_dispatch != null and emergency_dispatch.has_signal("incident_created"):
		emergency_dispatch.incident_created.connect(_on_emergency_incident_created)
	if route.size() < 2:
		route = PackedVector3Array([Vector3(-5,0,-5), Vector3(5,0,-5), Vector3(5,0,5), Vector3(-5,0,5)])
	_target_index = 1
	personality = _rng.randi_range(1, 5)
	_initialize_personality()
	_simulation_awareness.setup(citizen_id, float(_personality_traits.get("curiosity", 0.5)))
	_decide_goal()

func _register_life_profile() -> void:
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim == null or not life_sim.has_method("register_citizen"):
		return
	var resolved_city := city_id if not city_id.is_empty() else "UnmappedSettlement"
	life_profile = life_sim.call("register_citizen", citizen_id, resolved_city, occupation)
	occupation = str(life_profile.get("occupation", occupation))
	_last_visual_age = -1



func _on_emergency_incident_created(incident_id: String, payload: Dictionary) -> void:
	var incident_position: Vector3 = payload.get("position", global_position)
	var distance := global_position.distance_to(incident_position)
	if distance > 38.0:
		return
	var severity := float(payload.get("severity", 0.5))
	if _cognitive_plan_id >= 0 and severity >= 0.55:
		_independent_mind.advance_plan(_cognitive_plan_id, false, "high_severity_emergency")
		_cognitive_plan_id = -1
	_cognition.appraise_event("threat", severity, clampf(1.0 - distance / 38.0, 0.0, 1.0))
	_cognition.remember_episode("emergency", "Nearby " + str(payload.get("kind", "incident")), severity, incident_position, incident_id)
	var courage := float(_personality_traits.get("courage", 0.5))
	var curiosity := float(_personality_traits.get("curiosity", 0.5))
	_stress = clampf(_stress + severity * (0.45 + (1.0 - courage) * 0.25), 0.0, 1.0)
	remember_event("nearby_emergency:" + incident_id)
	_independent_mind.observe_world_fact("nearby_emergency:" + incident_id, "An emergency occurred nearby", severity, "emergency_dispatch", {"distance":distance,"position":incident_position})
	if courage < 0.32:
		_crime_flee_timer = maxf(_crime_flee_timer, 3.0 + severity * 5.0)
		_crime_flee_direction = global_position - incident_position
		_crime_flee_direction.y = 0.0
		if _crime_flee_direction.length_squared() > 0.01:
			_crime_flee_direction = _crime_flee_direction.normalized()
		current_goal = "flee"
	elif curiosity > 0.82 and severity < 0.45:
		current_goal = "avoid_crowd"
		_decision_reason = "observed_low_risk_emergency_from_safe_distance"

func _on_crime_reported(crime_id: String, crime_position: Vector3, severity: int) -> void:
	var distance := global_position.distance_to(crime_position)
	if distance > 55.0:
		return
	if _cognitive_plan_id >= 0:
		_independent_mind.advance_plan(_cognitive_plan_id, false, "crime_interrupt")
		_cognitive_plan_id = -1
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
	_independent_mind.observe_world_fact("crime:" + crime_id, "A crime was reported nearby", clampf(float(severity) / 5.0, 0.2, 1.0), "crime_report", {"distance":distance,"position":crime_position})
	var dispatch := get_tree().get_first_node_in_group("emergency_dispatch_ai")
	var courage := float(_personality_traits.get("courage", 0.5))
	var severity_factor := clampf(float(severity) / 5.0, 0.0, 1.0)
	if dispatch != null and courage > 0.28 and _rng.randf() < 0.45 + courage * 0.45:
		dispatch.call("report_incident", "crime", crime_position, severity_factor, citizen_id, {"source": "citizen_witness", "crime_id": crime_id})

func _physics_process(delta: float) -> void:
	_spatial_update_timer += delta
	_simulation_scan_timer += delta
	if _simulation_scan_timer >= 2.0:
		_simulation_scan_timer = 0.0
		_scan_simulation_anomalies()
	if _spatial_update_timer >= 0.2:
		_spatial_update_timer = 0.0
		var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
		if spatial_index != null:
			spatial_index.call("update_citizen", self)
	if _taxi_riding:
		_motion_controller.reset_motion(global_position)
		return
	if _crime_flee_timer > 0.0:
		_crime_flee_timer = maxf(0.0, _crime_flee_timer - delta)
		_motion_controller.move_toward(self, global_position + _crime_flee_direction * 12.0, delta, 2.1, _get_crowd_separation(), true)
		if _crime_flee_timer <= 0.0:
			current_goal = "avoid_crowd"
			_pause_remaining = 1.5
		return
	_cognition.update_emotions(delta, _stress < 0.45, 0.35 if _social_need < 0.35 else 0.0)
	_age_refresh_timer += delta
	if _age_refresh_timer >= 10.0:
		_age_refresh_timer = 0.0
		var current_age := int(life_profile.get("age_years", _last_visual_age))
		if current_age != _last_visual_age:
			_last_visual_age = current_age
			var body_scale := 0.55 if current_age < 6 else (0.76 if current_age < 18 else (0.94 if current_age >= 65 else 1.0))
			scale = Vector3.ONE * body_scale
	_transport_cooldown = maxf(0.0, _transport_cooldown - delta)
	_phone_action_cooldown = maxf(0.0, _phone_action_cooldown - delta)
	_phone_brain_timer += delta
	if _phone_brain_timer >= 9.0:
		_phone_brain_timer = 0.0
		_consider_autonomous_phone_use()
	_decision_timer += delta
	if _decision_timer >= 2.5:
		_decision_timer = 0.0
		_update_needs()
		_decide_goal()
		_consider_autonomous_taxi()
	_social_scan_timer += delta
	if _social_scan_timer >= 5.0:
		_social_scan_timer = 0.0
		_scan_social_context()
	if _building_visit_phase == "inside":
		_update_indoor_activity(delta)
	if _pause_remaining > 0.0:
		_motion_controller.stop(self, delta)
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		if _pause_remaining == 0.0:
			is_using_phone = false
			if _phone != null: _phone.visible = false
			if _building_visit_phase == "inside":
				_reset_indoor_pose()
				route = PackedVector3Array([global_position, _building_exit_position])
				_target_index = 1
				_building_visit_phase = "exiting"
		return
	if route.size() < 2:
		return
	var target := route[_target_index]
	if current_goal == "social" and is_instance_valid(_social_target):
		target = _social_target.global_position
	var direction := target - position
	direction.y = 0.0
	if direction.length() < (1.8 if current_goal == "social" else 0.35):
		if current_goal == "social" and is_instance_valid(_social_target):
			var other_id := str(_social_target.get("citizen_id"))
			_social_target.call("remember_event", "met:" + citizen_id)
			remember_event("conversation:" + other_id)
			var own_name := str(life_profile.get("name", citizen_id))
			var other_profile: Dictionary = _social_target.get("life_profile")
			var other_name := str(other_profile.get("name", other_id))
			var greeting := _dialogue.generate_greeting(other_name, relationship_score, "night" if int(Time.get_time_dict_from_system().get("hour",12)) >= 21 else "day")
			var other_reply := str(_social_target.call("talk_to_npc", greeting, citizen_id, own_name))
			var own_reply := _dialogue.answer_question(other_reply, {"speaker_name":other_name,"my_name":own_name,"occupation":occupation,"city":str(life_profile.get("city","this city")),"goal":_long_term_goal,"children":int(life_profile.get("children_count",0)),"relationship":relationship_score})
			var closing_line := str(_social_target.call("talk_to_npc", own_reply, citizen_id, own_name))
			var shared_topic := _dialogue.suggest_topic()
			_dialogue.remember_conversation(other_id, shared_topic, greeting, other_reply)
			_dialogue.remember_conversation(other_id, shared_topic, own_reply, closing_line)
			_cognition.update_social_impression(other_id, "friendly_chat", 0.62)
			_social_target.call("remember_event", "dialogue:" + citizen_id)
			var life_sim := get_tree().get_first_node_in_group("world_life_sim")
			if life_sim != null and life_sim.has_method("record_social_interaction"):
				life_sim.call("record_social_interaction", citizen_id, other_id, "friendly_chat")
			if life_sim != null and life_sim.has_method("get_family_members") and life_sim.has_method("record_family_interaction"):
				for member in life_sim.call("get_family_members", citizen_id):
					if str(member.get("id", "")) == other_id:
						life_sim.call("record_family_interaction", citizen_id, "family_conversation")
						remember_event("family_conversation:" + other_id)
						break
			_social_target = null
			_pause_remaining = _rng.randf_range(2.0, 5.0)
			return
		_choose_next_waypoint()
		if _building_visit_phase != "inside":
			_pause_remaining = _pause_for_goal()
		is_using_phone = current_goal in ["social", "commute", "explore"] and _rng.randf() < 0.68
		if is_using_phone: phone_interaction_count += 1
		if _phone != null: _phone.visible = is_using_phone
		return
	var speed_factor := 1.3 if current_goal == "commute" else (0.65 if current_goal in ["rest", "leisure", "family"] else (1.12 if current_goal in ["food", "school", "play"] else 1.0))
	_motion_controller.move_toward(self, target, delta, speed_factor, _get_crowd_separation(), false)

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

func _initialize_personality() -> void:
	# Stable traits are derived from citizen identity, preserving temperament across streaming.
	var trait_rng := RandomNumberGenerator.new()
	trait_rng.seed = int(abs(hash(citizen_id + ":personality")))
	_personality_traits = {
		"ambition": trait_rng.randf_range(0.15, 1.0),
		"kindness": trait_rng.randf_range(0.15, 1.0),
		"courage": trait_rng.randf_range(0.15, 1.0),
		"curiosity": trait_rng.randf_range(0.15, 1.0),
		"discipline": trait_rng.randf_range(0.15, 1.0),
		"sociability": trait_rng.randf_range(0.15, 1.0),
		"risk_tolerance": trait_rng.randf_range(0.1, 0.9)
	}
	if float(_personality_traits["ambition"]) > 0.72:
		_long_term_goal = "career_success"
	elif float(_personality_traits["kindness"]) > 0.72:
		_long_term_goal = "help_others"
	elif float(_personality_traits["curiosity"]) > 0.72:
		_long_term_goal = "discover_the_world"
	elif float(_personality_traits["sociability"]) > 0.72:
		_long_term_goal = "build_relationships"
	else:
		_long_term_goal = "build_a_stable_life"
	_cognition.initialize(citizen_id, _personality_traits)
	_dialogue.initialize(citizen_id, _personality_traits, life_profile)
	_action_planner.initialize(citizen_id, _personality_traits)
	_motion_controller.initialize(citizen_id, _personality_traits, walk_speed)
	_self_direction.initialize(citizen_id, _personality_traits, life_profile)
	_independent_mind.initialize(citizen_id, _personality_traits)
	_independent_mind.form_belief("self", "I am " + str(life_profile.get("name", citizen_id)), 0.95, "identity_profile")


func _update_needs() -> void:
	_energy = clampf(_energy - 0.002, 0.0, 1.0)
	_hunger = clampf(_hunger + 0.003, 0.0, 1.0)
	_social_need = clampf(_social_need + 0.002, 0.0, 1.0)
	_curiosity = clampf(_curiosity + 0.0015, 0.0, 1.0)
	_stress = clampf(_stress + (0.001 if current_goal == "work" else -0.0015), 0.0, 1.0)
	_independent_mind.update_need("hunger", _hunger)
	_independent_mind.update_need("energy", 1.0 - _energy)
	_independent_mind.update_need("social", _social_need)
	_independent_mind.update_need("safety", _stress)
	_independent_mind.update_need("curiosity", _curiosity)
	_independent_mind.update_need("purpose", 1.0 - float(_personality_traits.get("ambition", 0.5)))

func _decide_goal() -> void:
	ai_decision_count += 1
	var hour := int(Time.get_time_dict_from_system().get("hour", 12))
	var society_clock := get_tree().get_first_node_in_group("world_society_sim")
	if society_clock != null:
		hour = int(society_clock.get("simulation_hour"))
	var ambition := float(_personality_traits.get("ambition", 0.5))
	var kindness := float(_personality_traits.get("kindness", 0.5))
	var curiosity_trait := float(_personality_traits.get("curiosity", 0.5))
	var sociability := float(_personality_traits.get("sociability", 0.5))
	var discipline := float(_personality_traits.get("discipline", 0.5))
	var risk_tolerance := float(_personality_traits.get("risk_tolerance", 0.5))
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	var own_standing: Dictionary = {}
	if life_sim != null and life_sim.has_method("get_resident_reputation"):
		own_standing = life_sim.call("get_resident_reputation", citizen_id)
	var community_respect := float(own_standing.get("respect", 0.0))
	var public_notoriety := float(own_standing.get("notoriety", 0.0))
	var scores := {
		"work": (1.0 if hour >= 8 and hour < 18 else 0.12) + (0.18 if occupation != "unemployed" else 0.0) + ambition * 0.38 + discipline * 0.2,
		"food": _hunger * 1.65,
		"social": _social_need * (0.75 + sociability * 0.8) + (0.25 if is_instance_valid(_social_target) else 0.0) + kindness * 0.08,
		"rest": (1.0 - _energy) * 1.5 + (0.35 if hour >= 21 or hour < 6 else 0.0) + (1.0 - discipline) * 0.12,
		"explore": _curiosity * (0.55 + curiosity_trait * 0.9) + risk_tolerance * 0.12,
		"commute": 0.9 if hour in [7, 8, 17, 18] else 0.18,
		"avoid_crowd": _stress * (0.45 + (1.0 - risk_tolerance) * 0.35)
	}
	if _long_term_goal == "career_success":
		scores["work"] = float(scores["work"]) + 0.32
	elif _long_term_goal == "help_others":
		scores["social"] = float(scores["social"]) + 0.18
	elif _long_term_goal == "discover_the_world":
		scores["explore"] = float(scores["explore"]) + 0.3
	elif _long_term_goal == "build_relationships":
		scores["social"] = float(scores["social"]) + 0.3
	scores["social"] = float(scores["social"]) + community_respect * 0.12
	scores["avoid_crowd"] = float(scores["avoid_crowd"]) + public_notoriety * 0.16
	if _memory.has("recently_rejected_social_contact"):
		scores["social"] = float(scores["social"]) * 0.72
	if _memory.has("recently_witnessed_violence"):
		scores["avoid_crowd"] = float(scores["avoid_crowd"]) + 0.35
	var life_stage := str(life_profile.get("life_stage", "adult"))
	if life_stage != "adult":
		scores["work"] = float(scores["work"]) * 0.2
	if life_stage == "student":
		scores["school"] = 1.25 if hour >= 7 and hour < 16 else 0.08
	elif life_stage == "child":
		scores["play"] = 1.0 if hour >= 8 and hour < 20 else 0.2
	elif life_stage == "retired":
		scores["leisure"] = 0.85
	if str(life_profile.get("marital_status", "single")) == "partnered":
		scores["family"] = 0.35 + _social_need * 0.2
	var recalled_experiences: Array[Dictionary] = _independent_mind.recall_memories("", 5)
	var cognition_context := {"recalled_experiences":recalled_experiences,"stress":_stress,"energy":_energy,"hunger":_hunger,"hour":hour,"day":int(life_profile.get("simulation_day",0)),"risk_tolerance":risk_tolerance}
	scores = _cognition.evaluate_goal_scores(scores, cognition_context, _personality_traits, _memory)
	var agency_context := {"stress":_stress,"loneliness":_social_need,"boredom":_curiosity,"financial_pressure":float(life_profile.get("debt",0.0))/1000.0,"profile":life_profile,"available_time":1.0}
	if _rng.randf() < 0.08:
		var agency_memories: Array[Dictionary] = []
		for memory_entry in _memory:
			agency_memories.append({"id":str(abs(hash(memory_entry))),"event":memory_entry,"importance":0.45,"emotional_intensity":0.35,"unresolved":false,"suggested_activity":"reflect"})
		agency_context["memories"] = agency_memories
		var nearby_affordances: Array[Dictionary] = []
		var affordance_nodes := get_tree().get_nodes_in_group("npc_affordance")
		for affordance_node in affordance_nodes:
			if nearby_affordances.size() >= 16:
				break
			if not is_instance_valid(affordance_node) or not affordance_node.has_method("get_npc_affordance"):
				continue
			var affordance: Dictionary = affordance_node.call("get_npc_affordance", citizen_id)
			if not affordance.is_empty():
				var affordance_position: Vector3 = affordance.get("position", global_position)
				if global_position.distance_to(affordance_position) <= 35.0:
					affordance["distance"] = global_position.distance_to(affordance_position)
					nearby_affordances.append(affordance)
		agency_context["affordances"] = nearby_affordances
		if not _independent_mind.has_active_goal("exploration") and not nearby_affordances.is_empty():
			var discoveries: Array[Dictionary] = []
			for affordance in nearby_affordances:
				discoveries.append({"name":str(affordance.get("name", affordance.get("kind", "nearby opportunity"))),"novelty":float(affordance.get("novelty", affordance.get("relevance", 0.55))),"risk":float(affordance.get("danger", affordance.get("risk", 0.25))),"position":affordance.get("position", global_position)})
			_independent_mind.consider_curiosity_goal(discoveries)
			var conflicts: Array[Dictionary] = _independent_mind.detect_goal_conflicts()
			if not conflicts.is_empty():
				_decision_reason = "curiosity_balanced_against_conflicting_personal_goals"
		var previous_personal_goal := str(_self_direction.active_personal_goal.get("id", ""))
		var chosen_personal_goal: Dictionary = _self_direction.choose_personal_goal(agency_context)
		var chosen_goal_id := str(chosen_personal_goal.get("id", ""))
		if not chosen_goal_id.is_empty() and chosen_goal_id != previous_personal_goal and chosen_goal_id != _last_economic_goal_id:
			_last_economic_goal_id = chosen_goal_id
			var economy_sim := get_tree().get_first_node_in_group("world_life_sim")
			if economy_sim != null and economy_sim.has_method("execute_autonomous_resident_goal"):
				var execution: Dictionary = economy_sim.call("execute_autonomous_resident_goal", citizen_id, chosen_goal_id, _personality_traits)
				var succeeded := bool(execution.get("executed", false))
				_self_direction.record_goal_outcome(chosen_goal_id, 0.72 if succeeded else 0.38, succeeded)
				if economy_sim.has_method("update_resident_autonomy_goal"):
					economy_sim.call("update_resident_autonomy_goal", citizen_id, chosen_goal_id, succeeded, _personality_traits)
			if economy_sim != null and economy_sim.has_method("process_resident_autonomy_economy") and _rng.randf() < 0.03:
				economy_sim.call("process_resident_autonomy_economy", citizen_id, _personality_traits)
	var personal_biases: Dictionary = _self_direction.activity_biases(agency_context)
	for activity_key in personal_biases:
		if scores.has(activity_key):
			scores[activity_key] = float(scores[activity_key]) + float(personal_biases[activity_key])

	_sync_independent_goal_state(cognition_context)
	_apply_independent_goal_bias(scores)
	var deliberation_options: Array[Dictionary] = []
	for activity_name in scores:
		var normalized_score := clampf(float(scores[activity_name]) / 2.2, 0.0, 1.0)
		deliberation_options.append({"action":str(activity_name),"personal_fit":normalized_score,"reward":normalized_score,"risk":_stress * 0.65,"effort":1.0-_energy,"kind":"social" if activity_name == "social" else "activity"})
	var deliberation: Dictionary = _independent_mind.deliberate(deliberation_options, cognition_context)
	var deliberated_activity := str(deliberation.get("best", {}).get("action", ""))
	if scores.has(deliberated_activity):
		scores[deliberated_activity] = float(scores[deliberated_activity]) + 0.12
	var cognitive_drives: Array[Dictionary] = _independent_mind.evaluate_need_drives()
	for drive in cognitive_drives:
		var drive_key := str(drive.get("need", ""))
		var drive_goal := {"hunger":"food","energy":"rest","social":"social","curiosity":"explore","safety":"avoid_crowd","purpose":"work"}.get(drive_key, "")
		if not str(drive_goal).is_empty() and scores.has(drive_goal): scores[drive_goal] = float(scores[drive_goal]) + float(drive.get("urgency", 0.0)) * 0.22
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
	if best != previous_goal or _planned_action.is_empty():
		_action_planner.build_plan(best, cognition_context)
		_planned_action = _action_planner.next_action()
		_create_cognitive_plan_from_action_plan(best)
	_decision_reason = "needs_personality_memory_emotion_schedule_and_combinatorial_action_planning"
	_independent_mind.add_memory("selected_goal:" + best, {"reason":_decision_reason,"score":best_score,"hour":hour}, 0.35, 0.95)
	_independent_mind.form_belief("current_goal", best, 0.85, "personal_decision")
	_cognition.record_decision(best, _decision_reason, best_score, cognition_context)
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


func _consider_autonomous_taxi() -> void:
	if _taxi_riding or not _taxi_request_id.is_empty() or _transport_cooldown > 0.0:
		return
	if _crime_flee_timer > 0.0 or _building_visit_phase == "inside" or route.size() < 2:
		return
	var destination: Vector3 = route[route.size() - 1]
	var distance := global_position.distance_to(destination)
	var preference := float(_personality_traits.get("risk_tolerance", 0.5))
	var should_call := distance > 95.0 and (_energy < 0.28 or _stress > 0.72 or (current_goal == "commute" and preference > 0.42))
	if not should_call:
		return
	var dispatch := get_tree().get_first_node_in_group("city_taxi_dispatch")
	if dispatch == null or not dispatch.has_method("request_taxi"):
		return
	var result: Dictionary = dispatch.call("request_taxi", citizen_id, global_position, destination)
	if bool(result.get("accepted", false)):
		var request: Dictionary = result.get("request", {})
		_taxi_request_id = str(request.get("id", ""))
		remember_event("requested_taxi:" + _taxi_request_id)
		_decision_reason = "autonomous_taxi_choice_for_long_trip"
	else:
		_transport_cooldown = 25.0

func begin_taxi_ride(request_id: String) -> void:
	if request_id != _taxi_request_id or _taxi_riding:
		return
	_taxi_riding = true
	visible = false
	remember_event("boarded_taxi:" + request_id)

func cancel_taxi_ride(request_id: String) -> void:
	if request_id != _taxi_request_id:
		return
	visible = true
	_taxi_riding = false
	_taxi_request_id = ""
	_transport_cooldown = 60.0
	remember_event("taxi_trip_cancelled:" + request_id)

func finish_taxi_ride(request_id: String, destination: Vector3) -> void:
	if request_id != _taxi_request_id or not _taxi_riding:
		return
	global_position = destination
	visible = true
	_taxi_riding = false
	_taxi_request_id = ""
	_transport_cooldown = 45.0
	route = PackedVector3Array([global_position, global_position + Vector3(2.0, 0.0, 0.0)])
	_target_index = 1
	_last_routed_goal = ""
	remember_event("completed_taxi_trip:" + request_id)

func _choose_next_waypoint() -> void:
	# A planned destination route is a one-way trip, not a patrol loop.
	# Once the final node is reached, wait for the next AI decision to pick
	# a fresh activity and destination from the route network.
	if not _last_routed_goal.is_empty() and _target_index >= route.size() - 1:
		if _building_visit_phase == "entering":
			_building_visit_phase = "inside"
			route = PackedVector3Array([global_position])
			_target_index = 0
			_start_indoor_activity()
			_pause_remaining = maxf(_rng.randf_range(8.0, 22.0), _get_personal_activity_duration(_get_active_personal_goal_id()) + 1.0)
			remember_event("entered_building:" + _last_routed_goal + ":" + _indoor_activity)
			return
		if _building_visit_phase == "exiting":
			var completed_goal := _last_routed_goal
			remember_event("arrived_at_destination:" + completed_goal)
			_record_cognitive_activity_outcome(completed_goal, true, 0.62)
			var life_sim := get_tree().get_first_node_in_group("world_life_sim")
			if life_sim != null and life_sim.has_method("record_event"):
				life_sim.call("record_event", citizen_id, "visited_building:" + completed_goal)
			if completed_goal == "family" and life_sim != null and life_sim.has_method("record_family_interaction"):
				life_sim.call("record_family_interaction", citizen_id, "family_visit")
				if life_sim.has_method("record_childcare"):
					for child_id in life_profile.get("children_ids", []):
						life_sim.call("record_childcare", citizen_id, str(child_id), "family_visit")
				remember_event("family_time_shared")
			_last_routed_goal = ""
			_building_visit_phase = ""
			_building_exit_position = Vector3.ZERO
			route = PackedVector3Array([global_position])
			_target_index = 0
			return
		var route_network := get_tree().get_first_node_in_group("pedestrian_route_network")
		if route_network != null and route_network.has_method("request_activity_interior_position"):
			var interior: Vector3 = route_network.call("request_activity_interior_position", _last_routed_goal, citizen_id)
			if interior != Vector3.ZERO and global_position.distance_to(interior) > 1.0:
				_building_exit_position = route[route.size() - 1]
				route = PackedVector3Array([global_position, interior])
				_target_index = 1
				_building_visit_phase = "entering"
				return
		var completed_goal := _last_routed_goal
		remember_event("arrived_at_destination:" + completed_goal)
		_last_routed_goal = ""
		route = PackedVector3Array([global_position])
		_target_index = 0
		return
	if route.size() <= 2 or _rng.randf() < 0.75:
		_target_index = (_target_index + 1) % route.size()
	else:
		_target_index = _rng.randi_range(0, route.size() - 1)


func _start_indoor_activity() -> void:
	_indoor_activity_time = 0.0
	match current_goal:
		"food": _indoor_activity = "eating"
		"work": _indoor_activity = "working"
		"school": _indoor_activity = "studying"
		"rest", "family": _indoor_activity = "resting"
		"social", "leisure": _indoor_activity = "socializing"
		"play": _indoor_activity = "playing"
		_: _indoor_activity = "browsing"
	var personal_activity := _resolve_personal_indoor_activity()
	if not personal_activity.is_empty(): _indoor_activity = personal_activity
	_indoor_action_completed = false
	_indoor_action_token = _make_indoor_action_token()
	is_using_phone = _indoor_activity in ["socializing", "browsing"]
	if _phone != null:
		_phone.visible = is_using_phone
	if is_using_phone:
		phone_interaction_count += 1

func _update_indoor_activity(delta: float) -> void:
	_indoor_activity_time += delta
	_advance_indoor_life_action()
	var wave := sin(_indoor_activity_time * (2.8 if _indoor_activity == "working" else 1.7))
	if _body != null:
		_body.position = _body_rest_position
		_body.rotation = Vector3.ZERO
		match _indoor_activity:
			"eating":
				_body.rotation.x = wave * 0.055
				_body.position.y += absf(wave) * 0.025
			"working", "studying":
				_body.rotation.x = -0.09 + wave * 0.018
				_body.position.y += absf(wave) * 0.012
			"resting":
				_body.rotation.x = 0.08 + wave * 0.025
				_body.position.y -= 0.025 + absf(wave) * 0.018
			"socializing", "browsing":
				_body.rotation.y = wave * 0.045
			"playing":
				_body.position.y += absf(wave) * 0.07
	if _head != null:
		_head.rotation = _head_rest_rotation
		_head.rotation.y += wave * (0.12 if _indoor_activity == "socializing" else 0.035)
		if _indoor_activity in ["eating", "studying"]:
			_head.rotation.x = 0.08 + absf(wave) * 0.06

func _reset_indoor_pose() -> void:
	_indoor_activity = ""
	_indoor_activity_time = 0.0
	if _body != null:
		_body.position = _body_rest_position
		_body.rotation = Vector3.ZERO
	if _head != null:
		_head.rotation = _head_rest_rotation
	if _phone != null:
		_phone.visible = false
	is_using_phone = false

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
	var best_score := INF
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	var family_ids: Dictionary = {}
	if life_sim != null and life_sim.has_method("get_family_members"):
		for member in life_sim.call("get_family_members", citizen_id):
			family_ids[str(member.get("id", ""))] = true
	for candidate in _get_nearby_citizens(11.0):
		if candidate == self:
			continue
		var other_id := str(candidate.get("citizen_id"))
		var distance := global_position.distance_to(candidate.global_position)
		var score := distance
		if family_ids.has(other_id):
			score -= 4.0
		if life_sim != null and life_sim.has_method("get_social_bond"):
			var bond: Dictionary = life_sim.call("get_social_bond", citizen_id, other_id)
			score -= float(bond.get("familiarity", 0.0)) * 1.1
			score -= float(bond.get("friendship", 0.0)) * 2.2
			score -= float(bond.get("trust", 0.0)) * 0.8
		if life_sim != null and life_sim.has_method("get_resident_reputation"):
			var public_standing: Dictionary = life_sim.call("get_resident_reputation", other_id)
			var respect := float(public_standing.get("respect", 0.0))
			var notoriety := float(public_standing.get("notoriety", 0.0))
			var kindness_trait := float(_personality_traits.get("kindness", 0.5))
			var courage_trait := float(_personality_traits.get("courage", 0.5))
			score -= respect * (1.2 + kindness_trait)
			score += notoriety * (0.6 + (1.0 - courage_trait))
		# Familiarity, relationship quality and public standing shape who a resident approaches.
		if score < best_score:
			best_score = score
			_social_target = candidate

func get_ai_snapshot() -> Dictionary:
	return {"cognition":_independent_mind.get_cognitive_snapshot(),"id":citizen_id,"goal":current_goal,"energy":_energy,"hunger":_hunger,"social":_social_need,"stress":_stress,"flee_timer":_crime_flee_timer,"last_crime_id":_last_crime_id,"crowd_avoidance":true,"memories":_memory.size(),"decisions":ai_decision_count,"personality_traits":_personality_traits.duplicate(true),"long_term_goal":_long_term_goal,"decision_reason":_decision_reason,"route_nodes":route.size(),"route_target_index":_target_index,"route_goal":_last_routed_goal,"route_active":not _last_routed_goal.is_empty(),"building_visit_phase":_building_visit_phase,"indoor_activity":_indoor_activity,"indoor_activity_time":_indoor_activity_time,"name":str(life_profile.get("name",citizen_id)),"age_years":int(life_profile.get("age_years",30)),"life_stage":str(life_profile.get("life_stage","adult")),"occupation":occupation,"marital_status":str(life_profile.get("marital_status","single")),"children":int(life_profile.get("children_count",0)),"phone_visible":is_using_phone,"phone_interactions":phone_interaction_count,"phone_battery":_phone_battery_visual,"phone_action_cooldown":_phone_action_cooldown,"last_browser_topic":_last_browser_topic}

func remember_event(event_name: String) -> void:
	_memory.append(event_name)
	_independent_mind.add_memory(event_name, {"goal":current_goal,"position":global_position}, 0.55, 0.9)
	var normalized_event := event_name.to_lower()
	if "crime" in normalized_event or "violence" in normalized_event or "attack" in normalized_event:
		_stress = clampf(_stress + 0.12, 0.0, 1.0)
		if not _memory.has("recently_witnessed_violence"):
			_memory.append("recently_witnessed_violence")
	if "help" in normalized_event or "saved" in normalized_event:
		relationship_score = clampf(relationship_score + 0.12, -1.0, 1.0)
		_stress = clampf(_stress - 0.08, 0.0, 1.0)
	elif "betray" in normalized_event or "threat" in normalized_event:
		relationship_score = clampf(relationship_score - 0.16, -1.0, 1.0)
		_stress = clampf(_stress + 0.1, 0.0, 1.0)
	elif "met:" in normalized_event or "conversation:" in normalized_event:
		relationship_score = clampf(relationship_score + 0.035, -1.0, 1.0)
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null:
		life_sim.call("record_event", citizen_id, event_name)
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
	_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	_head.mesh = head_mesh
	_head.position.y = 1.78
	_head.material_override = glow
	add_child(_head)
	_body_rest_position = _body.position
	_head_rest_rotation = _head.rotation
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
	_phone.position = Vector3(0.34, 1.05, -0.12)
	_phone.scale = Vector3.ONE
	add_child(_phone)


func _exit_tree() -> void:
	var spatial_index := get_tree().get_first_node_in_group("citizen_spatial_index")
	if spatial_index != null:
		spatial_index.call("unregister_citizen", self)
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and not citizen_id.is_empty():
		life_sim.call("unregister_citizen", citizen_id)


func _consider_autonomous_phone_use() -> void:
	if _phone_action_cooldown > 0.0 or _taxi_riding or _crime_flee_timer > 0.0:
		return
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim == null:
		return
	var chance := 0.12 + float(_personality_traits.get("sociability", 0.5)) * 0.18
	if current_goal in ["social", "leisure", "rest", "family"]:
		chance += 0.22
	if _indoor_activity in ["working", "studying"]:
		chance *= 0.25
	if _rng.randf() > chance:
		return
	# Entertainment is a genuine autonomous choice, weighted by mood and free time.
	var free_time := current_goal in ["social", "leisure", "rest", "family", "play"]
	var entertainment_roll := _rng.randf()
	if free_time and entertainment_roll < 0.34 and life_sim.has_method("get_phone_media_feed"):
		var media_feed: Array = life_sim.call("get_phone_recommended_feed", citizen_id, "video", 60)
		if not media_feed.is_empty():
			var watched: Dictionary = media_feed[_rng.randi_range(0, media_feed.size() - 1)]
			var watch_time := _rng.randf_range(18.0, minf(180.0, float(watched.get("duration_seconds", 180))))
			life_sim.call("record_phone_media_view", citizen_id, str(watched.get("id", "")), watch_time)
			remember_event("watched_video:" + str(watched.get("topic", "variety")))
			_phone_action_cooldown = _rng.randf_range(45.0, 120.0)
			_phone_battery_visual = maxf(0.15, _phone_battery_visual - watch_time * 0.0008)
			_set_phone_visible(true)
			_pause_remaining = maxf(_pause_remaining, watch_time * 0.08)
			return
	if free_time and entertainment_roll >= 0.52 and entertainment_roll < 0.70 and life_sim.has_method("get_phone_recommended_feed"):
		var image_feed: Array = life_sim.call("get_phone_recommended_feed", citizen_id, "image", 40)
		if not image_feed.is_empty():
			var image_item: Dictionary = image_feed[_rng.randi_range(0, image_feed.size() - 1)]
			life_sim.call("record_phone_media_view", citizen_id, str(image_item.get("id", "")), _rng.randf_range(3.0, 12.0))
			if _rng.randf() < 0.3 and life_sim.has_method("react_to_phone_media"):
				life_sim.call("react_to_phone_media", citizen_id, str(image_item.get("id", "")), "like")
			remember_event("viewed_phone_image:" + str(image_item.get("topic", "photo")))
			_phone_action_cooldown = _rng.randf_range(25.0, 75.0)
			_set_phone_visible(true)
			_pause_remaining = maxf(_pause_remaining, 0.8)
			return
	if free_time and _curiosity > 0.42 and entertainment_roll >= 0.70 and _rng.randf() < 0.38 and life_sim.has_method("get_phone_browser_recommendation") and life_sim.has_method("record_phone_browser_visit"):
		var preferred_topic := "technology" if float(_personality_traits.get("curiosity", 0.5)) > 0.72 else ""
		var page: Dictionary = life_sim.call("get_phone_browser_recommendation", citizen_id, preferred_topic)
		if not page.is_empty():
			var reading_time := _rng.randf_range(12.0, 95.0)
			var topic := str(page.get("topic", "general"))
			life_sim.call("record_phone_browser_visit", citizen_id, str(page.get("id", "")), str(page.get("title", "World page")), topic, reading_time)
			_last_browser_topic = topic
			remember_event("read_web_page:" + topic)
			_phone_action_cooldown = _rng.randf_range(55.0, 130.0)
			_phone_battery_visual = maxf(0.15, _phone_battery_visual - reading_time * 0.0007)
			_set_phone_visible(true)
			_pause_remaining = maxf(_pause_remaining, reading_time * 0.06)
			return
	if free_time and entertainment_roll < 0.52 and life_sim.has_method("play_phone_game"):
		var games: Array = life_sim.call("get_phone_games_catalog")
		if not games.is_empty():
			var selected_game: Dictionary = games[_rng.randi_range(0, games.size() - 1)]
			var match_time := _rng.randi_range(5, 18)
			var match_result: Dictionary = life_sim.call("play_phone_game", citizen_id, str(selected_game.get("id", "")), match_time)
			if not match_result.is_empty():
				remember_event("phone_game:" + str(selected_game.get("id", "")) + (":won" if bool(match_result.get("won", false)) else ":lost"))
				_phone_action_cooldown = _rng.randf_range(70.0, 150.0)
				_phone_battery_visual = maxf(0.15, _phone_battery_visual - float(match_time) * 0.0045)
				_set_phone_visible(true)
				_pause_remaining = maxf(_pause_remaining, float(match_time) * 0.12)
				return
	if _curiosity > 0.58 and life_sim.has_method("publish_phone_media") and _rng.randf() < 0.24:
		var media_kind := ["video", "image", "post"][_rng.randi_range(0, 2)]
		var topics := ["city_life", "music", "cars", "food", "travel", "gaming", "wildlife", "fashion", "sports", "technology"]
		var topic: String = topics[_rng.randi_range(0, topics.size() - 1)]
		var captions := ["Bugungi lahza!", "Shahardan yangi kadrlar.", "Buni ko'rishingiz kerak.", "Yangi taassurotlar."]
		life_sim.call("publish_phone_media", citizen_id, media_kind, topic.capitalize() + " — " + str(_rng.randi_range(1, 9999)), topic, captions[_rng.randi_range(0, captions.size() - 1)])
		remember_event("shared_phone_" + media_kind)
		_phone_action_cooldown = _rng.randf_range(90.0, 180.0)
		_set_phone_visible(true)
		return
	var contacts: Array = life_sim.call("get_phone_snapshot", citizen_id).get("contacts", [])
	var possible_contacts: Array[String] = []
	for candidate in _get_nearby_citizens(35.0):
		if candidate == self:
			continue
		var other_id := str(candidate.get("citizen_id"))
		if not other_id.is_empty():
			possible_contacts.append(other_id)
	if possible_contacts.is_empty() and life_sim.has_method("get_family_members"):
		for member in life_sim.call("get_family_members", citizen_id):
			var family_id := str(member.get("id", ""))
			if not family_id.is_empty() and family_id != citizen_id:
				possible_contacts.append(family_id)
	# Residents independently notice and answer unread messages when they have time.
	if life_sim.has_method("get_phone_inbox") and life_sim.has_method("send_phone_message"):
		var unread_messages: Array = life_sim.call("get_phone_inbox", citizen_id, true, 6)
		for incoming_value in unread_messages:
			var incoming: Dictionary = incoming_value
			var sender_id := str(incoming.get("from", ""))
			if sender_id.is_empty() or sender_id == citizen_id or str(incoming.get("to", "")) != citizen_id:
				continue
			if _rng.randf() > 0.62:
				break
			var incoming_text := str(incoming.get("text", "")).to_lower()
			var kindness := float(_personality_traits.get("kindness", 0.5))
			var courage := float(_personality_traits.get("courage", 0.5))
			var replies: Array[String] = []
			if "?" in incoming_text or "qalaysan" in incoming_text or "yaxshi" in incoming_text:
				replies = ["Yaxshiman, rahmat! O'zingiz-chi?", "Hammasi joyida. Sizda qanday yangilik?", "Yaxshi, hozir biroz bandman. Keyinroq gaplashamiz."]
			elif "yordam" in incoming_text or "help" in incoming_text:
				replies = ["Nima bo'ldi? Qo'limdan kelsa yordam beraman.", "Tushundim. Batafsil aytib bering."]
			elif kindness > 0.68:
				replies = ["Xabaringizni oldim. Rahmat!", "Sizdan xabar olganim yaxshi bo'ldi.", "Albatta, keyinroq gaplashamiz."]
			elif courage > 0.68:
				replies = ["Fikringiz qiziq. Buni yaxshilab o'ylab ko'raman.", "Bunga qo'shimcha ma'lumot bera olasizmi?"]
			else:
				replies = ["Tushunarli.", "Mayli, xabar kutaman.", "Hozir yo'ldaman, keyin yozaman."]
			life_sim.call("mark_phone_message_read", citizen_id, str(incoming.get("id", "")))
			if life_sim.call("send_phone_message", citizen_id, sender_id, replies[_rng.randi_range(0, replies.size() - 1)], "reply"):
				remember_event("replied_to_phone_message:" + sender_id)
				_phone_action_cooldown = _rng.randf_range(45.0, 95.0)
				_phone_battery_visual = maxf(0.15, _phone_battery_visual - 0.012)
				_set_phone_visible(true)
				return
	if _social_need > 0.62 and not possible_contacts.is_empty():
		var recipient_id := possible_contacts[_rng.randi_range(0, possible_contacts.size() - 1)]
		var messages := ["Qalaysan? Bugun ko'rishamizmi?", "Ishlaring yaxshimi?", "Keyinroq gaplashamiz.", "Bugun shaharda nima yangilik?"]
		if life_sim.has_method("send_phone_message"):
			life_sim.call("send_phone_message", citizen_id, recipient_id, messages[_rng.randi_range(0, messages.size() - 1)])
			remember_event("sent_message_to:" + recipient_id)
			_phone_action_cooldown = _rng.randf_range(35.0, 75.0)
			_phone_battery_visual = maxf(0.15, _phone_battery_visual - 0.015)
			_set_phone_visible(true)
			return
	if _social_need > 0.48 and not possible_contacts.is_empty() and _rng.randf() < 0.28:
		var call_target := possible_contacts[_rng.randi_range(0, possible_contacts.size() - 1)]
		if life_sim.has_method("make_phone_call"):
			life_sim.call("make_phone_call", citizen_id, call_target, _rng.randi_range(18, 150))
			remember_event("called:" + call_target)
			_phone_action_cooldown = _rng.randf_range(55.0, 110.0)
			_phone_battery_visual = maxf(0.15, _phone_battery_visual - 0.025)
			_set_phone_visible(true)
			return
	if free_time and _social_need > 0.5 and life_sim.has_method("get_phone_trending_feed") and _rng.randf() < 0.32:
		var network_posts: Array = life_sim.call("get_phone_trending_feed", citizen_id, 18)
		var interesting_posts: Array[Dictionary] = []
		for network_post_value in network_posts:
			var network_post: Dictionary = network_post_value
			var liked_by: Array = network_post.get("liked_by", [])
			if str(network_post.get("author_id", "")) != citizen_id and not liked_by.has(citizen_id):
				interesting_posts.append(network_post)
		if not interesting_posts.is_empty():
			var selected_post: Dictionary = interesting_posts[_rng.randi_range(0, interesting_posts.size() - 1)]
			var selected_post_id := str(selected_post.get("id", ""))
			var selected_author := str(selected_post.get("author_id", ""))
			if not selected_post_id.is_empty() and life_sim.has_method("react_to_phone_post"):
				life_sim.call("react_to_phone_post", citizen_id, selected_post_id)
				remember_event("liked_social_post:" + selected_author)
				if _curiosity > 0.82 and life_sim.has_method("add_phone_social_comment") and _rng.randf() < 0.18:
					var short_replies: Array[String] = []
					var kindness := float(_personality_traits.get("kindness", 0.5))
					var courage := float(_personality_traits.get("courage", 0.5))
					var post_mood := str(selected_post.get("mood", "neutral"))
					if post_mood in ["sad", "worried", "stress", "negative"]:
						short_replies = ["Hammasi yaxshi bo'lishiga umid qilaman.", "Yordam kerak bo'lsa, ayting.", "O'zingizni ehtiyot qiling."]
					elif kindness > 0.68:
						short_replies = ["Zo'r fikr, qo'llab-quvvatlayman!", "Buni ko'rib xursand bo'ldim.", "Ajoyib! Omad sizga!"]
					elif courage > 0.68:
						short_replies = ["Bu fikrga qanday keldingiz?", "Boshqa odamlar bunga qanday qaraydi?", "Qiziq, bunga dalilingiz bormi?"]
					else:
						short_replies = ["Men ham shuni ko'rdim.", "Bu haqda ko'proq bilmoqchiman.", "Qiziqarli yangilik."]
					life_sim.call("add_phone_social_comment", citizen_id, selected_post_id, short_replies[_rng.randi_range(0, short_replies.size() - 1)])
				_phone_action_cooldown = _rng.randf_range(35.0, 90.0)
				_set_phone_visible(true)
				return
	if free_time and _social_need > 0.68 and life_sim.has_method("get_phone_suggested_residents") and _rng.randf() < 0.16:
		var suggested_people: Array = life_sim.call("get_phone_suggested_residents", citizen_id, 8)
		if not suggested_people.is_empty():
			var suggested_person: Dictionary = suggested_people[_rng.randi_range(0, suggested_people.size() - 1)]
			var followed_id := str(suggested_person.get("id", ""))
			if not followed_id.is_empty() and life_sim.call("follow_phone_resident", citizen_id, followed_id):
				remember_event("followed_resident:" + followed_id)
				_phone_action_cooldown = _rng.randf_range(65.0, 140.0)
				_set_phone_visible(true)
				return
	if _curiosity > 0.66 and life_sim.has_method("publish_phone_post") and _rng.randf() < 0.2:
		var posts := ["Bugun shahar juda gavjum.", "Yangi kun, yangi rejalar.", "Bugun yaxshi voqea yuz berdi.", "Kelajak tez o'zgaryapti."]
		life_sim.call("publish_phone_post", citizen_id, posts[_rng.randi_range(0, posts.size() - 1)], "curious")
		remember_event("published_phone_post")
		_phone_action_cooldown = _rng.randf_range(80.0, 160.0)
		_phone_battery_visual = maxf(0.15, _phone_battery_visual - 0.02)
		_set_phone_visible(true)


func talk_to_npc(question: String, other_id: String = "", speaker_name: String = "friend") -> String:
	var context := {"speaker_name":speaker_name,"my_name":str(life_profile.get("name",citizen_id)),"occupation":occupation,"city":str(life_profile.get("city","this city")),"goal":_long_term_goal,"children":int(life_profile.get("children_count",0)),"relationship":relationship_score,"other_id":other_id}
	var normalized := question.to_lower()
	var reply := _dialogue.answer_uzbek(question,context) if _contains_dialogue_uzbek(normalized) else _dialogue.answer_question(question,context)
	_dialogue.remember_conversation(other_id,_dialogue.suggest_topic(),reply,question)
	_cognition.update_social_impression(other_id,"conversation",0.58)
	remember_event("dialogue:" + other_id)
	return reply

func _contains_dialogue_uzbek(value: String) -> bool:
	for word in ["qandaysan","qalaysan","isming","kimsan","rahmat","kechir","o'ylaysan","fikring","qayerda","kasbing","oilangg"]:
		if word in value:
			return true
	return false

func get_dialogue_snapshot() -> Dictionary:
	return _dialogue.get_dialogue_snapshot()

func _set_phone_visible(show_phone: bool) -> void:
	is_using_phone = show_phone
	if _phone != null:
		_phone.visible = show_phone

 
func get_ai_decision_snapshot() -> Dictionary:
	return {
		"citizen_id": citizen_id,
		"goal": current_goal,
		"long_term_goal": _long_term_goal,
		"decision_reason": _decision_reason,
		"decision_count": ai_decision_count,
		"needs": {"energy": _energy, "hunger": _hunger, "social": _social_need, "curiosity": _curiosity, "stress": _stress},
		"personality": _personality_traits.duplicate(true),
		"recent_memories": _memory.duplicate(),
		"life_stage": str(life_profile.get("life_stage", "unknown")),
		"transport": "taxi" if _taxi_riding else "walking",
		"emergency_flee_remaining": _crime_flee_timer,
		"cognition": _cognition.get_cognition_snapshot(),
		"decision_explanation": _cognition.explain_last_decision(),
		"dialogue": _dialogue.get_dialogue_snapshot(),
		"action_planner": _action_planner.get_plan_snapshot(),
		"independent_mind": _independent_mind.get_cognitive_snapshot(),
		"planned_action": _planned_action.duplicate(true)
	}

func evaluate_local_risk(threat_position: Vector3, threat_severity: float = 0.5) -> Dictionary:
	var distance := global_position.distance_to(threat_position)
	var courage := float(_personality_traits.get("courage", 0.5))
	var risk_tolerance := float(_personality_traits.get("risk_tolerance", 0.5))
	var exposure := clampf(1.0 - distance / 65.0, 0.0, 1.0)
	var perceived_risk := clampf(exposure * clampf(threat_severity, 0.0, 1.0) * (1.25 - courage * 0.45) * (1.15 - risk_tolerance * 0.3), 0.0, 1.0)
	return {"distance": distance, "perceived_risk": perceived_risk, "should_evacuate": perceived_risk >= 0.38, "courage": courage, "risk_tolerance": risk_tolerance}


func get_autonomy_snapshot() -> Dictionary:
	return _self_direction.get_snapshot()

func _get_active_personal_goal_id() -> String:
	return str(_self_direction.active_personal_goal.get("id", ""))

func _get_personal_goal_activity(goal_id: String) -> String:
	match goal_id:
		"learn_skill", "advance_career", "find_better_job": return "working"
		"start_small_business", "save_money": return "working"
		"help_neighbor", "make_friend", "repair_relationship", "volunteer": return "socializing"
		"spend_time_with_family": return "resting"
		"exercise_for_health", "practice_hobby", "create_something": return "playing"
		"find_quiet_place": return "resting"
		"explore_unknown_place": return "browsing"
	return ""

func _make_indoor_action_token() -> String:
	return citizen_id + ":" + _get_active_personal_goal_id() + ":" + str(int(Time.get_ticks_msec() / 1000.0))

func _get_personal_activity_duration(goal_id: String) -> float:
	match goal_id:
		"learn_skill", "advance_career": return 18.0
		"start_small_business", "find_better_job": return 16.0
		"spend_time_with_family", "repair_relationship": return 14.0
		"exercise_for_health": return 20.0
		"practice_hobby", "create_something": return 17.0
		"save_money": return 10.0
	return 12.0

func _score_personal_activity_satisfaction(goal_id: String) -> float:
	var score := 0.52
	if goal_id == "exercise_for_health": score += (1.0 - _stress) * 0.16 + _energy * 0.12
	elif goal_id in ["make_friend", "repair_relationship", "spend_time_with_family", "help_neighbor"]: score += _social_need * 0.18 + float(_personality_traits.get("kindness", 0.5)) * 0.12
	elif goal_id in ["learn_skill", "advance_career", "find_better_job"]: score += float(_personality_traits.get("ambition", 0.5)) * 0.18 + float(_personality_traits.get("discipline", 0.5)) * 0.1
	elif goal_id in ["practice_hobby", "create_something", "explore_unknown_place"]: score += float(_personality_traits.get("curiosity", 0.5)) * 0.2
	return clampf(score, 0.0, 1.0)

func _get_indoor_action_context() -> Dictionary:
	return {"goal_id":_get_active_personal_goal_id(),"activity":_indoor_activity,"elapsed":_indoor_activity_time,"energy":_energy,"hunger":_hunger,"stress":_stress,"social_need":_social_need,"occupation":occupation}

func _resolve_personal_indoor_activity() -> String:
	var goal_id := _get_active_personal_goal_id()
	var mapped := _get_personal_goal_activity(goal_id)
	if not mapped.is_empty(): return mapped
	return ""

func _record_personal_activity_progress(goal_id: String, amount: float) -> void:
	if goal_id.is_empty(): return
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and life_sim.has_method("update_resident_goal_progress"):
		life_sim.call("update_resident_goal_progress", citizen_id, goal_id, amount)

func _record_personal_skill_practice(goal_id: String) -> void:
	if goal_id not in ["learn_skill", "advance_career", "practice_hobby"]: return
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim == null or not life_sim.has_method("record_resident_skill_mastery"): return
	var skill := str(life_profile.get("career_field", occupation))
	if goal_id == "practice_hobby": skill = _self_direction.discover_hobby({})
	life_sim.call("record_resident_skill_mastery", citizen_id, skill, "autonomous_practice")

func _complete_indoor_personal_action() -> void:
	if _indoor_action_completed: return
	_indoor_action_completed = true
	var goal_id := _get_active_personal_goal_id()
	var satisfaction := _score_personal_activity_satisfaction(goal_id)
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null:
		if life_sim.has_method("record_activity"): life_sim.call("record_activity", citizen_id, _indoor_activity)
		if life_sim.has_method("record_autonomous_goal_result") and not goal_id.is_empty(): life_sim.call("record_autonomous_goal_result", citizen_id, goal_id, true, "completed_indoor_activity")
	_record_personal_skill_practice(goal_id)
	_record_personal_activity_progress(goal_id, 0.2)
	if not goal_id.is_empty(): _self_direction.record_goal_outcome(goal_id, satisfaction, true)
	_finalize_personal_activity_effects(goal_id, satisfaction)
	_record_cognitive_activity_outcome(_indoor_activity, true, satisfaction)
	_memory.append("completed_personal_activity:" + goal_id)
	if _memory.size() > 24: _memory.pop_front()

func _advance_indoor_life_action() -> void:
	if _indoor_action_completed: return
	var goal_id := _get_active_personal_goal_id()
	var threshold := _get_personal_activity_duration(goal_id)
	if _indoor_activity_time >= threshold:
		_complete_indoor_personal_action()

func _apply_indoor_need_outcomes(goal_id: String) -> void:
	match goal_id:
		"exercise_for_health": _stress = maxf(0.0, _stress - 0.08); _energy = maxf(0.0, _energy - 0.06)
		"spend_time_with_family", "make_friend", "repair_relationship", "help_neighbor": _social_need = maxf(0.0, _social_need - 0.16)
		"learn_skill", "advance_career": _stress = minf(1.0, _stress + 0.025)
		"find_quiet_place": _stress = maxf(0.0, _stress - 0.14)
		"practice_hobby", "create_something": _curiosity = maxf(0.0, _curiosity - 0.12)

func _remember_personal_activity_outcome(goal_id: String, satisfaction: float) -> void:
	if goal_id.is_empty(): return
	var result := "satisfied" if satisfaction >= 0.58 else "unsatisfied"
	remember_event("personal_goal:" + goal_id + ":" + result)
	_self_direction.learn_from_satisfaction(goal_id, satisfaction)

func _record_autonomous_family_time(goal_id: String) -> void:
	if goal_id != "spend_time_with_family": return
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and life_sim.has_method("record_family_interaction"):
		life_sim.call("record_family_interaction", citizen_id, "autonomous_family_time")

func _record_autonomous_social_progress(goal_id: String) -> void:
	if goal_id not in ["make_friend", "help_neighbor", "volunteer", "repair_relationship"]: return
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and life_sim.has_method("record_event"):
		life_sim.call("record_event", citizen_id, "self_directed_social_effort:" + goal_id)

func _finalize_personal_activity_effects(goal_id: String, satisfaction: float) -> void:
	_apply_indoor_need_outcomes(goal_id)
	_record_autonomous_family_time(goal_id)
	_record_autonomous_social_progress(goal_id)
	_remember_personal_activity_outcome(goal_id, satisfaction)

func get_indoor_action_snapshot() -> Dictionary:
	return {"activity":_indoor_activity,"elapsed":_indoor_activity_time,"completed":_indoor_action_completed,"token":_indoor_action_token,"personal_goal":_get_active_personal_goal_id(),"context":_get_indoor_action_context()}

func update_resident_belief(subject: String, claim: String, confidence: float, evidence: String = "") -> void:
	_independent_mind.form_belief(subject, claim, confidence, evidence)

func revise_resident_belief(subject: String, claim: String, evidence_quality: float) -> bool:
	return _independent_mind.revise_belief(subject, claim, evidence_quality)

func get_independent_mind_snapshot() -> Dictionary:
	var snapshot: Dictionary = _independent_mind.get_full_cognitive_snapshot()
	snapshot["current_world_goal"] = current_goal
	snapshot["current_action_plan"] = _action_planner.get_plan_snapshot()
	snapshot["cognitive_plan_id"] = _cognitive_plan_id
	return snapshot

func reflect_on_recent_life(topic: String = "") -> Dictionary:
	return _independent_mind.simulate_reflection({"topic":topic,"goal":current_goal,"stress":_stress})


func _sync_independent_goal_state(context: Dictionary) -> void:
	_cognitive_reflection_timer += 2.5
	if _cognitive_reflection_timer >= 10.0:
		_cognitive_reflection_timer = 0.0
		_independent_mind.reconsider_goals(context)
	var active_categories: Dictionary = {}
	var active_count := 0
	for goal in _independent_mind.goals:
		if str(goal.get("status", "")) == "active":
			active_categories[str(goal.get("category", ""))] = true
			active_count += 1
	if active_count >= 6:
		return
	var descriptions := {"hunger":"Find food","energy":"Recover energy","social":"Build a meaningful connection","safety":"Find a safer situation","curiosity":"Discover something new","comfort":"Improve living comfort","purpose":"Make progress toward a personal ambition"}
	for drive in _independent_mind.evaluate_need_drives():
		var category := str(drive.get("need", ""))
		if float(drive.get("urgency", 0.0)) < 0.48 or active_categories.has(category):
			continue
		_independent_mind.generate_goal(str(descriptions.get(category, "Improve life")), category, float(drive.get("urgency", 0.5)), context)
		active_categories[category] = true
		active_count += 1
		if active_count >= 6:
			break

func _apply_independent_goal_bias(scores: Dictionary) -> void:
	var activity_map := {"hunger":"food","energy":"rest","social":"social","safety":"avoid_crowd","curiosity":"explore","comfort":"rest","purpose":"work","exploration":"explore"}
	var ranked: Array[Dictionary] = _independent_mind.get_active_goals(32)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("priority", 0.0)) > float(b.get("priority", 0.0)))
	for index in range(mini(3, ranked.size())):
		var goal: Dictionary = ranked[index]
		var activity := str(activity_map.get(str(goal.get("category", "")), ""))
		if scores.has(activity):
			var progress := float(goal.get("progress", 0.0))
			scores[activity] = float(scores[activity]) + float(goal.get("priority", 0.0)) * (0.16 + (1.0-progress)*0.12)

func _create_cognitive_plan_from_action_plan(goal: String) -> void:
	var snapshot: Dictionary = _action_planner.get_plan_snapshot()
	var planner_steps: Array = snapshot.get("plan", [])
	var steps: Array[Dictionary] = []
	for item in planner_steps:
		if steps.size() >= 8:
			break
		steps.append({"action":str(item.get("action", "")), "goal":goal, "status":"pending"})
	if steps.is_empty():
		return
	var active_goal_id := -1
	for cognitive_goal in _independent_mind.goals:
		if str(cognitive_goal.get("status", "")) == "active" and str(cognitive_goal.get("category", "")) in [goal, "purpose" if goal == "work" else goal]:
			active_goal_id = int(cognitive_goal.get("id", -1))
			break
	_cognitive_plan_id = _independent_mind.create_plan(active_goal_id, steps, "translated_from_world_action_planner")

func _record_cognitive_activity_outcome(activity: String, success: bool, satisfaction: float) -> void:
	_independent_mind.reflect_on_outcome(activity, success, satisfaction, {"goal":current_goal,"position":global_position})
	if _cognitive_plan_id >= 0:
		var advanced: Dictionary = _independent_mind.advance_plan(_cognitive_plan_id, success, "world_activity:" + activity)
		var plan_status := str(advanced.get("status", ""))
		if plan_status == "completed":
			var completed_goal_id := int(advanced.get("goal_id", -1))
			if completed_goal_id >= 0:
				_independent_mind.complete_goal(completed_goal_id, "world_plan_completed:" + activity)
			_cognitive_plan_id = -1
		elif plan_status == "interrupted" or advanced.is_empty():
			_cognitive_plan_id = -1

 
## Residents only reason about anomalies they can physically perceive.
func _scan_simulation_anomalies() -> void:
	if _simulation_awareness == null:
		return
	_simulation_awareness.update_personal_traits(float(_personality_traits.get("curiosity", 0.5)), 1.0 - float(_personality_traits.get("courage", 0.5)))
	var candidates := get_tree().get_nodes_in_group("simulation_anomaly")
	var nearest: Node3D
	var nearest_distance := 10.0 + float(_personality_traits.get("curiosity", 0.5)) * 12.0
	for candidate in candidates:
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	if nearest == null:
		return
	var anomaly_id := str(nearest.get("anomaly_id"))
	var kind := str(nearest.get("anomaly_kind"))
	var detail := str(nearest.get("anomaly_detail"))
	var strength := float(nearest.get("evidence_strength"))
	if _simulation_awareness.observe_anomaly(anomaly_id, kind, detail, strength, "direct_observation"):
		_independent_mind.observe_world_fact("simulation_anomaly:" + anomaly_id, detail, strength, "direct_observation", {"distance":nearest_distance,"kind":kind})
		remember_event("noticed_simulation_anomaly:" + anomaly_id)
		_decision_reason = "noticed_unusual_world_pattern"

func receive_simulation_rumor(payload: Dictionary, trust: float = 0.35) -> bool:
	var accepted := _simulation_awareness.receive_rumor(payload, trust)
	if accepted:
		remember_event("heard_simulation_rumor:" + str(payload.get("id", "unknown")))
	return accepted

func get_simulation_awareness_snapshot() -> Dictionary:
	return _simulation_awareness.get_snapshot()

func test_simulation_hypothesis(question: String, expected: String, risk: float = 0.1) -> int:
	return _simulation_awareness.create_experiment(question, expected, risk)

func resolve_simulation_test(index: int, result: String, supports_theory: bool) -> bool:
	return _simulation_awareness.resolve_experiment(index, result, supports_theory)
