extends Node
## Hierarchical life simulation: aggregate populations plus persistent individual residents.
@export_range(60.0, 86400.0, 60.0) var month_seconds := 3600.0
@export_range(1000, 100000, 1000) var max_saved_profiles := 50000
const SAVE_PATH := "user://zero_mercy_life_state.json"
const JOBS := ["engineer", "doctor", "teacher", "pilot", "police", "mechanic", "designer", "courier", "scientist", "merchant", "artist", "security"]
const FIRST_NAMES := ["Amina", "Aziz", "Laylo", "Jasur", "Malika", "Sardor", "Madina", "Bekzod", "Yelena", "Denni", "Kamila", "Timur", "Nodira", "Akmal", "Sofia", "Maksim"]
const LAST_NAMES := ["Karimov", "Saidova", "Rahimov", "Ismoilova", "Tursunov", "Nazarova", "Aliyev", "Yusupova", "Mirzaev", "Qodirova", "Petrov", "Sultonova"]
const SCHOOLS := ["Neo Primary School", "Cybernetics Academy", "District Technical School", "Global Science Institute"]
const START_HUBS := ["Neo-Tashkent", "Neo-Tokyo", "Neo-Seoul", "Neo-Shanghai", "Neo-Singapore", "Neo-Dubai", "Neo-Istanbul", "Neo-London", "Neo-Paris", "Neo-New York", "Neo-Los Angeles", "Neo-Sao Paulo", "Neo-Sydney", "Neo-Cairo", "Neo-Mumbai", "Neo-Mexico City", "Neo-Johannesburg", "Neo-Toronto"]
var simulation_day := 1
var simulation_month := 1
var simulation_year := 1
var hub_state: Dictionary = {}
var resident_profiles: Dictionary = {}
var social_bonds: Dictionary = {}
var _claim_cache: Dictionary = {}
var births_total := 0
var deaths_total := 0
var marriages_total := 0
var separations_total := 0
var graduations_total := 0
var career_promotions_total := 0
var independent_households_total := 0
var _elapsed := 0.0
var _save_elapsed := 0.0
var _dirty := false
const SAVE_INTERVAL_SECONDS := 30.0
var _rng := RandomNumberGenerator.new()
var _last_routine_hour := -1

func _ready() -> void:
    add_to_group("world_life_sim")
    _rng.randomize()
    if has_node("/root/GameSession"):
        GameSession.session_clock_changed.connect(_on_session_clock_changed)
    _load_state()
    _rebuild_claim_cache()
    for city_id in START_HUBS:
        _ensure_hub(city_id)
    print("ZERO MERCY life simulation ready: ", hub_state.size(), " city hubs, ", resident_profiles.size(), " saved resident profiles.")

func _process(delta: float) -> void:
    _elapsed += delta
    _save_elapsed += delta
    if _elapsed >= month_seconds:
        _elapsed = 0.0
        advance_month()
    if _dirty and _save_elapsed >= SAVE_INTERVAL_SECONDS:
        _save_elapsed = 0.0
        _save_state()


func _exit_tree() -> void:
    if _dirty:
        _save_state()

func _ensure_hub(city_id: String, population_hint: int = 100000) -> void:
    if hub_state.has(city_id):
        var existing: Dictionary = hub_state[city_id]
        var previous_population := int(existing.get("population", 0))
        var updated_population := maxi(previous_population, maxi(1, population_hint))
        if updated_population != previous_population:
            existing["population"] = updated_population
            _dirty = true
        hub_state[city_id] = existing
        return
    var population := maxi(1, population_hint)
    hub_state[city_id] = {
        "city": city_id, "population": population, "births": 0, "deaths": 0,
        "students": int(round(population * 0.18)), "workers": int(round(population * 0.46)),
        "unemployed": int(round(population * 0.06)),
        "married_families": int(round(population * 0.24)), "retired": int(round(population * 0.09)),
        "public_mood": 0.62, "schools": SCHOOLS.duplicate(),
        "jobs": 0, "last_updated_day": simulation_day
    }


func register_settlement_hub(city_id: String, display_name: String, population_hint: int, latitude: float = 0.0, longitude: float = 0.0) -> void:
    if city_id.is_empty():
        return
    _ensure_hub(city_id, population_hint)
    var hub: Dictionary = hub_state[city_id]
    hub["display_name"] = display_name
    hub["latitude"] = latitude
    hub["longitude"] = longitude
    hub["source"] = "openstreetmap_settlement"
    hub_state[city_id] = hub
    _dirty = true

