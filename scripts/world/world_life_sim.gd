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
var _social_feed: Array = []
var _claim_cache: Dictionary = {}
var births_total := 0
var deaths_total := 0
var marriages_total := 0
var separations_total := 0
var graduations_total := 0
var career_promotions_total := 0
var career_changes_total := 0
var education_levels_completed_total := 0
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
    _build_phone_media_catalog()
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
        "jobs": 0, "last_updated_day": simulation_day,
        "market": {
            "food": {"price": 8.0, "base_price": 8.0, "stock": 12000, "demand": 9000},
            "water": {"price": 2.0, "base_price": 2.0, "stock": 18000, "demand": 11000},
            "medicine": {"price": 24.0, "base_price": 24.0, "stock": 1800, "demand": 1200},
            "electronics": {"price": 95.0, "base_price": 95.0, "stock": 900, "demand": 650},
            "clothing": {"price": 32.0, "base_price": 32.0, "stock": 2600, "demand": 1800},
            "fuel": {"price": 5.0, "base_price": 5.0, "stock": 7000, "demand": 5200}
        }
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
    if stage in ["student", "university"]:
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
        "school": _choose_school(stage, local_rng.randf_range(0.35, 0.95), local_rng) if stage in ["student", "university"] else "",
        "education_progress": local_rng.randf_range(0.0, 0.85),
        "school_grade": maxi(0, age - 5),
        "academic_performance": local_rng.randf_range(0.35, 0.95),
        "school_attendance": 0.0,
        "career_satisfaction": local_rng.randf_range(0.35, 0.8),
        "career_field": _career_specialization(str(_education_for_age(age, local_rng)), local_rng.randf_range(0.35, 0.95), local_rng),
        "marital_status": "single",
        "partner_id": "family_" + str(abs(hash(citizen_id))) if married else "",
        "children_count": local_rng.randi_range(0, 3) if married and age >= 25 else 0,
        "family_id": "family_" + str(abs(hash(citizen_id))) if married else "",
        "household_id": "household_" + str(abs(hash(citizen_id))),
        "money": local_rng.randi_range(50, 250000), "savings": 0, "monthly_budget": 0,
        "financial_goal": "build_savings", "credit_score": 600, "debt": 0,
        "owns_home": false, "home_value": 0,
        "vehicle_id": "", "vehicle_type": "", "vehicle_value": 0,
        "phone_id": "phone_" + str(abs(hash(citizen_id))),
        "phone_model": "Neon One",
        "phone_number": _generate_phone_number(citizen_id),
        "phone_contacts": [], "phone_inbox": [], "phone_outbox": [],
        "phone_call_history": [], "phone_notifications": [],
        "phone_social_posts": [], "phone_following": [], "phone_followers": [], "phone_last_used_day": simulation_day,
        "public_reputation": 0.0, "public_notoriety": 0.0, "community_respect": 0.0,
        "phone_battery": 100.0, "phone_privacy": "friends",
        "vehicle_fuel": 0.0, "vehicle_condition": 1.0, "vehicle_monthly_km": 0,
        "transport_preference": "public" if local_rng.randf() < 0.72 else "private",
        "business_id": "", "business_revenue": 0,
        "business_months": 0, "business_last_profit": 0, "business_health": 0.0,
        "health": local_rng.randf_range(0.65, 1.0),
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
    if interaction in ["friendly_chat", "help", "shared_activity", "phone_message"]:
        var trust_gain := 0.008 if interaction == "phone_message" else 0.025
        var friendship_gain := 0.012 if interaction == "phone_message" else 0.035
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) + trust_gain, -1.0, 1.0)
        bond["friendship"] = clampf(float(bond.get("friendship", 0.0)) + friendship_gain, -1.0, 1.0)
    elif interaction == "social_comment":
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) + 0.012, -1.0, 1.0)
        bond["friendship"] = clampf(float(bond.get("friendship", 0.0)) + 0.01, -1.0, 1.0)
    elif interaction == "social_post_like":
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) + 0.004, -1.0, 1.0)
    elif interaction in ["argument", "threat", "betrayal"]:
        bond["trust"] = clampf(float(bond.get("trust", 0.0)) - 0.12, -1.0, 1.0)
        bond["friendship"] = clampf(float(bond.get("friendship", 0.0)) - 0.08, -1.0, 1.0)
    social_bonds[pair_id] = bond
    if interaction in ["help", "saved", "community_service"]:
        adjust_resident_reputation(first_id, 0.025, 0.0, 0.035, interaction)
    elif interaction in ["betrayal", "threat"]:
        adjust_resident_reputation(first_id, -0.04, 0.045, -0.035, interaction)
    elif interaction == "argument":
        adjust_resident_reputation(first_id, -0.015, 0.02, -0.01, interaction)
    elif interaction == "social_post_like":
        adjust_resident_reputation(first_id, 0.002, 0.0, 0.001, interaction)
    _dirty = true


func get_city_market_snapshot(city_id: String) -> Dictionary:
    if not hub_state.has(city_id):
        return {}
    var hub: Dictionary = hub_state[city_id]
    var market: Dictionary = hub.get("market", {})
    return market.duplicate(true)


func get_citizen_business_snapshot(citizen_id: String) -> Dictionary:
    if not resident_profiles.has(citizen_id):
        return {}
    var profile: Dictionary = resident_profiles[citizen_id]
    var business_id := str(profile.get("business_id", ""))
    if business_id.is_empty():
        return {}
    var worker_ids: Array[String] = []
    for worker_id in resident_profiles.keys():
        var worker: Dictionary = resident_profiles[worker_id]
        if str(worker.get("employer_id", "")) == business_id:
            worker_ids.append(str(worker_id))
    return {
        "business_id": business_id,
        "owner_id": citizen_id,
        "city": str(profile.get("business_city", profile.get("city", ""))),
        "type": str(profile.get("business_type", "")),
        "capital": int(profile.get("business_capital", 0)),
        "revenue": int(profile.get("business_revenue", 0)),
        "last_profit": int(profile.get("business_last_profit", 0)),
        "health": float(profile.get("business_health", 0.0)),
        "inventory": int(profile.get("business_inventory", 0)),
        "workers": worker_ids,
        "months_open": int(profile.get("business_months", 0))
    }


func get_citizen_financial_snapshot(citizen_id: String) -> Dictionary:
    if not resident_profiles.has(citizen_id):
        return {}
    var profile: Dictionary = resident_profiles[citizen_id]
    return {
        "money": int(profile.get("money", 0)),
        "savings": int(profile.get("savings", 0)),
        "bank_balance": int(profile.get("bank_balance", 0)),
        "bank_interest_earned": int(profile.get("bank_interest_earned", 0)),
        "debt": int(profile.get("debt", 0)),
        "credit_score": int(profile.get("credit_score", 600)),
        "monthly_income": int(profile.get("monthly_income", 0)),
        "monthly_housing_cost": int(profile.get("monthly_housing_cost", 0)),
        "monthly_transport_cost": int(profile.get("monthly_transport_cost", 0)),
        "vehicle_maintenance_cost": int(profile.get("vehicle_maintenance_cost", 0)),
        "vehicle_last_month_km": int(profile.get("vehicle_last_month_km", 0)),
        "vehicle_id": str(profile.get("vehicle_id", "")),
        "vehicle_type": str(profile.get("vehicle_type", "")),
        "vehicle_value": int(profile.get("vehicle_value", 0)),
        "vehicle_fuel": float(profile.get("vehicle_fuel", 0.0)),
        "vehicle_condition": float(profile.get("vehicle_condition", 1.0)),
        "vehicle_monthly_km": int(profile.get("vehicle_monthly_km", 0)),
        "transport_preference": str(profile.get("transport_preference", "public"))
    }


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
        elif hour >= 8 and hour < 15 and stage in ["student", "university"]:
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
            _advance_education(profile)
        resident_profiles[citizen_id] = profile
        changed_count += 1
    if changed_count > 0:
        _dirty = true
        publish_event_if_available("daily_routine_updated", {"hour": hour, "citizens_updated": changed_count})


func _advance_education(profile: Dictionary) -> void:
    var stage := str(profile.get("life_stage", ""))
    if stage not in ["student", "university"]:
        return
    var attendance := clampf(float(profile.get("school_attendance", 0.0)) + 0.015, 0.0, 1.0)
    var performance := clampf(float(profile.get("academic_performance", 0.5)) + _rng.randf_range(-0.008, 0.012), 0.1, 1.0)
    var progress := float(profile.get("education_progress", 0.0))
    progress += 0.006 + performance * 0.004
    if progress >= 1.0:
        progress -= 1.0
        profile["school_grade"] = int(profile.get("school_grade", 0)) + 1
        education_levels_completed_total += 1
        _append_event(profile, "completed_education_level:" + str(profile["school_grade"]))
    profile["school_attendance"] = attendance
    profile["academic_performance"] = performance
    profile["education_progress"] = progress


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
        hub["monthly_business_revenue"] = 0
        hub["monthly_business_profit"] = 0
        hub["monthly_trade_exports"] = 0
        hub["monthly_trade_imports"] = 0
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
        if new_stage == "adult" and old_stage in ["student", "university"]:
            _start_independent_life(profile)
        if new_stage == "adult":
            _advance_career_month(profile)
            _process_job_interview(profile)
            _process_monthly_finances(profile)
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
    _simulate_city_markets()
    _simulate_intercity_trade()
    _recount_businesses_by_city()
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
        "education_progress": 0.0, "academic_performance": 0.5,
        "school_attendance": 0.0, "career_satisfaction": 0.5, "career_field": "",
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
    if age < 23: return "university"
    if age < 65: return "adult"
    return "retired"

func _choose_school(stage: String, performance: float, rng: RandomNumberGenerator) -> String:
    if stage == "university":
        if performance >= 0.82:
            return "Global Science Institute"
        if performance >= 0.65:
            return "Cybernetics Academy"
        return "District Technical School"
    if performance >= 0.8:
        return "Cybernetics Academy"
    return "Neo Primary School" if rng.randf() < 0.7 else "District Technical School"


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
    elif new_stage == "university":
        profile["occupation"] = "student"
        profile["school"] = "Global Science Institute"
        profile["education"] = "university"
        _append_event(profile, "entered_university")
    elif old_stage in ["student", "university"] and new_stage == "adult":
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


func _career_specialization(education: String, performance: float, rng: RandomNumberGenerator) -> String:
    var fields := JOBS.duplicate()
    if education in ["university", "postgraduate", "graduated"]:
        fields = ["engineer", "doctor", "scientist", "designer", "pilot"]
    elif education == "technical":
        fields = ["mechanic", "courier", "security", "merchant", "engineer"]
    elif performance < 0.45:
        fields = ["courier", "merchant", "artist", "mechanic"]
    return str(fields[rng.randi_range(0, fields.size() - 1)])


