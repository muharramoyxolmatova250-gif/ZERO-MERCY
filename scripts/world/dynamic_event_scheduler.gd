extends Node
## Schedules world events against an externally supplied simulation clock.
signal event_started(event_id: String, payload: Dictionary)
signal event_ended(event_id: String)
var _events: Dictionary = {}

func schedule_event(event_id: String, start_time: float, duration: float, payload: Dictionary = {}) -> bool:
	if event_id.is_empty() or duration <= 0.0 or _events.has(event_id):
		return false
	_events[event_id] = {"start": start_time, "end": start_time + duration, "payload": payload.duplicate(true), "state": "scheduled"}
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