func register_citizen(citizen_id: String, city_id: String, fallback_occupation: String = "resident") -> Dictionary:
    _ensure_hub(city_id)
    if resident_profiles.has(citizen_id):
        var existing: Dictionary = resident_profiles[citizen_id]
        existing["active"] = true
        existing["last_seen_day"] = simulation_day
        resident_profiles[citizen_id] = existing
        _dirty = true
        if _claim_cache.has(city_id):
            _claim_cache[city_id].erase(citizen_id)
        return existing
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = int(abs(hash(citizen_id)))
    var age := local_rng.randi_range(5, 78)
    var stage := _stage_for_age(age)
    var sex := "female" if local_rng.randf() < 0.5 else "male"
    var job := fallback_occupation
    if stage == "student":
        job = "student"
    elif stage == "child":
        job = "child"
    elif stage == "retired":
        job = "retired"
    elif job == "resident" or job.is_empty():
        job = JOBS[local_rng.randi_range(0, JOBS.size() - 1)]
    # Household status is assigned only when a real second resident can be linked.
    var married := false
    var profile := {
        "id": citizen_id, "name": FIRST_NAMES[local_rng.randi_range(0, FIRST_NAMES.size() - 1)] + " " + LAST_NAMES[local_rng.randi_range(0, LAST_NAMES.size() - 1)],
        "city": city_id, "sex": sex,
        "age_days": age * 365 + local_rng.randi_range(0, 364), "age_years": age,
        "life_stage": stage, "occupation": job,
        "education": _education_for_age(age, local_rng),
        "school": SCHOOLS[local_rng.randi_range(0, SCHOOLS.size() - 1)] if stage == "student" else "",
        "marital_status": "single",
        "partner_id": "family_" + str(abs(hash(citizen_id))) if married else "",
        "children_count": local_rng.randi_range(0, 3) if married and age >= 25 else 0,
        "family_id": "family_" + str(abs(hash(citizen_id))) if married else "",
        "household_id": "household_" + str(abs(hash(citizen_id))),
        "money": local_rng.randi_range(50, 250000), "health": local_rng.randf_range(0.65, 1.0),
        "happiness": local_rng.randf_range(0.35, 0.9), "active": true,
        "born_day": simulation_day - age * 365, "last_seen_day": simulation_day,
        "last_activity": "commute", "life_events": ["registered_in_world"]
    }
    resident_profiles[citizen_id] = profile
    _prune_profiles_if_needed()
    _try_form_household(citizen_id)
    _dirty = true
    return resident_profiles.get(citizen_id, profile)


func _try_form_household(citizen_id: String) -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    var age := int(profile.get("age_years", 0))
    if age < 20 or age > 60 or str(profile.get("marital_status", "single")) != "single":
        return
    # Retry with a fresh world RNG roll each month; failed attempts are not permanent.
    if _rng.randf() > 0.22:
        return
    var candidates: Array[String] = []
    for other_id in resident_profiles.keys():
        if str(other_id) == citizen_id:
            continue
        var other: Dictionary = resident_profiles[other_id]
        if str(other.get("city", "")) != str(profile.get("city", "")):
            continue
        if str(other.get("marital_status", "single")) != "single":
            continue
        var other_age := int(other.get("age_years", 0))
        if other_age < 20 or other_age > 60 or str(other.get("life_stage", "")) == "deceased":
            continue
        candidates.append(str(other_id))
    if candidates.is_empty():
        return
    candidates.sort()
    var partner_id := candidates[_rng.randi_range(0, candidates.size() - 1)]
    var family_id := "family_" + str(abs(hash(citizen_id + "::" + partner_id)))
    profile["marital_status"] = "partnered"
    profile["partner_id"] = partner_id
    profile["family_id"] = family_id
    profile["household_id"] = family_id
    _append_event(profile, "formed_household_with:" + partner_id)
    var partner: Dictionary = resident_profiles[partner_id]
    partner["marital_status"] = "partnered"
    partner["partner_id"] = citizen_id
    partner["family_id"] = family_id
    partner["household_id"] = family_id
    _append_event(partner, "formed_household_with:" + citizen_id)
    resident_profiles[citizen_id] = profile
    resident_profiles[partner_id] = partner
    marriages_total += 1
    _dirty = true