func _monthly_salary_for_job(job: String, level: int) -> int:
    var base := {
        "engineer": 4200, "doctor": 4800, "teacher": 2600, "pilot": 5600,
        "police": 3000, "mechanic": 2800, "designer": 3400, "courier": 1900,
        "scientist": 5200, "merchant": 3100, "artist": 2400, "security": 2200
    }
    return int(base.get(job, 1600)) + maxi(0, level - 1) * 180


func _consider_vehicle_purchase(profile: Dictionary) -> void:
    if not str(profile.get("vehicle_id", "")).is_empty():
        return
    if int(profile.get("age_years", 0)) < 18 or str(profile.get("life_stage", "")) != "adult":
        return
    if str(profile.get("occupation", "")) not in JOBS:
        return
    var money := int(profile.get("money", 0))
    var savings := int(profile.get("savings", 0))
    var bank_balance := int(profile.get("bank_balance", 0))
    var total_funds := money + savings + bank_balance
    if total_funds < 18000 or float(profile.get("financial_stability", 0.0)) < 0.55:
        return
    if _rng.randf() > 0.035:
        return
    var vehicle_types := ["compact_car", "sedan", "motorcycle", "electric_car"]
    var vehicle_prices := {"compact_car": 18000, "sedan": 26000, "motorcycle": 8500, "electric_car": 34000}
    var vehicle_type := vehicle_types[_rng.randi_range(0, vehicle_types.size() - 1)]
    var price := int(vehicle_prices[vehicle_type])
    if total_funds < price:
        vehicle_type = "motorcycle"
        price = int(vehicle_prices[vehicle_type])
    if total_funds < price:
        return
    var remaining := price
    var from_money := mini(money, remaining)
    remaining -= from_money
    var from_savings := mini(savings, remaining)
    remaining -= from_savings
    var from_bank := mini(bank_balance, remaining)
    remaining -= from_bank
    if remaining > 0:
        return
    profile["money"] = money - from_money
    profile["savings"] = savings - from_savings
    profile["bank_balance"] = bank_balance - from_bank
    profile["vehicle_id"] = "vehicle_" + str(abs(hash(str(profile.get("id", "")) + ":" + str(simulation_day))))
    profile["vehicle_type"] = vehicle_type
    profile["vehicle_value"] = price
    profile["vehicle_fuel"] = 45.0 if vehicle_type != "motorcycle" else 14.0
    profile["vehicle_condition"] = 1.0
    profile["transport_preference"] = "private"
    _append_event(profile, "purchased_vehicle:" + vehicle_type + ":" + str(price))


func _process_npc_transport(profile: Dictionary) -> int:
    var vehicle_id := str(profile.get("vehicle_id", ""))
    var job := str(profile.get("occupation", ""))
    if vehicle_id.is_empty():
        if job in JOBS:
            return _rng.randi_range(90, 240)
        return _rng.randi_range(25, 90)
    var monthly_km := _rng.randi_range(180, 1100) if job in JOBS else _rng.randi_range(60, 260)
    var fuel_used := float(monthly_km) * 0.085
    var fuel := maxf(0.0, float(profile.get("vehicle_fuel", 0.0)) - fuel_used)
    var fuel_cost := 0
    if fuel < 18.0:
        var fuel_needed := 45.0 - fuel
        var city_id := str(profile.get("city", ""))
        var fuel_price := 1.4
        var purchased_fuel := fuel_needed
        if hub_state.has(city_id):
            var city_hub: Dictionary = hub_state[city_id]
            var city_market: Dictionary = city_hub.get("market", {})
            if city_market.has("fuel"):
                var fuel_good: Dictionary = city_market["fuel"]
                fuel_price = float(fuel_good.get("price", 1.4))
                purchased_fuel = minf(fuel_needed, float(fuel_good.get("stock", 0)))
                fuel_good["stock"] = maxi(0, int(fuel_good.get("stock", 0)) - int(ceil(purchased_fuel)))
                fuel_good["npc_vehicle_fuel_sales"] = int(fuel_good.get("npc_vehicle_fuel_sales", 0)) + int(ceil(purchased_fuel))
                city_market["fuel"] = fuel_good
                city_hub["market"] = city_market
                hub_state[city_id] = city_hub
        fuel += purchased_fuel
        fuel_cost = int(ceil(purchased_fuel * fuel_price))
    var wear := float(monthly_km) / 180000.0
    var condition := clampf(float(profile.get("vehicle_condition", 1.0)) - wear, 0.0, 1.0)
    var maintenance := 0
    if condition < 0.55:
        maintenance = _rng.randi_range(180, 650)
        condition = minf(1.0, condition + 0.12)
    profile["vehicle_fuel"] = fuel
    profile["vehicle_condition"] = condition
    profile["vehicle_monthly_km"] = int(profile.get("vehicle_monthly_km", 0)) + monthly_km
    profile["vehicle_last_month_km"] = monthly_km
    profile["vehicle_maintenance_cost"] = maintenance
    return fuel_cost + maintenance


func _process_monthly_finances(profile: Dictionary) -> void:
    var job := str(profile.get("occupation", "unemployed"))
    var level := int(profile.get("career_level", 1))
    var employer_id := str(profile.get("employer_id", ""))
    var income := _monthly_salary_for_job(job, level) if job in JOBS and employer_id.is_empty() else 0
    var living_independently := bool(profile.get("living_independently", false))
    var owns_home := bool(profile.get("owns_home", false))
    var rent := 90 if owns_home else (650 if living_independently else 180)
    var food_and_services := 420 if job in JOBS else 300
    var transport_cost := _process_npc_transport(profile)
    var balance := income - rent - food_and_services - transport_cost
    profile["monthly_income"] = income
    profile["monthly_housing_cost"] = rent
    profile["monthly_living_cost"] = food_and_services
    profile["monthly_transport_cost"] = transport_cost
    profile["money"] = maxi(0, int(profile.get("money", 0)) + balance)
    _manage_personal_savings(profile, balance)
    _consider_business_startup(profile)
    _operate_personal_business(profile)
    _consider_home_purchase(profile)
    _manage_credit_and_debt(profile)
    _process_npc_banking(profile)
    _consider_vehicle_purchase(profile)
    _apply_business_city_economy(profile)
    profile["financial_stability"] = clampf(float(profile.get("money", 0)) / 12000.0, 0.0, 1.0)
    if int(profile.get("money", 0)) < 500:
        profile["housing_status"] = "shared_or_family_home"
    elif living_independently:
        profile["housing_status"] = "independent_rental"
    else:
        profile["housing_status"] = "family_or_shared_home"
    if bool(profile.get("owns_home", false)):
        profile["housing_status"] = "home_owner"
    _append_event(profile, "monthly_finances:" + str(balance))


func _apply_business_city_economy(profile: Dictionary) -> void:
    var city_id := str(profile.get("business_city", ""))
    if city_id.is_empty() or not hub_state.has(city_id):
        return
    var hub: Dictionary = hub_state[city_id]
    var revenue := int(profile.get("business_revenue", 0))
    var profit := int(profile.get("business_last_profit", 0))
    hub["business_count"] = int(hub.get("business_count", 0)) + (1 if int(profile.get("business_months", 0)) == 1 else 0)
    hub["monthly_business_revenue"] = int(hub.get("monthly_business_revenue", 0)) + revenue
    hub["monthly_business_profit"] = int(hub.get("monthly_business_profit", 0)) + profit
    hub["local_economic_activity"] = clampf(float(hub.get("local_economic_activity", 0.5)) + float(profit) / 100000.0, 0.0, 1.0)
    hub_state[city_id] = hub
    _dirty = true


func _process_npc_banking(profile: Dictionary) -> void:
    var money := int(profile.get("money", 0))
    var balance := int(profile.get("bank_balance", 0))
    var interest := int(float(balance) * 0.0025)
    if balance > 0:
        balance += maxi(0, interest)
        profile["bank_interest_earned"] = int(profile.get("bank_interest_earned", 0)) + maxi(0, interest)
    if money < 900 and int(profile.get("debt", 0)) == 0 and int(profile.get("credit_score", 600)) >= 660 and _rng.randf() < 0.025:
        var loan := mini(3500, 1200 + int(float(profile.get("credit_score", 600) - 660) * 12.0))
        profile["debt"] = loan
        money += loan
        _append_event(profile, "approved_bank_loan:" + str(loan))
    if money > 6000 and balance < 250000 and _rng.randf() < 0.32:
        var deposit := mini(money - 3500, mini(2500, 250000 - balance))
        if deposit > 0:
            money -= deposit
            balance += deposit
            _append_event(profile, "bank_deposit:" + str(deposit))
    elif money < 700 and balance > 0 and _rng.randf() < 0.45:
        var withdrawal := mini(balance, maxi(0, 1200 - money))
        if withdrawal > 0:
            balance -= withdrawal
            money += withdrawal
            _append_event(profile, "bank_withdrawal:" + str(withdrawal))
    profile["money"] = money
    profile["bank_balance"] = balance
    profile["credit_score"] = clampi(int(profile.get("credit_score", 600)) + (1 if interest > 0 else 0), 300, 850)


func _manage_credit_and_debt(profile: Dictionary) -> void:
    var debt := int(profile.get("debt", 0))
    var money := int(profile.get("money", 0))
    var credit := int(profile.get("credit_score", 600))
    if debt > 0:
        var interest_charge := maxi(1, int(float(debt) * 0.012))
        debt += interest_charge
        var payment := mini(debt, maxi(0, int(float(money) * 0.08)))
        profile["money"] = money - payment
        profile["debt"] = debt - payment
        profile["monthly_debt_interest"] = interest_charge
        credit = mini(850, credit + (3 if payment > interest_charge else -2))
    elif money < 250 and int(profile.get("savings", 0)) < 300 and _rng.randf() < 0.015:
        var loan := 1200 if credit >= 620 else 400
        profile["debt"] = loan
        profile["money"] = money + loan
        _append_event(profile, "took_emergency_loan:" + str(loan))
    if int(profile.get("debt", 0)) > 5000:
        credit = maxi(300, credit - 5)
    profile["credit_score"] = clampi(credit, 300, 850)


