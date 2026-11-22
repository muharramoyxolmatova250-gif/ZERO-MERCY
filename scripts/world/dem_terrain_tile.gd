extends Node3D
## Renders a compact float32 DEM tile exported by tools/geodata/convert_dem.py.
@export_file("*.json") var metadata_path := "res://data/terrain/tile.json"
@export_file("*.f32") var height_path := "res://data/terrain/tile.f32"
@export var horizontal_size := Vector2(4000.0, 4000.0)
@export var vertical_scale := 1.0
@export var vertical_offset := 0.0
@export var terrain_material: Material

func _ready() -> void:
    build_from_files()

func build_from_files() -> void:
    if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(height_path):
        push_warning("DEM tile missing. Convert a GeoTIFF with tools/geodata/convert_dem.py.")
        return
    var mf := FileAccess.open(metadata_path, FileAccess.READ)
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
    var bytes := file.get_buffer(file.get_length())
    if bytes.size() != w * h * 4:
        push_error("DEM byte count does not match metadata dimensions.")
        return
    var vertices := PackedVector3Array()
    var uvs := PackedVector2Array()
    for z in range(h):
        for x in range(w):
            var index := (z * w + x) * 4
            var elevation := bytes.decode_float(index) * vertical_scale + vertical_offset
            vertices.append(Vector3((float(x) / float(w - 1) - 0.5) * horizontal_size.x,
                elevation, (float(z) / float(h - 1) - 0.5) * horizontal_size.y))
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
    var instance := MeshInstance3D.new()
    instance.name = "DEM_Terrain"
    instance.mesh = mesh
    if terrain_material != null:
        instance.material_override = terrain_material
    add_child(instance)
    print("ZERO MERCY DEM: rendered ", w, "x", h, " elevation samples.")