func get_family_members(citizen_id: String) -> Array:
    if not resident_profiles.has(citizen_id):
        return []
    var profile: Dictionary = resident_profiles[citizen_id]
    var family_id := str(profile.get("family_id", ""))
    var parent_ids: Array = profile.get("parents", [])
    if parent_ids.is_empty():
        var parent_id := str(profile.get("parent_id", ""))
        var second_parent_id := str(profile.get("second_parent_id", ""))
        if not parent_id.is_empty(): parent_ids.append(parent_id)
        if not second_parent_id.is_empty(): parent_ids.append(second_parent_id)
    var child_ids: Array = profile.get("children_ids", [])
    var members: Array = []
    for member_id in resident_profiles.keys():
        if str(member_id) == citizen_id:
            continue
        var member: Dictionary = resident_profiles[member_id]
        var member_parents: Array = member.get("parents", [])
        if member_parents.is_empty():
            var p1 := str(member.get("parent_id", ""))
            var p2 := str(member.get("second_parent_id", ""))
            if not p1.is_empty(): member_parents.append(p1)
            if not p2.is_empty(): member_parents.append(p2)
        var relationship := ""
        if str(member.get("partner_id", "")) == citizen_id:
            relationship = "partner"
        elif parent_ids.has(str(member_id)):
            relationship = "parent"
        elif child_ids.has(str(member_id)) or str(member.get("parent_id", "")) == citizen_id or str(member.get("second_parent_id", "")) == citizen_id:
            relationship = "child"
        else:
            for parent_id in parent_ids:
                if member_parents.has(parent_id):
                    relationship = "sibling"
                    break
        if relationship.is_empty() and not family_id.is_empty() and str(member.get("family_id", "")) == family_id:
            relationship = "relative"
        if not relationship.is_empty():
            members.append({"id": str(member_id), "name": str(member.get("name", member_id)),
                "age_years": int(member.get("age_years", 0)),
                "occupation": str(member.get("occupation", "resident")),
                "relationship": relationship, "life_stage": str(member.get("life_stage", "adult"))})
    return members

func record_family_interaction(citizen_id: String, activity: String = "family_time") -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    profile["happiness"] = clampf(float(profile.get("happiness", 0.5)) + 0.015, 0.0, 1.0)
    _append_event(profile, activity)
    resident_profiles[citizen_id] = profile
    for member_data in get_family_members(citizen_id):
        var member_id := str(member_data.get("id", ""))
        if not resident_profiles.has(member_id):
            continue
        var member: Dictionary = resident_profiles[member_id]
        var relation := str(member_data.get("relationship", "relative"))
        var boost := 0.012 if relation in ["child", "parent", "partner"] else 0.006
        member["happiness"] = clampf(float(member.get("happiness", 0.5)) + boost, 0.0, 1.0)
        _append_event(member, "shared_" + activity + ":" + citizen_id)
        resident_profiles[member_id] = member
    _dirty = true


func record_family_conflict(first_id: String, second_id: String, severity: float = 0.25) -> void:
    if not resident_profiles.has(first_id) or not resident_profiles.has(second_id):
        return
    var first: Dictionary = resident_profiles[first_id]
    var second: Dictionary = resident_profiles[second_id]
    var amount := clampf(severity, 0.0, 1.0)
    first["happiness"] = clampf(float(first.get("happiness", 0.5)) - amount * 0.12, 0.0, 1.0)
    second["happiness"] = clampf(float(second.get("happiness", 0.5)) - amount * 0.12, 0.0, 1.0)
    first["family_stress"] = clampf(float(first.get("family_stress", 0.0)) + amount * 0.2, 0.0, 1.0)
    second["family_stress"] = clampf(float(second.get("family_stress", 0.0)) + amount * 0.2, 0.0, 1.0)
    _append_event(first, "family_conflict_with:" + second_id)
    _append_event(second, "family_conflict_with:" + first_id)
    resident_profiles[first_id] = first
    resident_profiles[second_id] = second
    record_social_interaction(first_id, second_id, "argument")
    _dirty = true


func record_childcare(parent_id: String, child_id: String, care_action: String = "care") -> bool:
    if not resident_profiles.has(parent_id) or not resident_profiles.has(child_id):
        return false
    var child: Dictionary = resident_profiles[child_id]
    if str(child.get("parent_id", "")) != parent_id and str(child.get("second_parent_id", "")) != parent_id:
        return false
    child["happiness"] = clampf(float(child.get("happiness", 0.5)) + 0.025, 0.0, 1.0)
    child["health"] = clampf(float(child.get("health", 0.8)) + 0.008, 0.0, 1.0)
    _append_event(child, "received_care:" + care_action)
    resident_profiles[child_id] = child
    var parent: Dictionary = resident_profiles[parent_id]
    parent["family_stress"] = clampf(float(parent.get("family_stress", 0.0)) - 0.025, 0.0, 1.0)
    _append_event(parent, "provided_childcare:" + child_id)
    resident_profiles[parent_id] = parent
    _dirty = true
    return true


