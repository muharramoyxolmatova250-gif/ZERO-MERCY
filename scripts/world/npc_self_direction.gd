extends RefCounted
## Self-directed resident agency: generates personal goals and chooses among them.
## Needs and safety remain constraints; routines are preferences, not commands.
var citizen_id := ""
var traits: Dictionary = {}
var preferences: Dictionary = {}
var aspirations: Array[Dictionary] = []
var active_personal_goal: Dictionary = {}
var completed_goals: Array[Dictionary] = []
var rejected_goals: Array[String] = []
var decision_count := 0
var autonomy_score := 0.0
var _rng := RandomNumberGenerator.new()
var _goal_counter := 0

const GOAL_CATALOG := [
	{"id":"learn_skill","activity":"work","drive":"curiosity","weight":0.72,"need":"growth"},
	{"id":"advance_career","activity":"work","drive":"ambition","weight":0.78,"need":"achievement"},
	{"id":"find_better_job","activity":"work","drive":"ambition","weight":0.68,"need":"security"},
	{"id":"start_small_business","activity":"work","drive":"ambition","weight":0.62,"need":"independence"},
	{"id":"help_neighbor","activity":"social","drive":"kindness","weight":0.64,"need":"purpose"},
	{"id":"make_friend","activity":"social","drive":"sociability","weight":0.72,"need":"belonging"},
	{"id":"repair_relationship","activity":"family","drive":"kindness","weight":0.58,"need":"belonging"},
	{"id":"explore_unknown_place","activity":"explore","drive":"curiosity","weight":0.7,"need":"discovery"},
	{"id":"create_something","activity":"leisure","drive":"curiosity","weight":0.6,"need":"expression"},
	{"id":"exercise_for_health","activity":"leisure","drive":"discipline","weight":0.56,"need":"health"},
	{"id":"save_money","activity":"work","drive":"discipline","weight":0.66,"need":"security"},
	{"id":"volunteer","activity":"social","drive":"kindness","weight":0.55,"need":"purpose"},
	{"id":"spend_time_with_family","activity":"family","drive":"sociability","weight":0.7,"need":"belonging"},
	{"id":"find_quiet_place","activity":"rest","drive":"risk_tolerance","weight":0.42,"need":"calm"},
	{"id":"practice_hobby","activity":"leisure","drive":"curiosity","weight":0.65,"need":"expression"}
]

func initialize(identity: String, personality: Dictionary, profile: Dictionary = {}) -> void:
	citizen_id = identity
	traits = personality.duplicate(true)
	_rng.seed = int(abs(hash(identity + ":self-direction")))
	_generate_initial_aspirations(profile)

func _trait(key: String, fallback: float = 0.5) -> float:
	return clampf(float(traits.get(key, fallback)), 0.0, 1.0)

func _generate_initial_aspirations(profile: Dictionary) -> void:
	aspirations.clear()
	var ranked: Array[Dictionary] = []
	for candidate in GOAL_CATALOG:
		var score := _trait(str(candidate.get("drive", ""))) * float(candidate.get("weight", 0.5))
		if str(candidate.get("need", "")) == "security" and float(profile.get("savings", 0.0)) < 100.0:
			score += 0.12
		if str(candidate.get("need", "")) == "belonging" and str(profile.get("marital_status", "single")) == "single":
			score += 0.06
		ranked.append({"goal":candidate.duplicate(true),"score":score + _rng.randf_range(0.0,0.12)})
	ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.score) > float(b.score))
	for index in range(mini(4, ranked.size())):
		aspirations.append(ranked[index].goal)
	if aspirations.size() > 0:
		active_personal_goal = aspirations[0].duplicate(true)

func choose_personal_goal(context: Dictionary = {}) -> Dictionary:
	decision_count += 1
	var best: Dictionary = {}
	var best_score := -INF
	for candidate in GOAL_CATALOG:
		var goal_id := str(candidate.get("id", ""))
		if rejected_goals.has(goal_id):
			continue
		var drive := str(candidate.get("drive", "curiosity"))
		var score := _trait(drive) * float(candidate.get("weight", 0.5))
		score += float(preferences.get(goal_id, 0.0)) * 0.3
		score += _context_bonus(candidate, context)
		if str(active_personal_goal.get("id", "")) == goal_id:
			score -= 0.08
		score += _rng.randf_range(0.0, 0.09)
		if score > best_score:
			best_score = score
			best = candidate.duplicate(true)
	if best.is_empty():
		return {}
	_goal_counter += 1
	best["instance_id"] = citizen_id + "_personal_" + str(_goal_counter)
	best["chosen_score"] = best_score
	best["status"] = "chosen"
	best["self_chosen"] = true
	active_personal_goal = best.duplicate(true)
	autonomy_score = clampf(best_score, 0.0, 1.0)
	return best

