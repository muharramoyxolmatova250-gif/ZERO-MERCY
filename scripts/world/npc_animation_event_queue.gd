extends RefCounted
## Bounded, time-ordered animation events; prevents unbounded resident queues.
var events: Array[Dictionary] = []
var capacity := 16
var serial := 0
func push_event(kind: String, payload: Dictionary = {}, delay: float = 0.0) -> int:
	serial += 1
	events.append({"id":serial,"kind":kind,"payload":payload.duplicate(true),"remaining":maxf(0.0,delay)})
	while events.size() > maxi(1,capacity): events.pop_front()
	return serial
func update(delta: float) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	for index in range(events.size() - 1, -1, -1):
		events[index]["remaining"] = maxf(0.0, float(events[index].get("remaining",0.0)) - maxf(0.0,delta))
		if float(events[index]["remaining"]) <= 0.0:
			ready.push_front(events[index])
			events.remove_at(index)
	return ready
func clear() -> void:
	events.clear()
