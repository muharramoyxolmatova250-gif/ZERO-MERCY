extends Node3D
## Loads a georeferenced float32 DEM tile exported by tools/geodata/convert_dem.py.
@export_file("*.json") var metadata_path := "res://data/terrain/tile.json"
@export_file("*.f32") var height_path := "res://data/terrain/tile.f32"
@export var vertical_scale := 1.0
@export var vertical_offset := 0.0
@export var terrain_material: Material
@export var create_collision := true

func _ready() -> void:
	build_from_files()

func build_from_files() -> void:
	if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(height_path):
		push_warning("DEM tile missing. Convert a GeoTIFF with tools/geodata/convert_dem.py.")
		return
	var mf := FileAccess.open(metadata_path, FileAccess.READ)
	if mf == null:
		push_error("Cannot open DEM metadata.")
		return
	var meta: Variant = JSON.parse_string(mf.get_as_text())
	if typeof(meta) != TYPE_DICTIONARY:
		push_error("Invalid DEM metadata JSON.")
		return
	var w := int(meta.get("width", 0))
	var h := int(meta.get("height", 0))
	if w < 2 or h < 2:
		push_error("DEM dimensions must be at least 2x2.")
		return
	var file := FileAccess.open(height_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open DEM binary samples.")
		return
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() != w * h * 4:
		push_error("DEM byte count does not match metadata dimensions.")
		return
	var metres_per_unit := float(meta.get("metres_per_unit", 1.0))
	var width_m := float(meta.get("horizontal_width_m", 4000.0)) / metres_per_unit
	var depth_m := float(meta.get("horizontal_depth_m", 4000.0)) / metres_per_unit
	var origin_x := float(meta.get("origin_x", 0.0)) / metres_per_unit
	var origin_z := float(meta.get("origin_z", 0.0)) / metres_per_unit
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for z in range(h):
		for x in range(w):
			var index := (z * w + x) * 4
			var elevation := bytes.decode_float(index) / metres_per_unit * vertical_scale + vertical_offset
			vertices.append(Vector3((float(x) / float(w - 1) - 0.5) * width_m, elevation,
				(float(z) / float(h - 1) - 0.5) * depth_m))
			uvs.append(Vector2(float(x) / float(w - 1), float(z) / float(h - 1)))
	var indices := PackedInt32Array()
	for z in range(h - 1):
		for x in range(w - 1):
			var a := z * w + x
			var b := a + 1
			var c := a + w
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	mesh = st.commit()
	var instance := MeshInstance3D.new()
	instance.name = "DEM_Terrain"
	instance.mesh = mesh
	instance.position = Vector3(origin_x, 0.0, origin_z)
	if terrain_material != null:
		instance.material_override = terrain_material
	add_child(instance)
	if create_collision:
		var body := StaticBody3D.new()
		body.name = "DEM_Collision"
		body.position = instance.position
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
	print("ZERO MERCY DEM: rendered and placed ", w, "x", h, " samples at ", instance.position)