func _simulate_household_month() -> void:
    var handled_pairs: Dictionary = {}
    for citizen_id in resident_profiles.keys():
        var profile: Dictionary = resident_profiles[citizen_id]
        var partner_id := str(profile.get("partner_id", ""))
        if partner_id.is_empty() or not resident_profiles.has(partner_id):
            continue
        var pair_key := _social_pair_key(str(citizen_id), partner_id)
        if handled_pairs.has(pair_key):
            continue
        handled_pairs[pair_key] = true
        var partner: Dictionary = resident_profiles[partner_id]
        var stress := (float(profile.get("family_stress", 0.0)) + float(partner.get("family_stress", 0.0))) * 0.5
        var happiness := (float(profile.get("happiness", 0.5)) + float(partner.get("happiness", 0.5))) * 0.5
        if stress > 0.9 and happiness < 0.18 and _rng.randf() < 0.015:
            separate_partners(str(citizen_id), "relationship_breakdown")
        elif stress > 0.72 and happiness < 0.3 and _rng.randf() < 0.08:
            record_family_conflict(str(citizen_id), partner_id, 0.3)
        else:
            profile["family_stress"] = maxf(0.0, float(profile.get("family_stress", 0.0)) - 0.02)
            partner["family_stress"] = maxf(0.0, float(partner.get("family_stress", 0.0)) - 0.02)
            resident_profiles[citizen_id] = profile
            resident_profiles[partner_id] = partner


func separate_partners(citizen_id: String, reason: String = "mutual_separation") -> bool:
    if not resident_profiles.has(citizen_id):
        return false
    var profile: Dictionary = resident_profiles[citizen_id]
    var partner_id := str(profile.get("partner_id", ""))
    if partner_id.is_empty() or not resident_profiles.has(partner_id):
        return false
    var partner: Dictionary = resident_profiles[partner_id]
    profile["partner_id"] = ""
    partner["partner_id"] = ""
    profile["marital_status"] = "single"
    partner["marital_status"] = "single"
    # Children retain their shared family identity and links to both parents.
    var retained_family := str(profile.get("family_id", ""))
    _append_event(profile, "separated:" + reason)
    _append_event(partner, "separated:" + reason)
    if retained_family.is_empty():
        retained_family = str(partner.get("family_id", ""))
    profile["family_id"] = retained_family
    partner["family_id"] = retained_family
    profile["household_id"] = "household_" + str(abs(hash(citizen_id + ":separated:" + str(simulation_day))))
    partner["household_id"] = "household_" + str(abs(hash(partner_id + ":separated:" + str(simulation_day))))
    resident_profiles[citizen_id] = profile
    resident_profiles[partner_id] = partner
    # Lifetime marriage count stays cumulative; separations are separate statistics.
    separations_total += 1
    _dirty = true
    return true

func claim_resident_id(city_id: String) -> String:
    if not _claim_cache.has(city_id):
        _claim_cache[city_id] = []
    var candidates: Array = _claim_cache[city_id]
    while not candidates.is_empty():
        var candidate_index := _rng.randi_range(0, candidates.size() - 1)
        var selected_id := str(candidates.pop_at(candidate_index))
        if not resident_profiles.has(selected_id):
            continue
        var selected: Dictionary = resident_profiles[selected_id]
        if bool(selected.get("active", false)) or str(selected.get("life_stage", "")) == "deceased":
            continue
        selected["active"] = true
        selected["last_seen_day"] = simulation_day
        resident_profiles[selected_id] = selected
        _dirty = true
        _claim_cache[city_id] = candidates
        return selected_id
    _claim_cache[city_id] = candidates
    return ""

func unregister_citizen(citizen_id: String) -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    profile["active"] = false
    profile["last_seen_day"] = simulation_day
    resident_profiles[citizen_id] = profile
    _dirty = true
    var city_id := str(profile.get("city", ""))
    if not _claim_cache.has(city_id):
        _claim_cache[city_id] = []
    if not _claim_cache[city_id].has(citizen_id):
        _claim_cache[city_id].append(citizen_id)

func record_activity(citizen_id: String, activity: String) -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    profile["last_activity"] = activity
    if activity in ["family", "social", "play", "leisure"]:
        profile["happiness"] = clampf(float(profile.get("happiness", 0.5)) + 0.002, 0.0, 1.0)
    elif activity == "work":
        profile["money"] = int(profile.get("money", 0)) + 1
    resident_profiles[citizen_id] = profile
    _dirty = true

