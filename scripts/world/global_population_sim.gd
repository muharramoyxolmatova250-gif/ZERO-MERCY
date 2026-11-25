extends Node3D
## Scalable Earth population model. Residents are aggregate cohorts, not billions of scene nodes.
## Replace estimates with a licensed/current settlement population dataset when one is imported.

@export_range(1000000000, 10000000000, 1000000) var target_world_population: int = 8000000000
@export_range(1.0, 60.0, 1.0) var tick_seconds := 5.0

# Approximate metropolitan-area reference populations (not census claims).
# The remaining global population is retained in distributed urban/rural cohorts.
const MAJOR_METROS := [
	["Tokyo", "Japan", 35.6762, 139.6503, 37000000],
	["Delhi", "India", 28.6139, 77.2090, 34000000],
	["Shanghai", "China", 31.2304, 121.4737, 30000000],
	["Dhaka", "Bangladesh", 23.8103, 90.4125, 24000000],
	["Sao Paulo", "Brazil", -23.5505, -46.6333, 23000000],
	["Cairo", "Egypt", 30.0444, 31.2357, 23000000],
	["Mexico City", "Mexico", 19.4326, -99.1332, 22000000],
	["Beijing", "China", 39.9042, 116.4074, 22000000],
	["Mumbai", "India", 19.0760, 72.8777, 22000000],
	["Osaka", "Japan", 34.6937, 135.5023, 19000000],
	["Chongqing", "China", 29.4316, 106.9123, 18000000],
	["Karachi", "Pakistan", 24.8607, 67.0011, 18000000],
	["Kinshasa", "DR Congo", -4.4419, 15.2663, 17000000],
	["Lagos", "Nigeria", 6.5244, 3.3792, 17000000],
	["Istanbul", "Türkiye", 41.0082, 28.9784, 16000000],
	["Buenos Aires", "Argentina", -34.6037, -58.3816, 16000000],
	["New York", "United States", 40.7128, -74.0060, 20000000],
	["London", "United Kingdom", 51.5072, -0.1276, 15000000],
	["Tashkent", "Uzbekistan", 41.2995, 69.2401, 3000000]
]

var cohorts: Array[Dictionary] = []
var represented_residents: int = 0
var other_urban_and_rural_residents: int = 0
var simulation_ticks := 0
var active_workers := 0
var active_commuters := 0
var active_socializing := 0
var active_resting := 0
var _timer := 0.0
var _registered_visual_hubs: Dictionary = {}

func _ready() -> void:
	_build_global_cohorts()
	_simulate()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= tick_seconds:
		_timer = 0.0
		_simulate()

func _build_global_cohorts() -> void:
	cohorts.clear()
	var metro_total := 0
	for metro in MAJOR_METROS:
		var population := int(metro[4])
		metro_total += population
		cohorts.append(_make_cohort(str(metro[0]), str(metro[1]), float(metro[2]), float(metro[3]), population, true))
	other_urban_and_rural_residents = maxi(0, target_world_population - metro_total)
	# This cohort represents all remaining cities, towns and villages worldwide.
	# It is split conceptually into urban and rural populations for simulation.
	var other_urban := int(round(float(other_urban_and_rural_residents) * 0.58))
	var rural := other_urban_and_rural_residents - other_urban
	cohorts.append(_make_cohort("Other cities and towns worldwide", "Global", 0.0, 0.0, other_urban, false))
	cohorts.append(_make_cohort("Rural settlements worldwide", "Global", 0.0, 0.0, rural, false))
	represented_residents = target_world_population

func _make_cohort(id: String, country: String, lat: float, lon: float, population: int, is_metro: bool) -> Dictionary:
	return {
		"id": id, "city": id, "country": country, "lat": lat, "lon": lon,
		"population_reference": population, "residents": population,
		"workers": int(population * 0.46), "students": int(population * 0.18),
		"families": int(population * 0.24), "commuting": 0, "socializing": 0,
		"resting": 0, "local_time": 12, "is_major_metro": is_metro,
		"counts_toward_global_total": true
	}

func _sync_registered_hubs() -> void:
	# Local procedural settlements add detailed simulation anchors, but do not
	# inflate the fixed global headcount a second time.
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim == null:
		return
	var registered: Dictionary = life_sim.get("hub_state")
	for city_id in registered:
		var key := str(city_id)
		if _registered_visual_hubs.has(key):
			continue
		var hub: Dictionary = registered[city_id]
		var population := maxi(1, int(hub.get("population", 100000)))
		var local_cohort := _make_cohort(
			str(hub.get("display_name", hub.get("city", key))),
			str(hub.get("country", "Unknown")),
			float(hub.get("latitude", 0.0)),
			float(hub.get("longitude", 0.0)),
			population,
			false
		)
		local_cohort["counts_toward_global_total"] = false
		local_cohort["local_detail_anchor"] = true
		_registered_visual_hubs[key] = cohorts.size()
		cohorts.append(local_cohort)

func _simulate() -> void:
	_sync_registered_hubs()
	simulation_ticks += 1
	active_workers = 0
	active_commuters = 0
	active_socializing = 0
	active_resting = 0
	var utc := int(Time.get_time_dict_from_system().get("hour", 12))
	for i in range(cohorts.size()):
		var h: Dictionary = cohorts[i]
		var local_hour := posmod(utc + int(round(float(h.get("lon", 0.0)) / 15.0)), 24)
		h["local_time"] = local_hour
		var residents := int(h["residents"])
		var workers := int(h["workers"])
		var commute_ratio := 0.24 if local_hour in [7, 8, 17, 18] else (0.04 if local_hour >= 9 and local_hour < 17 else 0.0)
		var social_ratio := 0.05 if local_hour >= 18 and local_hour < 23 else 0.015
		var resting_ratio := 0.68 if local_hour < 6 or local_hour >= 22 else 0.18
		h["commuting"] = int(float(workers) * commute_ratio)
		h["socializing"] = int(float(residents) * social_ratio)
		h["resting"] = int(float(residents) * resting_ratio)
		if bool(h.get("counts_toward_global_total", false)):
			active_workers += workers - int(h["commuting"])
			active_commuters += int(h["commuting"])
			active_socializing += int(h["socializing"])
			active_resting += int(h["resting"])
		cohorts[i] = h

func get_world_population_snapshot() -> Dictionary:
	return {
		"world_population": target_world_population,
		"represented_residents": represented_residents,
		"major_metro_cohorts": MAJOR_METROS.size(),
		"all_other_urban_and_rural_residents": other_urban_and_rural_residents,
		"city_hubs": MAJOR_METROS.size() + _registered_visual_hubs.size(),
		"aggregate_cohorts": cohorts.size(),
		"active_workers": active_workers,
		"commuting": active_commuters,
		"socializing": active_socializing,
		"resting": active_resting,
		"ticks": simulation_ticks,
		"population_is_aggregate_not_individual_npcs": true
	}