func _consider_business_startup(profile: Dictionary) -> void:
    if not str(profile.get("business_id", "")).is_empty():
        return
    if int(profile.get("savings", 0)) < 50000 or str(profile.get("financial_goal", "")) != "start_business":
        return
    if _rng.randf() > 0.025:
        return
    var citizen_id := str(profile.get("id", "unknown"))
    var business_id := "business_" + str(abs(hash(citizen_id + ":" + str(simulation_day))))
    profile["business_id"] = business_id
    var business_types := ["food_store", "pharmacy", "electronics_shop", "clothing_store", "fuel_station"]
    profile["business_type"] = business_types[_rng.randi_range(0, business_types.size() - 1)]
    profile["business_inventory"] = _rng.randi_range(80, 260)
    profile["business_restock_budget"] = 1800
    profile["business_capital"] = 30000
    profile["business_revenue"] = 0
    profile["business_months"] = 0
    profile["business_city"] = str(profile.get("city", ""))
    profile["business_workers"] = 0
    profile["business_capacity"] = 2
    profile["business_competition_pressure"] = 0.0
    profile["savings"] = int(profile.get("savings", 0)) - 30000
    profile["financial_goal"] = "grow_business"
    _append_event(profile, "founded_business:" + business_id)


func _measure_business_competition(city_id: String, own_business_id: String) -> float:
    var competitors := 0
    for resident in resident_profiles.values():
        if str(resident.get("business_city", resident.get("city", ""))) != city_id:
            continue
        var other_id := str(resident.get("business_id", ""))
        if not other_id.is_empty() and other_id != own_business_id:
            competitors += 1
    return clampf(float(competitors) / 12.0, 0.0, 0.85)


func _hire_business_workers(owner: Dictionary) -> void:
    var capacity := int(owner.get("business_capacity", 2))
    var workers := int(owner.get("business_workers", 0))
    if workers >= capacity:
        return
    var city := str(owner.get("city", ""))
    var owner_id := str(owner.get("id", ""))
    var candidates: Array[String] = []
    for resident_id in resident_profiles:
        var worker: Dictionary = resident_profiles[resident_id]
        if str(resident_id) == owner_id or str(worker.get("city", "")) != city:
            continue
        if str(worker.get("life_stage", "")) != "adult":
            continue
        if str(worker.get("occupation", "")) in ["unemployed", "resident"] and str(worker.get("employer_id", "")).is_empty():
            candidates.append(str(resident_id))
    if candidates.is_empty() or _rng.randf() > 0.18:
        return
    candidates.sort()
    var hired_id := candidates[_rng.randi_range(0, candidates.size() - 1)]
    var hired: Dictionary = resident_profiles[hired_id]
    hired["occupation"] = "merchant"
    hired["employer_id"] = str(owner.get("business_id", ""))
    hired["monthly_income"] = 1500
    hired["job_search_status"] = "employed"
    _append_event(hired, "hired_by_business:" + str(owner.get("business_id", "")))
    resident_profiles[hired_id] = hired
    owner["business_workers"] = workers + 1
    owner["business_capacity"] = capacity + 1


func _release_business_workers(business_id: String) -> void:
    if business_id.is_empty():
        return
    for worker_id in resident_profiles.keys():
        var worker: Dictionary = resident_profiles[worker_id]
        if str(worker.get("employer_id", "")) != business_id:
            continue
        worker["employer_id"] = ""
        worker["occupation"] = "unemployed"
        worker["monthly_income"] = 0
        worker["job_search_status"] = "seeking"
        _append_event(worker, "business_closed_job_lost:" + business_id)
        resident_profiles[worker_id] = worker


func _pay_business_workers(owner: Dictionary) -> int:
    var business_id := str(owner.get("business_id", ""))
    if business_id.is_empty():
        return 0
    var payroll := 0
    for worker_id in resident_profiles.keys():
        var worker: Dictionary = resident_profiles[worker_id]
        if str(worker.get("employer_id", "")) != business_id:
            continue
        if str(worker.get("life_stage", "")) == "deceased":
            continue
        var wage := maxi(650, int(worker.get("contract_salary", 1500)))
        var paid := mini(wage, maxi(0, int(owner.get("business_capital", 0)) - payroll))
        if paid <= 0:
            continue
        worker["money"] = int(worker.get("money", 0)) + paid
        worker["monthly_income"] = paid
        worker["last_employer_payment"] = paid
        worker["employer_paid_month"] = simulation_day
        _append_event(worker, "received_business_wage:" + str(paid))
        resident_profiles[worker_id] = worker
        payroll += paid
    return payroll


func _operate_personal_business(profile: Dictionary) -> void:
    if str(profile.get("business_id", "")).is_empty():
        return
    var months := int(profile.get("business_months", 0)) + 1
    var capital := int(profile.get("business_capital", 0))
    _hire_business_workers(profile)
    var competition := _measure_business_competition(str(profile.get("business_city", profile.get("city", ""))), str(profile.get("business_id", "")))
    profile["business_competition_pressure"] = competition
    var inventory := int(profile.get("business_inventory", 120))
    var inventory_factor := clampf(float(inventory) / 120.0, 0.15, 1.8)
    var market_factor := 1.0
    var retail_unit_price := 16.0
    var business_city := str(profile.get("business_city", profile.get("city", "")))
    var category_good := "food" if str(profile.get("business_type", "")) == "food_store" else "medicine" if str(profile.get("business_type", "")) == "pharmacy" else "electronics" if str(profile.get("business_type", "")) == "electronics_shop" else "clothing" if str(profile.get("business_type", "")) == "clothing_store" else "fuel"
    var units_sold := mini(inventory, _rng.randi_range(18, 55))
    inventory = maxi(0, inventory - units_sold)
    if hub_state.has(business_city):
        var local_hub: Dictionary = hub_state[business_city]
        var local_market: Dictionary = local_hub.get("market", {})
        if local_market.has(category_good):
            var market_good: Dictionary = local_market[category_good]
            market_factor = clampf(float(market_good.get("price", 10.0)) / float(market_good.get("base_price", 10.0)), 0.7, 1.6)
            retail_unit_price = maxf(1.0, float(market_good.get("price", 10.0)) * 1.35)
            var wholesale_units := mini(int(market_good.get("stock", 0)), mini(60, 120 - inventory))
            if wholesale_units > 0:
                market_good["stock"] = int(market_good.get("stock", 0)) - wholesale_units
                market_good["wholesale_sales"] = int(market_good.get("wholesale_sales", 0)) + wholesale_units
                inventory += wholesale_units
                local_market[category_good] = market_good
                local_hub["market"] = local_market
                hub_state[business_city] = local_hub
    inventory_factor = clampf(float(units_sold) / 30.0, 0.1, 1.6)
    var revenue := int(float(units_sold) * retail_unit_price * inventory_factor * (1.0 - competition * 0.22) + float(int(profile.get("business_workers", 0)) * 120))
    var payroll_total := _pay_business_workers(profile)
    var restock_cost := mini(capital, int(profile.get("business_restock_budget", 1800)))
    var operating_cost := _rng.randi_range(1200, 3600) + int(profile.get("business_workers", 0)) * 420 + restock_cost + payroll_total
    profile["business_inventory"] = clampi(inventory, 0, 500)
    profile["business_units_sold"] = int(profile.get("business_units_sold", 0)) + units_sold
    var profit := revenue - operating_cost
    capital = maxi(0, capital + profit)
    profile["business_months"] = months
    profile["business_revenue"] = revenue
    profile["business_last_profit"] = profit
    profile["business_capital"] = capital
    profile["business_restock_budget"] = clampi(int(float(revenue) * 0.22), 300, 5000)
    profile["business_health"] = clampf(float(capital) / 60000.0, 0.0, 1.0)
    profile["money"] = int(profile.get("money", 0)) + maxi(0, profit / 2)
    if capital > 90000 and int(profile.get("business_capacity", 2)) < 12 and _rng.randf() < 0.18:
        profile["business_capacity"] = int(profile.get("business_capacity", 2)) + 2
        profile["business_expansions"] = int(profile.get("business_expansions", 0)) + 1
        _append_event(profile, "business_expanded:" + str(profile["business_capacity"]))
    if capital < 500 and months > 2:
        var closed_business_id := str(profile.get("business_id", ""))
        _release_business_workers(closed_business_id)
        profile["business_id"] = ""
        profile["business_workers"] = 0
        profile["financial_goal"] = "rebuild_savings"
        _append_event(profile, "business_closed_after_losses")
    elif months % 6 == 0:
        _append_event(profile, "business_reviewed:" + str(profit))


func _manage_personal_savings(profile: Dictionary, monthly_balance: int) -> void:
    var money := int(profile.get("money", 0))
    var savings := int(profile.get("savings", 0))
    var goal := str(profile.get("financial_goal", "build_savings"))
    var reserve_target := 1800 + int(profile.get("monthly_living_cost", 300)) * 3
    var contribution := 0
    if monthly_balance > 0 and money > reserve_target:
        contribution = mini(int(float(monthly_balance) * 0.35), money - reserve_target)
    elif monthly_balance < 0 and savings > 0:
        var withdrawal := mini(savings, absi(monthly_balance))
        savings -= withdrawal
        money += withdrawal
        profile["money"] = money
        _append_event(profile, "used_savings_for_living_costs")
    savings += maxi(0, contribution)
    if savings >= 15000 and goal == "build_savings":
        profile["financial_goal"] = "save_for_home"
        _append_event(profile, "financial_goal_changed:save_for_home")
    elif savings >= 50000 and goal == "save_for_home":
        profile["financial_goal"] = "start_business"
        _append_event(profile, "financial_goal_changed:start_business")
    profile["savings"] = savings
    profile["monthly_savings_contribution"] = contribution


func _consider_home_purchase(profile: Dictionary) -> void:
    if bool(profile.get("owns_home", false)) or not bool(profile.get("living_independently", false)):
        return
    var money := int(profile.get("money", 0))
    var savings := int(profile.get("savings", 0))
    var bank_balance := int(profile.get("bank_balance", 0))
    var stability := float(profile.get("financial_stability", 0.0))
    var home_price := 42000 + int(profile.get("career_level", 1)) * 1800
    if money + savings + bank_balance < home_price or stability < 0.72:
        return
    if _rng.randf() > 0.12:
        return
    var remaining := home_price
    var from_money := mini(money, remaining)
    remaining -= from_money
    var from_savings := mini(savings, remaining)
    remaining -= from_savings
    var from_bank := mini(bank_balance, remaining)
    remaining -= from_bank
    if remaining > 0:
        return
    profile["money"] = money - from_money
    profile["savings"] = savings - from_savings
    profile["bank_balance"] = bank_balance - from_bank
    profile["owns_home"] = true
    profile["home_value"] = home_price
    profile["housing_status"] = "home_owner"
    profile["monthly_housing_cost"] = 90
    _append_event(profile, "purchased_home:" + str(home_price))


