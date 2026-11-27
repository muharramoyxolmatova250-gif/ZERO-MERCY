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
var personal_promises: Dictionary = {}
var _promise_counter := 0
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
	return {"citizen_id":citizen_id,"emotions":emotional_state.duplicate(true),"preferences":learned_preferences.duplicate(true),"beliefs":beliefs.duplicate(true),"intentions":active_intentions.duplicate(true),"last_decision":last_decision.duplicate(true),"memory_count":episodic_memory.size(),"pending_promises":get_pending_promises(),"promise_count":personal_promises.size()}


func appraise_event(event_kind: String, intensity: float, personal_relevance: float = 0.5) -> Dictionary:
	var impact := clampf(intensity * personal_relevance, 0.0, 1.0)
	match event_kind:
		"threat", "violence", "accident":
			emotional_state["fear"] = clampf(float(emotional_state.get("fear",0.0)) + impact * 0.42, 0.0, 1.0)
		"insult", "betrayal":
			emotional_state["anger"] = clampf(float(emotional_state.get("anger",0.0)) + impact * 0.35, 0.0, 1.0)
			emotional_state["trust"] = clampf(float(emotional_state.get("trust",0.35)) - impact * 0.28, 0.0, 1.0)
		"kindness", "help":
			emotional_state["joy"] = clampf(float(emotional_state.get("joy",0.5)) + impact * 0.22, 0.0, 1.0)
			emotional_state["trust"] = clampf(float(emotional_state.get("trust",0.35)) + impact * 0.18, 0.0, 1.0)
		"discovery", "novelty":
			emotional_state["curiosity"] = clampf(float(emotional_state.get("curiosity",0.5)) + impact * 0.3, 0.0, 1.0)
	return emotional_state.duplicate(true)



func update_emotions(delta: float, safe: bool, social_support: float = 0.0) -> void:
	var recovery := delta * (0.0025 + clampf(social_support,0.0,1.0) * 0.006)
	if safe:
		emotional_state["fear"] = maxf(0.0,float(emotional_state.get("fear",0.0))-recovery)
		emotional_state["anger"] = maxf(0.0,float(emotional_state.get("anger",0.0))-recovery*0.55)
		emotional_state["sadness"] = maxf(0.0,float(emotional_state.get("sadness",0.0))-recovery*0.35)
	emotional_state["joy"] = move_toward(float(emotional_state.get("joy",0.5)),0.5,recovery*0.2)
	emotional_state["curiosity"] = move_toward(float(emotional_state.get("curiosity",0.5)),0.5,recovery*0.08)



func remember_episode(kind: String, summary: String, importance: float, location: Vector3 = Vector3.ZERO, other_id: String = "") -> void:
	if kind.is_empty() or summary.is_empty():
		return
	episodic_memory.append({"kind":kind,"summary":summary,"importance":clampf(importance,0.0,1.0),"location":location,"other_id":other_id,"tick":Time.get_ticks_msec()})
	while episodic_memory.size() > 80:
		var weakest := 0
		for index in range(1,episodic_memory.size()):
			if float(episodic_memory[index].get("importance",0.0)) < float(episodic_memory[weakest].get("importance",0.0)):
				weakest = index
		episodic_memory.remove_at(weakest)



func recall_episodes(query: String, limit: int = 5) -> Array[Dictionary]:
	var terms := query.to_lower().split(" ",false)
	var matches: Array[Dictionary] = []
	for episode in episodic_memory:
		var text := (str(episode.get("kind",""))+" "+str(episode.get("summary",""))).to_lower()
		var relevance := 0.0
		for term in terms:
			if term.length() > 2 and term in text:
				relevance += 1.0
		if relevance > 0.0:
			var result := episode.duplicate(true)
			result["recall_score"] = relevance + float(episode.get("importance",0.0))
			matches.append(result)
	matches.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a.get("recall_score",0.0)) > float(b.get("recall_score",0.0)))
	if matches.size() > limit:
		matches.resize(limit)
	return matches



