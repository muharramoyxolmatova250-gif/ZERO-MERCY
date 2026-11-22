extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/mission_hud.tscn")
const BEACON_SCENE := preload("res://scenes/world/mission_beacon.tscn")
const RESCUE_SCENE := preload("res://scenes/world/rescue_zone.tscn")
const ENEMY_SCENE := preload("res://scenes/combat/training_enemy.tscn")

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_city()
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 1.2, 12)
	add_child(player)
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	var beacon := BEACON_SCENE.instantiate()
	beacon.position = Vector3(0, 0, -8)
	add_child(beacon)
	var rescue_zone := RESCUE_SCENE.instantiate()
	rescue_zone.position = Vector3(15, 0, -25)
	add_child(rescue_zone)
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = Vector3(0, 0, -18)
	add_child(enemy)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.008, 0.012, 0.045)
	sky_mat.sky_horizon_color = Color(0.12, 0.018, 0.09)
	sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.018)
	sky_mat.ground_horizon_color = Color(0.025, 0.012, 0.04)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.25, 0.42)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(0.35, 0.42, 0.8)
	sun.light_energy = 0.25
	add_child(sun)

func _build_city() -> void:
	_add_box(Vector3(0, -0.25, 0), Vector3(100, 0.5, 100), Color(0.025, 0.03, 0.055))
	_add_box(Vector3(0, -0.01, 0), Vector3(8, 0.04, 100), Color(0.012, 0.014, 0.022))
	_add_box(Vector3(0, 0.015, 0), Vector3(0.12, 0.025, 100), Color(0.0, 0.85, 1.0), true)

	for x in [-32, -20, 20, 32]:
		for z in [-32, -20, 20, 32]:
			var height := rng.randf_range(10.0, 27.0)
			var width := rng.randf_range(7.0, 10.0)
			var depth := rng.randf_range(7.0, 10.0)
			var base := Vector3(x, height * 0.5, z)
			_add_box(base, Vector3(width, height, depth), Color(0.035, 0.045, 0.075))
			_add_box(base + Vector3(0, height * 0.5 + 0.08, 0), Vector3(width + 0.2, 0.16, depth + 0.2), Color(0.0, 0.75, 1.0) if x < 0 else Color(1.0, 0.12, 0.48), true)
			_add_windows(x, z, height, width, depth)

	_add_box(Vector3(0, 5, -18), Vector3(18, 0.3, 0.5), Color(1.0, 0.08, 0.38), true)
	_add_box(Vector3(0, 5.5, -18), Vector3(0.12, 1.0, 0.12), Color(0.0, 0.9, 1.0), true)

func _add_windows(x: float, z: float, height: float, width: float, depth: float) -> void:
	var rows := int(height / 2.4)
	for row in range(1, rows):
		for col in range(2):
			var wx := x + (float(col) - 0.5) * width * 0.55
			var wy := row * 2.2
			var color := Color(0.0, 0.75, 1.0) if rng.randf() > 0.5 else Color(1.0, 0.15, 0.45)
			_add_box(Vector3(wx, wy, z - depth * 0.505), Vector3(0.65, 0.9, 0.06), color, true)

func _add_box(pos: Vector3, size: Vector3, color: Color, emissive := false) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