func _process_job_interview(profile: Dictionary) -> void:
    if str(profile.get("life_stage", "")) != "adult":
        return
    var occupation := str(profile.get("occupation", "unemployed"))
    if occupation not in ["unemployed", "resident"]:
        return
    var education := str(profile.get("education", "secondary"))
    var chance := 0.16 + float(profile.get("academic_performance", 0.5)) * 0.22
    if education in ["university", "postgraduate", "graduated"]:
        chance += 0.2
    if _rng.randf() > clampf(chance, 0.05, 0.7):
        profile["job_search_status"] = "application_rejected"
        _append_event(profile, "job_interview_rejected")
        return
    var preferred := str(profile.get("career_field", ""))
    if preferred.is_empty() or preferred not in JOBS:
        preferred = _career_specialization(education, float(profile.get("academic_performance", 0.5)), _rng)
    profile["occupation"] = preferred
    profile["career_field"] = preferred
    profile["job_search_status"] = "employed"
    profile["career_satisfaction"] = maxf(0.45, float(profile.get("career_satisfaction", 0.5)))
    _append_event(profile, "job_interview_passed:" + preferred)


func _advance_career_month(profile: Dictionary) -> void:
    var occupation := str(profile.get("occupation", ""))
    if occupation in ["", "unemployed", "retired", "student", "child"]:
        return
    var satisfaction := float(profile.get("career_satisfaction", 0.5))
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
    # Work satisfaction reacts to growth and gradually drifts, allowing rare career changes.
    satisfaction = clampf(satisfaction + (0.003 if progress > 0.35 else -0.002) + _rng.randf_range(-0.012, 0.01), 0.0, 1.0)
    if satisfaction < 0.18 and _rng.randf() < 0.08:
        var next_job := occupation
        for attempt in range(4):
            next_job = JOBS[_rng.randi_range(0, JOBS.size() - 1)]
            if next_job != occupation:
                break
        if next_job != occupation:
            profile["occupation"] = next_job
            profile["career_field"] = next_job
            career_changes_total += 1
            profile["career_progress"] = 0.0
            satisfaction = 0.48
            _append_event(profile, "changed_career_to:" + next_job)
    profile["career_satisfaction"] = satisfaction
    if str(profile.get("career_field", "")).is_empty():
        profile["career_field"] = occupation


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
            "student", "university", "child": counts["sample_students"] += 1
            "adult": counts["sample_workers"] += 1
            "retired": counts["sample_retired"] += 1
        if str(profile.get("marital_status", "")) == "partnered":
            counts["sample_families"] += 1
    for key in counts:
        hub[key] = counts[key]
    hub_state[city_id] = hub


func _simulate_intercity_trade() -> void:
    var city_ids: Array = hub_state.keys()
    city_ids.sort()
    if city_ids.size() < 2:
        return
    var goods_ids := ["food", "water", "medicine", "electronics", "clothing", "fuel"]
    for index in range(city_ids.size()):
        var from_id := str(city_ids[index])
        var to_id := str(city_ids[(index + 1) % city_ids.size()])
        if from_id == to_id:
            continue
        var from_hub: Dictionary = hub_state[from_id]
        var to_hub: Dictionary = hub_state[to_id]
        var from_market: Dictionary = from_hub.get("market", {})
        var to_market: Dictionary = to_hub.get("market", {})
        var shipped_total := 0
        for good_id in goods_ids:
            if not from_market.has(good_id) or not to_market.has(good_id):
                continue
            var source_good: Dictionary = from_market[good_id]
            var target_good: Dictionary = to_market[good_id]
            var source_stock := int(source_good.get("stock", 0))
            var target_stock := int(target_good.get("stock", 0))
            var source_price := float(source_good.get("price", 0.0))
            var target_price := float(target_good.get("price", 0.0))
            if source_stock < 100 or target_price < source_price * 1.18:
                continue
            var shipment := mini(350, maxi(0, int(float(source_stock - 100) * 0.025)))
            if shipment <= 0:
                continue
            source_good["stock"] = source_stock - shipment
            target_good["stock"] = target_stock + shipment
            source_good["trade_exports"] = int(source_good.get("trade_exports", 0)) + shipment
            target_good["trade_imports"] = int(target_good.get("trade_imports", 0)) + shipment
            shipped_total += shipment
            from_market[good_id] = source_good
            to_market[good_id] = target_good
        from_hub["market"] = from_market
        to_hub["market"] = to_market
        from_hub["monthly_trade_exports"] = int(from_hub.get("monthly_trade_exports", 0)) + shipped_total
        to_hub["monthly_trade_imports"] = int(to_hub.get("monthly_trade_imports", 0)) + shipped_total
        hub_state[from_id] = from_hub
        hub_state[to_id] = to_hub
    _dirty = true


func _simulate_city_markets() -> void:
    for city_id in hub_state.keys():
        var hub: Dictionary = hub_state[city_id]
        var market: Dictionary = hub.get("market", {})
        if market.is_empty():
            market = {
                "food": {"price": 8.0, "base_price": 8.0, "stock": 12000, "demand": 9000},
                "water": {"price": 2.0, "base_price": 2.0, "stock": 18000, "demand": 11000},
                "medicine": {"price": 24.0, "base_price": 24.0, "stock": 1800, "demand": 1200},
                "electronics": {"price": 95.0, "base_price": 95.0, "stock": 900, "demand": 650},
                "clothing": {"price": 32.0, "base_price": 32.0, "stock": 2600, "demand": 1800},
                "fuel": {"price": 5.0, "base_price": 5.0, "stock": 7000, "demand": 5200}
            }
        var population_factor := clampf(float(hub.get("population", 100000)) / 100000.0, 0.25, 8.0)
        for good_id in market.keys():
            var good: Dictionary = market[good_id]
            var base_price := float(good.get("base_price", good.get("price", 10.0)))
            var stock := int(good.get("stock", 0))
            var demand := maxi(1, int(float(good.get("demand", 1000)) * population_factor))
            var sold := mini(stock, demand)
            var shortage := 1.0 - float(sold) / float(demand)
            var restock := maxi(1, int(float(demand) * _rng.randf_range(0.72, 1.08)))
            stock = maxi(0, stock - sold + restock)
            var pressure := clampf(float(demand) / float(maxi(1, stock)), 0.45, 2.4)
            var price := clampf(base_price * (0.72 + pressure * 0.28 + shortage * 0.35), base_price * 0.55, base_price * 2.8)
            good["stock"] = stock
            good["demand"] = demand
            good["last_month_sales"] = sold
            good["price"] = snappedf(price, 0.01)
            market[good_id] = good
        hub["market"] = market
        hub_state[city_id] = hub
    _dirty = true


func _recount_businesses_by_city() -> void:
    var counts: Dictionary = {}
    for city_id in hub_state.keys():
        counts[str(city_id)] = 0
    for profile in resident_profiles.values():
        if str(profile.get("business_id", "")).is_empty():
            continue
        var city_id := str(profile.get("business_city", profile.get("city", "")))
        if counts.has(city_id):
            counts[city_id] = int(counts[city_id]) + 1
    for city_id in counts:
        var hub: Dictionary = hub_state[str(city_id)]
        hub["business_count"] = int(counts[city_id])
        hub_state[str(city_id)] = hub
    _dirty = true


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
            "child", "student", "university": students += 1
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
        "career_changes_total": career_changes_total,
        "education_levels_completed_total": education_levels_completed_total,
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
    _social_feed = parsed.get("social_feed", [])
    births_total = int(parsed.get("births_total", 0))
    deaths_total = int(parsed.get("deaths_total", 0))
    marriages_total = int(parsed.get("marriages_total", 0))
    separations_total = int(parsed.get("separations_total", 0))
    graduations_total = int(parsed.get("graduations_total", 0))
    career_promotions_total = int(parsed.get("career_promotions_total", 0))
    career_changes_total = int(parsed.get("career_changes_total", 0))
    education_levels_completed_total = int(parsed.get("education_levels_completed_total", 0))
    independent_households_total = int(parsed.get("independent_households_total", 0))

func _save_state() -> void:
    var data := {
        "simulation_day": simulation_day, "simulation_month": simulation_month,
        "simulation_year": simulation_year, "hub_state": hub_state,
        "resident_profiles": resident_profiles, "social_bonds": social_bonds, "social_feed": _social_feed, "births_total": births_total,
        "deaths_total": deaths_total, "marriages_total": marriages_total,
        "separations_total": separations_total, "graduations_total": graduations_total,
        "career_promotions_total": career_promotions_total,
        "career_changes_total": career_changes_total,
        "education_levels_completed_total": education_levels_completed_total,
        "independent_households_total": independent_households_total
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        _dirty = false
        _save_elapsed = 0.0


func _generate_phone_number(citizen_id: String) -> String:
    var number_rng := RandomNumberGenerator.new()
    number_rng.seed = int(abs(hash(citizen_id + ":phone_number")))
    return "+1-" + str(number_rng.randi_range(200, 999)) + "-" + str(number_rng.randi_range(200, 999)) + "-" + str(number_rng.randi_range(1000, 9999))


func _ensure_phone_profile(citizen_id: String) -> Dictionary:
    if not resident_profiles.has(citizen_id):
        return {}
    var profile: Dictionary = resident_profiles[citizen_id]
    var changed := false
    var defaults := {
        "phone_id":"phone_" + str(abs(hash(citizen_id))),
        "phone_model":"Neon One",
        "phone_number":_generate_phone_number(citizen_id),
        "phone_contacts":[], "phone_inbox":[], "phone_outbox":[],
        "phone_call_history":[], "phone_notifications":[],
        "phone_social_posts":[], "phone_following":[], "phone_followers":[], "phone_watch_history":[], "phone_browser_history":[],
        "public_reputation":0.0, "public_notoriety":0.0, "community_respect":0.0,
        "phone_game_stats":{}, "phone_topic_interests":{},
        "phone_saved_media":[], "phone_last_used_day":simulation_day,
        "phone_battery":100.0, "phone_privacy":"friends",
        "phone_blocked_contacts":[], "phone_muted_contacts":[], "phone_contact_aliases":{}
    }
    for key in defaults:
    }
    for key in defaults:
        if not profile.has(key):
            profile[key] = defaults[key]
            changed = true
    if changed:
        resident_profiles[citizen_id] = profile
        _dirty = true
    return profile


func get_phone_snapshot(citizen_id: String) -> Dictionary:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return {}
    return {
        "phone_id": str(profile.get("phone_id", "")),
        "model": str(profile.get("phone_model", "Neon One")),
        "number": str(profile.get("phone_number", "")),
        "contacts": (profile.get("phone_contacts", []) as Array).duplicate(true),
        "inbox": (profile.get("phone_inbox", []) as Array).duplicate(true),
        "outbox": (profile.get("phone_outbox", []) as Array).duplicate(true),
        "calls": (profile.get("phone_call_history", []) as Array).duplicate(true),
        "notifications": (profile.get("phone_notifications", []) as Array).duplicate(true),
        "battery": float(profile.get("phone_battery", 100.0)),
        "watch_history": (profile.get("phone_watch_history", []) as Array).duplicate(true),
        "browser_history": (profile.get("phone_browser_history", []) as Array).duplicate(true),
        "game_stats": (profile.get("phone_game_stats", {}) as Dictionary).duplicate(true),
        "saved_media": (profile.get("phone_saved_media", []) as Array).duplicate(true)
    }


