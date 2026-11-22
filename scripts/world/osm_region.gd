extends Node3D
## Converts a regional OSM GeoJSON FeatureCollection into simple local 3D geometry.
## Export GeoJSON from a regional PBF with:
## osmium export region.osm.pbf -o region.geojson
##
## Uses a WGS84 local tangent approximation; keep tiles small to limit distortion.

@export_file("*.geojson") var geojson_path := "res://data/osm/region.geojson"
@export var region_center_lat := 40.78
@export var region_center_lon := 72.34
@export var metres_per_unit := 1.0
@export var road_width_default := 5.0
@export var building_height_default := 8.0
@export_range(100.0, 50000.0, 100.0) var region_size_m := 4000.0
@export var max_features := 100000
var feature_stats: Dictionary = {}
var global_equirectangular := false

var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _ground_material: StandardMaterial3D
var _neon_cyan: StandardMaterial3D
var _neon_magenta: StandardMaterial3D



func configure_region(path: String, center_lat: float, center_lon: float, use_global_equirectangular: bool = false) -> void:
	geojson_path = path
	region_center_lat = center_lat
	region_center_lon = center_lon
	global_equirectangular = use_global_equirectangular

func _ready() -> void:
	_setup_materials()
	_add_ground()
	if not FileAccess.file_exists(geojson_path):
		push_warning("OSM GeoJSON not found. Export a regional PBF with osmium export first.")
		return
	_load_features(geojson_path)


func _setup_materials() -> void:
	_road_material = _material(Color(0.012, 0.02, 0.035), Color(0.0, 0.025, 0.06), 0.35)
	_building_material = _material(Color(0.025, 0.04, 0.065), Color(0.0, 0.08, 0.13), 0.5)
	_water_material = _material(Color(0.005, 0.12, 0.25), Color(0.0, 0.08, 0.22), 1.2)
	_ground_material = _material(Color(0.012, 0.022, 0.035), Color(0.0, 0.025, 0.05), 0.25)
	_neon_cyan = _material(Color(0.0, 0.72, 1.0), Color(0.0, 0.65, 1.0), 2.0)
	_neon_magenta = _material(Color(1.0, 0.04, 0.38), Color(1.0, 0.02, 0.25), 2.0)


