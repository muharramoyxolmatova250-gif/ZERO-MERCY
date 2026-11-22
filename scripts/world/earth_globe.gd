extends Node3D
## Builds a lightweight 3D globe from Natural Earth country GeoJSON.
## Download data first with: python tools/geodata/download_natural_earth.py --scale 110m

@export_file("*.geojson") var geojson_path: String = "res://data/geodata/world-50m.geojson"
@export_range(10.0, 1000.0, 1.0) var globe_radius: float = 100.0
@export var draw_country_borders: bool = true

const LAND_HEIGHT := 0.28
const BORDER_HEIGHT := 0.42

var _land_material: StandardMaterial3D
var _border_material: StandardMaterial3D
var _inland_water_material: StandardMaterial3D


func _ready() -> void:
	_setup_materials()
	_add_ocean()
	if not FileAccess.file_exists(geojson_path):
		var fallback := "res://data/geodata/world-110m.geojson"
		if FileAccess.file_exists(fallback):
			geojson_path = fallback
		else:
			push_warning("Earth GeoJSON missing. Run tools/geodata/download_natural_earth.py --scale all first.")
			return
	_load_geojson(geojson_path)


func _setup_materials() -> void:
	_land_material = StandardMaterial3D.new()
	_land_material.albedo_color = Color(0.035, 0.19, 0.18)
	_land_material.metallic = 0.42
	_land_material.roughness = 0.48
	_land_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_border_material = StandardMaterial3D.new()
	_border_material.albedo_color = Color(0.05, 0.95, 0.82)
	_border_material.emission_enabled = true
	_border_material.emission = Color(0.02, 0.75, 0.62)
	_border_material.emission_energy_multiplier = 1.4

	_inland_water_material = StandardMaterial3D.new()
	_inland_water_material.albedo_color = Color(0.004, 0.025, 0.055)
	_inland_water_material.metallic = 0.58
	_inland_water_material.roughness = 0.3
	_inland_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _add_ocean() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = globe_radius
	sphere.height = globe_radius * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.006, 0.018, 0.045)
	material.metallic = 0.72
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = Color(0.002, 0.012, 0.035)
	ocean.material_override = material
	add_child(ocean)


func _load_geojson(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open Earth GeoJSON: " + path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("features"):
		push_error("Invalid GeoJSON FeatureCollection: " + path)
		return

	var country_count := 0
	for feature in parsed["features"]:
		if typeof(feature) != TYPE_DICTIONARY:
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var properties: Dictionary = feature.get("properties", {})
		var display_name := str(properties.get("ADMIN", properties.get("NAME", "Unknown")))
		var kind := str(geometry.get("type", ""))
		var coordinates: Variant = geometry.get("coordinates", [])
		if kind == "Polygon":
			_add_polygon(coordinates, display_name)
		elif kind == "MultiPolygon":
			for polygon in coordinates:
				_add_polygon(polygon, display_name)
		country_count += 1
	print("ZERO MERCY Earth: loaded ", country_count, " country/map-unit features.")


func _add_polygon(rings: Array, country_name: String) -> void:
	if rings.is_empty():
		return
	var exterior := _ring_to_points(rings[0])
	if exterior.size() < 3:
		return
	_add_surface_polygon(exterior, country_name, _land_material, LAND_HEIGHT, true)

	# GeoJSON Polygon rings after the first are interior holes (lakes and enclaves).
	# Render them as ocean-coloured patches slightly above the land surface so
	# large inland water bodies are not incorrectly filled with land.
	for ring_index in range(1, rings.size()):
		var hole := _ring_to_points(rings[ring_index])
		if hole.size() >= 3:
			_add_surface_polygon(hole, country_name + "_Water_" + str(ring_index), _inland_water_material, LAND_HEIGHT + 0.012, draw_country_borders)


func _ring_to_points(ring: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var previous_lon := 0.0
	var has_previous := false
	for coordinate in ring:
		if coordinate is Array and coordinate.size() >= 2:
			var longitude := float(coordinate[0])
			# Unwrap antimeridian-crossing rings before planar triangulation.
			if has_previous:
				while longitude - previous_lon > 180.0:
					longitude -= 360.0
				while longitude - previous_lon < -180.0:
					longitude += 360.0
			points.append(Vector2(longitude, float(coordinate[1])))
			previous_lon = longitude
			has_previous = true
	if points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	return points


func _add_surface_polygon(points: PackedVector2Array, surface_name: String, material: Material, height: float, add_border: bool) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var vertices := PackedVector3Array()
	for point in points:
		vertices.append(_lat_lon_to_sphere(point.y, point.x, globe_radius + height))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		if (b - a).cross(c - a).dot((a + b + c) / 3.0) < 0.0:
			var swap := b
			b = c
			c = swap
		st.set_normal(a.normalized())
		st.add_vertex(a)
		st.set_normal(b.normalized())
		st.add_vertex(b)
		st.set_normal(c.normalized())
		st.add_vertex(c)
	var mesh := st.commit()
	if mesh == null:
		return
	var land := MeshInstance3D.new()
	land.name = surface_name.validate_node_name()
	land.mesh = mesh
	land.material_override = material
	add_child(land)

	if add_border:
		_add_border(points, surface_name)


func _add_border(points: PackedVector2Array, country_name: String) -> void:
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _border_material)
	for point in points:
		line.surface_add_vertex(_lat_lon_to_sphere(point.y, point.x, globe_radius + BORDER_HEIGHT))
	line.surface_add_vertex(_lat_lon_to_sphere(points[0].y, points[0].x, globe_radius + BORDER_HEIGHT))
	line.surface_end()
	var border := MeshInstance3D.new()
	border.name = country_name.validate_node_name() + "_Border"
	border.mesh = line
	add_child(border)


func _lat_lon_to_sphere(latitude: float, longitude: float, radius: float) -> Vector3:
	var lat := deg_to_rad(latitude)
	var lon := deg_to_rad(longitude)
	var x := -radius * cos(lat) * cos(lon)
	var y := radius * sin(lat)
	var z := radius * cos(lat) * sin(lon)
	return Vector3(x, y, z)
