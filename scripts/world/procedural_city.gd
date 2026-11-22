extends Node3D
## Seeded cyberpunk district with instanced facade lights to reduce draw calls.
@export_range(2, 12, 1) var blocks_per_side := 5
@export var block_spacing := 52.0
@export var road_width := 14.0
@export var seed_value := 20261122
@export var min_building_height := 16.0
@export var max_building_height := 110.0
@export var generate_collision := true
@export var window_step := 3.2

var rng := RandomNumberGenerator.new()
var mats: Array[StandardMaterial3D] = []
var _window_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	rng.seed = seed_value
	_materials()
	_roads_and_blocks()
	_spawn_street_furniture()
	_spawn_city_life()

func _materials() -> void:
	for c in [Color(0.018, 0.028, 0.05), Color(0.035, 0.025, 0.065), Color(0.045, 0.055, 0.075), Color(0.065, 0.025, 0.055)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.72
		m.roughness = 0.34
		mats.append(m)
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
	_box(Vector3(0, -0.3, 0), Vector3(extent + road_width, 0.5, extent + road_width), Color(0.012, 0.018, 0.028), false, false)
	for i in range(blocks_per_side + 1):
		var p := (float(i) - float(blocks_per_side) * 0.5) * block_spacing
		_box(Vector3(p, 0.0, 0), Vector3(road_width, 0.08, extent + road_width), Color(0.02, 0.028, 0.045), false, false)
		_box(Vector3(0, 0.0, p), Vector3(extent + road_width, 0.08, road_width), Color(0.02, 0.028, 0.045), false, false)
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
	# Keep the visual tower shell, but build collision as separate wall segments so the lobby entrance is traversable.
	_box(base + Vector3(0, size.y * 0.5, 0), size, body_color, false, false)
	if generate_collision:
		_building_collision_shell(base, size)
	_building_lobby(base, size, _window_materials[rng.randi_range(0, 1)].albedo_color)
	var accent_index := rng.randi_range(0, 1)
	var accent: Color = _window_materials[accent_index].albedo_color
	_box(base + Vector3(0, size.y + 0.12, 0), Vector3(size.x + 0.4, 0.24, size.z + 0.4), accent, true, false)
	_facade_windows_instanced(base, size, accent_index)
	_ground_floor_frontage(base, size, accent)
	_roof_detail(base, size, accent)


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
	_box(base + Vector3(0, roof_y, 0), Vector3(size.x * 0.22, 1.4, size.z * 0.22), Color(0.025, 0.035, 0.055), false, false)
	_box(base + Vector3(0, roof_y + 0.8, 0), Vector3(0.18, 1.6, 0.18), accent, true, false)
	if rng.randf() > 0.5:
		_box(base + Vector3(size.x * 0.3, roof_y + 0.35, 0), Vector3(1.4, 0.6, 1.4), Color(0.07, 0.09, 0.12), false, false)

func _box(pos: Vector3, size: Vector3, color: Color, glow: bool, collision: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.62
	material.roughness = 0.4
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	instance.material_override = material
	instance.position = pos
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
	for i in range(mini(12, blocks_per_side * 2)):
		var citizen := Node3D.new()
		citizen.set_script(citizen_script)
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
	for i in range(4):
		var car := Node3D.new()
		car.set_script(traffic_script)
		car.add_to_group("city_traffic")
		var offset := (float(i) - 1.5) * 3.2
		var route := PackedVector3Array([
			Vector3(-half, 0, offset),
			Vector3(half, 0, offset),
			Vector3(half, 0, offset + 5.0),
			Vector3(-half, 0, offset + 5.0)
		])
		car.set("route", route)
		car.set("speed", rng.randf_range(7.0, 12.0))
		car.set("vehicle_color", [Color(0.02,0.12,0.2), Color(0.12,0.025,0.09), Color(0.08,0.1,0.14), Color(0.16,0.09,0.025)][i])
		car.position = route[0]
		add_child(car)