func _context_bonus(goal: Dictionary, context: Dictionary) -> float:
	var bonus := 0.0
	var need := str(goal.get("need", ""))
	if need == "health":
		bonus += float(context.get("health_motivation", 0.0)) * 0.25
	if need == "security":
		bonus += float(context.get("financial_pressure", 0.0)) * 0.28
	if need == "belonging":
		bonus += float(context.get("loneliness", 0.0)) * 0.25
	if need == "growth":
		bonus += float(context.get("boredom", 0.0)) * 0.22
	if need == "calm":
		bonus += float(context.get("stress", 0.0)) * 0.22
	if bool(context.get("danger", false)) and need not in ["security", "calm"]:
		bonus -= 0.8
	if bool(context.get("unavailable", false)):
		bonus -= 0.5
	return bonus

func activity_biases(context: Dictionary = {}) -> Dictionary:
	var biases := {"work":0.0,"social":0.0,"family":0.0,"explore":0.0,"leisure":0.0,"rest":0.0}
	if active_personal_goal.is_empty():
		choose_personal_goal(context)
	var activity := str(active_personal_goal.get("activity", ""))
	if biases.has(activity):
		biases[activity] = 0.22 + autonomy_score * 0.3
	return biases

func record_goal_outcome(goal_id: String, satisfaction: float, completed: bool) -> void:
	if goal_id.is_empty():
		return
	var value := clampf(satisfaction, 0.0, 1.0)
	preferences[goal_id] = clampf(float(preferences.get(goal_id, 0.0)) * 0.78 + (value - 0.5) * 0.44, -1.0, 1.0)
	var record := {"id":goal_id,"satisfaction":value,"completed":completed,"day":Time.get_ticks_msec()}
	completed_goals.append(record)
	while completed_goals.size() > 40:
		completed_goals.pop_front()
	if str(active_personal_goal.get("id", "")) == goal_id:
		active_personal_goal["status"] = "completed" if completed else "abandoned"

func abandon_goal(reason: String) -> void:
	var goal_id := str(active_personal_goal.get("id", ""))
	if goal_id.is_empty():
		return
	active_personal_goal["status"] = "abandoned"
	active_personal_goal["abandon_reason"] = reason
	rejected_goals.append(goal_id)
	while rejected_goals.size() > 8:
		rejected_goals.pop_front()
	active_personal_goal.clear()

func get_snapshot() -> Dictionary:
	return {"citizen_id":citizen_id,"active_goal":active_personal_goal.duplicate(true),"aspirations":aspirations.duplicate(true),"preferences":preferences.duplicate(true),"completed_goal_count":completed_goals.size(),"decisions":decision_count,"autonomy_score":autonomy_score}
func revise_aspirations(context: Dictionary = {}) -> void:
	if float(context.get("life_change", 0.0)) > 0.6 or aspirations.is_empty():
		_generate_initial_aspirations(context.get("profile", {}))
func career_preference(context: Dictionary = {}) -> Dictionary:
	var options := ["stay_in_job","seek_promotion","learn_new_trade","change_career","start_business"]
	var scores: Dictionary = {}
	for option in options:
		var score := _trait("ambition") * 0.35 + _trait("discipline") * 0.2
		if option == "start_business": score += _trait("risk_tolerance") * 0.4
		if option == "change_career": score += float(context.get("dissatisfaction", 0.0)) * 0.5
		if option == "seek_promotion": score += float(context.get("experience", 0.0)) * 0.35
		if option == "learn_new_trade": score += _trait("curiosity") * 0.35
		scores[option] = score + _rng.randf_range(0.0, 0.08)
	var best := "stay_in_job"
	for option in scores:
		if float(scores[option]) > float(scores[best]): best = option
	return {"choice":best,"scores":scores}
func evaluate_opportunity(opportunity: Dictionary, context: Dictionary = {}) -> float:
	var benefit := float(opportunity.get("benefit", 0.5))
	var effort := float(opportunity.get("effort", 0.5))
	var risk := float(opportunity.get("risk", 0.2))
	var interest := float(preferences.get(str(opportunity.get("type", "")), 0.0)) + 0.5
	return benefit * 0.38 + interest * 0.24 + _trait("curiosity") * 0.12 - effort * (1.0 - _trait("discipline")) * 0.12 - risk * (1.0 - _trait("risk_tolerance")) * 0.28
