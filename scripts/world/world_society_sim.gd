extends Node
## Background world institutions and social feed. Aggregate simulation, not individual human cognition.
@export_range(1.0, 120.0, 1.0) var update_interval := 5.0
@export_range(1, 100, 1) var posts_per_update := 8
const FALLBACK_CITIES := ["Neo-Tashkent","Neo-Tokyo","Neo-Seoul","Neo-Shanghai","Neo-Singapore","Neo-Dubai","Neo-Istanbul","Neo-London","Neo-Paris","Neo-New York","Neo-Los Angeles","Neo-Sao Paulo","Neo-Sydney","Neo-Cairo","Neo-Mumbai","Neo-Mexico City","Neo-Johannesburg","Neo-Toronto"]
var city_names: Array[String] = []
const INSTITUTIONS := ["government","police","hospital","school","university","transit","energy","media","commerce","emergency"]
const FEED_TOPICS := ["night_market","transit_delay","neon_festival","public_safety","school_event","weather_alert","new_product","community_meetup","city_council","music_release","street_art","power_grid"]
var city_state: Array[Dictionary] = []
var social_feed: Array[Dictionary] = []
var institution_activity: Dictionary = {}
var simulation_day := 1
var simulation_hour := 8
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var total_generated_posts := 0
func _ready() -> void:
 add_to_group("world_society_sim")
 _rng.randomize()
 # Populate social hubs from settlements registered by the global life simulation.
 # Starter cities are only a fallback when map data has not registered any hubs.
 var life_sim := get_tree().get_first_node_in_group("world_life_sim")
 if life_sim != null:
  var hubs: Dictionary = life_sim.get("hub_state")
  for city_id in hubs.keys():
   var hub: Dictionary = hubs[city_id]
   city_names.append(str(hub.get("display_name", city_id)))
 if city_names.is_empty():
  city_names.assign(FALLBACK_CITIES)
 city_names.sort()
 for city in city_names:
  city_state.append({"city":city,"population_cohort":100000,"employment":_rng.randf_range(0.82,0.97),"public_mood":_rng.randf_range(0.35,0.75),"crime_pressure":_rng.randf_range(0.03,0.18),"infrastructure":_rng.randf_range(0.65,0.98),"active_events":[]})
 for institution in INSTITUTIONS:
  institution_activity[institution] = {"staff_on_duty":_rng.randi_range(120,12000),"service_load":_rng.randf_range(0.1,0.8),"budget_health":_rng.randf_range(0.55,1.0),"active":true}
 _advance_world()
func _process(delta: float) -> void:
 _elapsed += delta
 if _elapsed >= update_interval:
  _elapsed = 0.0
  _advance_world()
func _advance_world() -> void:
 simulation_hour += 1
 if simulation_hour >= 24:
  simulation_hour = 0
  simulation_day += 1
 for i in range(city_state.size()):
  var state: Dictionary = city_state[i]
  state["employment"] = clampf(float(state.employment) + _rng.randf_range(-0.004,0.004),0.55,0.99)
  state["public_mood"] = clampf(float(state.public_mood) + _rng.randf_range(-0.025,0.025) + (float(state.infrastructure)-0.7)*0.01,0.05,0.98)
  state["crime_pressure"] = clampf(float(state.crime_pressure) + _rng.randf_range(-0.008,0.008),0.005,0.45)
  state["infrastructure"] = clampf(float(state.infrastructure) + _rng.randf_range(-0.002,0.002),0.35,1.0)
  city_state[i] = state
 for institution in INSTITUTIONS:
  var activity: Dictionary = institution_activity[institution]
  activity["service_load"] = clampf(float(activity.service_load)+_rng.randf_range(-0.08,0.08),0.02,1.0)
  institution_activity[institution] = activity
 _generate_social_posts()
func _generate_social_posts() -> void:
 var life_sim := get_tree().get_first_node_in_group("world_life_sim")
 var profiles: Dictionary = life_sim.get("resident_profiles") if life_sim != null else {}
 var profile_ids: Array = profiles.keys()
 for i in range(posts_per_update):
  var city_index := _rng.randi_range(0,city_names.size()-1)
  var city: Dictionary = city_state[city_index]
  var topic: String = FEED_TOPICS[_rng.randi_range(0,FEED_TOPICS.size()-1)]
  var author_id := "resident_" + str(_rng.randi_range(100000,999999))
  var author_name := "Citizen " + author_id.trim_prefix("resident_")
  var city_name := str(city.city)
  if not profile_ids.is_empty():
   var selected_profile: Dictionary = {}
   for attempt in range(5):
    var candidate_id := str(profile_ids[_rng.randi_range(0, profile_ids.size() - 1)])
    var candidate: Dictionary = profiles[candidate_id]
    if bool(candidate.get("active", false)):
     selected_profile = candidate
     break
   if selected_profile.is_empty():
    selected_profile = profiles[str(profile_ids[_rng.randi_range(0, profile_ids.size() - 1)])]
   author_id = str(selected_profile.get("id", author_id))
   author_name = str(selected_profile.get("name", author_name))
   city_name = str(selected_profile.get("city", city_name))
   topic = _topic_for_resident(selected_profile, topic)
  var post := {"post_id":"ZM-"+str(simulation_day)+"-"+str(simulation_hour)+"-"+str(total_generated_posts),"city":city_name,"author_id":author_id,"author_name":author_name,"topic":topic,"likes":_rng.randi_range(0,9000),"comments":_rng.randi_range(0,800),"created_day":simulation_day,"created_hour":simulation_hour,"caption":_caption_for(topic,city_name),"video":topic in ["neon_festival","street_art","music_release","night_market"]}
  social_feed.push_front(post)
  total_generated_posts += 1
 while social_feed.size() > 300:
  social_feed.pop_back()

func _topic_for_resident(profile: Dictionary, fallback: String) -> String:
 var activity := str(profile.get("last_activity", ""))
 var stage := str(profile.get("life_stage", "adult"))
 if activity == "school" or stage == "student":
  return "school_event"
 if activity == "work":
  return "new_product"
 if activity == "family" or str(profile.get("marital_status", "")) == "married":
  return "community_meetup"
 if activity == "play" or stage == "child":
  return "street_art"
 if stage == "retired":
  return "city_council"
 return fallback
func _caption_for(topic: String, city: String) -> String:
 match topic:
  "night_market": return "Night market is alive in "+city+" tonight."
  "transit_delay": return "Transit update: check the city route network."
  "neon_festival": return "Neon festival lights are on in "+city+"!"
  "public_safety": return "Community safety update from "+city+"."
  "school_event": return "A new school event is happening in "+city+"."
  "weather_alert": return "Weather alert for residents in "+city+"."
  "new_product": return "A new product just launched in "+city+"."
  "community_meetup": return "Residents are meeting downtown in "+city+"."
  "city_council": return "City council bulletin from "+city+"."
  "music_release": return "New underground music is trending in "+city+"."
  "street_art": return "Fresh street art spotted in "+city+"."
  _: return "Live update from "+city+"."
func get_world_society_snapshot() -> Dictionary:
 return {"cities":city_state.size(),"institutions":institution_activity.size(),"feed_posts_cached":social_feed.size(),"posts_generated":total_generated_posts,"simulation_day":simulation_day,"simulation_hour":simulation_hour}
func get_social_feed(limit: int = 20) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for i in range(mini(limit,social_feed.size())):
  result.append(social_feed[i])
 return result