func get_phone_inbox(citizen_id: String, unread_only: bool = false, limit: int = 40) -> Array:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return []
    var inbox: Array = profile.get("phone_inbox", [])
    var result: Array = []
    for message in inbox:
        if unread_only and bool(message.get("read", false)):
            continue
        result.append(message.duplicate(true))
    result.reverse()
    return result.slice(0, mini(result.size(), maxi(1, limit)))


func get_phone_unread_by_contact(citizen_id: String) -> Dictionary:
    var profile := _ensure_phone_profile(citizen_id)
    var counts: Dictionary = {}
    for message_value in profile.get("phone_inbox", []):
        var message: Dictionary = message_value
        if not bool(message.get("read", false)):
            var sender_id := str(message.get("from", ""))
            counts[sender_id] = int(counts.get(sender_id, 0)) + 1
    return counts


func get_phone_conversation(citizen_id: String, other_id: String, limit: int = 60) -> Array:
    if not resident_profiles.has(citizen_id) or not resident_profiles.has(other_id) or citizen_id == other_id:
        return []
    var profile := _ensure_phone_profile(citizen_id)
    var conversation: Array[Dictionary] = []
    for message_value in profile.get("phone_inbox", []):
        var message: Dictionary = message_value
        if str(message.get("from", "")) == other_id and str(message.get("to", "")) == citizen_id:
            conversation.append(message.duplicate(true))
    for message_value in profile.get("phone_outbox", []):
        var message: Dictionary = message_value
        if str(message.get("from", "")) == citizen_id and str(message.get("to", "")) == other_id:
            conversation.append(message.duplicate(true))
    conversation.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("day", 0)) < int(b.get("day", 0))
    )
    var safe_limit := maxi(1, limit)
    return conversation.slice(maxi(0, conversation.size() - safe_limit))


func get_phone_contacts(citizen_id: String) -> Array:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return []
    var contacts: Array = profile.get("phone_contacts", [])
    return contacts.duplicate(true)


func get_phone_unread_count(citizen_id: String) -> int:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return 0
    var count := 0
    for message in profile.get("phone_inbox", []):
        if not bool(message.get("read", false)):
            count += 1
    return count


func send_phone_message(sender_id: String, recipient_id: String, message_text: String, message_kind: String = "text") -> bool:
    message_text = message_text.strip_edges()
    if message_text.length() > 500:
        return false
    if sender_id == recipient_id or message_text.is_empty():
        return false
    if not resident_profiles.has(sender_id) or not resident_profiles.has(recipient_id):
        return false
    var sender := _ensure_phone_profile(sender_id)
    var recipient := _ensure_phone_profile(recipient_id)
    if (sender.get("phone_blocked_contacts", []) as Array).has(recipient_id):
        return false
    if (recipient.get("phone_blocked_contacts", []) as Array).has(sender_id):
        return false
    var message := {
        "id": "msg_" + str(Time.get_unix_time_from_system()) + "_" + str(_rng.randi()),
        "from": sender_id, "to": recipient_id, "text": message_text,
        "kind": message_kind, "day": simulation_day, "read": false,
        "timestamp": Time.get_datetime_string_from_system()
    }
    var inbox: Array = recipient.get("phone_inbox", [])
    inbox.append(message.duplicate(true))
    while inbox.size() > 80:
        inbox.pop_front()
    recipient["phone_inbox"] = inbox
    var outbox: Array = sender.get("phone_outbox", [])
    outbox.append(message.duplicate(true))
    while outbox.size() > 80:
        outbox.pop_front()
    sender["phone_outbox"] = outbox
    _add_phone_contact(sender_id, recipient_id)
    _add_phone_contact(recipient_id, sender_id)
    _add_phone_notification(recipient_id, "message", "New message from " + str(sender.get("name", sender_id)))
    sender["phone_last_used_day"] = simulation_day
    recipient["phone_last_used_day"] = simulation_day
    resident_profiles[sender_id] = sender
    resident_profiles[recipient_id] = recipient
    record_event(sender_id, "sent_phone_message:" + recipient_id)
    record_event(recipient_id, "received_phone_message:" + sender_id)
    record_social_interaction(sender_id, recipient_id, "phone_message")
    _dirty = true
    return true


func mark_phone_message_read(citizen_id: String, message_id: String) -> bool:
    if not resident_profiles.has(citizen_id) or message_id.is_empty():
        return false
    var profile := _ensure_phone_profile(citizen_id)
    var inbox: Array = profile.get("phone_inbox", [])
    for index in range(inbox.size()):
        var message: Dictionary = inbox[index]
        if str(message.get("id", "")) != message_id:
            continue
        message["read"] = true
        inbox[index] = message
        profile["phone_inbox"] = inbox
        resident_profiles[citizen_id] = profile
        _dirty = true
        return true
    return false


func _add_phone_contact(owner_id: String, contact_id: String) -> void:
    var owner := _ensure_phone_profile(owner_id)
    if owner.is_empty():
        return
    var contacts: Array = owner.get("phone_contacts", [])
    for contact in contacts:
        if str(contact.get("id", "")) == contact_id:
            return
    var contact_profile: Dictionary = resident_profiles.get(contact_id, {})
    contacts.append({"id": contact_id, "name": str(contact_profile.get("name", contact_id)), "number": str(contact_profile.get("phone_number", ""))})
    owner["phone_contacts"] = contacts
    resident_profiles[owner_id] = owner


func _add_phone_notification(citizen_id: String, kind: String, title: String) -> void:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return
    var notifications: Array = profile.get("phone_notifications", [])
    notifications.append({"kind": kind, "title": title, "day": simulation_day, "read": false})
    while notifications.size() > 40:
        notifications.pop_front()
    profile["phone_notifications"] = notifications
    resident_profiles[citizen_id] = profile


func make_phone_call(caller_id: String, recipient_id: String, duration_seconds: int = 30) -> bool:
    if caller_id == recipient_id or not resident_profiles.has(caller_id) or not resident_profiles.has(recipient_id):
        return false
    var caller := _ensure_phone_profile(caller_id)
    var recipient := _ensure_phone_profile(recipient_id)
    var safe_duration := clampi(duration_seconds, 0, 3600)
    var call_record := {
        "id": "call_" + str(Time.get_unix_time_from_system()) + "_" + str(_rng.randi()),
        "to": recipient_id, "from": caller_id, "day": simulation_day,
        "timestamp": Time.get_datetime_string_from_system(),
        "duration_seconds": safe_duration, "status": "completed"
    }
    var caller_calls: Array = caller.get("phone_call_history", [])
    caller_calls.append(call_record)
    while caller_calls.size() > 40:
        caller_calls.pop_front()
    caller["phone_call_history"] = caller_calls
    var recipient_calls: Array = recipient.get("phone_call_history", [])
    var received := call_record.duplicate(true)
    received["status"] = "received"
    recipient_calls.append(received)
    while recipient_calls.size() > 40:
        recipient_calls.pop_front()
    recipient["phone_call_history"] = recipient_calls
    _add_phone_contact(caller_id, recipient_id)
    _add_phone_contact(recipient_id, caller_id)
    _add_phone_notification(recipient_id, "call", "Incoming call from " + str(caller.get("name", caller_id)))
    caller["phone_battery"] = maxf(0.0, float(caller.get("phone_battery", 100.0)) - maxf(0.1, float(safe_duration) / 75.0))
    recipient["phone_battery"] = maxf(0.0, float(recipient.get("phone_battery", 100.0)) - maxf(0.05, float(safe_duration) / 150.0))
    resident_profiles[caller_id] = caller
    resident_profiles[recipient_id] = recipient
    record_social_interaction(caller_id, recipient_id, "phone_call")
    record_event(caller_id, "phone_call_with:" + recipient_id)
    _dirty = true
    return true


func get_phone_call_history(citizen_id: String, limit: int = 30) -> Array:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return []
    var calls: Array = profile.get("phone_call_history", []).duplicate(true)
    calls.reverse()
    return calls.slice(0, mini(calls.size(), maxi(1, limit)))


func publish_phone_post(citizen_id: String, post_text: String, mood: String = "neutral") -> bool:
    if post_text.strip_edges().is_empty() or not resident_profiles.has(citizen_id):
        return false
    var profile := _ensure_phone_profile(citizen_id)
    var post := {
        "id": "post_" + str(Time.get_unix_time_from_system()) + "_" + str(_rng.randi()),
        "author_id": citizen_id, "author": str(profile.get("name", citizen_id)),
        "text": post_text, "mood": mood, "day": simulation_day,
        "likes": 0, "comments": 0
    }
    var personal_posts: Array = profile.get("phone_social_posts", [])
    personal_posts.append(post.duplicate(true))
    while personal_posts.size() > 30:
        personal_posts.pop_front()
    profile["phone_social_posts"] = personal_posts
    _add_phone_notification(citizen_id, "social", "Your post was published")
    resident_profiles[citizen_id] = profile
    _social_feed.append(post)
    while _social_feed.size() > 200:
        _social_feed.pop_front()
    record_event(citizen_id, "published_social_post")
    _dirty = true
    return true


func get_phone_social_feed(limit: int = 30) -> Array:
    var result: Array = _social_feed.duplicate(true)
    var start := maxi(0, result.size() - maxi(1, limit))
    return result.slice(start)


func react_to_phone_post(citizen_id: String, post_id: String) -> bool:
    if not resident_profiles.has(citizen_id):
        return false
    for index in range(_social_feed.size() - 1, -1, -1):
        var post: Dictionary = _social_feed[index]
        if str(post.get("id", "")) != post_id or str(post.get("author_id", "")) == citizen_id:
            continue
        var liked_by: Array = post.get("liked_by", [])
        if liked_by.has(citizen_id):
            return false
        liked_by.append(citizen_id)
        post["liked_by"] = liked_by
        post["likes"] = int(post.get("likes", 0)) + 1
        _social_feed[index] = post
        var author_id := str(post.get("author_id", ""))
        if resident_profiles.has(author_id):
            var author_profile := _ensure_phone_profile(author_id)
            var author_posts: Array = author_profile.get("phone_social_posts", [])
            for own_index in range(author_posts.size() - 1, -1, -1):
                if str(author_posts[own_index].get("id", "")) == post_id:
                    author_posts[own_index] = post.duplicate(true)
                    break
            author_profile["phone_social_posts"] = author_posts
            resident_profiles[author_id] = author_profile
            _add_phone_notification(author_id, "social_like", str(_ensure_phone_profile(citizen_id).get("name", citizen_id)) + " liked your post")
        record_social_interaction(citizen_id, author_id, "social_post_like")
        _dirty = true
        return true
    return false