func create_goal_from_experience(event: String, activity: String, motivation: float = 0.6) -> Dictionary:
	if event.is_empty() or activity.is_empty():
		return {}
	var goal := {"id":"experience_" + str(abs(hash(event))),"activity":activity,"drive":"curiosity","weight":clampf(motivation,0.1,1.0),"need":"growth","origin_event":event,"self_chosen":true,"status":"chosen"}
	active_personal_goal = goal.duplicate(true)
	return goal
func is_goal_feasible(goal: Dictionary, context: Dictionary = {}) -> bool:
	if goal.is_empty() or bool(context.get("danger", false)):
		return false
	if bool(context.get("has_dependents", false)) and str(goal.get("need", "")) == "discovery" and float(context.get("responsibility_pressure", 0.0)) > 0.8:
		return false
	return float(context.get("available_time", 1.0)) > 0.05 and not bool(context.get("unavailable", false))
func learn_from_satisfaction(goal_id: String, satisfaction: float) -> void:
	var value := clampf(satisfaction, 0.0, 1.0)
	preferences[goal_id] = lerpf(float(preferences.get(goal_id, 0.0)), (value - 0.5) * 1.5, 0.16)
func choose_idle_initiative(context: Dictionary = {}) -> Dictionary:
	var candidates := ["practice_hobby","explore_unknown_place","make_friend","create_something","exercise_for_health","learn_skill"]
	var best := candidates[0]
	var score := -INF
	for candidate in candidates:
		var item: Dictionary = {}
		for entry in GOAL_CATALOG:
			if str(entry.id) == candidate: item = entry
		var value := _trait(str(item.get("drive", "curiosity"))) * float(item.get("weight", 0.5)) + _rng.randf_range(0.0, 0.12)
		if value > score: score = value; best = candidate
	return create_goal_from_experience("idle_initiative", str(_catalog_activity(best)), score)
func _catalog_activity(goal_id: String) -> String:
	for entry in GOAL_CATALOG:
		if str(entry.id) == goal_id: return str(entry.activity)
	return "leisure"
func wants_new_job(context: Dictionary = {}) -> bool:
	var dissatisfaction := clampf(float(context.get("dissatisfaction", 0.0)), 0.0, 1.0)
	var financial_pressure := clampf(float(context.get("financial_pressure", 0.0)), 0.0, 1.0)
	return dissatisfaction * 0.55 + financial_pressure * 0.3 + _trait("ambition") * 0.15 > 0.62
func wants_business(context: Dictionary = {}) -> bool:
	var capital := clampf(float(context.get("capital_readiness", 0.0)), 0.0, 1.0)
	var opportunity := clampf(float(context.get("market_opportunity", 0.0)), 0.0, 1.0)
	return _trait("risk_tolerance") * 0.38 + _trait("ambition") * 0.28 + capital * 0.18 + opportunity * 0.16 > 0.68
func discover_hobby(context: Dictionary = {}) -> String:
	var hobbies := ["music","photography","sports","cooking","reading","crafting","gaming","gardening"]
	var best := hobbies[0]
	var best_score := -INF
	for hobby in hobbies:
		var score := _trait("curiosity") * 0.4 + float(preferences.get("hobby_" + hobby, 0.0)) + _rng.randf_range(0.0, 0.3)
		if hobby == str(context.get("current_hobby", "")): score -= 0.35
		if score > best_score: best_score = score; best = hobby
	return best
func preferred_activity_window(activity: String) -> Dictionary:
	var morning_bias := _trait("discipline") * 0.55 + _trait("ambition") * 0.25
	var evening_bias := _trait("curiosity") * 0.35 + _trait("sociability") * 0.4
	if activity in ["work","learn_skill"]: return {"start":7.0 + (1.0-morning_bias)*2.0,"end":16.0 + morning_bias*2.0}
	if activity in ["social","practice_hobby"]: return {"start":16.0 + (1.0-evening_bias)*2.0,"end":22.0}
	return {"start":0.0,"end":24.0}
func relationship_initiative(context: Dictionary = {}) -> String:
	if float(context.get("loneliness", 0.0)) > 0.7 and _trait("sociability") > 0.45: return "seek_company"
	if float(context.get("conflict", 0.0)) > 0.55 and _trait("kindness") > 0.5: return "repair_relationship"
	if _trait("kindness") > 0.8: return "check_on_friend"
	return "keep_in_touch"
func goal_urgency(context: Dictionary = {}) -> float:
	var urgency := float(context.get("deadline_pressure", 0.0)) * 0.35
	urgency += float(context.get("need_pressure", 0.0)) * 0.4
	urgency += float(context.get("emotional_importance", 0.0)) * 0.25
	return clampf(urgency, 0.0, 1.0)
