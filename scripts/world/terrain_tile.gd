extends Node3D
## Renders a float32 DEM tile exported by tools/geodata/convert_dem.py.
@export_file("*.json") var metadata_path := "res://data/terrain/tile.json"
@export_file("*.bin") var height_data_path := "res://data/terrain/tile.f32"
@export_range(0.01, 20.0, 0.01) var vertical_scale := 1.0
@export var build_collision := true

func _ready() -> void:
	_build_terrain()

func _build_terrain() -> void:
	if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(height_data_path):
		push_warning("DEM files missing; convert a GeoTIFF with tools/geodata/convert_dem.py.")
		return
	var meta_file := FileAccess.open(metadata_path, FileAccess.READ)
	var meta: Variant = JSON.parse_string(meta_file.get_as_text())
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("DEM metadata must be a JSON object.")
		return
	var width := int(meta.get("width", 0))
	var height := int(meta.get("height", 0))
	if width < 2 or height < 2:
		push_error("DEM dimensions must be at least 2x2.")
		return
	var bytes := FileAccess.get_file_as_bytes(height_data_path)
	if bytes.size() != width * height * 4:
		push_error("DEM binary size does not match metadata dimensions.")
		return
	var elevations := PackedFloat32Array()
	elevations.resize(width * height)
	for i in range(elevations.size()):
		elevations[i] = bytes.decode_float(i * 4)
	var min_height := float(meta.get("min_elevation_m", 0.0))
	var width_m := float(meta.get("horizontal_width_m", 1000.0))
	var depth_m := float(meta.get("horizontal_depth_m", 1000.0))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for z in range(height):
		for x in range(width):
			var idx := z * width + x
			vertices.append(Vector3((float(x) / (width - 1) - 0.5) * width_m, (elevations[idx] - min_height) * vertical_scale, (float(z) / (height - 1) - 0.5) * depth_m))
			uvs.append(Vector2(float(x) / (width - 1), float(z) / (height - 1)))
	var indices := PackedInt32Array()
	for z in range(height - 1):
		for x in range(width - 1):
			var a := z * width + x
			var b := a + 1
			var c := a + width
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	mesh = surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = "DEM_TerrainMesh"
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.22, 0.19)
	material.roughness = 0.96
	visual.material_override = material
	add_child(visual)
	if build_collision:
		var body := StaticBody3D.new()
		body.name = "DEM_TerrainCollision"
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
	position = Vector3(float(meta.get("origin_x", 0.0)), min_height * vertical_scale, float(meta.get("origin_z", 0.0)))
	print("ZERO MERCY DEM tile loaded: %dx%d." % [width, height])
