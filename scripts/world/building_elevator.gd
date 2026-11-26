extends Node3D
## Reusable elevator controller for generated multi-storey buildings.
signal floor_reached(floor_index: int)
@export_range(1, 80, 1) var floor_count := 8
@export var floor_height := 3.2
@export var travel_speed := 2.4
@export var dwell_seconds := 1.2
var current_floor := 0
var target_floor := 0
var _dwell := 0.0
var _moving := false
var _queue: Array[int] = []

func request_floor(floor_index: int) -> bool:
	var requested := clampi(floor_index, 0, maxi(0, floor_count - 1))
	if requested == current_floor and not _moving:
		return true
	if not _queue.has(requested) and requested != target_floor:
		_queue.append(requested)
	if not _moving:
		_begin_next_trip()
	return true

func _begin_next_trip() -> void:
	if _queue.is_empty():
		_moving = false
		return
	target_floor = _queue.pop_front()
	_moving = target_floor != current_floor
	if not _moving:
		_dwell = dwell_seconds

func _physics_process(delta: float) -> void:
	if _dwell > 0.0:
		_dwell = maxf(0.0, _dwell - delta)
		if _dwell == 0.0:
			_begin_next_trip()
		return
	if not _moving:
		return
	var destination_y := float(target_floor) * floor_height
	var next_y := move_toward(position.y, destination_y, travel_speed * delta)
	position.y = next_y
	if is_equal_approx(position.y, destination_y):
		current_floor = target_floor
		_moving = false
		floor_reached.emit(current_floor)
		_dwell = dwell_seconds
		if _dwell <= 0.0:
			_begin_next_trip()

func get_elevator_snapshot() -> Dictionary:
	return {"current_floor": current_floor, "target_floor": target_floor, "moving": _moving, "queued_stops": _queue.size()}