func get_resident_reputation(citizen_id: String) -> Dictionary:
    if not resident_profiles.has(citizen_id):
        return {}
    var profile: Dictionary = resident_profiles[citizen_id]
    var reputation := float(profile.get("public_reputation", 0.0))
    var notoriety := float(profile.get("public_notoriety", 0.0))
    var respect := float(profile.get("community_respect", 0.0))
    var followers := (profile.get("phone_followers", []) as Array).size()
    var influence := _get_phone_social_influence(_ensure_phone_profile(citizen_id))
    return {
        "reputation": reputation, "notoriety": notoriety, "respect": respect,
        "followers": followers, "influence": influence,
        "standing": "respected" if respect > 0.35 else ("controversial" if notoriety > 0.35 else ("popular" if reputation > 0.35 else ("disliked" if reputation < -0.35 else "ordinary")))
    }


func adjust_resident_reputation(citizen_id: String, reputation_delta: float = 0.0, notoriety_delta: float = 0.0, respect_delta: float = 0.0, reason: String = "community_event") -> void:
    if not resident_profiles.has(citizen_id):
        return
    var profile: Dictionary = resident_profiles[citizen_id]
    profile["public_reputation"] = clampf(float(profile.get("public_reputation", 0.0)) + reputation_delta, -1.0, 1.0)
    profile["public_notoriety"] = clampf(float(profile.get("public_notoriety", 0.0)) + notoriety_delta, 0.0, 1.0)
    profile["community_respect"] = clampf(float(profile.get("community_respect", 0.0)) + respect_delta, -1.0, 1.0)
    var events: Array = profile.get("life_events", [])
    events.append({"day": simulation_day, "event": "reputation:" + reason})
    while events.size() > 32:
        events.pop_front()
    profile["life_events"] = events
    resident_profiles[citizen_id] = profile
    _dirty = true


func get_phone_social_profile(citizen_id: String) -> Dictionary:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return {}
    return {
        "id": citizen_id,
        "name": str(profile.get("name", citizen_id)),
        "occupation": str(profile.get("occupation", "Resident")),
        "city": str(profile.get("city", "Unknown city")),
        "following": (profile.get("phone_following", []) as Array).duplicate(),
        "followers": (profile.get("phone_followers", []) as Array).duplicate(),
        "posts": (profile.get("phone_social_posts", []) as Array).duplicate(true),
        "post_count": (profile.get("phone_social_posts", []) as Array).size(),
        "total_likes": _get_phone_social_engagement(profile, "likes"),
        "total_comments": _get_phone_social_engagement(profile, "comments"),
        "influence_score": _get_phone_social_influence(profile),
        "privacy": str(profile.get("phone_privacy", "friends"))
    }


func _get_phone_social_engagement(profile: Dictionary, field: String) -> int:
    var total := 0
    for post_value in profile.get("phone_social_posts", []):
        var post: Dictionary = post_value
        total += int(post.get(field, 0))
    return total


func _get_phone_social_influence(profile: Dictionary) -> int:
    var followers := (profile.get("phone_followers", []) as Array).size()
    var likes := _get_phone_social_engagement(profile, "likes")
    var comments := _get_phone_social_engagement(profile, "comments")
    return followers * 3 + likes + comments * 2


func follow_phone_resident(follower_id: String, target_id: String) -> bool:
    if follower_id == target_id or not resident_profiles.has(follower_id) or not resident_profiles.has(target_id):
        return false
    var follower := _ensure_phone_profile(follower_id)
    var target := _ensure_phone_profile(target_id)
    var following: Array = follower.get("phone_following", [])
    if following.has(target_id):
        return false
    following.append(target_id)
    follower["phone_following"] = following
    var followers: Array = target.get("phone_followers", [])
    if not followers.has(follower_id):
        followers.append(follower_id)
    target["phone_followers"] = followers
    resident_profiles[follower_id] = follower
    resident_profiles[target_id] = target
    _add_phone_notification(target_id, "social_follow", str(follower.get("name", follower_id)) + " started following you")
    record_social_interaction(follower_id, target_id, "social_follow")
    _dirty = true
    return true


func unfollow_phone_resident(follower_id: String, target_id: String) -> bool:
    if not resident_profiles.has(follower_id) or not resident_profiles.has(target_id):
        return false
    var follower := _ensure_phone_profile(follower_id)
    var target := _ensure_phone_profile(target_id)
    var following: Array = follower.get("phone_following", [])
    if not following.has(target_id):
        return false
    following.erase(target_id)
    follower["phone_following"] = following
    var followers: Array = target.get("phone_followers", [])
    followers.erase(follower_id)
    target["phone_followers"] = followers
    resident_profiles[follower_id] = follower
    resident_profiles[target_id] = target
    _dirty = true
    return true


func get_phone_network_feed(citizen_id: String, limit: int = 30, following_only: bool = false) -> Array:
    if not resident_profiles.has(citizen_id):
        return []
    var profile := _ensure_phone_profile(citizen_id)
    var following: Array = profile.get("phone_following", [])
    var result: Array = []
    for post_value in _social_feed:
        var post: Dictionary = post_value
        var author_id := str(post.get("author_id", ""))
        # Media catalogue entries are videos/images, not resident-authored social posts.
        if author_id.is_empty() or not resident_profiles.has(author_id):
            continue
        if author_id == citizen_id:
            result.append(post.duplicate(true))
        elif not following_only or following.has(author_id):
            result.append(post.duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("day", 0)) > int(b.get("day", 0)))
    return result.slice(0, mini(result.size(), maxi(1, limit)))


func get_phone_trending_feed(citizen_id: String, limit: int = 20) -> Array:
    if not resident_profiles.has(citizen_id):
        return []
    var ranked: Array = []
    for post_value in _social_feed:
        var post: Dictionary = post_value
        var author_id := str(post.get("author_id", ""))
        if author_id.is_empty() or not resident_profiles.has(author_id):
            continue
        if author_id == citizen_id:
            continue
        var age_days := maxi(0, simulation_day - int(post.get("day", simulation_day)))
        var engagement := float(post.get("likes", 0)) + float(post.get("comments", 0)) * 2.5
        var score := engagement / (1.0 + float(age_days) * 0.7)
        var copy: Dictionary = post.duplicate(true)
        copy["trend_score"] = snappedf(score, 0.01)
        ranked.append(copy)
    ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("trend_score", 0.0)) > float(b.get("trend_score", 0.0)))
    return ranked.slice(0, mini(ranked.size(), maxi(1, limit)))


func search_phone_social_posts(citizen_id: String, query: String, limit: int = 20) -> Array:
    if not resident_profiles.has(citizen_id):
        return []
    var needle := query.strip_edges().to_lower()
    if needle.is_empty():
        return []
    var matches: Array = []
    for post_value in _social_feed:
        var post: Dictionary = post_value
        var author_id := str(post.get("author_id", ""))
        if author_id.is_empty() or not resident_profiles.has(author_id):
            continue
        var author := _ensure_phone_profile(author_id)
        var searchable := (str(post.get("text", "")) + " " + str(post.get("topic", "")) + " " + str(post.get("mood", "")) + " " + str(post.get("author", author.get("name", "")))).to_lower()
        if needle in searchable:
            matches.append(post.duplicate(true))
    matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("day", 0)) > int(b.get("day", 0)))
    return matches.slice(0, mini(matches.size(), maxi(1, limit)))


func get_phone_suggested_residents(citizen_id: String, limit: int = 12) -> Array:
    if not resident_profiles.has(citizen_id):
        return []
    var profile := _ensure_phone_profile(citizen_id)
    var following: Array = profile.get("phone_following", [])
    var candidates: Array = []
    for other_id_value in resident_profiles.keys():
        var other_id := str(other_id_value)
        if other_id == citizen_id or following.has(other_id):
            continue
        var other := _ensure_phone_profile(other_id)
        if other.is_empty():
            continue
        var bond: Dictionary = get_social_bond(citizen_id, other_id)
        var follower_count := (other.get("phone_followers", []) as Array).size()
        var influence := _get_phone_social_influence(other)
        var score := float(bond.get("trust", 0.0)) * 2.0 + float(bond.get("familiarity", 0.0)) + minf(float(follower_count) * 0.015, 2.0) + minf(float(influence) * 0.002, 1.5)
        candidates.append({"id":other_id,"name":str(other.get("name", other_id)),"occupation":str(other.get("occupation", "Resident")),"followers":follower_count,"posts":(other.get("phone_social_posts", []) as Array).size(),"influence":influence,"score":score})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
    return candidates.slice(0, mini(candidates.size(), maxi(1, limit)))


func add_phone_social_comment(citizen_id: String, post_id: String, comment_text: String) -> bool:
    comment_text = comment_text.strip_edges()
    if comment_text.is_empty() or comment_text.length() > 240 or not resident_profiles.has(citizen_id):
        return false
    for index in range(_social_feed.size() - 1, -1, -1):
        var post: Dictionary = _social_feed[index]
        if str(post.get("id", "")) != post_id:
            continue
        var comments: Array = post.get("comment_list", [])
        var profile := _ensure_phone_profile(citizen_id)
        comments.append({"author_id":citizen_id,"author":str(profile.get("name", citizen_id)),"text":comment_text,"day":simulation_day})
        while comments.size() > 50:
            comments.pop_front()
        post["comment_list"] = comments
        post["comments"] = int(post.get("comments", 0)) + 1
        _social_feed[index] = post
        var author_id := str(post.get("author_id", ""))
        if resident_profiles.has(author_id):
            var author_profile := _ensure_phone_profile(author_id)
            var author_posts: Array = author_profile.get("phone_social_posts", [])
            for own_index in range(author_posts.size() - 1, -1, -1):
                if str(author_posts[own_index].get("id", "")) == post_id:
                    author_posts[own_index] = post.duplicate(true)
                    break
            author_profile["phone_social_posts"] = author_posts
            resident_profiles[author_id] = author_profile
        if not author_id.is_empty() and author_id != citizen_id:
            _add_phone_notification(author_id, "social_comment", str(profile.get("name", citizen_id)) + " commented on your post")
            record_social_interaction(citizen_id, author_id, "social_comment")
        record_event(citizen_id, "commented_on_social_post")
        _dirty = true
        return true
    return false


const PHONE_VIDEO_TOPICS := ["street_racing", "cyberpunk_music", "wildlife", "space_exploration", "cooking", "sports", "fashion", "comedy", "technology", "travel", "mystery", "parkour", "cars", "dance", "documentary", "gaming"]
const PHONE_IMAGE_TOPICS := ["night_city", "neon_architecture", "supercars", "street_food", "wildlife", "fashion", "space", "sports", "landscapes", "gadgets", "street_art", "portraits"]


