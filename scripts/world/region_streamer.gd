extends Node3D
## Regional OSM tile loader. Uses the same local-metre anchor as generated region_tiles.json.
@export var target_path: NodePath
@export_file("*.json") var tile_index_path := "res://data/world/region_tiles.json"
@export var region_scene: PackedScene
@export_range(100.0,100000.0,100.0) var tile_size_m := 4000.0
@export_range(0,5,1) var load_radius := 1
@export_range(1,8,1) var unload_radius := 2
@export_range(1,32,1) var max_operations_per_frame := 1
var _target:Node3D
var _root:Node3D
var _tiles:Dictionary={}
var _loaded:Dictionary={}
var _queue:Array[Vector2i]=[]
var _last:=Vector2i(2147483647,2147483647)
var indexed_tile_count := 0
var loaded_tile_count: int:
	get:
		return _loaded.size()

func _ready()->void:
	if target_path!=NodePath(): _target=get_node_or_null(target_path) as Node3D
	_root=Node3D.new()
	_root.name="LoadedRegions"
	add_child(_root)
	if not FileAccess.file_exists(tile_index_path):
		push_warning("Region index missing: "+tile_index_path)
		return
	var f:=FileAccess.open(tile_index_path,FileAccess.READ)
	if f==null: return
	var data:Variant=JSON.parse_string(f.get_as_text())
	if typeof(data)!=TYPE_DICTIONARY:
		push_error("Region index must be a JSON object.")
		return
	if data.has("_tile_size_m"):
		tile_size_m = maxf(100.0, float(data["_tile_size_m"]))
	for key in data:
		if str(key).begins_with("_"): continue
		var parts:=str(key).split(",")
		if parts.size()==2 and typeof(data[key])==TYPE_DICTIONARY:
			_tiles[Vector2i(int(parts[0]),int(parts[1]))]=data[key]
	indexed_tile_count = _tiles.size()
	print("ZERO MERCY: indexed ",_tiles.size()," region tiles.")

func _process(_delta:float)->void:
	if _target==null or region_scene==null: return
	var center:=Vector2i(floori(_target.global_position.x/tile_size_m),floori(_target.global_position.z/tile_size_m))
	if center!=_last:
		_last=center
		_refresh(center)
	_load_queue()

func _refresh(center:Vector2i)->void:
	var candidates:Array[Vector2i]=[]
	for x in range(center.x-load_radius,center.x+load_radius+1):
		for z in range(center.y-load_radius,center.y+load_radius+1):
			var candidate:=Vector2i(x,z)
			if _tiles.has(candidate) and not _loaded.has(_key(candidate)) and not _queue.has(candidate): candidates.append(candidate)
	candidates.sort_custom(func(a:Vector2i,b:Vector2i)->bool: return a.distance_squared_to(center)<b.distance_squared_to(center))
	for candidate in candidates: _queue.append(candidate)
	for k in _loaded.keys():
		var c:Vector2i=_loaded[k]["coord"]
		if maxi(abs(c.x-center.x),abs(c.y-center.y))>unload_radius:
			var n:Node=_loaded[k]["node"]
			if is_instance_valid(n): n.queue_free()
			_loaded.erase(k)
	var keep:Array[Vector2i]=[]
	for c in _queue:
		if maxi(abs(c.x-center.x),abs(c.y-center.y))<=load_radius and _tiles.has(c): keep.append(c)
	_queue=keep

func _load_queue()->void:
	var done:=0
	while not _queue.is_empty() and done<max_operations_per_frame:
		var c:=_queue.pop_front()
		var k:=_key(c)
		if _loaded.has(k) or not _tiles.has(c): continue
		var e:Dictionary=_tiles[c]
		var scene:=region_scene
		var scene_path:=str(e.get("scene_path",""))
		if scene_path!="":
			var resource=load(scene_path)
			if resource is PackedScene: scene=resource
		if scene == null:
			push_warning("ZERO MERCY: no PackedScene configured for region tile " + k)
			continue
		var instance:=scene.instantiate()
		if instance is Node3D and instance.has_method("configure_region"):
			instance.configure_region(str(e.get("geojson_path","")),float(e.get("center_lat",0.0)),float(e.get("center_lon",0.0)))
		_root.add_child(instance)
		if instance is Node3D:
			instance.position=Vector3(float(e.get("origin_x",c.x*tile_size_m)),0.0,float(e.get("origin_z",c.y*tile_size_m)))
		_loaded[k]={"coord":c,"node":instance}
		done+=1

func _key(c:Vector2i)->String:
	return str(c.x)+","+str(c.y)