func should_change_personal_goal(candidate_score: float, context: Dictionary = {}) -> bool:
	if active_personal_goal.is_empty(): return true
	var current_score := float(active_personal_goal.get("chosen_score", 0.0))
	return candidate_score > current_score + 0.18 or goal_urgency(context) > 0.85
func update_aspiration_progress(goal_id: String, progress: float) -> void:
	for index in range(aspirations.size()):
		if str(aspirations[index].get("id", "")) == goal_id:
			aspirations[index]["progress"] = clampf(float(aspirations[index].get("progress", 0.0)) + progress, 0.0, 1.0)
			break
func respect_personal_boundaries(context: Dictionary = {}) -> bool:
	if bool(context.get("sleeping", false)) or bool(context.get("injured", false)):
		return false
	if float(context.get("stress", 0.0)) > 0.96 and _trait("risk_tolerance") < 0.3:
		return false
	return true
func explain_choice() -> String:
	if active_personal_goal.is_empty(): return "No personal goal selected"
	return "Self-selected " + str(active_personal_goal.get("id", "goal")) + " because of personal drives, learned preferences and current circumstances"
func get_agency_metrics() -> Dictionary:
	return {"autonomy_score":autonomy_score,"decision_count":decision_count,"personal_goal_count":completed_goals.size(),"preference_count":preferences.size(),"aspiration_count":aspirations.size(),"self_directed":not active_personal_goal.is_empty()}
func on_major_life_event(event_type: String, context: Dictionary = {}) -> void:
	if event_type in ["job_loss","marriage","birth","retirement","relocation","business_failure","graduation"]:
		revise_aspirations({"life_change":0.8,"profile":context})


func observe_environment(observations: Array[Dictionary]) -> Array[Dictionary]:
	var discovered: Array[Dictionary] = []
	for item in observations:
		var affordance := str(item.get("affordance",""))
		if affordance.is_empty() or not bool(item.get("available",true)): continue
		var interest := float(item.get("interest",0.5))
		var risk := float(item.get("risk",0.0))
		var score := evaluate_opportunity({"type":affordance,"benefit":float(item.get("benefit",0.5)),"effort":float(item.get("effort",0.5)),"risk":risk})
		if score > 0.28:
			discovered.append({"id":"world_"+affordance,"activity":str(item.get("activity","explore")),"drive":str(item.get("drive","curiosity")),"weight":score,"need":str(item.get("need","discovery")),"target":str(item.get("target","")),"self_chosen":true,"origin":"environment","interest":interest})
	return discovered

func remember_interest(topic: String, strength: float = 0.1) -> void:
	if topic.is_empty(): return
	preferences["interest_"+topic] = clampf(float(preferences.get("interest_"+topic,0.0))+clampf(strength,-0.25,0.25),-1.0,1.0)

func generate_goal_from_affordance(affordance: Dictionary) -> Dictionary:
	var verb := str(affordance.get("action","explore"))
	var target := str(affordance.get("target",""))
	if verb.is_empty(): return {}
	_goal_counter += 1
	return {"id":"emergent_"+str(_goal_counter),"activity":str(affordance.get("activity","explore")),"drive":str(affordance.get("drive","curiosity")),"weight":clampf(float(affordance.get("utility",0.5)),0.1,1.0),"need":"discovery","action":verb,"target":target,"origin":"self_discovery","self_chosen":true,"status":"considering"}

func score_goal_candidate(goal: Dictionary, context: Dictionary = {}) -> float:
	var score := float(goal.get("weight",0.5))*0.4
	score += _trait(str(goal.get("drive","curiosity")))*0.24
	score += float(preferences.get(str(goal.get("id","")),0.0))*0.2
	score += _context_bonus(goal,context)
	score += float(goal.get("interest",0.0))*0.16
	score -= float(goal.get("risk",0.0))*(1.0-_trait("risk_tolerance"))*0.3
	if str(goal.get("target","")) == str(context.get("last_target","")): score -= 0.12
	return score

func choose_from_candidates(candidates: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var ranked: Array[Dictionary] = []
	for candidate in candidates:
		if not is_goal_feasible(candidate,context): continue
		ranked.append({"goal":candidate,"score":score_goal_candidate(candidate,context)+_rng.randf_range(0.0,0.04)})
	ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.score)>float(b.score))
	if ranked.is_empty(): return {}
	var chosen: Dictionary = ranked[0].goal.duplicate(true)
	chosen["chosen_score"] = float(ranked[0].score)
	chosen["status"] = "chosen"
	chosen["self_chosen"] = true
	active_personal_goal = chosen.duplicate(true)
	autonomy_score = clampf(float(ranked[0].score),0.0,1.0)
	decision_count += 1
	return chosen

