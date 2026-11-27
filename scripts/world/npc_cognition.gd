extends RefCounted
## Utility-driven cognition layer for autonomous residents. All state is per citizen.
var citizen_id := ""
var emotional_state := {"joy":0.5,"fear":0.1,"anger":0.0,"sadness":0.0,"trust":0.35,"curiosity":0.5}
var learned_preferences: Dictionary = {}
var episodic_memory: Array[Dictionary] = []
var beliefs: Dictionary = {}
var active_intentions: Array[Dictionary] = []
var decision_history: Array[Dictionary] = []
var social_model: Dictionary = {}
var last_decision := {}

func initialize(identity: String, seed_traits: Dictionary = {}) -> void:
	citizen_id = identity
	for key in seed_traits:
		learned_preferences[str(key)] = float(seed_traits[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash(identity + ":cognition")))
	emotional_state["curiosity"] = rng.randf_range(0.2, 0.9)
	emotional_state["trust"] = rng.randf_range(0.15, 0.65)

func evaluate_goal_scores(base_scores: Dictionary, context: Dictionary, traits: Dictionary, memories: Array) -> Dictionary:
	var scores := base_scores.duplicate(true)
	var stress := clampf(float(context.get("stress", 0.0)), 0.0, 1.0)
	var energy := clampf(float(context.get("energy", 0.7)), 0.0, 1.0)
	var hunger := clampf(float(context.get("hunger", 0.2)), 0.0, 1.0)
	var curiosity := float(traits.get("curiosity", 0.5))
	var discipline := float(traits.get("discipline", 0.5))
	var kindness := float(traits.get("kindness", 0.5))
	var fear := float(emotional_state.get("fear", 0.0))
	var trust := float(emotional_state.get("trust", 0.35))
	if scores.has("rest"):
		scores["rest"] = float(scores["rest"]) + (1.0 - energy) * 0.42 + stress * 0.16
	if scores.has("food"):
		scores["food"] = float(scores["food"]) + hunger * 0.35
	if scores.has("explore"):
		scores["explore"] = float(scores["explore"]) + curiosity * float(emotional_state.get("curiosity", 0.5)) * 0.22
	if scores.has("social"):
		scores["social"] = float(scores["social"]) + trust * 0.12 + kindness * 0.08
	if scores.has("avoid_crowd"):
		scores["avoid_crowd"] = float(scores["avoid_crowd"]) + fear * 0.5
	for memory_value in memories:
		var memory := str(memory_value).to_lower()
		if "rejected" in memory and scores.has("social"):
			scores["social"] = float(scores["social"]) * 0.84
		elif "success" in memory and scores.has("work"):
			scores["work"] = float(scores["work"]) + 0.08
		elif "danger" in memory and scores.has("avoid_crowd"):
			scores["avoid_crowd"] = float(scores["avoid_crowd"]) + 0.18
		elif "friend" in memory and scores.has("social"):
			scores["social"] = float(scores["social"]) + 0.12
	for goal in scores:
		var preference := float(learned_preferences.get(str(goal), 0.0))
		scores[goal] = maxf(0.0, float(scores[goal]) + preference * 0.16)
		if str(goal) == "work":
			scores[goal] = float(scores[goal]) * (0.82 + discipline * 0.36)
	return scores

func record_decision(goal: String, reason: String, score: float, context: Dictionary) -> void:
	last_decision = {"goal":goal,"reason":reason,"score":score,"day":int(context.get("day",0)),"hour":int(context.get("hour",12))}
	decision_history.append(last_decision.duplicate(true))
	while decision_history.size() > 40:
		decision_history.pop_front()

func get_cognition_snapshot() -> Dictionary:
	return {"citizen_id":citizen_id,"emotions":emotional_state.duplicate(true),"preferences":learned_preferences.duplicate(true),"beliefs":beliefs.duplicate(true),"intentions":active_intentions.duplicate(true),"last_decision":last_decision.duplicate(true),"memory_count":episodic_memory.size()}
