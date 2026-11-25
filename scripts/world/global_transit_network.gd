extends Node
class_name GlobalTransitNetwork
## Data-driven metro, rail and air-route registry.
## Real station/airport coordinates and schedules must be imported from licensed sources.

signal network_changed
signal service_registered(service_id: StringName)

const MODES := [&"metro", &"rail", &"air", &"bus", &"ferry"]

var hubs: Dictionary = {} # hub_id -> {position, kind, region_id, display_name}
var services: Dictionary = {} # service_id -> {mode, stops, duration_minutes, headway_minutes, first_departure, last_departure, enabled}

func clear_network() -> void:
    hubs.clear()
    services.clear()
    network_changed.emit()

func register_hub(hub_id: StringName, display_name: String, kind: StringName, region_id: StringName, world_position: Vector3) -> bool:
    if hub_id == &"" or display_name.strip_edges().is_empty():
        push_warning("Transit hub needs a stable ID and display name.")
        return false
    if kind not in [&"station", &"airport", &"port", &"terminal"]:
        push_warning("Unsupported transit hub kind: %s" % kind)
        return false
    hubs[hub_id] = {
        "display_name": display_name,
        "kind": kind,
        "region_id": region_id,
        "position": world_position
    }
    network_changed.emit()
    return true

func register_service(
    service_id: StringName,
    mode: StringName,
    stop_ids: Array,
    duration_minutes: int,
    headway_minutes: int = 0,
    first_departure_minute: int = 360,
    last_departure_minute: int = 1380,
    enabled: bool = true
) -> bool:
    if service_id == &"" or mode not in MODES or stop_ids.size() < 2:
        push_warning("Transit service requires an ID, supported mode and at least two stops.")
        return false
    if duration_minutes <= 0 or headway_minutes < 0:
        push_warning("Transit duration must be positive and headway cannot be negative.")
        return false
    for stop_id in stop_ids:
        if not hubs.has(stop_id):
            push_warning("Transit service references unknown hub: %s" % stop_id)
            return false
    services[service_id] = {
        "mode": mode,
        "stops": stop_ids.duplicate(),
        "duration_minutes": duration_minutes,
        "headway_minutes": headway_minutes,
        "first_departure_minute": posmod(first_departure_minute, 1440),
        "last_departure_minute": posmod(last_departure_minute, 1440),
        "enabled": enabled
    }
    service_registered.emit(service_id)
    network_changed.emit()
    return true

func set_service_enabled(service_id: StringName, enabled: bool) -> bool:
    if not services.has(service_id):
        return false
    services[service_id]["enabled"] = enabled
    network_changed.emit()
    return true

func get_services_between(from_hub: StringName, to_hub: StringName, mode_filter: StringName = &"") -> Array[Dictionary]:
    var matches: Array[Dictionary] = []
    for service_id in services:
        var service: Dictionary = services[service_id]
        if not service["enabled"]:
            continue
        if mode_filter != &"" and service["mode"] != mode_filter:
            continue
        var stops: Array = service["stops"]
        var from_index := stops.find(from_hub)
        var to_index := stops.find(to_hub)
        if from_index >= 0 and to_index > from_index:
            matches.append({"service_id": service_id, "mode": service["mode"], "stops": stops.duplicate(), "from_index": from_index, "to_index": to_index, "duration_minutes": service["duration_minutes"]})
    return matches

## Returns the next departure minute on the current in-game day, or -1 if none.
func get_next_departure_minute(service_id: StringName, current_minute: int) -> int:
    if not services.has(service_id):
        return -1
    var service: Dictionary = services[service_id]
    if not service["enabled"]:
        return -1
    var now := posmod(current_minute, 1440)
    var first: int = service["first_departure_minute"]
    var last: int = service["last_departure_minute"]
    if first > last or now > last:
        return -1
    if now <= first:
        return first
    var headway: int = service["headway_minutes"]
    if headway <= 0:
        return -1
    var steps := int(ceil(float(now - first) / float(headway)))
    var departure := first + steps * headway
    return departure if departure <= last else -1

func get_hub(hub_id: StringName) -> Dictionary:
    return hubs.get(hub_id, {}).duplicate(true)

func get_service(service_id: StringName) -> Dictionary:
    return services.get(service_id, {}).duplicate(true)
