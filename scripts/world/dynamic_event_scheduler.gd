extends Node
## Schedules world events against an externally supplied simulation clock.
signal event_started(event_id: String, payload: Dictionary)
signal event_ended(event_id: String)
signal event_cancelled(event_id: String)
var _events: Dictionary = {}

func schedule_event(event_id: String, start_time: float, duration: float, payload: Dictionary = {}) -> bool:
	if event_id.is_empty() or duration <= 0.0 or _events.has(event_id):
		return false
	var event_data := payload.duplicate(true)
	event_data["priority"] = clampf(float(event_data.get("priority", 0.5)), 0.0, 1.0)
	_events[event_id] = {"start": start_time, "end": start_time + duration, "payload": event_data, "state": "scheduled", "created_msec": Time.get_ticks_msec()}
	return true

func update_simulation_time(simulation_time: float) -> void:
	for event_id in _events.keys():
		var event: Dictionary = _events[event_id]
		var state := str(event["state"])
		if state == "scheduled" and simulation_time >= float(event["start"]):
			event["state"] = "active"
			_events[event_id] = event
			event_started.emit(str(event_id), event["payload"].duplicate(true))
		elif state == "active" and simulation_time >= float(event["end"]):
			event["state"] = "ended"
			_events[event_id] = event
			event_ended.emit(str(event_id))

func get_active_events() -> Array[String]:
	var active: Array[String] = []
	for event_id in _events:
		if str(_events[event_id]["state"]) == "active":
			active.append(str(event_id))
	return active

func get_snapshot() -> Dictionary:
	return _events.duplicate(true)

 
func cancel_event(event_id: String) -> bool:
	if not _events.has(event_id):
		return false
	var event: Dictionary = _events[event_id]
	if str(event.get("state", "")) == "ended":
		return false
	event["state"] = "cancelled"
	event["cancelled_msec"] = Time.get_ticks_msec()
	_events[event_id] = event
	event_cancelled.emit(event_id)
	return true

func get_upcoming_events(limit: int = 10) -> Array[Dictionary]:
	var upcoming: Array[Dictionary] = []
	for event_id in _events:
		var event: Dictionary = _events[event_id]
		if str(event.get("state", "")) != "scheduled":
			continue
		var item := event.duplicate(true)
		item["id"] = str(event_id)
		upcoming.append(item)
	upcoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := float(a.get("payload", {}).get("priority", 0.5))
		var bp := float(b.get("payload", {}).get("priority", 0.5))
		if is_equal_approx(ap, bp):
			return float(a.get("start", 0.0)) < float(b.get("start", 0.0))
		return ap > bp
	)
	if upcoming.size() > maxi(0, limit):
		upcoming.resize(maxi(0, limit))
	return upcoming

 
func get_event_state(event_id: String) -> String:
	if not _events.has(event_id):
		return "missing"
	return str(_events[event_id].get("state", "unknown"))

func prune_finished_events(keep_last: int = 100) -> int:
	var finished: Array[String] = []
	for event_id in _events:
		if str(_events[event_id].get("state", "")) in ["ended", "cancelled"]:
			finished.append(str(event_id))
	finished.sort()
	var remove_count := maxi(0, finished.size() - maxi(0, keep_last))
	for index in range(remove_count):
		_events.erase(finished[index])
	return remove_count