func goal_matches_world_state(goal: Dictionary, world_state: Dictionary) -> bool:
	var target := str(goal.get("target",""))
	if not target.is_empty() and world_state.has("unavailable_targets") and (world_state.unavailable_targets as Array).has(target): return false
	if bool(world_state.get("emergency",false)) and str(goal.get("need","")) not in ["security","calm","health"]: return false
	return true


func build_personal_plan(goal: Dictionary, context: Dictionary = {}) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if goal.is_empty(): return actions
	var activity := str(goal.get("activity","explore"))
	var target := str(goal.get("target",""))
	var steps: Array[String] = []
	match activity:
		"work": steps = ["check_opportunity","prepare","travel","perform_task","review_result"]
		"social": steps = ["choose_person","approach","start_conversation","listen","respond","reflect"]
		"family": steps = ["check_family_needs","travel_home","offer_help","spend_time_together"]
		"food": steps = ["check_hunger","find_food_source","obtain_food","eat"]
		"rest": steps = ["find_safe_place","settle_down","rest","reassess_needs"]
		"leisure": steps = ["choose_interest","find_activity","participate","reflect"]
		_: steps = ["observe_environment","choose_target","approach_target","interact","reflect"]
	for step in steps:
		actions.append({"step":step,"target":target,"goal_id":str(goal.get("id","")),"status":"pending"})
	return actions

func evaluate_plan_step(step: Dictionary, context: Dictionary = {}) -> Dictionary:
	var action := str(step.get("step",""))
	var blocked := bool(context.get("blocked",false)) or bool(context.get("danger",false))
	var utility := 0.5 + _trait("discipline")*0.12 + _trait("curiosity")*0.08
	if blocked: utility -= 0.8
	if float(context.get("energy",1.0)) < 0.15 and action not in ["rest","reassess_needs"]: utility -= 0.45
	return {"step":action,"utility":clampf(utility,0.0,1.0),"feasible":utility>0.2,"reason":"context_and_personality_evaluation"}

func choose_plan_alternative(step: Dictionary, alternatives: Array[String], context: Dictionary = {}) -> String:
	var best := ""
	var best_score := -INF
	for option in alternatives:
		var score := _trait("curiosity")*0.25 + _trait("discipline")*0.2 + float(preferences.get("action_"+option,0.0))
		if option == str(context.get("last_action","")): score -= 0.3
		score += _rng.randf_range(0.0,0.08)
		if score > best_score: best_score=score; best=option
	return best

func interrupt_goal(reason: String, context: Dictionary = {}) -> Dictionary:
	if active_personal_goal.is_empty(): return {}
	var old := active_personal_goal.duplicate(true)
	old["status"]="interrupted"
	old["interrupt_reason"]=reason
	old["progress_before_interrupt"]=float(context.get("progress",0.0))
	completed_goals.append(old)
	active_personal_goal.clear()
	return old

func resume_goal(goal_id: String, context: Dictionary = {}) -> Dictionary:
	for record in completed_goals:
		if str(record.get("id",""))==goal_id and str(record.get("status",""))=="interrupted" and is_goal_feasible(record,context):
			active_personal_goal=record.duplicate(true)
			active_personal_goal["status"]="resumed"
			return active_personal_goal.duplicate(true)
	return {}

func record_action_experience(action: String, target: String, outcome: float) -> void:
	if action.is_empty(): return
	var key := "action_"+action
	preferences[key]=clampf(float(preferences.get(key,0.0))*0.8+(clampf(outcome,0.0,1.0)-0.5)*0.35,-1.0,1.0)
	if not target.is_empty(): remember_interest("target_"+target,(outcome-0.5)*0.08)

func should_reconsider_goal(context: Dictionary = {}) -> bool:
	if active_personal_goal.is_empty(): return true
	if not goal_matches_world_state(active_personal_goal,context): return true
	if bool(context.get("urgent_need",false)) or bool(context.get("major_event",false)): return true
	return float(context.get("goal_satisfaction",0.5)) < 0.12


func goal_is_repetitive(goal_id: String, window: int = 6) -> bool:
	var seen := 0
	for record in completed_goals:
		if str(record.get("id",""))==goal_id: seen+=1
	return seen >= maxi(2,window)