func record_social_interaction(first_id: String, second_id: String, interaction: String = "conversation") -> void:
    if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
        return
    var pair_id := _social_pair_key(first_id, second_id)
    var bond: Dictionary = social_bonds.get(pair_id, {
        "first": first_id, "second": second_id, "familiarity": 0.0,
        "trust": 0.0, "friendship": 0.0, "interactions": 0,
        "last_interaction_day": simulation_day, "history": []
    })
    bond["familiarity"] = clampf(float(bond.get("familiarity", 0.0)) + 0.04, 0.0, 1.0)
    bond["interactions"] = int(bond.get("interactions", 0)) + 1
    bond["last_interaction_day"] = simulation_day
    var history: Array = bond.get("history", [])
    history.append({"day": simulation_day, "type": interaction})
    while history.size() > 16:
        history.pop_front()
    bond["history"] = history
    if interaction in ["friendly_chat", "help", "shared_activity"]:
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) + 0.025, -1.0, 1.0)
        bond["friendship"] = clampf(float(bond.get("friendship", 0.0)) + 0.035, -1.0, 1.0)
    elif interaction in ["argument", "threat", "betrayal"]:
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) - 0.12, -1.0, 1.0)
        bond["friendship"] = clampf(float(bond.get("friendship", 0.0)) - 0.08, -1.0, 1.0)
    social_bonds[pair_id] = bond
    _dirty = true


func get_social_bond(first_id: String, second_id: String) -> Dictionary:
    if first_id.is_empty() or second_id.is_empty():
        return {}
    return social_bonds.get(_social_pair_key(first_id, second_id), {}).duplicate(true)


func _social_pair_key(first_id: String, second_id: String) -> String:
    var ids := [first_id, second_id]
    ids.sort()
    return str(ids[0]) + "::" + str(ids[1])


func record_event(citizen_id: String, event_name: String) -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    var events: Array = profile.get("life_events", [])
    events.append({"day": simulation_day, "event": event_name})
    while events.size() > 32:
        events.pop_front()
    profile["life_events"] = events
    resident_profiles[citizen_id] = profile
    _dirty = true


func _on_session_clock_changed(hour: float) -> void:
    var current_hour := floori(hour)
    if current_hour == _last_routine_hour:
        return
    _last_routine_hour = current_hour
    advance_daily_routines(current_hour)


func advance_daily_routines(hour: int) -> void:
    var changed_count := 0
    for citizen_id in resident_profiles.keys():
        var profile: Dictionary = resident_profiles[citizen_id]
        if str(profile.get("life_stage", "")) == "deceased":
            continue
        var stage := str(profile.get("life_stage", "adult"))
        var occupation := str(profile.get("occupation", "resident"))
        var activity := "sleep"
        if hour >= 6 and hour < 8:
            activity = "commute"
        elif hour >= 8 and hour < 15 and stage == "student":
            activity = "school"
        elif hour >= 8 and hour < 17 and stage == "adult" and occupation not in ["unemployed", "retired", "child", "student"]:
            activity = "work"
        elif hour >= 9 and hour < 16 and stage == "retired":
            activity = "leisure"
        elif hour >= 15 and hour < 18:
            activity = "commute" if stage == "adult" else "play"
        elif hour >= 18 and hour < 22:
            activity = "family" if str(profile.get("marital_status", "single")) == "partnered" or not Array(profile.get("children_ids", [])).is_empty() else "social"
        profile["last_activity"] = activity
        profile["schedule_hour"] = hour
        if activity in ["family", "social", "play", "leisure"]:
            profile["happiness"] = clampf(float(profile.get("happiness", 0.5)) + 0.001, 0.0, 1.0)
        if activity == "family":
            profile["family_time_days"] = int(profile.get("family_time_days", 0)) + 1
            var partner_id := str(profile.get("partner_id", ""))
            if resident_profiles.has(partner_id):
                var partner: Dictionary = resident_profiles[partner_id]
                partner["happiness"] = clampf(float(partner.get("happiness", 0.5)) + 0.002, 0.0, 1.0)
                resident_profiles[partner_id] = partner
        elif activity == "work":
            profile["money"] = int(profile.get("money", 0)) + 5
        elif activity == "school":
            profile["education"] = str(profile.get("education", "school"))
        resident_profiles[citizen_id] = profile
        changed_count += 1
    if changed_count > 0:
        _dirty = true
        publish_event_if_available("daily_routine_updated", {"hour": hour, "citizens_updated": changed_count})


func publish_event_if_available(event_id: String, payload: Dictionary) -> void:
    if has_node("/root/GameSession"):
        GameSession.publish_world_event(event_id, payload)

