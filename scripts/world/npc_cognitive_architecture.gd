extends RefCounted
class_name NPCCognitiveArchitecture
## Bounded, inspectable cognitive architecture. It models agency; it does not claim consciousness.

const MAX_MEMORIES := 256
const MAX_GOALS := 32
const MAX_PLANS := 12
const MAX_ACTIONS_PER_PLAN := 16
const MAX_REASONING_STEPS := 24

var resident_id := ""
var traits: Dictionary = {}
var needs: Dictionary = {}
var beliefs: Dictionary = {}
var memories: Array[Dictionary] = []
var goals: Array[Dictionary] = []
var plans: Array[Dictionary] = []
var preferences: Dictionary = {}
var last_decision: Dictionary = {}
var decision_count := 0
var _rng := RandomNumberGenerator.new()
var _next_memory_id := 1
var _next_goal_id := 1

const NEED_KEYS := ["hunger", "energy", "social", "safety", "curiosity", "comfort", "purpose"]

func initialize(id: String, personality: Dictionary = {}, seed_value: int = 0) -> void:
	resident_id = id
	traits = personality.duplicate(true)
	_rng.seed = hash(id) if seed_value == 0 else seed_value
	for key in NEED_KEYS:
		needs[key] = 0.35
	for key in ["curiosity", "sociability", "ambition", "discipline", "kindness", "courage", "risk_tolerance"]:
		preferences[key] = clampf(float(traits.get(key, 0.5)), 0.0, 1.0)
	beliefs = {"world_known": {}, "self_model": {}, "uncertainty": 0.5, "revision_count": 0}

func update_need(key: String, value: float) -> void:
	if key not in NEED_KEYS: return
	needs[key] = clampf(value, 0.0, 1.0)

func add_memory(event: String, context: Dictionary = {}, emotional_weight: float = 0.5, reliability: float = 0.8) -> int:
	if event.strip_edges().is_empty(): return -1
	var item := {"id":_next_memory_id,"event":event,"context":context.duplicate(true),"weight":clampf(emotional_weight,0.0,1.0),"reliability":clampf(reliability,0.0,1.0),"recall_count":0,"created_at":Time.get_unix_time_from_system()}
	_next_memory_id += 1
	memories.append(item)
	while memories.size() > MAX_MEMORIES: memories.pop_front()
	return int(item.id)

func recall_memories(query: String, limit: int = 8) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var q := query.to_lower()
	for memory in memories:
		var event := str(memory.get("event", "")).to_lower()
		var score := 0.0
		if q.is_empty() or event.contains(q): score += 1.0
		score += float(memory.get("weight", 0.5)) * 0.3
		score += float(memory.get("reliability", 0.5)) * 0.2
		if score > 0.0:
			var copy := memory.duplicate(true)
			copy["recall_score"] = score
			found.append(copy)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.recall_score) > float(b.recall_score))
	if found.size() > maxi(1, limit): found.resize(maxi(1, limit))
	return found

func form_belief(subject: String, claim: String, confidence: float, evidence: String = "") -> void:
	if subject.is_empty() or claim.is_empty(): return
	var world: Dictionary = beliefs.get("world_known", {})
	var previous: Dictionary = world.get(subject, {})
	var old_confidence := float(previous.get("confidence", 0.0))
	var evidence_weight := 0.65 if not evidence.is_empty() else 0.35
	var combined := clampf(old_confidence * (1.0 - evidence_weight) + confidence * evidence_weight, 0.0, 1.0)
	world[subject] = {"claim":claim,"confidence":combined,"evidence":evidence,"updated_at":Time.get_unix_time_from_system()}
	beliefs["world_known"] = world
	beliefs["revision_count"] = int(beliefs.get("revision_count", 0)) + 1