func set_personal_boundary(boundary: String, enabled: bool = true) -> void:
	if boundary.is_empty(): return
	var boundaries: Dictionary = preferences.get("boundaries",{})
	boundaries[boundary]=enabled
	preferences["boundaries"]=boundaries

func respects_goal_boundaries(goal: Dictionary, context: Dictionary = {}) -> bool:
	var boundaries: Dictionary = preferences.get("boundaries",{})
	var category := str(goal.get("need",""))
	if bool(boundaries.get(category,false)): return false
	if bool(context.get("sleeping",false)) or bool(context.get("injured",false)): return false
	if bool(context.get("danger",false)) and str(goal.get("need",""))=="discovery": return false
	return true

func discover_personal_values(events: Array[Dictionary]) -> Dictionary:
	var values := {"family":0.0,"freedom":0.0,"security":0.0,"knowledge":0.0,"community":0.0}
	for event in events:
		var kind := str(event.get("kind",""))
		var impact := clampf(float(event.get("impact",0.0)),-1.0,1.0)
		if kind in ["family","friend","child"]: values.family+=impact
		elif kind in ["restriction","choice","travel"]: values.freedom+=impact
		elif kind in ["danger","loss","debt"]: values.security+=impact
		elif kind in ["study","discovery","skill"]: values.knowledge+=impact
		elif kind in ["help","volunteer","community"]: values.community+=impact
	for key in values: values[key]=clampf(float(values[key]),-1.0,1.0)
	preferences["personal_values"]=values
	return values

func choose_value_aligned_goal(context: Dictionary = {}) -> Dictionary:
	var values: Dictionary = preferences.get("personal_values",{})
	var candidates: Array[Dictionary] = []
	for goal in GOAL_CATALOG:
		var need := str(goal.get("need",""))
		var value_key := "knowledge" if need in ["growth","discovery"] else ("family" if need=="belonging" else ("security" if need=="security" else ("community" if need=="purpose" else "freedom")))
		var candidate := goal.duplicate(true)
		candidate["interest"]=float(values.get(value_key,0.0))*0.25+0.25
		candidates.append(candidate)
	return choose_from_candidates(candidates,context)

func update_social_preference(person_id: String, interaction_result: float) -> void:
	if person_id.is_empty(): return
	var key := "person_"+person_id
	preferences[key]=clampf(float(preferences.get(key,0.0))*0.75+(clampf(interaction_result,0.0,1.0)-0.5)*0.5,-1.0,1.0)

