extends RefCounted
## Bounded evidence-based simulation-anomaly reasoning for one resident.
## This models beliefs and investigations; it does not imply consciousness.
const MAX_EVIDENCE := 48
const MAX_HYPOTHESES := 8
const MAX_EXPERIMENTS := 12
var resident_id := ""
var evidence: Array[Dictionary] = []
var hypotheses: Array[Dictionary] = []
var experiments: Array[Dictionary] = []
var known_anomalies: Dictionary = {}
var suspicion := 0.0
var curiosity := 0.5
var last_update_time := 0.0

func setup(id: String, curiosity_value: float = 0.5) -> void:
	resident_id = id
	curiosity = clampf(curiosity_value, 0.0, 1.0)

func observe_anomaly(anomaly_id: String, kind: String, detail: String, strength: float = 0.5, source: String = "world") -> bool:
	if anomaly_id.is_empty() or known_anomalies.has(anomaly_id):
		return false
	var weight := clampf(strength, 0.0, 1.0)
	var record := {"id":anomaly_id,"kind":kind,"detail":detail,"strength":weight,"source":source,"time":Time.get_unix_time_from_system()}
	evidence.append(record)
	known_anomalies[anomaly_id] = true
	while evidence.size() > MAX_EVIDENCE:
		var removed: Dictionary = evidence.pop_front()
		known_anomalies.erase(str(removed.get("id", "")))
	suspicion = clampf(suspicion + weight * (0.08 + curiosity * 0.12), 0.0, 1.0)
	_update_hypotheses(record)
	return true

func _update_hypotheses(record: Dictionary) -> void:
	var category := str(record.get("kind", "unknown"))
	var hypothesis_id := "pattern_" + category
	var index := _find_hypothesis(hypothesis_id)
	if index < 0:
		if hypotheses.size() >= MAX_HYPOTHESES:
			hypotheses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("confidence", 0.0)) < float(b.get("confidence", 0.0)))
			hypotheses.pop_front()
		hypotheses.append({"id":hypothesis_id,"claim":"Repeated anomaly pattern: " + category,"confidence":0.15,"support":0,"contradictions":0,"status":"tentative"})
		index = hypotheses.size() - 1
	var item: Dictionary = hypotheses[index]
	item.support = int(item.get("support", 0)) + 1
	var evidence_strength := float(record.get("strength", 0.5))
	item.confidence = clampf(float(item.get("confidence", 0.15)) + evidence_strength * 0.11, 0.0, 0.92)
	item.status = "strong_suspicion" if float(item.confidence) >= 0.68 else "tentative"
	hypotheses[index] = item

func _find_hypothesis(hypothesis_id: String) -> int:
	for index in range(hypotheses.size()):
		if str(hypotheses[index].get("id", "")) == hypothesis_id:
			return index
	return -1

func consider_counter_evidence(hypothesis_id: String, detail: String, strength: float = 0.5) -> bool:
	var index := _find_hypothesis(hypothesis_id)
	if index < 0:
		return false
	var item: Dictionary = hypotheses[index]
	item.contradictions = int(item.get("contradictions", 0)) + 1
	item.confidence = clampf(float(item.get("confidence", 0.0)) - clampf(strength, 0.0, 1.0) * 0.16, 0.02, 0.92)
	item.status = "questioned" if int(item.contradictions) > 0 else "tentative"
	item["last_counter_evidence"] = detail
	hypotheses[index] = item
	suspicion = clampf(suspicion - strength * 0.05, 0.0, 1.0)
	return true

func create_experiment(question: String, expected_observation: String, risk: float = 0.1) -> int:
	if question.strip_edges().is_empty() or experiments.size() >= MAX_EXPERIMENTS:
		return -1
	experiments.append({"id":experiments.size() + 1,"question":question,"expected":expected_observation,"risk":clampf(risk, 0.0, 1.0),"status":"planned","result":"","created_at":Time.get_unix_time_from_system()})
	return experiments.size() - 1

func resolve_experiment(index: int, result: String, supports_theory: bool) -> bool:
	if index < 0 or index >= experiments.size() or str(experiments[index].get("status", "")) != "planned":
		return false
	var item: Dictionary = experiments[index]
	item.status = "completed"
	item.result = result
	experiments[index] = item
	if not supports_theory:
		for hypothesis in hypotheses.duplicate():
			consider_counter_evidence(str(hypothesis.get("id", "")), result, 0.35)
	return true

func receive_rumor(payload: Dictionary, trust: float = 0.35) -> bool:
	var rumor_id := str(payload.get("id", ""))
	if rumor_id.is_empty() or known_anomalies.has(rumor_id):
		return false
	var accepted := clampf(trust, 0.0, 1.0) * float(payload.get("strength", 0.4))
	return observe_anomaly("rumor:" + rumor_id, str(payload.get("kind", "rumor")), str(payload.get("detail", "Unverified resident report")), accepted, "social_rumor")

func shareable_evidence(limit: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in evidence:
		if str(item.get("source", "")) != "social_rumor":
			result.append(item.duplicate(true))
		if result.size() >= maxi(1, limit):
			break
	return result

func choose_investigation() -> Dictionary:
	if evidence.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score := -1.0
	for item in evidence:
		var novelty := 1.0 if int(item.get("strength", 0.0) * 10.0) > 4 else 0.6
		var score := float(item.get("strength", 0.0)) * (0.4 + curiosity * 0.6) * novelty
		if score > best_score:
			best_score = score
			best = item
	return best.duplicate(true)

func update_personal_traits(curiosity_value: float, caution: float) -> void:
	curiosity = clampf(curiosity_value, 0.0, 1.0)
	suspicion = clampf(suspicion * (0.995 + clampf(caution, 0.0, 1.0) * 0.005), 0.0, 1.0)

func get_snapshot() -> Dictionary:
	return {"resident_id":resident_id,"evidence_count":evidence.size(),"evidence":evidence.duplicate(true),"hypotheses":hypotheses.duplicate(true),"experiments":experiments.duplicate(true),"suspicion":suspicion,"curiosity":curiosity,"last_update_time":last_update_time}

func clear_expired_evidence(max_age_seconds: float = 2592000.0) -> int:
	var now := Time.get_unix_time_from_system()
	var removed := 0
	for index in range(evidence.size() - 1, -1, -1):
		if now - int(evidence[index].get("time", now)) > max_age_seconds:
			known_anomalies.erase(str(evidence[index].get("id", "")))
			evidence.remove_at(index)
			removed += 1
	return removed

func get_hypothesis_confidence(hypothesis_id: String) -> float:
	var index := _find_hypothesis(hypothesis_id)
	return float(hypotheses[index].get("confidence", 0.0)) if index >= 0 else 0.0

func is_anomaly_known(anomaly_id: String) -> bool:
	return known_anomalies.has(anomaly_id)
