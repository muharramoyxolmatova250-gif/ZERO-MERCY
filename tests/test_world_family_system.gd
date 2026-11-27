extends SceneTree

const WorldLifeSim = preload("res://scripts/world/world_life_sim.gd")

func _initialize() -> void:
    _test_family_snapshot_links_real_residents()
    _test_shared_time_builds_relationship_bonds()
    _test_childcare_improves_parent_child_bond()
    _test_family_conflict_is_recorded()
    print("PASS world family system: kinship, household snapshots, shared bonds, childcare and conflict.")
    quit()

func _make_sim():
    var sim = WorldLifeSim.new()
    sim.simulation_day = 42
    sim.resident_profiles = {
        "parent_a": {
            "id": "parent_a", "name": "Amina", "age_years": 36, "occupation": "engineer",
            "life_stage": "adult", "family_id": "family_1", "household_id": "home_1",
            "marital_status": "partnered", "partner_id": "parent_b", "children_count": 1,
            "children_ids": ["child_a"], "parents": [], "life_events": [], "happiness": 0.5,
            "family_stress": 0.3, "money": 1000, "public_reputation": 0.0,
            "public_notoriety": 0.0, "community_respect": 0.0
        },
        "parent_b": {
            "id": "parent_b", "name": "Aziz", "age_years": 38, "occupation": "doctor",
            "life_stage": "adult", "family_id": "family_1", "household_id": "home_1",
            "marital_status": "partnered", "partner_id": "parent_a", "children_count": 1,
            "children_ids": ["child_a"], "parents": [], "life_events": [], "happiness": 0.5,
            "family_stress": 0.3, "money": 1000, "public_reputation": 0.0,
            "public_notoriety": 0.0, "community_respect": 0.0
        },
        "child_a": {
            "id": "child_a", "name": "Mira", "age_years": 9, "occupation": "child",
            "life_stage": "child", "family_id": "family_1", "household_id": "home_1",
            "marital_status": "single", "parent_id": "parent_a", "second_parent_id": "parent_b",
            "parents": ["parent_a", "parent_b"], "children_ids": [], "life_events": [],
            "happiness": 0.5, "health": 0.8, "family_stress": 0.1
        }
    }
    return sim

func _test_family_snapshot_links_real_residents() -> void:
    var sim = _make_sim()
    var snapshot: Dictionary = sim.get_family_snapshot("parent_a")
    assert(int(snapshot.get("member_count", 0)) == 2)
    assert(str(snapshot.get("household_id", "")) == "home_1")
    var found_child := false
    var found_partner := false
    for member in snapshot.get("members", []):
        if str(member.get("id", "")) == "child_a" and str(member.get("relationship", "")) == "child":
            found_child = true
        if str(member.get("id", "")) == "parent_b" and str(member.get("relationship", "")) == "partner":
            found_partner = true
    assert(found_child and found_partner)

func _test_shared_time_builds_relationship_bonds() -> void:
    var sim = _make_sim()
    sim.record_family_interaction("parent_a", "family_dinner")
    var bond: Dictionary = sim.get_social_bond("parent_a", "child_a")
    assert(float(bond.get("friendship", 0.0)) > 0.0)
    assert(int(bond.get("interactions", 0)) == 1)
    var snapshot: Dictionary = sim.get_family_snapshot("parent_a")
    assert(float(snapshot.get("happiness", 0.0)) > 0.5)

func _test_childcare_improves_parent_child_bond() -> void:
    var sim = _make_sim()
    var before := float(sim.resident_profiles["child_a"].get("happiness", 0.0))
    assert(sim.record_childcare("parent_a", "child_a", "homework_help"))
    assert(float(sim.resident_profiles["child_a"].get("happiness", 0.0)) > before)
    assert(float(sim.get_social_bond("parent_a", "child_a").get("trust", 0.0)) > 0.0)
    assert(not sim.record_childcare("parent_b", "unknown_child"))

func _test_family_conflict_is_recorded() -> void:
    var sim = _make_sim()
    sim.record_social_interaction("parent_a", "child_a", "friendly_chat")
    var before := float(sim.get_social_bond("parent_a", "child_a").get("trust", 0.0))
    sim.record_family_conflict("parent_a", "child_a", 0.8)
    var after := float(sim.get_social_bond("parent_a", "child_a").get("trust", 0.0))
    assert(after < before)
    assert(float(sim.resident_profiles["parent_a"].get("family_stress", 0.0)) > 0.3)