func _material(base: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.78
	m.metallic = 0.15
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	return m


func _add_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(region_size_m * metres_per_unit, region_size_m * metres_per_unit)
	var ground := MeshInstance3D.new()
	ground.name = "RegionGround"
	ground.mesh = plane
	ground.position.y = -0.15
	ground.material_override = _ground_material
	add_child(ground)


func _load_features(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open OSM GeoJSON: " + path)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("features"):
		push_error("OSM input is not a GeoJSON FeatureCollection.")
		return

	var counts := {"roads": 0, "buildings": 0, "waterways": 0, "skipped": 0}
	var features: Array = data["features"]
	var limit := mini(features.size(), max_features)
	for i in range(limit):
		var feature: Dictionary = features[i]
		var geometry: Dictionary = feature.get("geometry", {})
		var props: Dictionary = feature.get("properties", {})
		var tags: Dictionary = props.get("tags", props)
		var kind := str(geometry.get("type", ""))
		var coords: Variant = geometry.get("coordinates", [])
		if tags.has("highway"):
			_add_road_geometry(kind, coords, tags)
			counts.roads += 1
		elif tags.has("building"):
			_add_building_geometry(kind, coords, tags)
			counts.buildings += 1
		elif tags.has("waterway"):
			_add_water_geometry(kind, coords)
			counts.waterways += 1
		else:
			counts.skipped += 1
	feature_stats = counts.duplicate(true)
	feature_stats["processed"] = limit
	feature_stats["total"] = features.size()
	print("ZERO MERCY OSM region: ", feature_stats, " / ", features.size(), " input features.")


func _add_road_geometry(kind: String, coords: Variant, tags: Dictionary) -> void:
	var paths: Array = []
	if kind == "LineString":
		paths.append(coords)
	elif kind == "MultiLineString":
		paths = coords
	else:
		return
	var width := road_width_default
	var highway := str(tags.get("highway", ""))
	if highway in ["motorway", "trunk", "primary"]:
		width = 11.0
	elif highway in ["secondary", "tertiary"]:
		width = 7.0
	for path in paths:
		if path is Array:
			_add_strip(path, width, 0.025, _road_material, "Road")
			_add_strip(path, maxf(0.18, width * 0.035), 0.06, _neon_cyan if highway in ["motorway", "trunk", "primary"] else _neon_magenta, "RoadNeon")


func _add_water_geometry(kind: String, coords: Variant) -> void:
	var paths: Array = []
	if kind == "LineString":
		paths.append(coords)
	elif kind == "MultiLineString":
		paths = coords
	else:
		return
	for path in paths:
		if path is Array:
			_add_strip(path, 2.5, 0.045, _water_material, "Waterway")


func _add_strip(coordinates: Array, width: float, y: float, material: Material, node_name: String) -> void:
	if coordinates.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5 * metres_per_unit
	for i in range(coordinates.size() - 1):
		var a := _coordinate_to_local(coordinates[i])
		var b := _coordinate_to_local(coordinates[i + 1])
		var direction := Vector2(b.x - a.x, b.z - a.z)
		if direction.length_squared() < 0.0001:
			continue
		direction = direction.normalized()
		var side := Vector3(-direction.y, 0.0, direction.x) * half
		var a1 := a + side + Vector3.UP * y
		var a2 := a - side + Vector3.UP * y
		var b1 := b + side + Vector3.UP * y
		var b2 := b - side + Vector3.UP * y
		_add_quad(st, a1, b1, b2, a2)
	var mesh := st.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _add_building_geometry(kind: String, coords: Variant, tags: Dictionary) -> void:
	var polygons: Array = []
	if kind == "Polygon":
		polygons.append(coords)
	elif kind == "MultiPolygon":
		polygons = coords
	else:
		return
	var height := building_height_default
	if tags.has("height"):
		height = maxf(2.5, str(tags["height"]).replace("m", "").to_float())
	elif tags.has("building:levels"):
		height = maxf(2.5, str(tags["building:levels"]).to_float() * 3.1)
	for polygon in polygons:
		if polygon is Array and not polygon.is_empty():
			_add_extruded_polygon(polygon, height)


func _ring_to_local(ring: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for coord in ring:
		if coord is Array and coord.size() >= 2:
			var p := _coordinate_to_local(coord)
			points.append(Vector2(p.x, p.z))
	if points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	return points


func _add_extruded_polygon(rings: Array, height: float) -> void:
	if rings.is_empty():
		return
	var outer := _ring_to_local(rings[0])
	if outer.size() < 3:
		return
	var holes: Array[PackedVector2Array] = []
	var all_rings: Array[PackedVector2Array] = [outer]
	for ring_index in range(1, rings.size()):
		var hole := _ring_to_local(rings[ring_index])
		if hole.size() >= 3:
			holes.append(hole)
			all_rings.append(hole)
	var indices := Geometry2D.triangulate_polygon(outer)
	if indices.is_empty():
		push_warning("OSM building polygon could not be triangulated; skipped invalid footprint.")
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := Vector3(outer[indices[i]].x, height, outer[indices[i]].y)
		var b := Vector3(outer[indices[i + 1]].x, height, outer[indices[i + 1]].y)
		var c := Vector3(outer[indices[i + 2]].x, height, outer[indices[i + 2]].y)
		_add_triangle(st, a, b, c)
	for ring in all_rings:
		for i in range(ring.size()):
			var j := (i + 1) % ring.size()
			var a := Vector3(ring[i].x, 0.0, ring[i].y)
			var b := Vector3(ring[j].x, 0.0, ring[j].y)
			var c := Vector3(ring[j].x, height, ring[j].y)
			var d := Vector3(ring[i].x, height, ring[i].y)
			_add_quad(st, a, b, c, d)
	var mesh := st.commit()
	if mesh == null:
		return
	var building := MeshInstance3D.new()
	building.name = "OSM_Building"
	building.mesh = mesh
	building.material_override = _building_material
	add_child(building)
	var body := StaticBody3D.new()
	body.name = "OSM_BuildingCollision"
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(st, a, b, c)
	_add_triangle(st, a, c, d)


func _coordinate_to_local(coord: Array) -> Vector3:
	if coord.size() < 2:
		return Vector3.ZERO
	if global_equirectangular:
		var longitude := float(coord[0])
		while longitude - region_center_lon > 180.0:
			longitude -= 360.0
		while longitude - region_center_lon < -180.0:
			longitude += 360.0
		var x := (longitude - region_center_lon) * 111320.0
		var z := -(float(coord[1]) - region_center_lat) * 111320.0
		return Vector3(x * metres_per_unit, 0.0, z * metres_per_unit)
	var local := EarthCoordinates.lat_lon_to_local(
		float(coord[1]), float(coord[0]), region_center_lat, region_center_lon
	)
	return Vector3(local.x * metres_per_unit, 0.0, local.y * metres_per_unit)
