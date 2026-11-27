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