func revise_belief(subject: String, new_claim: String, evidence_quality: float) -> bool:
	var world: Dictionary = beliefs.get("world_known", {})
	if not world.has(subject): return false
	var current: Dictionary = world[subject]
	if evidence_quality < 0.25: return false
	current["claim"] = new_claim
	current["confidence"] = clampf(maxf(float(current.get("confidence", 0.0)), evidence_quality), 0.0, 1.0)
	current["updated_at"] = Time.get_unix_time_from_system()
	world[subject] = current
	beliefs["world_known"] = world
	beliefs["revision_count"] = int(beliefs.get("revision_count", 0)) + 1
	add_memory("belief_revised:" + subject, {"claim":new_claim}, 0.4, evidence_quality)
	return true

func generate_goal(description: String, category: String, priority: float, context: Dictionary = {}) -> int:
	if description.is_empty() or category.is_empty(): return -1
	var goal := {"id":_next_goal_id,"description":description,"category":category,"priority":clampf(priority,0.0,1.0),"progress":0.0,"status":"active","context":context.duplicate(true),"created_at":Time.get_unix_time_from_system()}
	_next_goal_id += 1
	goals.append(goal)
	while goals.size() > MAX_GOALS: goals.pop_front()
	return int(goal.id)

func update_goal_progress(goal_id: int, amount: float) -> bool:
	for i in range(goals.size()):
		if int(goals[i].get("id", -1)) == goal_id and goals[i].get("status") == "active":
			goals[i]["progress"] = clampf(float(goals[i].get("progress", 0.0)) + amount, 0.0, 1.0)
			if float(goals[i].progress) >= 1.0: goals[i]["status"] = "completed"
			return true
	return false

func abandon_goal(goal_id: int, reason: String) -> bool:
	for i in range(goals.size()):
		if int(goals[i].get("id", -1)) == goal_id:
			goals[i]["status"] = "abandoned"
			goals[i]["abandon_reason"] = reason
			return true
	return false

func evaluate_need_drives() -> Array[Dictionary]:
	var drives: Array[Dictionary] = []
	for key in NEED_KEYS:
		var deficit := float(needs.get(key, 0.0))
		if deficit >= 0.18:
			var trait_bias := _need_trait_bias(key)
			drives.append({"need":key,"urgency":clampf(deficit * 0.75 + trait_bias * 0.25,0.0,1.0)})
	drives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.urgency) > float(b.urgency))
	return drives

func _need_trait_bias(key: String) -> float:
	match key:
		"social": return float(preferences.get("sociability", 0.5))
		"curiosity": return float(preferences.get("curiosity", 0.5))
		"purpose": return float(preferences.get("ambition", 0.5))
		"safety": return 1.0 - float(preferences.get("risk_tolerance", 0.5))
		_: return 0.5

func evaluate_opportunity(opportunity: Dictionary, context: Dictionary = {}) -> float:
	var fit := clampf(float(opportunity.get("personal_fit", 0.5)),0.0,1.0)
	var reward := clampf(float(opportunity.get("reward", 0.5)),0.0,1.0)
	var risk := clampf(float(opportunity.get("risk", 0.5)),0.0,1.0)
	var effort := clampf(float(opportunity.get("effort", 0.5)),0.0,1.0)
	var curiosity := float(preferences.get("curiosity", 0.5))
	var courage := float(preferences.get("courage", 0.5))
	var energy := 1.0 - float(needs.get("energy", 0.35))
	var social_fit := 0.5
	if str(opportunity.get("kind", "")) == "social": social_fit = float(preferences.get("sociability", 0.5))
	return clampf(fit * 0.28 + reward * 0.22 + curiosity * 0.12 + courage * (1.0-risk) * 0.12 + energy * (1.0-effort) * 0.12 + social_fit * 0.14 - risk * (1.0-float(preferences.get("risk_tolerance", 0.5))) * 0.2,0.0,1.0)

func create_plan(goal_id: int, steps: Array[Dictionary], reason: String = "") -> int:
	if steps.is_empty(): return -1
	var safe_steps: Array[Dictionary] = []
	for step in steps:
		if safe_steps.size() >= MAX_ACTIONS_PER_PLAN: break
		if not str(step.get("action", "")).is_empty(): safe_steps.append(step.duplicate(true))
	if safe_steps.is_empty(): return -1
	var plan := {"id":_rng.randi(),"goal_id":goal_id,"steps":safe_steps,"step_index":0,"status":"ready","reason":reason,"created_at":Time.get_unix_time_from_system()}
	plans.append(plan)
	while plans.size() > MAX_PLANS: plans.pop_front()
	return int(plan.id)