func _build_phone_media_catalog() -> void:
    if not _social_feed.is_empty():
        return
    var creators := ["NovaLens", "CyberNomad", "PixelRider", "MiraVox", "UrbanGhost", "KaitoLive", "LunaFrame", "ZeroByte", "NeonChef", "WildEarth"]
    for index in range(240):
        var topic: String = PHONE_VIDEO_TOPICS[index % PHONE_VIDEO_TOPICS.size()]
        var creator: String = creators[index % creators.size()]
        var media := {
            "id": "video_%04d" % index, "type": "video",
            "title": _phone_video_title(topic, index),
            "creator": creator, "topic": topic,
            "duration_seconds": 15 + (index * 17) % 420,
            "views": 1200 + (index * 7919) % 9000000,
            "likes": 40 + (index * 137) % 500000,
            "asset_key": "phone_video_" + topic + "_" + str(index % 12),
            "day": simulation_day, "is_seeded": true
        }
        _social_feed.append(media)
    for index in range(180):
        var topic: String = PHONE_IMAGE_TOPICS[index % PHONE_IMAGE_TOPICS.size()]
        _social_feed.append({
            "id": "image_%04d" % index, "type": "image",
            "title": _phone_image_title(topic, index),
            "creator": creators[(index * 3) % creators.size()],
            "topic": topic, "likes": 25 + (index * 97) % 80000,
            "asset_key": "phone_image_" + topic + "_" + str(index % 15),
            "day": simulation_day, "is_seeded": true
        })
    _dirty = true


func _phone_video_title(topic: String, index: int) -> String:
    var titles := {
        "street_racing": ["Neon tunnel night run", "Electric hypercar launch", "Rainy highway drift"],
        "cyberpunk_music": ["Midnight synthwave session", "Underground club live set", "Rooftop music mix"],
        "wildlife": ["Rare animals of Earth", "Wild forest camera", "Ocean life in 4K"],
        "space_exploration": ["Beyond the lunar frontier", "Mars colony update", "Deep space discoveries"],
        "cooking": ["Street food masterclass", "Five-minute night noodles", "Chef's secret recipe"],
        "sports": ["Championship final highlights", "Rooftop basketball challenge", "Extreme athlete training"],
        "fashion": ["Neo-Tokyo streetwear", "Future style runway", "Custom cybernetic accessories"],
        "comedy": ["Unexpected city moments", "Stand-up from District 9", "Prank in the neon market"],
        "technology": ["Next-gen cybernetics explained", "AI lab behind the scenes", "Future gadgets review"],
        "travel": ["24 hours in Neo-Seoul", "Hidden places of Earth", "Across the megacity"],
        "mystery": ["Unsolved signal from Sector 7", "Abandoned station exploration", "The midnight mystery"],
        "parkour": ["Rooftop freerun compilation", "Impossible wall run", "Urban movement training"],
        "cars": ["Hypercar sound showcase", "Classic engine restoration", "Autonomous car test"],
        "dance": ["Neon street dance battle", "Zero-gravity dance routine", "Dance crew showcase"],
        "documentary": ["People of the megacity", "Earth's changing climate", "Inside a robotics factory"],
        "gaming": ["Ranked arena clutch", "Squad survival highlights", "Tactical team play"]
    }
    var choices: Array = titles.get(topic, ["Daily creator video"])
    return str(choices[index % choices.size()])


func _phone_image_title(topic: String, index: int) -> String:
    return topic.replace("_", " ").capitalize() + " photo #" + str(index + 1)


func get_phone_media_feed(media_type: String = "all", limit: int = 60) -> Array:
    var result: Array = []
    for item in _social_feed:
        if media_type == "all" or str(item.get("type", "post")) == media_type:
            result.append(item.duplicate(true))
    var start := maxi(0, result.size() - maxi(1, limit))
    result.reverse()
    return result.slice(0, maxi(1, limit))


func get_phone_recommended_feed(citizen_id: String, media_type: String = "all", limit: int = 40) -> Array:
    var profile := _ensure_phone_profile(citizen_id)
    var interests: Dictionary = profile.get("phone_topic_interests", {})
    var watched: Dictionary = {}
    for entry in profile.get("phone_watch_history", []):
        watched[str(entry.get("media_id", ""))] = true
    var ranked: Array = []
    for item in _social_feed:
        var kind := str(item.get("type", "post"))
        if media_type != "all" and kind != media_type:
            continue
        var topic := str(item.get("topic", "general"))
        var interest := float(interests.get(topic, 0.0))
        var freshness := float(item.get("day", simulation_day)) * 0.001
        var popularity := log(float(int(item.get("views", 0)) + int(item.get("likes", 0)) + 1)) * 0.08
        var score := interest + freshness + popularity + _rng.randf() * 0.04
        if watched.has(str(item.get("id", ""))):
            score -= 0.35
        ranked.append({"score":score,"item":item})
    ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
    var output: Array = []
    for entry in ranked.slice(0, mini(ranked.size(), maxi(1, limit))):
        output.append(entry.item.duplicate(true))
    return output


func react_to_phone_media(citizen_id: String, media_id: String, reaction: String = "like") -> bool:
    if not resident_profiles.has(citizen_id):
        return false
    for index in range(_social_feed.size() - 1, -1, -1):
        var item: Dictionary = _social_feed[index]
        if str(item.get("id", "")) != media_id:
            continue
        item["likes"] = int(item.get("likes", 0)) + 1
        if reaction == "save":
            var profile := _ensure_phone_profile(citizen_id)
            var saved: Array = profile.get("phone_saved_media", [])
            if not saved.has(media_id):
                saved.append(media_id)
            profile["phone_saved_media"] = saved
            resident_profiles[citizen_id] = profile
        _social_feed[index] = item
        var author_id := str(item.get("author_id", ""))
        if not author_id.is_empty() and author_id != citizen_id:
            record_social_interaction(citizen_id, author_id, "phone_media_" + reaction)
        _dirty = true
        return true
    return false


func add_phone_media_comment(citizen_id: String, media_id: String, comment_text: String) -> bool:
    if comment_text.strip_edges().is_empty():
        return false
    for index in range(_social_feed.size() - 1, -1, -1):
        var item: Dictionary = _social_feed[index]
        if str(item.get("id", "")) == media_id:
            var comments: Array = item.get("comment_list", [])
            comments.append({"author_id":citizen_id,"text":comment_text,"day":simulation_day})
            while comments.size() > 50:
                comments.pop_front()
            item["comment_list"] = comments
            item["comments"] = int(item.get("comments", 0)) + 1
            _social_feed[index] = item
            _dirty = true
            return true
    return false


func record_phone_media_view(citizen_id: String, media_id: String, watch_seconds: float) -> bool:
    if not resident_profiles.has(citizen_id):
        return false
    var profile := _ensure_phone_profile(citizen_id)
    var history: Array = profile.get("phone_watch_history", [])
    history.append({"media_id": media_id, "day": simulation_day, "watch_seconds": maxf(0.0, watch_seconds)})
    while history.size() > 100:
        history.pop_front()
    profile["phone_watch_history"] = history
    var interests: Dictionary = profile.get("phone_topic_interests", {})
    for item in _social_feed:
        if str(item.get("id", "")) == media_id:
            var topic := str(item.get("topic", "general"))
            interests[topic] = float(interests.get(topic, 0.0)) + minf(1.0, watch_seconds / 90.0)
            break
    profile["phone_topic_interests"] = interests
    profile["phone_battery"] = maxf(0.0, float(profile.get("phone_battery", 100.0)) - maxf(0.01, watch_seconds * 0.0008))
    profile["phone_last_used_day"] = simulation_day
    resident_profiles[citizen_id] = profile
    for index in range(_social_feed.size() - 1, -1, -1):
        var media: Dictionary = _social_feed[index]
        if str(media.get("id", "")) == media_id:
            media["views"] = int(media.get("views", 0)) + 1
            _social_feed[index] = media
            break
    _dirty = true
    return true


func publish_phone_media(citizen_id: String, media_type: String, title: String, topic: String, caption: String = "") -> bool:
    if not resident_profiles.has(citizen_id) or media_type not in ["video", "image", "post"]:
        return false
    var profile := _ensure_phone_profile(citizen_id)
    var media_id := "ugc_" + str(Time.get_unix_time_from_system()) + "_" + str(_rng.randi())
    var item := {
        "id": media_id, "type": media_type,
        "title": title, "caption": caption,
        "creator": str(profile.get("name", citizen_id)),
        "author_id": citizen_id, "topic": topic,
        "views": 0, "likes": 0, "day": simulation_day,
        "asset_key": "ugc_" + media_type + "_" + topic
    }
    _social_feed.append(item)
    var personal: Array = profile.get("phone_social_posts", [])
    personal.append(item.duplicate(true))
    while personal.size() > 60:
        personal.pop_front()
    profile["phone_social_posts"] = personal
    resident_profiles[citizen_id] = profile
    while _social_feed.size() > 1000:
        _social_feed.pop_front()
    record_event(citizen_id, "uploaded_phone_" + media_type)
    _dirty = true
    return true


func get_phone_browser_recommendation(citizen_id: String, preferred_topic: String = "") -> Dictionary:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return {}
    var pages := [
        {"id":"net_news","title":"NEO WORLD NEWS","topic":"news"},
        {"id":"net_jobs","title":"WORKFORCE EXCHANGE","topic":"work"},
        {"id":"net_market","title":"GLOBAL MARKET INDEX","topic":"economy"},
        {"id":"net_transit","title":"CITY TRANSIT GRID","topic":"travel"},
        {"id":"net_education","title":"OPEN KNOWLEDGE CAMPUS","topic":"education"},
        {"id":"net_health","title":"CIVIC HEALTH DIRECTORY","topic":"health"},
        {"id":"net_culture","title":"CULTURE STREAM","topic":"culture"},
        {"id":"net_vehicles","title":"MOTOR DISTRICT","topic":"vehicles"},
        {"id":"net_tech","title":"TECHNOLOGY FRONTIER","topic":"technology"},
        {"id":"net_safety","title":"CIVIC SAFETY ALERTS","topic":"safety"},
        {"id":"net_realestate","title":"URBAN PROPERTY EXCHANGE","topic":"property"},
        {"id":"net_wildlife","title":"PLANET BIOSPHERE","topic":"nature"}
    ]
    var interests: Dictionary = profile.get("phone_topic_interests", {})
    var best: Dictionary = {}
    var best_score := -INF
    for page in pages:
        var topic := str(page.get("topic", ""))
        var score := float(interests.get(topic, 0.0)) + _rng.randf_range(0.0, 0.45)
        if topic == preferred_topic:
            score += 1.2
        if score > best_score:
            best_score = score
            best = page.duplicate(true)
    return best


