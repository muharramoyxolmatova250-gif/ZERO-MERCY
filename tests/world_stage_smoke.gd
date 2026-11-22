extends SceneTree
## Headless smoke tests for Stage 2 Earth geometry/DEM and Stage 3 city generation.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var city_scene: PackedScene = load("res://scenes/world/cyberpunk_district.tscn")
	if city_scene == null:
		_fail("Cyberpunk district scene failed to load.")
		return
	var city := city_scene.instantiate()
	root.add_child(city)
	await process_frame
	var city_meshes := _count_meshes(city)
	if city_meshes < 100:
		_fail("Cyberpunk district generated too few meshes: " + str(city_meshes))
		return
	print("PASS Stage 3: cyberpunk district generated ", city_meshes, " mesh instances.")
	var citizens := city.get_tree().get_nodes_in_group("city_citizen").size()
	var traffic := city.get_tree().get_nodes_in_group("city_traffic").size()
	if citizens < 8 or traffic < 4:
		_fail("City life missing: citizens=" + str(citizens) + ", traffic=" + str(traffic))
		return
	print("PASS Stage 3: ", citizens, " pedestrians and ", traffic, " electric vehicles spawned.")
	var overview := load("res://scenes/world/earth_overview.tscn")
	if overview == null:
		_fail("Earth overview scene failed to load.")
		return
	print("PASS Stage 2: explorable Earth overview scene loads.")

	var globe_scene: PackedScene = load("res://scenes/world/earth_globe.tscn")
	if globe_scene == null:
		_fail("Earth globe scene failed to load.")
		return
	var globe := globe_scene.instantiate()
	globe.set("geojson_path", "res://tests/fixtures/earth_smoke.geojson")
	root.add_child(globe)
	await process_frame
	var globe_meshes := _count_meshes(globe)
	if globe_meshes < 3:
		_fail("Earth globe did not render ocean, land and border meshes: " + str(globe_meshes))
		return
	print("PASS Stage 2: Earth globe generated ", globe_meshes, " mesh instances.")

	var metadata_path := "user://zero_mercy_dem_smoke.json"
	var heights_path := "user://zero_mercy_dem_smoke.f32"
	var metadata := {
		"width": 3, "height": 3, "horizontal_width_m": 100.0,
		"horizontal_depth_m": 100.0, "origin_x": 250.0, "origin_z": -125.0,
		"metres_per_unit": 1.0
	}
	var meta_file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if meta_file == null:
		_fail("Could not create DEM smoke metadata.")
		return
	meta_file.store_string(JSON.stringify(metadata))
	meta_file.close()
	var height_file := FileAccess.open(heights_path, FileAccess.WRITE)
	if height_file == null:
		_fail("Could not create DEM smoke samples.")
		return
	for i in range(9):
		height_file.store_float(float(i * 10))
	height_file.close()

	var terrain := Node3D.new()
	terrain.set_script(load("res://scripts/world/dem_terrain_tile.gd"))
	terrain.set("metadata_path", metadata_path)
	terrain.set("height_path", heights_path)
	terrain.set("create_collision", true)
	root.add_child(terrain)
	await process_frame
	if terrain.get_node_or_null("DEM_Terrain") == null:
		_fail("DEM terrain mesh was not generated.")
		return
	if terrain.get_node_or_null("DEM_Collision") == null:
		_fail("DEM collision shape was not generated.")
		return
	print("PASS Stage 2: DEM terrain mesh and collision generated.")
	print("WORLD STAGE SMOKE TESTS PASSED.")
	quit(0)

func _count_meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _count_meshes(child)
	return total

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