func advance_month() -> void:
    simulation_day += 30
    simulation_month += 1
    if simulation_month > 12:
        simulation_month = 1
        simulation_year += 1
    for city_id in hub_state.keys():
        var hub: Dictionary = hub_state[city_id]
        var population := int(hub.get("population", 100000))
        var births := maxi(1, int(round(float(population) * 0.0011)))
        var deaths := maxi(1, int(round(float(population) * 0.00065)))
        hub["births"] = int(hub.get("births", 0)) + births
        hub["deaths"] = int(hub.get("deaths", 0)) + deaths
        hub["population"] = maxi(1, population + births - deaths)
        hub["public_mood"] = clampf(float(hub.get("public_mood", 0.6)) + _rng.randf_range(-0.025, 0.025), 0.1, 0.95)
        births_total += births
        deaths_total += deaths
        hub["last_updated_day"] = simulation_day
        hub_state[city_id] = hub
    var ids := resident_profiles.keys()
    for citizen_id in ids:
        var profile: Dictionary = resident_profiles[citizen_id]
        if str(profile.get("life_stage", "")) == "deceased":
            continue
        profile["age_days"] = int(profile.get("age_days", 0)) + 30
        var old_age := int(profile.get("age_years", 0))
        var new_age := int(floor(float(profile["age_days"]) / 365.0))
        profile["age_years"] = new_age
        var old_stage := str(profile.get("life_stage", "adult"))
        var new_stage := _stage_for_age(new_age)
        if new_stage != old_stage:
            profile["life_stage"] = new_stage
            _apply_stage_transition(profile, old_stage, new_stage)
        if new_age >= 20 and new_age <= 42 and str(profile.get("sex", "")) == "female" and str(profile.get("marital_status", "single")) == "partnered" and _rng.randf() < 0.006:
            profile["children_count"] = int(profile.get("children_count", 0)) + 1
            births_total += 1
            _append_event(profile, "new_child_born")
            _create_child_profile(profile, str(profile.get("partner_id", "")))
            profile = resident_profiles.get(citizen_id, profile)
        if new_stage == "adult" and old_stage == "student":
            _start_independent_life(profile)
        if new_stage == "adult":
            _advance_career_month(profile)
        if new_age >= 82 and _rng.randf() < 0.006:
            profile["life_stage"] = "deceased"
            profile["active"] = false
            deaths_total += 1
            _append_event(profile, "died_of_old_age")
        profile["health"] = clampf(float(profile.get("health", 0.9)) + _rng.randf_range(-0.015, 0.008), 0.05, 1.0)
        resident_profiles[citizen_id] = profile
    # Marriage is only recorded when two real residents are linked.
    for citizen_id in resident_profiles.keys():
        var candidate: Dictionary = resident_profiles[citizen_id]
        if str(candidate.get("marital_status", "single")) == "single":
            _try_form_household(str(citizen_id))
    _simulate_household_month()
    _recount_all_hubs()
    _save_state()
    print("ZERO MERCY life month ", simulation_year, "-", simulation_month,
        ": births=", births_total, " deaths=", deaths_total, " marriages=", marriages_total,
        " residents=", resident_profiles.size())


func _create_child_profile(parent: Dictionary, second_parent_id: String = "") -> void:
    var parent_id := str(parent.get("id", "parent"))
    resident_profiles[parent_id] = parent
    var child_number := int(parent.get("children_count", 1))
    var child_id := "birth_" + str(abs(hash(parent_id + ":" + str(simulation_day) + ":" + str(child_number))))
    if resident_profiles.has(child_id):
        return
    var city_id := str(parent.get("city", ""))
    resident_profiles[child_id] = {
        "id": child_id,
        "name": FIRST_NAMES[_rng.randi_range(0, FIRST_NAMES.size() - 1)] + " " + LAST_NAMES[_rng.randi_range(0, LAST_NAMES.size() - 1)],
        "city": city_id, "sex": "female" if _rng.randf() < 0.5 else "male",
        "age_days": 0, "age_years": 0, "life_stage": "child",
        "occupation": "child", "education": "early_childhood", "school": "",
        "marital_status": "single", "partner_id": "",
        "children_count": 0, "family_id": str(parent.get("family_id", "")) if not str(parent.get("family_id", "")).is_empty() else "family_" + str(abs(hash(parent_id))),
        "household_id": str(parent.get("household_id", parent.get("family_id", ""))),
        "parent_id": parent_id, "second_parent_id": second_parent_id,
        "parents": [parent_id, second_parent_id] if not second_parent_id.is_empty() else [parent_id],
        "money": 0, "health": 0.98,
        "happiness": 0.8, "active": false, "born_day": simulation_day,
        "last_seen_day": simulation_day, "last_activity": "sleep",
        "life_events": [{"day": simulation_day, "event": "born"}]
    }
    if not _claim_cache.has(city_id):
        _claim_cache[city_id] = []
    _claim_cache[city_id].append(child_id)
    var updated_parent: Dictionary = resident_profiles.get(parent_id, parent)
    var children: Array = updated_parent.get("children_ids", [])
    children.append(child_id)
    updated_parent["children_ids"] = children
    resident_profiles[parent_id] = updated_parent
    if resident_profiles.has(second_parent_id):
        var other_parent: Dictionary = resident_profiles[second_parent_id]
        other_parent["children_count"] = int(other_parent.get("children_count", 0)) + 1
        var other_children: Array = other_parent.get("children_ids", [])
        other_children.append(child_id)
        other_parent["children_ids"] = other_children
        _append_event(other_parent, "child_born:" + child_id)
        resident_profiles[second_parent_id] = other_parent
    _dirty = true


