extends Node3D
## Converts a regional OSM GeoJSON FeatureCollection into simple local 3D geometry.
## Export GeoJSON from a regional PBF with:
## osmium export region.osm.pbf -o region.geojson
##
## This is a first-pass local tangent/equirectangular preview, not a global projection.
## Keep each region small (e.g. a few kilometres across) to limit distortion.

@export_file("*.geojson") var geojson_path := "res://data/osm/region.geojson"
@export var region_center_lat := 40.78
@export var region_center_lon := 72.34
@export var metres_per_unit := 1.0
@export var road_width_default := 5.0
@export var building_height_default := 8.0
@export var max_features := 100000

var _road_material: StandardMaterial3D
var _building_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _ground_material: StandardMaterial3D



func configure_region(path: String, center_lat: float, center_lon: float) -> void:
	geojson_path = path
	region_center_lat = center_lat
	region_center_lon = center_lon

func _ready() -> void:
	_setup_materials()
	_add_ground()
	if not FileAccess.file_exists(geojson_path):
		push_warning("OSM GeoJSON not found. Export a regional PBF with osmium export first.")
		return
	_load_features(geojson_path)


func _setup_materials() -> void:
	_road_material = _material(Color(0.035, 0.055, 0.075), Color(0.015, 0.08, 0.12), 0.65)
	_building_material = _material(Color(0.12, 0.16, 0.20), Color(0.02, 0.16, 0.19), 0.25)
	_water_material = _material(Color(0.015, 0.22, 0.38), Color(0.01, 0.12, 0.3), 0.9)
	_ground_material = _material(Color(0.035, 0.09, 0.075), Color(0.005, 0.025, 0.02), 0.15)


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
	plane.size = Vector2(12000.0, 12000.0)
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
	print("ZERO MERCY OSM region: ", counts, " / ", features.size(), " input features.")


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
			_add_extruded_polygon(polygon[0], height)


func _add_extruded_polygon(ring: Array, height: float) -> void:
	var points := PackedVector2Array()
	for coord in ring:
		if coord is Array and coord.size() >= 2:
			var p := _coordinate_to_local(coord)
			points.append(Vector2(p.x, p.z))
	if points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	if points.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a := Vector3(points[indices[i]].x, height, points[indices[i]].y)
		var b := Vector3(points[indices[i + 1]].x, height, points[indices[i + 1]].y)
		var c := Vector3(points[indices[i + 2]].x, height, points[indices[i + 2]].y)
		_add_triangle(st, a, b, c)
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		var a := Vector3(points[i].x, 0.0, points[i].y)
		var b := Vector3(points[j].x, 0.0, points[j].y)
		var c := Vector3(points[j].x, height, points[j].y)
		var d := Vector3(points[i].x, height, points[i].y)
		_add_quad(st, a, b, c, d)
	var mesh := st.commit()
	if mesh == null:
		return
	var building := MeshInstance3D.new()
	building.name = "OSM_Building"
	building.mesh = mesh
	building.material_override = _building_material
	add_child(building)


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
	var lon := float(coord[0])
	var lat := float(coord[1])
	var metres_per_degree_lat := 111320.0
	var metres_per_degree_lon := 111320.0 * cos(deg_to_rad(region_center_lat))
	var x := (lon - region_center_lon) * metres_per_degree_lon * metres_per_unit
	var z := -(lat - region_center_lat) * metres_per_degree_lat * metres_per_unit
	return Vector3(x, 0.0, z)
