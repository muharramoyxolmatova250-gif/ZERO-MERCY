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
	var citizen_phones := _count_named_nodes(city, "Phone")
	if citizen_phones < citizens:
		_fail("City citizens are missing personal phones: " + str(citizen_phones))
		return
	print("PASS Stage 3: every spawned citizen has a personal cyberpunk phone prop.")
	var first_citizen := city.get_tree().get_first_node_in_group("city_citizen") as Node3D
	var first_car := city.get_tree().get_first_node_in_group("city_traffic") as Node3D
	var citizen_start := first_citizen.position
	var car_start := first_car.position
	await create_timer(1.25).timeout
	if first_citizen.position.distance_to(citizen_start) < 0.05:
		_fail("Pedestrian movement did not advance.")
		return
	if first_car.position.distance_to(car_start) < 0.05:
		_fail("Electric traffic movement did not advance.")
		return
	print("PASS Stage 3: pedestrian and electric traffic movement advanced.")
	var street_lights := _count_nodes_of_type(city, OmniLight3D)
	if street_lights < 4:
		_fail("Cyberpunk street lighting missing: " + str(street_lights))
		return
	print("PASS Stage 3: ", street_lights, " street lights generated at district junctions.")
	var city_doors := _count_nodes_of_type(city, StaticBody3D)
	if city_doors < 20:
		_fail("Procedural city building collision/frontage count too low: " + str(city_doors))
		return
	print("PASS Stage 3: building entrances and illuminated street-level frontage generated.")
	var lobby_lights := _count_named_nodes(city, "LobbyNeonLight")
	if lobby_lights < 10:
		_fail("Enterable building lobbies are missing: " + str(lobby_lights))
		return
	print("PASS Stage 3: ", lobby_lights, " building interiors/lobbies generated with neon lighting.")
	var overview := load("res://scenes/world/earth_overview.tscn")
	if overview == null:
		_fail("Earth overview scene failed to load.")
		return
	print("PASS Stage 2: explorable Earth overview scene loads.")

	# WGS84 coordinate round-trips, including the antimeridian.
	var origin_geo := Vector2(41.3111, 69.2797)
	var nearby_geo := Vector2(41.3150, 69.2860)
	var local_xy := EarthCoordinates.lat_lon_to_local(nearby_geo.x, nearby_geo.y, origin_geo.x, origin_geo.y)
	var restored_geo := EarthCoordinates.local_to_lat_lon(local_xy, origin_geo.x, origin_geo.y)
	if absf(restored_geo.x - nearby_geo.x) > 0.00001 or absf(restored_geo.y - nearby_geo.y) > 0.00001:
		_fail("WGS84 local coordinate round-trip exceeded tolerance: " + str(restored_geo))
		return
	var dateline_xy := EarthCoordinates.lat_lon_to_local(10.0, -179.9, 10.0, 179.9)
	if dateline_xy.x < 0.0 or dateline_xy.x > 30000.0:
		_fail("Antimeridian local projection selected the long route: " + str(dateline_xy))
		return
	var ecef := EarthCoordinates.lat_lon_to_ecef(nearby_geo.x, nearby_geo.y, 125.0)
	var restored_ecef := EarthCoordinates.ecef_to_lat_lon(ecef)
	if absf(restored_ecef.x - nearby_geo.x) > 0.0001 or absf(restored_ecef.y - nearby_geo.y) > 0.0001:
		_fail("WGS84 ECEF round-trip exceeded tolerance: " + str(restored_ecef))
		return
	print("PASS Stage 2: WGS84 ECEF/local transforms and antimeridian handling.")
	# Import a tiny OSM GeoJSON fixture and verify roads, buildings and waterways become geometry.
	var osm_region := Node3D.new()
	osm_region.set_script(load("res://scripts/world/osm_region.gd"))
	osm_region.set("geojson_path", "res://tests/fixtures/osm_region_smoke.geojson")
	osm_region.set("region_center_lat", 41.0)
	osm_region.set("region_center_lon", 69.0)
	osm_region.set("region_size_m", 1000.0)
	root.add_child(osm_region)
	await process_frame
	var osm_roads := _count_named_nodes(osm_region, "Road")
	var osm_buildings := _count_named_nodes(osm_region, "OSM_Building")
	var osm_water := _count_named_nodes(osm_region, "Waterway")
	if osm_roads < 1 or osm_buildings < 1 or osm_water < 1:
		_fail("OSM fixture import missing geometry: roads=" + str(osm_roads) + ", buildings=" + str(osm_buildings) + ", water=" + str(osm_water))
		return
	if int(osm_region.get("feature_stats").get("processed", 0)) != 3:
		_fail("OSM feature accounting did not process all fixture features.")
		return
	print("PASS Stage 2: WGS84 OSM roads, building footprints and waterways imported.")


	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		_fail("Main gameplay scene failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.call("_unhandled_input", _map_key_event())
	await process_frame
	if main.get_node_or_null("EarthMapOverview") == null:
		_fail("M key did not open the Earth map from gameplay.")
		return
	print("PASS Stage 2: M key opens the Earth overview from gameplay.")
	main.queue_free()

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

func _count_named_nodes(node: Node, wanted_name: String) -> int:
	var total := 1 if node.name == wanted_name else 0
	for child in node.get_children():
		total += _count_named_nodes(child, wanted_name)
	return total

func _count_nodes_of_type(node: Node, type: Variant) -> int:
	var total := 1 if is_instance_of(node, type) else 0
	for child in node.get_children():
		total += _count_nodes_of_type(child, type)
	return total

func _count_meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _count_meshes(child)
	return total

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _map_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	return event