func _rebuild_claim_cache() -> void:
    _claim_cache.clear()
    for citizen_id in resident_profiles.keys():
        var profile: Dictionary = resident_profiles[citizen_id]
        if bool(profile.get("active", false)) or str(profile.get("life_stage", "")) == "deceased":
            continue
        var city_id := str(profile.get("city", ""))
        if not _claim_cache.has(city_id):
            _claim_cache[city_id] = []
        _claim_cache[city_id].append(str(citizen_id))

func _stage_for_age(age: int) -> String:
    if age < 6: return "child"
    if age < 18: return "student"
    if age < 65: return "adult"
    return "retired"

func _education_for_age(age: int, rng: RandomNumberGenerator) -> String:
    if age < 6: return "early_childhood"
    if age < 18: return "school"
    if age < 23: return "secondary_or_university"
    return ["secondary", "technical", "university", "postgraduate"][rng.randi_range(0, 3)]

func _apply_stage_transition(profile: Dictionary, old_stage: String, new_stage: String) -> void:
    if new_stage == "student":
        profile["occupation"] = "student"
        profile["school"] = SCHOOLS[_rng.randi_range(0, SCHOOLS.size() - 1)]
        _append_event(profile, "started_school")
    elif old_stage == "student" and new_stage == "adult":
        profile["occupation"] = JOBS[_rng.randi_range(0, JOBS.size() - 1)]
        profile["school"] = ""
        profile["education"] = "graduated"
        profile["career_level"] = maxi(1, int(profile.get("career_level", 0)))
        profile["career_progress"] = 0.0
        graduations_total += 1
        _append_event(profile, "graduated_and_started_work")
    elif new_stage == "retired":
        profile["occupation"] = "retired"
        _append_event(profile, "retired")
    elif new_stage == "child":
        profile["occupation"] = "child"
        _append_event(profile, "born_into_world")

func _start_independent_life(profile: Dictionary) -> void:
    var citizen_id := str(profile.get("id", ""))
    if citizen_id.is_empty() or bool(profile.get("living_independently", false)):
        return
    # Preserve family links but give the adult a distinct household identity.
    var household_id := "household_" + str(abs(hash(citizen_id + ":adult:" + str(simulation_day))))
    profile["household_id"] = household_id
    profile["living_independently"] = true
    profile["moved_out_day"] = simulation_day
    profile["money"] = maxi(100, int(profile.get("money", 0)))
    independent_households_total += 1
    _append_event(profile, "started_independent_household")
    var parent_ids: Array = profile.get("parents", [])
    for parent_id in parent_ids:
        if resident_profiles.has(str(parent_id)):
            var parent: Dictionary = resident_profiles[str(parent_id)]
            _append_event(parent, "adult_child_moved_out:" + citizen_id)
            resident_profiles[str(parent_id)] = parent


func _advance_career_month(profile: Dictionary) -> void:
    var occupation := str(profile.get("occupation", ""))
    if occupation in ["", "unemployed", "retired", "student", "child"]:
        return
    var progress := float(profile.get("career_progress", 0.0))
    var education := str(profile.get("education", "secondary"))
    var education_bonus := 0.12 if education in ["university", "postgraduate", "graduated"] else 0.0
    progress += _rng.randf_range(0.015, 0.045) + education_bonus * 0.1
    if progress >= 1.0:
        progress -= 1.0
        profile["career_level"] = int(profile.get("career_level", 1)) + 1
        profile["money"] = int(profile.get("money", 0)) + 250
        career_promotions_total += 1
        _append_event(profile, "career_promotion:" + str(profile["career_level"]))
    profile["career_progress"] = progress


func _append_event(profile: Dictionary, event_name: String) -> void:
    var events: Array = profile.get("life_events", [])
    events.append({"day": simulation_day, "event": event_name})
    while events.size() > 32:
        events.pop_front()
    profile["life_events"] = events

