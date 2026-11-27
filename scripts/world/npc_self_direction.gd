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