func update_belief(topic: String, evidence: float, reliability: float = 0.5) -> void:
	if topic.is_empty():
		return
	var old: Dictionary = beliefs.get(topic,{"value":0.5,"confidence":0.0,"observations":0})
	var weight := clampf(reliability,0.05,1.0)
	old["value"] = lerpf(float(old.get("value",0.5)),clampf(evidence,0.0,1.0),weight*0.35)
	old["confidence"] = clampf(float(old.get("confidence",0.0))+weight*0.12,0.0,1.0)
	old["observations"] = int(old.get("observations",0))+1
	beliefs[topic] = old



func set_intention(action: String, target_id: String, priority: float, duration_seconds: float) -> void:
	if action.is_empty():
		return
	for index in range(active_intentions.size()-1,-1,-1):
		if str(active_intentions[index].get("action","")) == action and str(active_intentions[index].get("target_id","")) == target_id:
			active_intentions.remove_at(index)
	active_intentions.append({"action":action,"target_id":target_id,"priority":clampf(priority,0.0,1.0),"expires_msec":Time.get_ticks_msec()+int(maxf(1.0,duration_seconds)*1000.0)})
	active_intentions.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.get("priority",0.0)) > float(b.get("priority",0.0)))
	while active_intentions.size() > 8:
		active_intentions.pop_back()

func get_active_intention() -> Dictionary:
	var now := Time.get_ticks_msec()
	for index in range(active_intentions.size()-1,-1,-1):
		if int(active_intentions[index].get("expires_msec",0)) <= now:
			active_intentions.remove_at(index)
	return active_intentions[0].duplicate(true) if not active_intentions.is_empty() else {}



func make_personal_promise(other_id: String, promise_text: String, due_day: int, importance: float = 0.5) -> Dictionary:
	if other_id.is_empty() or promise_text.strip_edges().is_empty():
		return {}
	_promise_counter += 1
	var promise_id := citizen_id + "_promise_" + str(_promise_counter)
	var record := {"id":promise_id,"other_id":other_id,"promise":promise_text,"due_day":due_day,"importance":clampf(importance,0.0,1.0),"status":"pending"}
	personal_promises[promise_id] = record
	return record.duplicate(true)


func resolve_personal_promise(promise_id: String, fulfilled: bool, resolution_day: int = -1) -> Dictionary:
	if not personal_promises.has(promise_id):
		return {}
	var record: Dictionary = personal_promises[promise_id].duplicate(true)
	if str(record.get("status","")) != "pending":
		return record
	record["status"] = "fulfilled" if fulfilled else "broken"
	record["resolved_day"] = resolution_day
	personal_promises[promise_id] = record
	var other_id := str(record.get("other_id",""))
	var importance := float(record.get("importance",0.5))
	update_social_impression(other_id, "keep_promise" if fulfilled else "break_promise", 1.0 if fulfilled else 0.0)
	var impression: Dictionary = social_model.get(other_id,{})
	impression["last_promise"] = record.duplicate(true)
	social_model[other_id] = impression
	return record.duplicate(true)


func get_pending_promises(other_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for promise in personal_promises.values():
		if str(promise.get("status","")) != "pending":
			continue
		if not other_id.is_empty() and str(promise.get("other_id","")) != other_id:
			continue
		result.append(promise.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("due_day",0)) < int(b.get("due_day",0))
	)
	return result