func _sync_hub_demographics(city_id: String) -> void:
    var hub: Dictionary = hub_state.get(city_id, {})
    var counts := {"sample_students": 0, "sample_workers": 0, "sample_retired": 0, "sample_families": 0}
    for profile in resident_profiles.values():
        if str(profile.get("city", "")) != city_id:
            continue
        match str(profile.get("life_stage", "")):
            "student", "child": counts["sample_students"] += 1
            "adult": counts["sample_workers"] += 1
            "retired": counts["sample_retired"] += 1
        if str(profile.get("marital_status", "")) == "partnered":
            counts["sample_families"] += 1
    for key in counts:
        hub[key] = counts[key]
    hub_state[city_id] = hub


func _recount_all_hubs() -> void:
    # One pass over all saved residents instead of scanning the entire resident
    # table once per city. This keeps monthly updates practical as the world grows.
    var counts_by_city: Dictionary = {}
    for city_id in hub_state.keys():
        counts_by_city[str(city_id)] = {
            "sample_students": 0, "sample_workers": 0,
            "sample_retired": 0, "sample_families": 0
        }
    for profile in resident_profiles.values():
        var city_id := str(profile.get("city", ""))
        if not counts_by_city.has(city_id):
            continue
        var counts: Dictionary = counts_by_city[city_id]
        match str(profile.get("life_stage", "")):
            "student", "child": counts["sample_students"] += 1
            "adult": counts["sample_workers"] += 1
            "retired": counts["sample_retired"] += 1
        if str(profile.get("marital_status", "")) == "partnered":
            counts["sample_families"] += 1
    for city_id in counts_by_city:
        var hub: Dictionary = hub_state[city_id]
        var counts: Dictionary = counts_by_city[city_id]
        for key in counts:
            hub[key] = counts[key]
        hub_state[city_id] = hub

func _prune_profiles_if_needed() -> void:
    if resident_profiles.size() <= max_saved_profiles:
        return
    var inactive: Array[String] = []
    for citizen_id in resident_profiles:
        var profile: Dictionary = resident_profiles[citizen_id]
        if not bool(profile.get("active", false)):
            inactive.append(str(citizen_id))
    inactive.sort_custom(func(a: String, b: String) -> bool:
        return int(resident_profiles[a].get("last_seen_day", 0)) < int(resident_profiles[b].get("last_seen_day", 0))
    )
    for citizen_id in inactive:
        if resident_profiles.size() <= max_saved_profiles:
            break
        resident_profiles.erase(citizen_id)

func get_world_life_snapshot() -> Dictionary:
    var population := 0
    for hub in hub_state.values():
        population += int(hub.get("population", 0))
    var active := 0
    var students := 0
    var workers := 0
    var retired := 0
    for profile in resident_profiles.values():
        if bool(profile.get("active", false)):
            active += 1
        match str(profile.get("life_stage", "")):
            "child", "student": students += 1
            "adult": workers += 1
            "retired": retired += 1
    return {
        "simulation_day": simulation_day, "simulation_month": simulation_month,
        "simulation_year": simulation_year, "city_hubs": hub_state.size(),
        "aggregate_population": population, "individual_profiles": resident_profiles.size(),
        "active_residents": active, "sample_students": students, "sample_workers": workers,
        "sample_retired": retired, "births_total": births_total, "deaths_total": deaths_total,
        "marriages_total": marriages_total, "separations_total": separations_total,
        "graduations_total": graduations_total, "career_promotions_total": career_promotions_total,
        "independent_households_total": independent_households_total
    }

func _load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    simulation_day = int(parsed.get("simulation_day", simulation_day))
    simulation_month = int(parsed.get("simulation_month", simulation_month))
    simulation_year = int(parsed.get("simulation_year", simulation_year))
    hub_state = parsed.get("hub_state", {})
    resident_profiles = parsed.get("resident_profiles", {})
    social_bonds = parsed.get("social_bonds", {})
    births_total = int(parsed.get("births_total", 0))
    deaths_total = int(parsed.get("deaths_total", 0))
    marriages_total = int(parsed.get("marriages_total", 0))
    separations_total = int(parsed.get("separations_total", 0))
    graduations_total = int(parsed.get("graduations_total", 0))
    career_promotions_total = int(parsed.get("career_promotions_total", 0))
    independent_households_total = int(parsed.get("independent_households_total", 0))

func _save_state() -> void:
    var data := {
        "simulation_day": simulation_day, "simulation_month": simulation_month,
        "simulation_year": simulation_year, "hub_state": hub_state,
        "resident_profiles": resident_profiles, "social_bonds": social_bonds, "births_total": births_total,
        "deaths_total": deaths_total, "marriages_total": marriages_total,
        "separations_total": separations_total, "graduations_total": graduations_total,
        "career_promotions_total": career_promotions_total,
        "independent_households_total": independent_households_total
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        _dirty = false
        _save_elapsed = 0.0
