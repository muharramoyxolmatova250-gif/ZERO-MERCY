extends Node
## Spatial hash for nearby pedestrian queries. Avoids scanning every citizen for
## every crowd/social check as the active city population grows.
@export_range(4.0, 64.0, 1.0) var cell_size := 18.0
@export_range(2.0, 30.0, 1.0) var cleanup_interval := 10.0
var _buckets: Dictionary = {}
var _citizen_cells: Dictionary = {}
var _citizens: Dictionary = {}
var _cleanup_elapsed := 0.0

func _ready() -> void:
	add_to_group("citizen_spatial_index")

func _process(delta: float) -> void:
	_cleanup_elapsed += delta
	if _cleanup_elapsed < cleanup_interval:
		return
	_cleanup_elapsed = 0.0
	_prune_invalid_entries()

func register_citizen(citizen: Node3D) -> void:
	if not is_instance_valid(citizen):
		return
	var instance_id := citizen.get_instance_id()
	_citizens[instance_id] = citizen
	_move_to_cell(citizen, _cell_for(citizen.global_position))

func update_citizen(citizen: Node3D) -> void:
	if not is_instance_valid(citizen):
		return
	var instance_id := citizen.get_instance_id()
	if not _citizens.has(instance_id):
		register_citizen(citizen)
		return
	var new_cell := _cell_for(citizen.global_position)
	if _citizen_cells.get(instance_id, Vector2i(2147483647, 2147483647)) != new_cell:
		_move_to_cell(citizen, new_cell)

func unregister_citizen(citizen: Node3D) -> void:
	if citizen == null:
		return
	var instance_id := citizen.get_instance_id()
	if _citizen_cells.has(instance_id):
		_remove_from_bucket(instance_id, _citizen_cells[instance_id])
	_citizen_cells.erase(instance_id)
	_citizens.erase(instance_id)

func get_nearby_citizens(world_position: Vector3, radius: float) -> Array:
	var result: Array = []
	var min_cell := _cell_for(world_position - Vector3(radius, 0.0, radius))
	var max_cell := _cell_for(world_position + Vector3(radius, 0.0, radius))
	var radius_squared := radius * radius
	for x in range(min_cell.x, max_cell.x + 1):
		for z in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, z)
			if not _buckets.has(cell):
				continue
			var bucket: Array = _buckets[cell]
			for citizen in bucket:
				if not is_instance_valid(citizen):
					continue
				var offset: Vector3 = citizen.global_position - world_position
				offset.y = 0.0
				if offset.length_squared() <= radius_squared:
					result.append(citizen)
	return result

func get_index_snapshot() -> Dictionary:
	return {"registered_citizens": _citizens.size(), "occupied_cells": _buckets.size(), "cell_size_m": cell_size}

func _cell_for(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))

func _move_to_cell(citizen: Node3D, new_cell: Vector2i) -> void:
	var instance_id := citizen.get_instance_id()
	if _citizen_cells.has(instance_id):
		var old_cell: Vector2i = _citizen_cells[instance_id]
		if old_cell == new_cell:
			return
		_remove_from_bucket(instance_id, old_cell)
	if not _buckets.has(new_cell):
		_buckets[new_cell] = []
	var bucket: Array = _buckets[new_cell]
	bucket.append(citizen)
	_buckets[new_cell] = bucket
	_citizen_cells[instance_id] = new_cell
	_citizens[instance_id] = citizen

func _remove_from_bucket(instance_id: int, cell: Vector2i) -> void:
	if not _buckets.has(cell):
		return
	var bucket: Array = _buckets[cell]
	var citizen: Variant = _citizens.get(instance_id)
	if citizen != null:
		bucket.erase(citizen)
	if bucket.is_empty():
		_buckets.erase(cell)
	else:
		_buckets[cell] = bucket

func _prune_invalid_entries() -> void:
	var invalid_ids: Array[int] = []
	for instance_id in _citizens:
		if not is_instance_valid(_citizens[instance_id]):
			invalid_ids.append(int(instance_id))
	for instance_id in invalid_ids:
		var cell: Vector2i = _citizen_cells.get(instance_id, Vector2i.ZERO)
		_remove_from_bucket(instance_id, cell)
		_citizen_cells.erase(instance_id)
		_citizens.erase(instance_id)