func choose_environmental_target(targets: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var best: Dictionary={}
	var top := -INF
	for target in targets:
		var score := float(target.get("interest",0.0))*0.35+float(target.get("usefulness",0.0))*0.3
		score += float(preferences.get("target_"+str(target.get("id","")),0.0))*0.2
		score -= float(target.get("risk",0.0))*(1.0-_trait("risk_tolerance"))*0.35
		score -= float(target.get("distance",0.0))/250.0
		if score>top: top=score;best=target.duplicate(true)
	best["score"]=top
	return best

func goal_completion_reward(goal: Dictionary, result: Dictionary = {}) -> float:
	var reward := float(result.get("satisfaction",0.5))*0.55
	reward += float(result.get("progress",0.0))*0.25
	reward += _trait("discipline")*0.1
	if bool(result.get("helped_other",false)): reward += _trait("kindness")*0.1
	return clampf(reward,0.0,1.0)


func reflect_on_outcome(goal_id: String, outcome: Dictionary) -> Dictionary:
	var reward := goal_completion_reward(active_personal_goal,outcome)
	record_goal_outcome(goal_id,reward,bool(outcome.get("completed",false)))
	var reflection := {"goal":goal_id,"reward":reward,"lesson":str(outcome.get("lesson","")),"day":int(outcome.get("day",0))}
	var reflections: Array = preferences.get("reflections",[])
	reflections.append(reflection)
	while reflections.size()>24: reflections.pop_front()
	preferences["reflections"]=reflections
	return reflection

func generate_goal_from_memory(memories: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var best: Dictionary={}
	var best_score := 0.0
	for memory in memories:
		var emotion := absf(float(memory.get("emotional_intensity",0.0)))
		var unresolved := bool(memory.get("unresolved",false))
		var score := emotion*(0.65 if unresolved else 0.3)+float(memory.get("importance",0.0))*0.35
		if score>best_score:
			best_score=score
			best={"id":"memory_goal_"+str(memory.get("id",_goal_counter)),"activity":str(memory.get("suggested_activity","reflect")),"drive":"curiosity","weight":score,"need":"growth","origin_memory":str(memory.get("id","")),"self_chosen":true}
	if best_score>0.35 and is_goal_feasible(best,context):
		_goal_counter+=1
		best["instance_id"]=citizen_id+"_memory_"+str(_goal_counter)
		return best
	return {}

func evaluate_conflicting_goals(goals: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var candidates := goals.duplicate(true)
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var sa:=score_goal_candidate(a,context)
		var sb:=score_goal_candidate(b,context)
		return sa>sb)
	if candidates.is_empty(): return {}
	var chosen: Dictionary=candidates[0]
	var second_score := score_goal_candidate(candidates[1],context) if candidates.size()>1 else 0.0
	return {"chosen":chosen.duplicate(true),"conflict":candidates.size()>1,"margin":score_goal_candidate(chosen,context)-second_score}

func set_goal_deadline(goal_id: String, deadline_day: int) -> void:
	if str(active_personal_goal.get("id",""))!=goal_id: return
	active_personal_goal["deadline_day"]=deadline_day

func update_goal_deadline_pressure(current_day: int) -> float:
	var deadline := int(active_personal_goal.get("deadline_day",-1))
	if deadline<0: return 0.0
	var remaining := deadline-current_day
	return clampf(1.0-float(remaining)/14.0,0.0,1.0)

func serialize_agency_state() -> Dictionary:
	return {"citizen_id":citizen_id,"traits":traits.duplicate(true),"preferences":preferences.duplicate(true),"aspirations":aspirations.duplicate(true),"active_goal":active_personal_goal.duplicate(true),"completed_goals":completed_goals.duplicate(true),"decision_count":decision_count,"goal_counter":_goal_counter}

func restore_agency_state(state: Dictionary) -> void:
	if str(state.get("citizen_id",citizen_id))!=citizen_id: return
	traits=state.get("traits",traits).duplicate(true)
	preferences=state.get("preferences",{}).duplicate(true)
	aspirations=state.get("aspirations",[]).duplicate(true)
	active_personal_goal=state.get("active_goal",{}).duplicate(true)
	completed_goals=state.get("completed_goals",[]).duplicate(true)
	decision_count=int(state.get("decision_count",decision_count))
	_goal_counter=int(state.get("goal_counter",_goal_counter))

func autonomy_profile() -> Dictionary:
	return {"traits":traits.duplicate(true),"values":preferences.get("personal_values",{}).duplicate(true),"interests":preferences.duplicate(true),"aspirations":aspirations.duplicate(true),"active_goal":active_personal_goal.duplicate(true),"agency_score":autonomy_score}

func record_failed_attempt(goal_id: String, reason: String) -> void:
	var failures: Dictionary=preferences.get("failures",{})
	failures[goal_id]=int(failures.get(goal_id,0))+1
	preferences["failures"]=failures
	preferences["failure_reason_"+goal_id]=reason
	if int(failures[goal_id])>=3: rejected_goals.append(goal_id)

func goal_failure_penalty(goal_id: String) -> float:
	var failures: Dictionary=preferences.get("failures",{})
	return minf(0.45,float(failures.get(goal_id,0))*0.12)

func update_personal_interest_from_activity(activity: String, enjoyment: float) -> void:
	if activity.is_empty(): return
	var key: String="activity_"+activity
	preferences[key]=clampf(float(preferences.get(key,0.0))*0.82+(clampf(enjoyment,0.0,1.0)-0.5)*0.36,-1.0,1.0)

func create_long_term_ambition(value: String, activity: String, drive: String = "ambition") -> Dictionary:
	if value.is_empty() or activity.is_empty(): return {}
	_goal_counter+=1
	var ambition := {"id":"ambition_"+str(_goal_counter),"value":value,"activity":activity,"drive":drive,"weight":0.8,"need":"achievement","self_chosen":true,"status":"aspiration"}
	aspirations.append(ambition)
	while aspirations.size()>12: aspirations.pop_front()
	return ambition

func select_next_autonomous_intention(context: Dictionary = {}) -> Dictionary:
	var candidates: Array[Dictionary]=[]
	for goal in GOAL_CATALOG:
		candidates.append(goal.duplicate(true))
	for emergent in observe_environment(context.get("affordances",[])):
		candidates.append(emergent)
	var memory_goal := generate_goal_from_memory(context.get("memories",[]),context)
	if not memory_goal.is_empty(): candidates.append(memory_goal)
	return choose_from_candidates(candidates,context)


undefined

undefined

undefined

undefined

undefined

undefined

func resume_interrupted_goal(goal_id: String, context: Dictionary = {}) -> Dictionary:
	for record in completed_goals:
		if str(record.get("id",""))==goal_id and str(record.get("status",""))=="interrupted":
			if is_goal_feasible(record,context):
				active_personal_goal=record.duplicate(true)
				active_personal_goal["status"]="resumed"
				return active_personal_goal.duplicate(true)
	return {}

func learn_from_action_result(action: String, result: Dictionary) -> void:
	var satisfaction := clampf(float(result.get("satisfaction",0.5)),0.0,1.0)
	record_action_experience(action,str(result.get("target","")),satisfaction)
	if not bool(result.get("success",true)):
		record_failed_attempt(str(result.get("goal_id","")),str(result.get("reason","unknown")))

func get_decision_explanation(candidate: Dictionary, context: Dictionary = {}) -> Dictionary:
	return {"goal":str(candidate.get("id","")),"score":score_goal_candidate(candidate,context),"personality_drive":str(candidate.get("drive","")),"learned_preference":float(preferences.get(str(candidate.get("id","")),0.0)),"context_need":str(candidate.get("need","")),"self_selected":true}

func prune_agency_history(max_records: int = 80) -> void:
	while completed_goals.size()>max_records: completed_goals.pop_front()
	while rejected_goals.size()>16: rejected_goals.pop_front()
	var failures: Dictionary=preferences.get("failures",{})
	for key in failures.keys():
		if int(failures[key])<=0: failures.erase(key)
	preferences["failures"]=failures

func get_autonomous_decision_candidates(context: Dictionary = {}) -> Array[Dictionary]:
	var candidates: Array[Dictionary]=[]
	for goal in GOAL_CATALOG:
		var copy: Dictionary=goal.duplicate(true)
		copy["score"]=score_goal_candidate(copy,context)-goal_failure_penalty(str(copy.get("id","")))
		if not goal_is_repetitive(str(copy.get("id",""))): candidates.append(copy)
	for emergent in observe_environment(context.get("affordances",[])):
		emergent["score"]=score_goal_candidate(emergent,context)
		candidates.append(emergent)
	return candidates

func choose_goal_with_constraints(context: Dictionary = {}) -> Dictionary:
	if not respects_goal_boundaries({"need":"discovery"},context):
		context["unavailable"]=true
	var candidates := get_autonomous_decision_candidates(context)
	return choose_from_candidates(candidates,context)

func register_personal_commitment(goal_id: String, reason: String, importance: float = 0.5) -> void:
	if goal_id.is_empty(): return
	var commitments: Dictionary=preferences.get("commitments",{})
	commitments[goal_id]={"reason":reason,"importance":clampf(importance,0.0,1.0),"created_tick":Time.get_ticks_msec()}
	preferences["commitments"]=commitments

func get_personal_commitment(goal_id: String) -> Dictionary:
	var commitments: Dictionary=preferences.get("commitments",{})
	return commitments.get(goal_id,{}).duplicate(true)

func update_personal_relationship_memory(person_id: String, trust_delta: float, warmth_delta: float) -> void:
	if person_id.is_empty(): return
	var relations: Dictionary=preferences.get("relationships",{})
	var record: Dictionary=relations.get(person_id,{"trust":0.5,"warmth":0.5})
	record["trust"]=clampf(float(record.get("trust",0.5))+trust_delta,0.0,1.0)
	record["warmth"]=clampf(float(record.get("warmth",0.5))+warmth_delta,0.0,1.0)
	relations[person_id]=record
	preferences["relationships"]=relations

func choose_personal_goal_for_relationship(person_id: String, context: Dictionary = {}) -> Dictionary:
	var relations: Dictionary=preferences.get("relationships",{})
	var relation: Dictionary=relations.get(person_id,{})
	var warmth := float(relation.get("warmth",0.5))
	var trust := float(relation.get("trust",0.5))
	var goal := {"id":"relationship_"+person_id,"activity":"social","drive":"sociability","weight":warmth*0.65+trust*0.35,"need":"belonging","target":person_id,"self_chosen":true}
	if not is_goal_feasible(goal,context): return {}
	active_personal_goal=goal.duplicate(true)
	return goal

func update_goal_from_new_information(information: Dictionary, context: Dictionary = {}) -> Dictionary:
	var goal_id := str(active_personal_goal.get("id",""))
	if goal_id.is_empty(): return {}
	var relevance := float(information.get("relevance",0.0))
	if relevance>0.65 and bool(information.get("contradicts_plan",false)):
		interrupt_goal("new_information",context)
		return select_next_autonomous_intention(context)
	return active_personal_goal.duplicate(true)


undefined

undefined

undefined