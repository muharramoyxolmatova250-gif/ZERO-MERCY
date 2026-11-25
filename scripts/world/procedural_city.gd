extends Node3D
## Seeded cyberpunk district with instanced facade lights to reduce draw calls.
@export_range(2, 12, 1) var blocks_per_side := 5
@export_range(0.05, 1.0, 0.05) var population_density := 0.25
@export_range(0.05, 1.0, 0.05) var traffic_density := 0.15
@export var block_spacing := 52.0
@export var road_width := 14.0
@export var seed_value := 20261122
@export_range(1, 100000000, 1) var settlement_population := 100000
@export var min_building_height := 16.0
@export var max_building_height := 110.0
@export var generate_collision := true
@export var window_step := 3.2
@export var distance_lod_enabled := true
@export_range(100.0, 4000.0, 50.0) var building_visibility_range := 1400.0
@export_range(50.0, 2000.0, 25.0) var detail_visibility_range := 420.0
@export_range(25.0, 1000.0, 25.0) var neon_visibility_range := 220.0

var rng := RandomNumberGenerator.new()
var mats: Array[StandardMaterial3D] = []
var _window_materials: Array[StandardMaterial3D] = []
var _wet_road_material: Material
var _facade_trim_material: StandardMaterial3D
var _glass_facade_material: StandardMaterial3D
var _building_shell_shader: Shader
@export var settlement_id := ""
@export var settlement_display_name := ""

func _ready() -> void:
	rng.seed = seed_value
	_materials()
	_register_settlement_hub()
	_roads_and_blocks()
	_spawn_street_furniture()
	_spawn_city_life()
	_spawn_interactive_props()


func _resolved_settlement_id() -> String:
	return settlement_id if not settlement_id.is_empty() else str(name)


func _resolved_settlement_name() -> String:
	return settlement_display_name if not settlement_display_name.is_empty() else str(name)


func _register_settlement_hub() -> void:
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	if life_sim != null and life_sim.has_method("register_settlement_hub"):
		life_sim.call("register_settlement_hub", _resolved_settlement_id(), _resolved_settlement_name(), settlement_population)


