extends Node
## Small local rumor network: only residents in proximity can exchange observed evidence.
const SCAN_INTERVAL := 8.0
const MAX_NEIGHBORS_PER_RESIDENT := 3
const MAX_RUMORS_PER_SCAN := 2
var _elapsed := 0.0
var _exchange_cooldowns: Dictionary = {}
var exchanges_total := 0
var rumors_total := 0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < SCAN_INTERVAL:
		return
	_elapsed = 0.0
	_exchange_nearby_evidence()

func _exchange_nearby_evidence() -> void:
	var residents := get_tree().get_nodes_in_group("city_citizen")
	if residents.size() < 2:
		return
	var now := Time.get_unix_time_from_system()
	for source in residents:
		if not is_instance_valid(source) or not source.has_method("get_simulation_awareness_snapshot"):
			continue
		var snapshot: Dictionary = source.call("get_simulation_awareness_snapshot")
		var evidence: Array = snapshot.get("evidence", [])
		if evidence.is_empty():
			continue
		var neighbors: Array[Node3D] = []
		for candidate in residents:
			if candidate == source or not is_instance_valid(candidate):
				continue
			if not candidate is Node3D:
				continue
			if source.global_position.distance_to(candidate.global_position) <= 10.0:
				neighbors.append(candidate as Node3D)
		neighbors.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return source.global_position.distance_squared_to(a.global_position) < source.global_position.distance_squared_to(b.global_position)
		)
		var shared := 0
		for neighbor in neighbors:
			if shared >= MAX_NEIGHBORS_PER_RESIDENT:
				break
			if not neighbor.has_method("receive_simulation_rumor"):
				continue
			var pair_key := str(source.get("citizen_id")) + ">" + str(neighbor.get("citizen_id"))
			if now - int(_exchange_cooldowns.get(pair_key, 0)) < 90:
				continue
			var sent := 0
			for item in evidence:
				if sent >= MAX_RUMORS_PER_SCAN:
					break
				if str(item.get("source", "")) == "social_rumor":
					continue
				var rumor := {"id":str(item.get("id", "")),"kind":str(item.get("kind", "unknown")),"detail":str(item.get("detail", "")),"strength":float(item.get("strength", 0.35))}
				var trust := 0.3 + clampf(float(neighbor.get("relationship_score")) / 100.0, 0.0, 0.5)
				if bool(neighbor.call("receive_simulation_rumor", rumor, trust)):
					sent += 1
					rumors_total += 1
			if sent > 0:
				_exchange_cooldowns[pair_key] = now
				exchanges_total += 1
				shared += 1
	_prune_cooldowns(now)

func _prune_cooldowns(now: int) -> void:
	if _exchange_cooldowns.size() < 256:
		return
	for key in _exchange_cooldowns.keys():
		if now - int(_exchange_cooldowns[key]) > 3600:
			_exchange_cooldowns.erase(key)

func get_network_snapshot() -> Dictionary:
	return {"resident_count":get_tree().get_nodes_in_group("city_citizen").size(),"exchange_count":exchanges_total,"rumor_count":rumors_total,"active_pair_cooldowns":_exchange_cooldowns.size()}