func advance_plan(plan_id: int, success: bool, outcome: String = "") -> Dictionary:
	for i in range(plans.size()):
		if int(plans[i].get("id", -1)) != plan_id: continue
		var plan: Dictionary = plans[i]
		if not success:
			plan["status"] = "interrupted"
			plan["failure"] = outcome
		else:
			plan["step_index"] = int(plan.get("step_index", 0)) + 1
			if int(plan.step_index) >= plan.steps.size(): plan["status"] = "completed"
			else: plan["status"] = "ready"
		plans[i] = plan
		return plan.duplicate(true)
	return {}

func choose_next_action(world: Dictionary, available_actions: Array[Dictionary]) -> Dictionary:
	decision_count += 1
	var drives := evaluate_need_drives()
	var best: Dictionary = {}
	var best_score := -INF
	var reasoning: Array[String] = []
	for action in available_actions:
		var score := evaluate_opportunity(action, world)
		var action_need := str(action.get("need", ""))
		for drive in drives:
			if str(drive.need) == action_need: score += float(drive.urgency) * 0.35
		var action_name := str(action.get("action", ""))
		if action_name.is_empty(): continue
		var recent_penalty := _recent_action_penalty(action_name)
		score -= recent_penalty
		if score > best_score:
			best_score = score
			best = action.duplicate(true)
	if not best.is_empty():
		reasoning.append("highest_contextual_utility")
		reasoning.append("need_drives_considered")
		reasoning.append("personality_preferences_considered")
		reasoning.append("recent_repetition_penalty")
	last_decision = {"action":best.duplicate(true),"score":best_score,"reasoning":reasoning,"decision_number":decision_count,"at":Time.get_unix_time_from_system()}
	if not best.is_empty(): add_memory("decision:" + str(best.get("action", "")), {"score":best_score}, 0.25, 0.9)
	return best

func _recent_action_penalty(action_name: String) -> float:
	var penalty := 0.0
	for i in range(maxi(0, memories.size()-12), memories.size()):
		if str(memories[i].get("event", "")) == "decision:" + action_name: penalty += 0.025
	return minf(penalty, 0.2)

func reflect_on_outcome(action_name: String, success: bool, satisfaction: float, context: Dictionary = {}) -> void:
	add_memory("outcome:" + action_name + (":success" if success else ":failure"), context, satisfaction, 0.95)
	var preference_key := "action:" + action_name
	var old := float(preferences.get(preference_key, 0.5))
	preferences[preference_key] = clampf(old * 0.8 + satisfaction * 0.2,0.0,1.0)
	if not success: beliefs["uncertainty"] = minf(1.0, float(beliefs.get("uncertainty", 0.5)) + 0.04)

func simulate_reflection(context: Dictionary = {}) -> Dictionary:
	var drives := evaluate_need_drives()
	var active_goals: Array[Dictionary] = []
	for goal in goals:
		if goal.get("status") == "active": active_goals.append(goal.duplicate(true))
	active_goals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.priority) > float(b.priority))
	return {"drives":drives,"active_goals":active_goals,"memories_recalled":recall_memories(str(context.get("topic", "")), 5),"belief_uncertainty":beliefs.get("uncertainty", 0.5),"decision_count":decision_count}

func get_cognitive_snapshot() -> Dictionary:
	return {"resident_id":resident_id,"needs":needs.duplicate(true),"beliefs":beliefs.duplicate(true),"memory_count":memories.size(),"goal_count":goals.size(),"plan_count":plans.size(),"decision_count":decision_count,"last_decision":last_decision.duplicate(true),"active_drives":evaluate_need_drives()}