func _materials() -> void:
	for c in [Color(0.018, 0.028, 0.05), Color(0.035, 0.025, 0.065), Color(0.045, 0.055, 0.075), Color(0.065, 0.025, 0.055)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.72
		m.roughness = 0.34
		mats.append(m)
	var asphalt_shader := load("res://shaders/wet_asphalt.gdshader") as Shader
	if asphalt_shader != null:
		var asphalt_shader_material := ShaderMaterial.new()
		asphalt_shader_material.shader = asphalt_shader
		asphalt_shader_material.set_shader_parameter("asphalt_tint", Color(0.012, 0.022, 0.038))
		asphalt_shader_material.set_shader_parameter("wetness", 0.82)
		_wet_road_material = asphalt_shader_material
	else:
		push_warning("Wet asphalt shader missing; using StandardMaterial fallback.")
		var asphalt_fallback := StandardMaterial3D.new()
		asphalt_fallback.albedo_color = Color(0.012, 0.022, 0.038)
		asphalt_fallback.metallic = 0.48
		asphalt_fallback.roughness = 0.16
		asphalt_fallback.clearcoat_enabled = true
		asphalt_fallback.clearcoat = 1.0
		asphalt_fallback.clearcoat_roughness = 0.08
		_wet_road_material = asphalt_fallback
	_facade_trim_material = StandardMaterial3D.new()
	_facade_trim_material.albedo_color = Color(0.035, 0.055, 0.085)
	_facade_trim_material.metallic = 0.88
	_facade_trim_material.roughness = 0.2
	_facade_trim_material.clearcoat_enabled = true
	_facade_trim_material.clearcoat = 0.7
	_building_shell_shader = load("res://shaders/cyberpunk_concrete.gdshader") as Shader
	_glass_facade_material = StandardMaterial3D.new()
	_glass_facade_material.albedo_color = Color(0.018, 0.095, 0.14, 1.0)
	_glass_facade_material.metallic = 0.82
	_glass_facade_material.roughness = 0.12
	_glass_facade_material.clearcoat_enabled = true
	_glass_facade_material.clearcoat = 1.0
	_glass_facade_material.clearcoat_roughness = 0.06
	for c in [Color(0.0, 0.82, 1.0), Color(1.0, 0.08, 0.42), Color(0.95, 0.58, 0.2)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.2
		_window_materials.append(m)

func _roads_and_blocks() -> void:
	var extent := blocks_per_side * block_spacing
	_wet_road_box(Vector3(0, -0.3, 0), Vector3(extent + road_width, 0.5, extent + road_width))
	for i in range(blocks_per_side + 1):
		var p := (float(i) - float(blocks_per_side) * 0.5) * block_spacing
		_wet_road_box(Vector3(p, 0.0, 0), Vector3(road_width, 0.08, extent + road_width))
		_wet_road_box(Vector3(0, 0.0, p), Vector3(extent + road_width, 0.08, road_width))
		_box(Vector3(p, 0.07, 0), Vector3(0.16, 0.035, extent), Color(0.0, 0.7, 0.95), true, false)
		_box(Vector3(0, 0.07, p), Vector3(extent, 0.035, 0.16), Color(1.0, 0.08, 0.38), true, false)
	for x in range(blocks_per_side):
		for z in range(blocks_per_side):
			var center := Vector3((float(x) - float(blocks_per_side - 1) * 0.5) * block_spacing, 0, (float(z) - float(blocks_per_side - 1) * 0.5) * block_spacing)
			_block(center)

func _block(center: Vector3) -> void:
	var count := rng.randi_range(2, 4)
	for _i in range(count):
		var size := Vector3(rng.randf_range(10.0, 17.0), rng.randf_range(min_building_height, max_building_height), rng.randf_range(10.0, 17.0))
		var base := center + Vector3(rng.randf_range(-block_spacing * 0.27, block_spacing * 0.27), 0, rng.randf_range(-block_spacing * 0.27, block_spacing * 0.27))
		_building(base, size)

func _building(base: Vector3, size: Vector3) -> void:
	var body_color: Color = mats[rng.randi_range(0, mats.size() - 1)].albedo_color
	# Hollow visual shell: the front doorway remains physically and visually open.
	_building_visual_shell(base, size, body_color)
	if generate_collision:
		_building_collision_shell(base, size)
	_building_lobby(base, size, _window_materials[rng.randi_range(0, 1)].albedo_color)
	var accent_index := rng.randi_range(0, 1)
	var accent: Color = _window_materials[accent_index].albedo_color
	_box(base + Vector3(0, size.y + 0.12, 0), Vector3(size.x + 0.4, 0.24, size.z + 0.4), accent, true, false)
	_facade_windows_instanced(base, size, accent_index)
	_architectural_facade_details(base, size, accent)
	_glass_facade_panels(base, size)
	_ground_floor_frontage(base, size, accent)
	_roof_detail(base, size, accent)



func _building_visual_shell(base: Vector3, size: Vector3, wall_color: Color) -> void:
	var shell_material: Material
	if _building_shell_shader != null:
		var concrete := ShaderMaterial.new()
		concrete.shader = _building_shell_shader
		concrete.set_shader_parameter("wall_tint", wall_color)
		shell_material = concrete
	else:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = wall_color
		fallback.metallic = 0.12
		fallback.roughness = 0.78
		shell_material = fallback
	var wall := 0.45
	var door_width := minf(2.2, size.x * 0.24)
	var front_z := base.z - size.z * 0.5
	var side_width := maxf(0.5, (size.x - door_width) * 0.5)
	var pieces := [
		[Vector3(base.x - (door_width + side_width) * 0.5, size.y * 0.5, front_z), Vector3(side_width, size.y, wall)],
		[Vector3(base.x + (door_width + side_width) * 0.5, size.y * 0.5, front_z), Vector3(side_width, size.y, wall)],
		[Vector3(base.x, size.y - 1.5, front_z), Vector3(door_width, 3.0, wall)],
		[Vector3(base.x, size.y * 0.5, base.z + size.z * 0.5), Vector3(size.x, size.y, wall)],
		[Vector3(base.x - size.x * 0.5, size.y * 0.5, base.z), Vector3(wall, size.y, size.z)],
		[Vector3(base.x + size.x * 0.5, size.y * 0.5, base.z), Vector3(wall, size.y, size.z)]
	]
	for piece in pieces:
		var wall_mesh := _box(piece[0], piece[1], wall_color, false, false)
		wall_mesh.material_override = shell_material
		wall_mesh.add_to_group("building_shell_visual")
	var roof_mesh := _box(base + Vector3(0.0, size.y, 0.0), Vector3(size.x, wall, size.z), wall_color, false, false)
	roof_mesh.material_override = shell_material
	roof_mesh.add_to_group("building_shell_visual")


func _building_collision_shell(base: Vector3, size: Vector3) -> void:
	var wall := 0.45
	var door_width := minf(2.2, size.x * 0.24)
	var front_z := base.z - size.z * 0.5
	# Left and right front wall segments leave a real doorway in the centre.
	var side_width := maxf(0.5, (size.x - door_width) * 0.5)
	_box(Vector3(base.x - (door_width + side_width) * 0.5, size.y * 0.5, front_z), Vector3(side_width, size.y, wall), Color.BLACK, false, true)
	_box(Vector3(base.x + (door_width + side_width) * 0.5, size.y * 0.5, front_z), Vector3(side_width, size.y, wall), Color.BLACK, false, true)
	_box(Vector3(base.x, size.y - 1.5, front_z), Vector3(door_width, 3.0, wall), Color.BLACK, false, true)
	_box(Vector3(base.x, size.y * 0.5, base.z + size.z * 0.5), Vector3(size.x, size.y, wall), Color.BLACK, false, true)
	_box(Vector3(base.x - size.x * 0.5, size.y * 0.5, base.z), Vector3(wall, size.y, size.z), Color.BLACK, false, true)
	_box(Vector3(base.x + size.x * 0.5, size.y * 0.5, base.z), Vector3(wall, size.y, size.z), Color.BLACK, false, true)
	_box(Vector3(base.x, -0.12, base.z), Vector3(size.x, 0.24, size.z), Color.BLACK, false, true)


func _building_lobby(base: Vector3, size: Vector3, accent: Color) -> void:
	var room_depth := minf(size.z * 0.72, 8.0)
	var room_width := minf(size.x * 0.72, 9.0)
	var lobby_center := Vector3(base.x, 0.0, base.z - size.z * 0.5 + room_depth * 0.5 + 0.55)
	_box(lobby_center + Vector3(0.0, 0.035, 0.0), Vector3(room_width, 0.07, room_depth), Color(0.018, 0.035, 0.055), false, false)
	_box(lobby_center + Vector3(0.0, 1.35, room_depth * 0.5 - 0.35), Vector3(room_width * 0.72, 2.5, 0.16), Color(0.025, 0.055, 0.085), false, false)
	_box(lobby_center + Vector3(0.0, 1.55, room_depth * 0.5 - 0.23), Vector3(room_width * 0.58, 0.12, 0.12), accent, true, false)
	# Reception counter, interactive-looking holographic directory and seating.
	_box(lobby_center + Vector3(0.0, 0.62, -room_depth * 0.08), Vector3(room_width * 0.42, 1.15, 0.72), Color(0.025, 0.04, 0.07), false, false)
	_box(lobby_center + Vector3(0.0, 1.25, -room_depth * 0.08), Vector3(room_width * 0.44, 0.08, 0.78), accent, true, false)
	_box(lobby_center + Vector3(-room_width * 0.27, 1.45, room_depth * 0.12), Vector3(0.08, 1.6, 0.08), accent, true, false)
	_box(lobby_center + Vector3(-room_width * 0.27, 2.15, room_depth * 0.12), Vector3(1.4, 0.8, 0.06), Color(0.0, 0.18, 0.25), true, false)
	for seat_x in [-1.0, 1.0]:
		_box(lobby_center + Vector3(seat_x * room_width * 0.27, 0.42, -room_depth * 0.25), Vector3(1.0, 0.35, 0.75), Color(0.04, 0.055, 0.08), false, false)
	var lobby_light := OmniLight3D.new()
	lobby_light.name = "LobbyNeonLight"
	lobby_light.add_to_group("building_lobby_light")
	lobby_light.position = lobby_center + Vector3(0.0, 2.8, 0.0)
	lobby_light.light_color = accent
	lobby_light.light_energy = 1.1
	lobby_light.omni_range = 10.0
	lobby_light.shadow_enabled = false
	add_child(lobby_light)

func _facade_windows_instanced(base: Vector3, size: Vector3, accent_index: int) -> void:
	var columns := maxi(2, int(size.x / 2.8))
	var rows := mini(24, maxi(1, int(size.y / window_step)))
	var transforms: Array[Array] = [[], [], []]
	for side in [-1.0, 1.0]:
		for row in range(rows):
			for col in range(columns):
				if rng.randf() < 0.22:
					continue
				var x := (float(col) - float(columns - 1) * 0.5) * (size.x / float(columns))
				var y := (float(row) + 0.5) * window_step
				var category := accent_index if rng.randf() > 0.52 else 2
				if rng.randf() < 0.5:
					category = 1 - accent_index
				var pos := base + Vector3(x, y, side * (size.z * 0.5 + 0.035))
				transforms[category].append(Transform3D(Basis(), pos))
	for category in range(3):
		if transforms[category].is_empty():
			continue
		var box := BoxMesh.new()
		box.size = Vector3(0.72, 1.15, 0.07)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = transforms[category].size()
		for i in range(transforms[category].size()):
			mm.set_instance_transform(i, transforms[category][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = _window_materials[category]
		if distance_lod_enabled:
			instance.visibility_range_end = detail_visibility_range * 1.5
			instance.visibility_range_end_margin = 35.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(instance)



func _architectural_facade_details(base: Vector3, size: Vector3, accent: Color) -> void:
	# Repeated metal fins and floor bands add architectural depth without one node per detail.
	var fin_transforms: Array[Transform3D] = []
	var band_transforms: Array[Transform3D] = []
	var fin_count := maxi(3, int(size.x / 3.6))
	for side in [-1.0, 1.0]:
		var facade_z: float = base.z + float(side) * (size.z * 0.5 + 0.16)
		for fin in range(fin_count + 1):
			var x := base.x - size.x * 0.5 + float(fin) * size.x / float(fin_count)
			fin_transforms.append(Transform3D(Basis(), Vector3(x, size.y * 0.5, facade_z)))
		for floor_index in range(1, int(size.y / 3.2)):
			var y := float(floor_index) * 3.2
			band_transforms.append(Transform3D(Basis(), Vector3(base.x, y, facade_z + side * 0.035)))
	_add_facade_multimesh("FacadeVerticalFins", Vector3(0.16, maxf(4.0, size.y - 0.5), 0.28), fin_transforms, _facade_trim_material)
	_add_facade_multimesh("FacadeFloorBands", Vector3(size.x + 0.12, 0.11, 0.34), band_transforms, _facade_trim_material)

	# Four illuminated corner markers provide a readable silhouette at night.
	var corner_transforms: Array[Transform3D] = []
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			corner_transforms.append(Transform3D(Basis(), base + Vector3(side_x * (size.x * 0.5 + 0.09), size.y * 0.5, side_z * (size.z * 0.5 + 0.09))))
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = accent
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.emission_enabled = true
	marker_material.emission = accent
	marker_material.emission_energy_multiplier = 0.8
	_add_facade_multimesh("FacadeCornerNeon", Vector3(0.09, size.y, 0.09), corner_transforms, marker_material)



func _glass_facade_panels(base: Vector3, size: Vector3) -> void:
	# Tinted reflective curtain-wall panels sit between the structural fins.
	var front_back: Array[Transform3D] = []
	var sides: Array[Transform3D] = []
	var bays := maxi(2, int(size.x / 3.4))
	var floors := maxi(1, int(size.y / 3.2))
	for face in [-1.0, 1.0]:
		var z: float = base.z + float(face) * (size.z * 0.5 + 0.012)
		for bay in range(bays):
			var x := base.x - size.x * 0.5 + (float(bay) + 0.5) * size.x / float(bays)
			for floor_index in range(floors):
				var y := (float(floor_index) + 0.5) * 3.2
				front_back.append(Transform3D(Basis(), Vector3(x, y, z)))
	for face in [-1.0, 1.0]:
		var x: float = base.x + float(face) * (size.x * 0.5 + 0.012)
		for bay in range(maxi(2, int(size.z / 3.4))):
			var z := base.z - size.z * 0.5 + (float(bay) + 0.5) * size.z / float(maxi(2, int(size.z / 3.4)))
			for floor_index in range(floors):
				var y := (float(floor_index) + 0.5) * 3.2
				var basis := Basis(Vector3.UP, PI * 0.5)
				sides.append(Transform3D(basis, Vector3(x, y, z)))
	_add_facade_multimesh("ReflectiveGlassFrontBack", Vector3(size.x / float(bays) - 0.42, 2.45, 0.045), front_back, _glass_facade_material)
	_add_facade_multimesh("ReflectiveGlassSides", Vector3(size.z / float(maxi(2, int(size.z / 3.4))) - 0.42, 2.45, 0.045), sides, _glass_facade_material)



func _add_facade_multimesh(label: String, mesh_size: Vector3, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multi_mesh
	instance.material_override = material
	if distance_lod_enabled:
		instance.visibility_range_end = detail_visibility_range * 2.0
		instance.visibility_range_end_margin = 40.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)


func _ground_floor_frontage(base: Vector3, size: Vector3, accent: Color) -> void:
	# A visible entrance, illuminated shopfront and canopy give each tower a street-level identity.
	var front_z := base.z - size.z * 0.5 - 0.055
	var door_width := minf(2.2, size.x * 0.24)
	var door_height := minf(3.1, size.y * 0.28)
	_box(base + Vector3(0.0, door_height * 0.5, -size.z * 0.5 - 0.07),
		Vector3(door_width, door_height, 0.12), Color(0.008, 0.018, 0.032), false, false)
	_box(base + Vector3(0.0, door_height + 0.14, -size.z * 0.5 - 0.1),
		Vector3(door_width + 0.55, 0.18, 0.18), accent, true, false)
	var shop_width := minf(size.x * 0.62, 7.0)
	_box(base + Vector3(-size.x * 0.27, 1.65, -size.z * 0.5 - 0.065),
		Vector3(shop_width * 0.45, 2.25, 0.1), Color(0.015, 0.12, 0.17), true, false)
	_box(base + Vector3(0.0, 3.45, -size.z * 0.5 - 0.16),
		Vector3(minf(size.x * 0.78, 9.0), 0.28, 0.55), accent, true, false)
	_box(base + Vector3(0.0, 0.18, -size.z * 0.5 - 0.32),
		Vector3(minf(size.x * 0.8, 9.0), 0.22, 1.1), Color(0.025, 0.045, 0.065), false, false)

func _roof_detail(base: Vector3, size: Vector3, accent: Color) -> void:
	var roof_y := size.y + 0.8
	var roof_material := _facade_trim_material
	# Raised roof parapet gives the tower a finished architectural silhouette.
	_box(base + Vector3(0, size.y + 0.32, -size.z * 0.5), Vector3(size.x, 0.64, 0.24), Color(0.025, 0.035, 0.055), false, false)
	_box(base + Vector3(0, size.y + 0.32, size.z * 0.5), Vector3(size.x, 0.64, 0.24), Color(0.025, 0.035, 0.055), false, false)
	_box(base + Vector3(-size.x * 0.5, size.y + 0.32, 0), Vector3(0.24, 0.64, size.z), Color(0.025, 0.035, 0.055), false, false)
	_box(base + Vector3(size.x * 0.5, size.y + 0.32, 0), Vector3(0.24, 0.64, size.z), Color(0.025, 0.035, 0.055), false, false)

	# Central mechanical penthouse, exhaust stacks and antenna mast.
	_box(base + Vector3(0, roof_y, 0), Vector3(size.x * 0.3, 1.4, size.z * 0.3), Color(0.025, 0.035, 0.055), false, false)
	_box(base + Vector3(0, roof_y + 0.8, 0), Vector3(0.18, 1.6, 0.18), accent, true, false)
	var exhaust_positions: Array[Transform3D] = []
	var equipment_positions: Array[Transform3D] = []
	var solar_positions: Array[Transform3D] = []
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			exhaust_positions.append(Transform3D(Basis(), base + Vector3(side_x * size.x * 0.3, size.y + 1.25, side_z * size.z * 0.3)))
	for unit in range(3):
		var x := (float(unit) - 1.0) * size.x * 0.22
		equipment_positions.append(Transform3D(Basis(), base + Vector3(x, size.y + 0.65, size.z * 0.28)))
	for panel in range(3):
		var x := (float(panel) - 1.0) * size.x * 0.2
		var panel_basis := Basis(Vector3.RIGHT, deg_to_rad(-12.0))
		solar_positions.append(Transform3D(panel_basis, base + Vector3(x, size.y + 0.92, -size.z * 0.28)))
	var exhaust_mesh := CylinderMesh.new()
	exhaust_mesh.top_radius = 0.18
	exhaust_mesh.bottom_radius = 0.24
	exhaust_mesh.height = 1.1
	_add_roof_multimesh("RoofExhaustStacks", exhaust_mesh, exhaust_positions, roof_material)
	var equipment_mesh := BoxMesh.new()
	equipment_mesh.size = Vector3(1.7, 1.1, 1.25)
	_add_roof_multimesh("RoofHVACUnits", equipment_mesh, equipment_positions, roof_material)
	var solar_mesh := BoxMesh.new()
	solar_mesh.size = Vector3(maxf(1.4, size.x * 0.16), 0.12, maxf(1.2, size.z * 0.22))
	_add_roof_multimesh("RoofSolarPanels", solar_mesh, solar_positions, _glass_facade_material)


func _add_roof_multimesh(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multi_mesh
	instance.material_override = material
	if distance_lod_enabled:
		instance.visibility_range_end = detail_visibility_range * 2.0
		instance.visibility_range_end_margin = 40.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)


func _wet_road_box(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var road := _box(pos, size, Color(0.012, 0.022, 0.038), false, false)
	road.material_override = _wet_road_material
	return road


func _box(pos: Vector3, size: Vector3, color: Color, glow: bool, collision: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72 if not glow else 0.28
	material.roughness = 0.32 if not glow else 0.24
	material.clearcoat_enabled = not glow
	material.clearcoat = 0.35 if not glow else 0.0
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	instance.material_override = material
	instance.position = pos
	if distance_lod_enabled:
		var largest_dimension := maxf(size.x, maxf(size.y, size.z))
		if glow or largest_dimension < 1.5:
			instance.visibility_range_end = neon_visibility_range if glow else detail_visibility_range
		elif largest_dimension < 8.0:
			instance.visibility_range_end = detail_visibility_range
		else:
			instance.visibility_range_end = building_visibility_range
		instance.visibility_range_end_margin = 30.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		add_child(body)
	return instance


func _spawn_street_furniture() -> void:
	# Cyberpunk street lighting and visible pedestrian crossings at selected junctions.
	var extent := blocks_per_side * block_spacing
	var first := -float(blocks_per_side) * block_spacing * 0.5
	for ix in range(blocks_per_side + 1):
		for iz in range(blocks_per_side + 1):
			if ix % 2 != 0 and iz % 2 != 0:
				continue
			var x := first + float(ix) * block_spacing
			var z := first + float(iz) * block_spacing
			_crosswalk(Vector3(x, 0.11, z), true)
			if (ix + iz) % 2 == 0:
				_street_light(Vector3(x + road_width * 0.62, 0.0, z + road_width * 0.62))
				_street_light(Vector3(x - road_width * 0.62, 0.0, z - road_width * 0.62))
	_spawn_traffic_signals()

func _spawn_traffic_signals() -> void:
	var signal_script := load("res://scripts/world/cyberpunk_traffic_signal.gd")
	if signal_script == null:
		push_warning("Traffic signal script is missing; intersections remain uncontrolled.")
		return
	var first := -float(blocks_per_side) * block_spacing * 0.5
	for ix in range(blocks_per_side + 1):
		for iz in range(blocks_per_side + 1):
			if (ix + iz) % 2 != 0:
				continue
			var traffic_signal := Node3D.new()
			traffic_signal.name = "TrafficSignal_%d_%d" % [ix, iz]
			traffic_signal.set_script(signal_script)
			traffic_signal.set("phase_offset", float((ix * 3 + iz * 5) % 10) / 10.0)
			traffic_signal.position = Vector3(first + float(ix) * block_spacing + road_width * 0.58, 0.0, first + float(iz) * block_spacing + road_width * 0.58)
			add_child(traffic_signal)

func _crosswalk(center: Vector3, along_x: bool) -> void:
	for stripe in range(6):
		var offset := (float(stripe) - 2.5) * 1.15
		var size := Vector3(0.65, 0.035, 5.2) if along_x else Vector3(5.2, 0.035, 0.65)
		var position := center + (Vector3(offset, 0.0, road_width * 0.5 + 2.0) if along_x else Vector3(road_width * 0.5 + 2.0, 0.0, offset))
		_box(position, size, Color(0.18, 0.72, 0.88), true, false)

func _street_light(base: Vector3) -> void:
	_box(base + Vector3(0.0, 4.0, 0.0), Vector3(0.16, 8.0, 0.16), Color(0.035, 0.055, 0.075), false, false)
	_box(base + Vector3(0.0, 8.0, 0.0), Vector3(1.15, 0.12, 0.22), Color(0.0, 0.72, 1.0), true, false)
	var lamp := OmniLight3D.new()
	lamp.position = base + Vector3(0.0, 7.7, 0.0)
	lamp.light_color = Color(0.0, 0.58, 1.0)
	lamp.light_energy = 1.25
	lamp.omni_range = 13.0
	lamp.shadow_enabled = false
	add_child(lamp)

func _spawn_city_life() -> void:
	var citizen_script := load("res://scripts/world/city_citizen.gd")
	var traffic_script := load("res://scripts/world/city_traffic.gd")
	var half := blocks_per_side * block_spacing * 0.5
	var inset := road_width * 0.5 + 2.0
	var citizen_count := mini(240, maxi(6, int(round(float(blocks_per_side * 24) * population_density))))
	var life_sim := get_tree().get_first_node_in_group("world_life_sim")
	for i in range(citizen_count):
		var citizen := Node3D.new()
		citizen.set_script(citizen_script)
		if life_sim != null:
			var claimed_id := str(life_sim.call("claim_resident_id", _resolved_settlement_id()))
			if not claimed_id.is_empty():
				citizen.set("citizen_id", claimed_id)
		citizen.set("city_id", _resolved_settlement_id())
		citizen.add_to_group("city_citizen")
		var lane := (float(i % blocks_per_side) - float(blocks_per_side - 1) * 0.5) * block_spacing
		var side := -1.0 if i % 2 == 0 else 1.0
		citizen.set("route", PackedVector3Array([
			Vector3(lane - 8.0, 0, side * (half - inset)),
			Vector3(lane + 8.0, 0, side * (half - inset)),
			Vector3(lane + 8.0, 0, side * (half - inset - 10.0)),
			Vector3(lane - 8.0, 0, side * (half - inset - 10.0))
		]))
		citizen.set("walk_speed", rng.randf_range(0.8, 1.6))
		citizen.position = Vector3(lane - 8.0, 0, side * (half - inset))
		add_child(citizen)
	var traffic_count := maxi(3, int(round(float(blocks_per_side * 5) * traffic_density)))
	for i in range(traffic_count):
		var car := Node3D.new()
		car.set_script(traffic_script)
		car.add_to_group("city_traffic")
		var offset := (float(i % 12) - 5.5) * 2.6 + float(i / 12) * 1.1
		var route := PackedVector3Array([
			Vector3(-half, 0, offset),
			Vector3(half, 0, offset),
			Vector3(half, 0, offset + 5.0),
			Vector3(-half, 0, offset + 5.0)
		])
		car.set("route", route)
		car.set("speed", rng.randf_range(7.0, 12.0))
		car.set("vehicle_color", [Color(0.02,0.12,0.2), Color(0.12,0.025,0.09), Color(0.08,0.1,0.14), Color(0.16,0.09,0.025)][i % 4])
		car.position = route[0]
		add_child(car)

func _spawn_interactive_props() -> void:
	var prop_script := load("res://scripts/world/world_pickup.gd")
	var props := [
		[Vector3(-9.0, 0.65, -18.0), "Neon energy drink", Color(0.0, 0.75, 1.0)],
		[Vector3(8.0, 0.55, -24.0), "Holo data tablet", Color(1.0, 0.12, 0.42)],
		[Vector3(14.0, 0.45, 12.0), "Cybernetic component", Color(0.95, 0.58, 0.2)],
		[Vector3(-16.0, 0.5, 9.0), "Smart device", Color(0.25, 0.95, 0.72)]
	]
	for entry in props:
		var item := StaticBody3D.new()
		item.set_script(prop_script)
		item.set("display_name", entry[1])
		item.set("glow_color", entry[2])
		item.position = entry[0]
		add_child(item)