func record_phone_browser_visit(citizen_id: String, page_id: String, page_title: String, topic: String, seconds: float = 30.0) -> bool:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty() or page_id.is_empty():
        return false
    var history: Array = profile.get("phone_browser_history", [])
    history.append({"page_id":page_id,"title":page_title,"topic":topic,"day":simulation_day,"seconds":maxf(1.0, seconds)})
    while history.size() > 80:
        history.pop_front()
    profile["phone_browser_history"] = history
    var interests: Dictionary = profile.get("phone_topic_interests", {})
    interests[topic] = float(interests.get(topic, 0.0)) + minf(1.0, maxf(1.0, seconds) / 60.0)
    profile["phone_topic_interests"] = interests
    profile["phone_battery"] = maxf(0.0, float(profile.get("phone_battery", 100.0)) - maxf(1.0, seconds) * 0.0007)
    profile["phone_last_used_day"] = simulation_day
    resident_profiles[citizen_id] = profile
    record_event(citizen_id, "browsed_web:" + topic)
    _dirty = true
    return true


func get_phone_browser_activity(citizen_id: String, limit: int = 12) -> Array:
    var profile := _ensure_phone_profile(citizen_id)
    if profile.is_empty():
        return []
    var history: Array = profile.get("phone_browser_history", []).duplicate(true)
    history.reverse()
    return history.slice(0, mini(history.size(), maxi(1, limit)))


const PHONE_GAMES := ["Last Circle", "Counter Sector", "Neon Strike", "Dropzone Royale", "Tactical Breach", "Cyber Ops"]


func get_phone_games_catalog() -> Array:
    # Production targets, not claims that these full games are already implemented.
    return [
        {"id":"last_circle","title":"Last Circle","genre":"battle_royale","mode":"solo_duo_squad","max_players":100,"description":"Large-scale survival shooter with persistent world events.","world_scale":"100-player open battlefield","visual_target":"high-fidelity 3D, dynamic weather, day/night, advanced effects","systems":["vehicles","loot economy","ballistics","squad AI","safe-zone simulation"],"production_tier":"AAA target","playable":false},
        {"id":"counter_sector","title":"Counter Sector","genre":"tactical_shooter","mode":"5v5_objective","max_players":10,"description":"Competitive tactical combat with coordinated operator roles.","world_scale":"multi-map 5v5 tactical arenas","visual_target":"high-fidelity materials, lighting and character animation","systems":["weapon handling","destructible cover","objective rounds","team tactics","ranked progression"],"production_tier":"AAA target","playable":false},
        {"id":"neon_strike","title":"Neon Strike","genre":"arena_shooter","mode":"team_deathmatch","max_players":12,"description":"High-speed cyberpunk arena combat.","world_scale":"large multi-level arenas","visual_target":"neon global illumination, VFX, advanced movement animation","systems":["parkour","weapon classes","arena hazards","team modes","matchmaking"],"production_tier":"AAA target","playable":false},
        {"id":"dropzone_royale","title":"Dropzone Royale","genre":"battle_royale","mode":"squad","max_players":60,"description":"Squad survival across a huge evolving combat zone.","world_scale":"60-player large terrain map","visual_target":"detailed landscapes, weather, vehicles and effects","systems":["drop insertion","large map","loot","vehicles","shrinking zone","squad commands"],"production_tier":"AAA target","playable":false},
        {"id":"tactical_breach","title":"Tactical Breach","genre":"tactical_shooter","mode":"5v5_objective","max_players":10,"description":"Coordinated attack and defense rounds.","world_scale":"multi-map tactical combat","visual_target":"high-fidelity 3D target; current prototype uses procedural greybox assets","systems":["squad AI","weapon handling","cover","objectives","round economy"],"production_tier":"AAA target","playable":true},
        {"id":"cyber_ops","title":"Cyber Ops","genre":"strategy_action","mode":"ranked_team","max_players":8,"description":"Team tactics and objective control in a cybernetic battlefield.","world_scale":"large connected combat zones","visual_target":"high-detail environments, character rigs and tactical effects","systems":["class builds","team strategy","dynamic objectives","ranked seasons","AI commanders"],"production_tier":"AAA target","playable":false}
    ]


func play_phone_game(citizen_id: String, game_id: String, match_minutes: int = 12) -> Dictionary:
    if not resident_profiles.has(citizen_id):
        return {}
    var game_found := false
    var game_title := ""
    var game_genre := ""
    for game in get_phone_games_catalog():
        if str(game.get("id", "")) == game_id:
            game_found = true
            game_title = str(game.get("title", ""))
            game_genre = str(game.get("genre", ""))
            break
    if not game_found:
        return {}
    var profile := _ensure_phone_profile(citizen_id)
    var stats: Dictionary = profile.get("phone_game_stats", {})
    var game_stats: Dictionary = stats.get(game_id, {"matches":0,"wins":0,"losses":0,"rank_points":0,"minutes":0})
    var personality_skill := float(profile.get("gaming_skill", 0.35))
    if not profile.has("gaming_skill"):
        var skill_rng := RandomNumberGenerator.new()
        skill_rng.seed = int(abs(hash(citizen_id + ":gaming")))
        personality_skill = skill_rng.randf_range(0.2, 0.92)
        profile["gaming_skill"] = personality_skill
    var score := clampf(personality_skill + _rng.randf_range(-0.25, 0.25), 0.05, 0.98)
    var won := score > 0.56
    game_stats["matches"] = int(game_stats.get("matches", 0)) + 1
    game_stats["wins"] = int(game_stats.get("wins", 0)) + (1 if won else 0)
    game_stats["losses"] = int(game_stats.get("losses", 0)) + (0 if won else 1)
    game_stats["rank_points"] = maxi(0, int(game_stats.get("rank_points", 0)) + (18 if won else -7))
    game_stats["minutes"] = int(game_stats.get("minutes", 0)) + maxi(1, match_minutes)
    stats[game_id] = game_stats
    profile["phone_game_stats"] = stats
    profile["phone_battery"] = maxf(0.0, float(profile.get("phone_battery", 100.0)) - float(match_minutes) * 0.45)
    profile["phone_last_used_day"] = simulation_day
    resident_profiles[citizen_id] = profile
    record_event(citizen_id, "played_" + game_id + (":won" if won else ":lost"))
    _dirty = true
    return {"game_id":game_id,"game_title":game_title,"genre":game_genre,"won":won,"score":snappedf(score,0.01),"stats":game_stats.duplicate(true),"match_minutes":match_minutes}


func play_phone_party_game(game_id: String, invited_ids: Array, match_minutes: int = 12) -> Dictionary:
    var game_data: Dictionary = {}
    for game in get_phone_games_catalog():
        if str(game.get("id", "")) == game_id:
            game_data = game
            break
    if game_data.is_empty():
        return {"started": false, "reason": "unknown_game"}
    var roster: Array[Dictionary] = []
    var total_skill := 0.62
    var accepted := 0
    for citizen_id_value in invited_ids:
        var citizen_id := str(citizen_id_value)
        if not resident_profiles.has(citizen_id):
            continue
        var profile := _ensure_phone_profile(citizen_id)
        if profile.is_empty():
            continue
        var battery := float(profile.get("phone_battery", 100.0))
        var energy := float(profile.get("energy", profile.get("energy_level", 0.7)))
        var availability := clampf(0.72 + energy * 0.18 + battery * 0.001 - (1.0 - _rng.randf()) * 0.28, 0.12, 0.98)
        if battery < 5.0 or _rng.randf() > availability:
            _add_phone_notification(citizen_id, "game_invite", "You missed a game invite for " + str(game_data.get("title", "a game")))
            continue
        var skill := float(profile.get("gaming_skill", 0.45))
        if not profile.has("gaming_skill"):
            var skill_rng := RandomNumberGenerator.new()
            skill_rng.seed = int(abs(hash(citizen_id + ":gaming")))
            skill = skill_rng.randf_range(0.2, 0.92)
            profile["gaming_skill"] = skill
        total_skill += skill
        accepted += 1
        var stats: Dictionary = profile.get("phone_game_stats", {})
        var game_stats: Dictionary = stats.get(game_id, {"matches":0,"wins":0,"losses":0,"rank_points":0,"minutes":0})
        game_stats["matches"] = int(game_stats.get("matches", 0)) + 1
        game_stats["minutes"] = int(game_stats.get("minutes", 0)) + maxi(1, match_minutes)
        stats[game_id] = game_stats
        profile["phone_game_stats"] = stats
        profile["phone_battery"] = maxf(0.0, battery - float(match_minutes) * 0.45)
        profile["phone_last_used_day"] = simulation_day
        resident_profiles[citizen_id] = profile
        record_event(citizen_id, "joined_phone_party:" + game_id)
        _add_phone_notification(citizen_id, "game_party", "Party match started: " + str(game_data.get("title", "Game")))
        roster.append({"id": citizen_id, "name": str(profile.get("name", citizen_id)), "skill": snappedf(skill, 0.01)})
    var team_score := total_skill / float(accepted + 1)
    var won := team_score + _rng.randf_range(-0.18, 0.18) >= 0.56
    for member in roster:
        var member_id := str(member.get("id", ""))
        var member_profile := _ensure_phone_profile(member_id)
        var member_stats: Dictionary = member_profile.get("phone_game_stats", {})
        var member_game_stats: Dictionary = member_stats.get(game_id, {})
        member_game_stats["wins"] = int(member_game_stats.get("wins", 0)) + (1 if won else 0)
        member_game_stats["losses"] = int(member_game_stats.get("losses", 0)) + (0 if won else 1)
        member_game_stats["rank_points"] = maxi(0, int(member_game_stats.get("rank_points", 0)) + (18 if won else -7))
        member_stats[game_id] = member_game_stats
        member_profile["phone_game_stats"] = member_stats
        member_profile["energy"] = clampf(float(member_profile.get("energy", 0.7)) - 0.035, 0.0, 1.0)
        member_profile["social_need"] = maxf(0.0, float(member_profile.get("social_need", 0.5)) - 0.12)
        resident_profiles[member_id] = member_profile
        record_event(member_id, "phone_party_result:" + ("won" if won else "lost"))
    for first_index in range(roster.size()):
        for second_index in range(first_index + 1, roster.size()):
            record_social_interaction(str(roster[first_index].get("id", "")), str(roster[second_index].get("id", "")), "shared_activity")
    _dirty = true
    return {"started": true, "game_id": game_id, "game_title": str(game_data.get("title", "Game")), "won": won, "team_score": snappedf(team_score, 0.01), "accepted_count": accepted, "roster": roster, "invited_count": invited_ids.size(), "match_minutes": maxi(1, match_minutes)}


func get_phone_game_stats(citizen_id: String) -> Dictionary:
    var profile := _ensure_phone_profile(citizen_id)
    return (profile.get("phone_game_stats", {}) as Dictionary).duplicate(true)
