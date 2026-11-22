extends Node3D
## Streams globally aligned OSM tiles around the player in the shared world grid.
@export var target_path: NodePath
@export_file("*.json") var tile_index_path := "res://data/world/region_tiles.json"
@export var region_scene: PackedScene
@export var terrain_scene: PackedScene = preload("res://scenes/world/dem_terrain_tile.tscn")
@export_range(100.0,100000.0,100.0) var tile_size_m := 11132.0
@export_range(0,8,1) var load_radius := 1
@export_range(1,12,1) var unload_radius := 2
@export_range(1,32,1) var max_operations_per_frame := 1
var _target: Node3D
var _root: Node3D
var _tiles: Dictionary = {}
var _loaded: Dictionary = {}
var _anchor_lon := 72.3
var _anchor_lat := 40.7
var _queue: Array[Vector2i] = []
var _last := Vector2i(2147483647, 2147483647)
var indexed_tile_count := 0
var loaded_tile_count: int:
    get:
        return _loaded.size()

func _ready() -> void:
    if target_path != NodePath():
        _target = get_node_or_null(target_path) as Node3D
    _root = Node3D.new()
    _root.name = "LoadedRegions"
    add_child(_root)
    if not FileAccess.file_exists(tile_index_path):
        push_warning("Region index missing: " + tile_index_path)
        return
    var f := FileAccess.open(tile_index_path, FileAccess.READ)
    if f == null:
        return
    var data: Variant = JSON.parse_string(f.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Region index must be a JSON object.")
        return
    _anchor_lon = float(data.get("_anchor_lon", _anchor_lon))
    _anchor_lat = float(data.get("_anchor_lat", _anchor_lat))
    if data.has("_tile_size_m"):
        tile_size_m = maxf(100.0, float(data["_tile_size_m"]))
    for key in data:
        if str(key).begins_with("_"):
            continue
        var parts := str(key).split(",")
        if parts.size() == 2 and typeof(data[key]) == TYPE_DICTIONARY:
            _tiles[Vector2i(int(parts[0]), int(parts[1]))] = data[key]
    indexed_tile_count = _tiles.size()
    print("ZERO MERCY: indexed ", _tiles.size(), " global world tiles.")

func _process(_delta: float) -> void:
    if _target == null or region_scene == null:
        return
    var center := Vector2i(floori(_target.global_position.x / tile_size_m), floori(_target.global_position.z / tile_size_m))
    if center != _last:
        _last = center
        _refresh(center)
    _load_queue()

func _refresh(center: Vector2i) -> void:
    var candidates: Array[Vector2i] = []
    for x in range(center.x - load_radius, center.x + load_radius + 1):
        for z in range(center.y - load_radius, center.y + load_radius + 1):
            var candidate := Vector2i(x, z)
            if _tiles.has(candidate) and not _loaded.has(_key(candidate)) and not _queue.has(candidate):
                candidates.append(candidate)
    candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
    for candidate in candidates:
        _queue.append(candidate)
    for key in _loaded.keys():
        var coord: Vector2i = _loaded[key]["coord"]
        if maxi(abs(coord.x - center.x), abs(coord.y - center.y)) > unload_radius:
            for node in _loaded[key]["nodes"]:
                if is_instance_valid(node):
                    node.queue_free()
            _loaded.erase(key)
    var keep: Array[Vector2i] = []
    for coord in _queue:
        if maxi(abs(coord.x - center.x), abs(coord.y - center.y)) <= load_radius and _tiles.has(coord):
            keep.append(coord)
    _queue = keep

func _load_queue() -> void:
    var done := 0
    while not _queue.is_empty() and done < max_operations_per_frame:
        var coord := _queue.pop_front()
        var key := _key(coord)
        if _loaded.has(key) or not _tiles.has(coord):
            continue
        var entry: Dictionary = _tiles[coord]
        var scene: PackedScene = region_scene
        var scene_path := str(entry.get("scene_path", ""))
        if scene_path != "":
            var resource: Resource = load(scene_path)
            if resource is PackedScene:
                scene = resource as PackedScene
        if scene == null:
            push_warning("ZERO MERCY: no PackedScene configured for tile " + key)
            continue
        var paths: Array = entry.get("geojson_paths", [])
        if paths.is_empty():
            var single := str(entry.get("geojson_path", ""))
            if single != "":
                paths.append(single)
        var nodes: Array[Node3D] = []
        for path_value in paths:
            var instance := scene.instantiate() as Node3D
            if instance == null:
                continue
            if instance.has_method("configure_region"):
                instance.configure_region(
                    str(path_value),
                    float(entry.get("center_lat", 0.0)),
                    float(entry.get("center_lon", 0.0)),
                    str(entry.get("projection", "")) == "global_equirectangular",
                    str(entry.get("dem_metadata_path", "")),
                    str(entry.get("dem_height_path", ""))
                )
            if entry.has("region_size_m"):
                instance.set("region_size_m", float(entry["region_size_m"]))
            _root.add_child(instance)
            instance.position = Vector3(
                float(entry.get("origin_x", coord.x * tile_size_m)),
                0.0,
                float(entry.get("origin_z", coord.y * tile_size_m))
            )
            nodes.append(instance)
        var dem_metadata := str(entry.get("dem_metadata_path", ""))
        var dem_height := str(entry.get("dem_height_path", ""))
        if terrain_scene != null and not dem_metadata.is_empty() and not dem_height.is_empty():
            if FileAccess.file_exists(dem_metadata) and FileAccess.file_exists(dem_height):
                var terrain := terrain_scene.instantiate() as Node3D
                terrain.set("metadata_path", dem_metadata)
                terrain.set("height_path", dem_height)
                _root.add_child(terrain)
                nodes.append(terrain)
                _place_target_on_terrain(terrain)
        if not nodes.is_empty():
            _loaded[key] = {"coord": coord, "nodes": nodes}
            done += 1


func _place_target_on_terrain(terrain: Node3D) -> void:
    if _target == null or not terrain.has_method("sample_elevation"):
        return
    var latitude := _anchor_lat - (_target.global_position.z / 111320.0)
    var longitude := _anchor_lon + (_target.global_position.x / 111320.0)
    var elevation := float(terrain.call("sample_elevation", latitude, longitude))
    if is_finite(elevation):
        var position := _target.global_position
        position.y = maxf(position.y, elevation + 1.5)
        _target.global_position = position

func _key(coord: Vector2i) -> String:
    return str(coord.x) + "," + str(coord.y)
