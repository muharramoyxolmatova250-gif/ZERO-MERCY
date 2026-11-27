extends RefCounted
## Combinatorial action planner. It composes reusable verbs, targets and motives into
## context-sensitive choices; it does not store a million hand-authored animations.
var citizen_id := ""
var traits: Dictionary = {}
var learned: Dictionary = {}
var habits: Dictionary = {}
var recent_actions: Array[Dictionary] = []
var active_plan: Array[Dictionary] = []
var plan_index := 0
var plan_reason := "initial"
var plan_confidence := 0.0
var decision_count := 0
var last_action := ""
var last_target := ""
var _rng := RandomNumberGenerator.new()
var _cooldowns: Dictionary = {}

const ACTIONS := {
 "work": ["prepare","travel","arrive","focus","ask_for_help","solve_problem","take_break","finish_task"],
 "food": ["search_food","compare_prices","buy_food","prepare_meal","eat","share_food"],
 "social": ["greet","listen","ask_question","share_opinion","tell_story","offer_help","joke","say_goodbye"],
 "rest": ["find_safe_place","sit","relax","sleep","recover"],
 "explore": ["observe","investigate","photograph","collect_information","visit_place","reflect"],
 "commute": ["check_route","choose_transport","travel","avoid_obstacle","change_route","arrive"],
 "family": ["check_on_relative","talk","help_household","care_for_child","share_activity"],
 "school": ["prepare_lessons","travel","attend_class","ask_teacher","study","socialize"],
 "play": ["find_activity","invite_friend","play","take_turn","cooperate"],
 "leisure": ["browse","listen_music","exercise","visit_friend","create_something"],
 "avoid_crowd": ["assess_safety","keep_distance","find_quiet_route","contact_trusted_person"],
 "flee": ["identify_exit","move_to_safety","warn_others","seek_help"]
}

func initialize(identity: String, personality: Dictionary) -> void:
 citizen_id = identity
 traits = personality.duplicate(true)
 _rng.seed = int(abs(hash(identity + ":action-planner")))
 
func _trait(key: String, fallback: float = 0.5) -> float:
 return clampf(float(traits.get(key, fallback)), 0.0, 1.0)

func _cooldown_key(goal: String, action: String) -> String:
 return goal + "::" + action

func _action_utility(goal: String, action: String, context: Dictionary) -> float:
 var curiosity := _trait("curiosity")
 var kindness := _trait("kindness")
 var discipline := _trait("discipline")
 var courage := _trait("courage")
 var score := 0.45 + float(learned.get(action, 0.0)) * 0.22
 score += float(context.get("urgency", 0.0)) * 0.2
 if action in ["investigate","observe","collect_information","photograph"]:
  score += curiosity * 0.22
 if action in ["offer_help","share_food","care_for_child","warn_others"]:
  score += kindness * 0.24
 if action in ["prepare","focus","study","finish_task"]:
  score += discipline * 0.2
 if action in ["defend","confront","warn_others"]:
  score += courage * 0.12
 if action in ["sleep","relax","take_break"]:
  score += (1.0 - float(context.get("energy",0.7))) * 0.35
 if action in ["eat","buy_food","prepare_meal"]:
  score += float(context.get("hunger",0.2)) * 0.35
 if action in ["greet","listen","ask_question","tell_story"]:
  score += _trait("sociability") * 0.16
 if float(_cooldowns.get(_cooldown_key(goal,action),0.0)) > 0.0:
  score -= 0.65
 return score + _rng.randf_range(-0.035,0.035)

func build_plan(goal: String, context: Dictionary = {}) -> Dictionary:
 var actions: Array = ACTIONS.get(goal, ["observe","reassess","continue"])
 var ranked: Array[Dictionary] = []
 for action_value in actions:
  var action := str(action_value)
  ranked.append({"action":action,"utility":_action_utility(goal,action,context)})
 ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool: return float(a.utility) > float(b.utility))
 active_plan.clear()
 var count := mini(3 + int(_trait("discipline") * 2.0), ranked.size())
 for index in range(count):
  active_plan.append({"goal":goal,"action":str(ranked[index].action),"status":"planned"})
 plan_index = 0
 plan_reason = "personality_needs_context_and_learned_outcomes"
 plan_confidence = clampf(float(ranked[0].utility) / 1.6,0.1,0.98) if not ranked.is_empty() else 0.0
 decision_count += 1
 if not active_plan.is_empty():
  last_action = str(active_plan[0].action)
 return get_plan_snapshot()

func next_action() -> Dictionary:
 if plan_index >= active_plan.size():
  return {}
 var result: Dictionary = active_plan[plan_index].duplicate(true)
 plan_index += 1
 last_action = str(result.get("action",""))
 last_target = str(result.get("target",""))
 _cooldowns[_cooldown_key(str(result.get("goal","")),last_action)] = 1.0
 recent_actions.append({"action":last_action,"target":last_target,"tick":Time.get_ticks_msec()})
 while recent_actions.size() > 30:
  recent_actions.pop_front()
 return result

func learn_outcome(action: String, satisfaction: float) -> void:
 if action.is_empty():
  return
 var old := float(learned.get(action,0.0))
 learned[action] = clampf(lerpf(old,(clampf(satisfaction,0.0,1.0)-0.5)*2.0,0.12),-1.0,1.0)

func get_plan_snapshot() -> Dictionary:
 return {"citizen_id":citizen_id,"plan":active_plan.duplicate(true),"next_index":plan_index,"reason":plan_reason,"confidence":plan_confidence,"decisions":decision_count,"last_action":last_action,"last_target":last_target,"learned_actions":learned.size()}


func expand_action_variants(action: String, context: Dictionary) -> Array[String]:
 var variants: Array[String] = [action]
 var weather := str(context.get("weather","clear"))
 var crowd := float(context.get("crowd_density",0.0))
 if action in ["travel","visit_place"] and weather in ["rain","storm","snow"]:
  variants.append("seek_shelter_then_" + action)
 if action in ["greet","talk"] and crowd > 0.7:
  variants.append("wait_for_quieter_moment")
 if action in ["investigate","observe"] and float(context.get("risk",0.0)) > 0.6:
  variants.append("observe_from_cover")
 return variants


func choose_target(candidates: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
 var best: Dictionary = {}
 var best_score := -INF
 for candidate in candidates:
  var distance := float(candidate.get("distance",50.0))
  var affinity := float(candidate.get("affinity",0.0))
  var relevance := float(candidate.get("relevance",0.0))
  var risk := float(candidate.get("risk",0.0))
  var score := relevance*0.42 + affinity*0.28 - distance/100.0 - risk*(1.0-_trait("courage"))*0.3
  score += _rng.randf_range(-0.025,0.025)
  if score > best_score:
   best_score = score
   best = candidate.duplicate(true)
 best["selection_score"] = best_score
 return best


func should_interrupt(context: Dictionary) -> bool:
 var danger := float(context.get("danger",0.0))
 var urgent_need := float(context.get("urgent_need",0.0))
 var social_pressure := float(context.get("social_pressure",0.0))
 return danger > 0.72 or urgent_need > 0.88 or social_pressure > 0.94
func interrupt_plan(reason: String, replacement_goal: String, context: Dictionary = {}) -> Dictionary:
 active_plan.clear()
 plan_index = 0
 plan_reason = "interrupted:" + reason
 return build_plan(replacement_goal,context)
