extends Node3D
## Deterministic procedural cyberpunk district generator.
## Use as visual filler only where licensed building footprints are unavailable.
## Real mapped building footprints should take priority over generated filler.

@export_range(1, 32, 1) var blocks_per_side := 5
@export var block_spacing := 42.0
@export var road_width := 12.0
@export var seed_value := 20261122
@export var min_building_height := 12.0
@export var max_building_height := 95.0
@export var generate_collision := true

var _rng := RandomNumberGenerator.new()
var _building_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_rng.seed = seed_value
	_create_materials()
	_generate_district()

func _create_materials() -> void:
	for color in [
		Color(0.025, 0.045, 0.075),
		Color(0.045, 0.035, 0.085),
		Color(0.055, 0.065, 0.085),
		Color(0.075, 0.035, 0.065)
	]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.62
		material.roughness = 0.38
		_building_materials.append(material)

func _generate_district() -> void:
	var half := blocks_per_side * block_spacing * 0.5
	for x in range(blocks_per_side):
		for z in range(blocks_per_side):
			var center := Vector3(
				(float(x) - float(blocks_per_side - 1) * 0.5) * block_spacing,
				0.0,
				(float(z) - float(blocks_per_side - 1) * 0.5) * block_spacing
			)
			_add_road(center, block_spacing - road_width, road_width * 0.55)
			_generate_block(center)
	_add_road(Vector3.ZERO, blocks_per_side * block_spacing + road_width, road_width)

func _generate_block(center: Vector3) -> void:
	var count := _rng.randi_range(2, 5)
	for i in range(count):
		var width := _rng.randf_range(7.0, 15.0)
		var depth := _rng.randf_range(7.0, 15.0)
		var height := _rng.randf_range(min_building_height, max_building_height)
		var offset := Vector3(
			_rng.randf_range(-block_spacing * 0.28, block_spacing * 0.28),
			height * 0.5,
			_rng.randf_range(-block_spacing * 0.28, block_spacing * 0.28)
		)
		_add_building(center + offset, Vector3(width, height, depth), _building_materials[_rng.randi_range(0, _building_materials.size() - 1)])

func _add_building(position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	add_child(instance)

	var crown_mesh := BoxMesh.new()
	crown_mesh.size = Vector3(size.x + 0.35, 0.22, size.z + 0.35)
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh
	crown.position = position + Vector3(0, size.y * 0.5 + 0.12, 0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.0, 0.8, 1.0) if _rng.randf() > 0.5 else Color(1.0, 0.08, 0.42)
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.0
	crown.material_override = glow
	add_child(crown)

	if generate_collision:
		var body := StaticBody3D.new()
		body.position = position
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _add_road(center: Vector3, length: float, width: float) -> void:
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.12, width)
	road.mesh = mesh
	road.position = center + Vector3(0, 0.015, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.012, 0.018, 0.03)
	material.roughness = 0.92
	road.material_override = material
	add_child(road)
