extends Node3D
## Distance-based region scene streamer.
## The player position is interpreted in the same local metre coordinate system
## as the region scenes. Tiles are loaded within load_radius and removed beyond unload_radius.
## This prototype processes a limited number of scene operations per frame; it is
## not yet a threaded planet-scale streamer.

@export var target_path: NodePath
@export_file("*.json") var tile_index_path := "res://data/world/region_tiles.json"
@export var region_scene: PackedScene
@export_range(100.0, 100000.0, 100.0) var tile_size_m := 2000.0
@export_range(0, 5, 1) var load_radius := 1
@export_range(1, 8, 1) var unload_radius := 2
@export_range(1, 32, 1) var max_operations_per_frame := 2
@export var region_root_name := "LoadedRegions"

var _target: Node3D
var _region_root: Node3D
var _tile_index: Dictionary = {}
var _loaded: Dictionary = {}
var _pending: Array[Vector2i] = []
var _known_tiles: Dictionary = {}


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	_region_root = Node3D.new()
	_region_root.name = region_root_name
	add_child(_region_root)
	_load_tile_index()


func _process(_delta: float) -> void:
	if _target == null or region_scene == null:
		return
	_update_desired_tiles()
	_process_queue()


func _load_tile_index() -> void:
	if not FileAccess.file_exists(tile_index_path):
		push_warning("Region tile index not found: " + tile_index_path)
		return
	var file := FileAccess.open(tile_index_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Region tile index must be a JSON object.")
		return
	_tile_index = parsed
	for key in _tile_index.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			continue
		_known_tiles[Vector2i(int(parts[0]), int(parts[1]))] = _tile_index[key]


func _update_desired_tiles() -> void:
	var current := Vector2i(
		floori(_target.global_position.x / tile_size_m),
		floori(_target.global_position.z / tile_size_m)
	)
	var desired: Dictionary = {}
	for x in range(current.x - load_radius, current.x + load_radius + 1):
		for z in range(current.y - load_radius, current.y + load_radius + 1):
			var coord := Vector2i(x, z)
			var key := _coord_key(coord)
			if _known_tiles.has(coord):
				desired[key] = true
				if not _loaded.has(key) and not _pending.has(coord):
					_pending.append(coord)

	for loaded_key in _loaded.keys():
		var loaded_coord: Vector2i = _loaded[loaded_key]["coord"]
		var distance := maxi(abs(loaded_coord.x - current.x), abs(loaded_coord.y - current.y))
		if distance > unload_radius:
			var node: Node = _loaded[loaded_key]["node"]
			if is_instance_valid(node):
				node.queue_free()
			_loaded.erase(loaded_key)

	# Drop queued tiles that are no longer near the player.
	var kept: Array[Vector2i] = []
	for coord in _pending:
		var distance := maxi(abs(coord.x - current.x), abs(coord.y - current.y))
		if distance <= load_radius and _known_tiles.has(coord):
			kept.append(coord)
	_pending = kept


func _process_queue() -> void:
	var operations := 0
	while not _pending.is_empty() and operations < max_operations_per_frame:
		var coord: Vector2i = _pending.pop_front()
		var key := _coord_key(coord)
		if _loaded.has(key) or not _known_tiles.has(coord):
			continue
		var entry: Dictionary = _known_tiles[coord]
		var path := str(entry.get("scene_path", ""))
		var packed: PackedScene = region_scene
		if path != "":
			var loaded_resource := load(path)
			if loaded_resource is PackedScene:
				packed = loaded_resource
		if packed == null:
			push_warning("No region PackedScene configured for tile " + key)
			continue
		var instance := packed.instantiate()
		if instance is Node3D:
			var center_lat := float(entry.get("center_lat", 0.0))
			var center_lon := float(entry.get("center_lon", 0.0))
			if instance.has_method("configure_region"):
				instance.call("configure_region", str(entry.get("geojson_path", "")), center_lat, center_lon)
			elif "geojson_path" in instance:
				instance.set("geojson_path", str(entry.get("geojson_path", "")))
				instance.set("region_center_lat", center_lat)
				instance.set("region_center_lon", center_lon)
			instance.position = Vector3(
				float(entry.get("origin_x", coord.x * tile_size_m)),
				0.0,
				float(entry.get("origin_z", coord.y * tile_size_m))
			)
		_region_root.add_child(instance)
		_loaded[key] = {"coord": coord, "node": instance}
		operations += 1


func _coord_key(coord: Vector2i) -> String:
	return str(coord.x) + "," + str(coord.y)
