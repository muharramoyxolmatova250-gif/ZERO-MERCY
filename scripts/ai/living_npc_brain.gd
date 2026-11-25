extends Node
class_name LivingNPCBrain
## Lightweight, data-driven daily routine controller for a single civilian NPC.
## Attach as a child of an NPC scene and call set_world_minutes() from the world clock.
## This is a routine/state foundation; navigation, dialogue, persistence and needs are
## intentionally owned by the NPC actor/gameplay systems.

signal routine_changed(state: StringName, destination_id: StringName)

@export var citizen_id: StringName = &"citizen_001"
@export var home_id: StringName = &"home"
@export var work_id: StringName = &"work"
@export var leisure_id: StringName = &"plaza"

@export_range(0, 1439, 1) var wake_minutes := 420 # 07:00
@export_range(0, 1439, 1) var work_minutes := 540 # 09:00
@export_range(0, 1439, 1) var leisure_minutes := 1080 # 18:00
@export_range(0, 1439, 1) var sleep_minutes := 1320 # 22:00

var current_state: StringName = &"sleeping"
var destination_id: StringName = &"home"
var _last_minute := -1

func set_world_minutes(total_minutes: int) -> void:
    var minute_of_day := posmod(total_minutes, 1440)
    if minute_of_day == _last_minute:
        return
    _last_minute = minute_of_day
    _evaluate_routine(minute_of_day)

func _evaluate_routine(minute_of_day: int) -> void:
    var next_state: StringName
    var next_destination: StringName

    if _is_between(minute_of_day, wake_minutes, work_minutes):
        next_state = &"commuting_to_work"
        next_destination = work_id
    elif _is_between(minute_of_day, work_minutes, leisure_minutes):
        next_state = &"working"
        next_destination = work_id
    elif _is_between(minute_of_day, leisure_minutes, sleep_minutes):
        next_state = &"leisure"
        next_destination = leisure_id
    else:
        next_state = &"sleeping"
        next_destination = home_id

    if next_state == current_state and next_destination == destination_id:
        return

    current_state = next_state
    destination_id = next_destination
    routine_changed.emit(current_state, destination_id)

func _is_between(value: int, start_value: int, end_value: int) -> bool:
    if start_value <= end_value:
        return value >= start_value and value < end_value
    return value >= start_value or value < end_value