func update_social_impression(other_id: String, interaction: String, outcome: float) -> void:
	if other_id.is_empty():
		return
	var impression: Dictionary = social_model.get(other_id, {"trust":0.35,"familiarity":0.0,"warmth":0.5,"respect":0.5,"conflict":0.0,"interactions":0})
	var result := clampf(outcome, 0.0, 1.0)
	var change := (result - 0.5) * 0.22
	if interaction in ["help", "give_item", "protect", "comfort", "keep_promise", "cooperate"]:
		change += 0.12 * result
	elif interaction in ["attack", "threaten", "steal", "betray", "insult"]:
		change -= 0.3 * (1.0 - result)
	impression["trust"] = clampf(float(impression.get("trust",0.35)) + change, 0.0, 1.0)
	impression["warmth"] = clampf(float(impression.get("warmth",0.5)) + change * 0.72, 0.0, 1.0)
	impression["respect"] = clampf(float(impression.get("respect",0.5)) + change * (0.5 + result * 0.5), 0.0, 1.0)
	var conflict_change := 0.0
	if interaction in ["attack", "threaten", "steal", "betray", "insult"]:
		conflict_change = (1.0 - result) * 0.38
	elif interaction in ["apologize", "forgive", "reconcile"]:
		conflict_change = -result * 0.3
	impression["conflict"] = clampf(float(impression.get("conflict",0.0)) + conflict_change, 0.0, 1.0)
	impression["familiarity"] = clampf(float(impression.get("familiarity",0.0)) + 0.06, 0.0, 1.0)
	impression["interactions"] = int(impression.get("interactions",0)) + 1
	impression["last_interaction"] = interaction
	var history: Array = impression.get("history", []).duplicate(true)
	history.append({"interaction":interaction,"outcome":result,"trust_after":impression["trust"]})
	while history.size() > 12:
		history.pop_front()
	impression["history"] = history
	impression["relationship"] = _relationship_label(impression)
	social_model[other_id] = impression



func score_social_approach(other_id: String, kindness: float, current_stress: float) -> float:
	var impression := get_social_impression(other_id)
	var trust := float(impression.get("trust",0.35))
	var familiarity := float(impression.get("familiarity",0.0))
	var fear := float(emotional_state.get("fear",0.0))
	return clampf(0.28+trust*0.38+familiarity*0.2+kindness*0.14-current_stress*0.28-fear*0.2,0.0,1.0)



func choose_threat_response(distance: float, severity: float, courage: float, protect_dependents: bool = false) -> String:
	var urgency := clampf((1.0-maxf(0.0,distance)/70.0)*severity,0.0,1.0)
	var fear := float(emotional_state.get("fear",0.0))
	var bravery := clampf(courage*0.58+float(emotional_state.get("anger",0.0))*0.12-fear*0.38,0.0,1.0)
	if protect_dependents and urgency > 0.18:
		return "protect_and_evacuate"
	if urgency > 0.72 and bravery < 0.62:
		return "flee"
	if urgency > 0.4 and bravery > 0.72:
		return "assist_from_cover"
	if urgency > 0.2:
		return "seek_safety_and_observe"
	return "continue_cautiously"



func learn_from_outcome(action: String, satisfaction: float, learning_rate: float = 0.08) -> void:
	if action.is_empty():
		return
	var old := float(learned_preferences.get(action,0.0))
	var target := (clampf(satisfaction,0.0,1.0)-0.5)*2.0
	learned_preferences[action] = clampf(lerpf(old,target,clampf(learning_rate,0.01,0.3)),-1.0,1.0)



func evaluate_option_utility(option: Dictionary, context: Dictionary) -> float:
	var benefit := float(option.get("benefit",0.5))
	var cost := float(option.get("cost",0.2))
	var risk := float(option.get("risk",0.1))
	var value_alignment := float(option.get("value_alignment",0.5))
	var urgency := float(option.get("urgency",0.0))
	var fear := float(emotional_state.get("fear",0.0))
	var risk_tolerance := float(context.get("risk_tolerance",0.5))
	return benefit*0.42+value_alignment*0.24+urgency*0.18-cost*0.28-risk*(1.0-risk_tolerance)*0.32-fear*risk*0.18