func generate_goal_from_drive(context: Dictionary = {}) -> int:
	var drives := evaluate_need_drives()
	if drives.is_empty(): return -1
	var drive: Dictionary = drives[0]
	var need := str(drive.get("need", ""))
	var descriptions := {"hunger":"Find food and eat","energy":"Find a safe place to rest","social":"Seek meaningful company","safety":"Move toward a safer place","curiosity":"Explore something unfamiliar","comfort":"Improve personal comfort","purpose":"Pursue a meaningful challenge"}
	return generate_goal(str(descriptions.get(need, "Improve my situation")), need, float(drive.get("urgency", 0.5)), context)

func detect_goal_conflicts() -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	for i in range(goals.size()):
		if goals[i].get("status") != "active": continue
		for j in range(i+1, goals.size()):
			if goals[j].get("status") != "active": continue
			var a := str(goals[i].get("category", "")); var b := str(goals[j].get("category", ""))
			if (a == "energy" and b == "purpose") or (b == "energy" and a == "purpose") or (a == "safety" and b == "exploration") or (b == "safety" and a == "exploration"):
				conflicts.append({"first":goals[i].id,"second":goals[j].id,"reason":"limited_time_or_risk_tradeoff"})
	return conflicts

func deliberate(options: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var examined: Array[Dictionary] = []
	var count := mini(options.size(), MAX_REASONING_STEPS)
	for i in range(count):
		var option: Dictionary = options[i]
		examined.append({"action":str(option.get("action", "")),"utility":evaluate_opportunity(option, context),"risk":float(option.get("risk", 0.5))})
	examined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.utility) > float(b.utility))
	return {"best":examined[0] if not examined.is_empty() else {},"examined":examined,"limited_by_reasoning_budget":options.size()>MAX_REASONING_STEPS}

func get_decision_caution(action: Dictionary) -> float:
	var uncertainty := float(beliefs.get("uncertainty", 0.5))
	var risk := clampf(float(action.get("risk", 0.5)),0.0,1.0)
	var courage := float(preferences.get("courage", 0.5))
	return clampf(uncertainty * 0.45 + risk * (1.0-courage) * 0.55,0.0,1.0)

func consider_curiosity_goal(discoveries: Array[Dictionary]) -> int:
	if float(preferences.get("curiosity", 0.5)) < 0.35 or discoveries.is_empty(): return -1
	var best: Dictionary = {}
	var best_score := -INF
	for discovery in discoveries:
		var novelty := clampf(float(discovery.get("novelty", 0.5)),0.0,1.0)
		var safe := 1.0-clampf(float(discovery.get("risk", 0.5)),0.0,1.0)
		var score := novelty * float(preferences.get("curiosity", 0.5)) * 0.7 + safe * 0.3
		if score > best_score: best_score = score; best = discovery
	if best.is_empty(): return -1
	return generate_goal("Investigate " + str(best.get("name", "an unfamiliar place")), "exploration", best_score, best)

func reconsider_goals(context: Dictionary = {}) -> Dictionary:
	var changed := 0
	for i in range(goals.size()):
		if goals[i].get("status") != "active": continue
		var category := str(goals[i].get("category", ""))
		var drive := float(needs.get(category, 0.0))
		var priority := float(goals[i].get("priority", 0.5))
		var revised := clampf(priority * 0.82 + drive * 0.18,0.0,1.0)
		if absf(revised-priority) > 0.04: goals[i]["priority"] = revised; changed += 1
	return {"revised_goals":changed,"conflicts":detect_goal_conflicts().size()}

func build_autobiographical_summary(max_items: int = 12) -> Array[String]:
	var summary: Array[String] = []
	var start := maxi(0, memories.size()-maxi(1,max_items))
	for i in range(start, memories.size()):
		var event := str(memories[i].get("event", ""))
		if not event.is_empty(): summary.append(event)
	return summary

func reinforce_preference(key: String, outcome: float, learning_rate: float = 0.08) -> void:
	if key.is_empty(): return
	var old := float(preferences.get(key, 0.5))
	preferences[key] = clampf(old + (clampf(outcome,0.0,1.0)-old)*clampf(learning_rate,0.0,0.5),0.0,1.0)