func compare_decision_outcomes(options: Array[Dictionary], context: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_utility := -INF
	var scored: Array[Dictionary] = []
	for option in options:
		var item := option.duplicate(true)
		var utility := evaluate_option_utility(item,context)
		item["expected_utility"] = utility
		scored.append(item)
		if utility > best_utility:
			best_utility = utility
			best = item
	scored.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.get("expected_utility",0.0)) > float(b.get("expected_utility",0.0)))
	return {"best":best,"ranked":scored,"confidence":decision_confidence(scored)}



func decision_confidence(ranked_options: Array[Dictionary]) -> float:
	if ranked_options.is_empty():
		return 0.0
	if ranked_options.size() == 1:
		return 0.55
	var first := float(ranked_options[0].get("expected_utility",0.0))
	var second := float(ranked_options[1].get("expected_utility",0.0))
	return clampf(0.5+absf(first-second)*0.8,0.5,0.98)



func choose_conflict_response(other_id: String, provocation: float, courage: float, kindness: float) -> String:
	var impression := get_social_impression(other_id)
	var trust := float(impression.get("trust",0.35))
	var anger := float(emotional_state.get("anger",0.0))
	var threat := clampf(provocation*0.55+anger*0.3-trust*0.15,0.0,1.0)
	if threat > 0.78 and courage < 0.4:
		return "withdraw_and_seek_help"
	if kindness > 0.72 or trust > 0.68:
		return "calm_dialogue"
	if threat > 0.62 and courage > 0.72:
		return "defend_boundaries"
	return "question_and_deescalate"



func infer_observed_intent(action: String, target_id: String, context: Dictionary) -> Dictionary:
	var confidence := 0.35
	var inferred := "unknown"
	match action:
		"approach":
			inferred = "social_contact"
			confidence = 0.48
		"run_away":
			inferred = "fear_or_urgency"
			confidence = 0.62
		"give_item", "help":
			inferred = "cooperation"
			confidence = 0.78
		"attack", "threaten":
			inferred = "hostility"
			confidence = 0.82
		"trade":
			inferred = "exchange"
			confidence = 0.72
	if bool(context.get("repeated",false)):
		confidence = minf(0.96,confidence+0.12)
	return {"target_id":target_id,"intent":inferred,"confidence":confidence,"evidence":action}



func assess_crowd_context(observations: Array[Dictionary]) -> Dictionary:
	var danger := 0.0
	var support := 0.0
	var count := 0
	for observation in observations:
		count += 1
		danger += clampf(float(observation.get("danger",0.0)),0.0,1.0)
		support += clampf(float(observation.get("helpfulness",0.0)),0.0,1.0)
	var divisor := maxf(1.0,float(count))
	return {"crowd_size":count,"danger_level":clampf(danger/divisor,0.0,1.0),"social_support":clampf(support/divisor,0.0,1.0),"should_leave":count > 0 and danger/divisor > 0.58}



func adapt_routine(activity: String, disruption: float, importance: float) -> Dictionary:
	var severity := clampf(disruption*importance,0.0,1.0)
	var response := "continue"
	if severity > 0.78:
		response = "cancel_and_replan"
	elif severity > 0.48:
		response = "delay_and_reassess"
	elif severity > 0.22:
		response = "shorten_activity"
	return {"activity":activity,"response":response,"disruption":severity,"priority":clampf(importance,0.0,1.0)}



func explain_last_decision() -> Dictionary:
	return {"citizen_id":citizen_id,"decision":last_decision.duplicate(true),"dominant_emotion":_dominant_emotion(),"active_intention":get_active_intention(),"recalled_memories":recall_episodes(str(last_decision.get("goal","")),3),"belief_topics":beliefs.keys()}

func _dominant_emotion() -> String:
	var selected := "joy"
	var highest := -INF
	for emotion in emotional_state:
		var value := float(emotional_state[emotion])
		if value > highest:
			highest = value
			selected = str(emotion)
	return selected

