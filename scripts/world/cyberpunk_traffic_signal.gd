extends Node3D
class_name CyberpunkTrafficSignal
## Two-phase intersection signal. Vehicles query it before entering the junction.
@export var green_axis := Vector3.RIGHT
@export_range(4.0, 40.0, 1.0) var cycle_seconds := 18.0
@export_range(0.0, 1.0, 0.05) var phase_offset := 0.0
@export_range(0.1, 0.45, 0.05) var green_fraction := 0.45

func _ready() -> void:
    add_to_group("traffic_signals")
    _build_signal_visual()

func is_green_for(travel_direction: Vector3) -> bool:
    var direction := travel_direction.normalized()
    var axis := green_axis.normalized()
    var aligned := absf(direction.dot(axis)) > 0.65
    var phase := fposmod(Time.get_ticks_msec() / 1000.0 / cycle_seconds + phase_offset, 1.0)
    var axis_is_green := phase < green_fraction
    return axis_is_green if aligned else not axis_is_green

func _build_signal_visual() -> void:
    var pole := MeshInstance3D.new()
    var pole_mesh := BoxMesh.new()
    pole_mesh.size = Vector3(0.14, 4.2, 0.14)
    pole.mesh = pole_mesh
    pole.position.y = 2.1
    var pole_mat := StandardMaterial3D.new()
    pole_mat.albedo_color = Color(0.025, 0.035, 0.055)
    pole_mat.metallic = 0.8
    pole.material_override = pole_mat
    add_child(pole)

    var housing := MeshInstance3D.new()
    var housing_mesh := BoxMesh.new()
    housing_mesh.size = Vector3(0.48, 1.15, 0.32)
    housing.mesh = housing_mesh
    housing.position = Vector3(0.0, 3.65, 0.0)
    housing.material_override = pole_mat
    add_child(housing)

    for i in range(3):
        var lamp := MeshInstance3D.new()
        var lamp_mesh := SphereMesh.new()
        lamp_mesh.radius = 0.12
        lamp_mesh.height = 0.24
        lamp.mesh = lamp_mesh
        lamp.position = Vector3(0.0, 4.02 - float(i) * 0.36, -0.18)
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var colors := [Color(1.0, 0.04, 0.08), Color(1.0, 0.62, 0.05), Color(0.0, 0.95, 0.48)]
        mat.albedo_color = colors[i]
        mat.emission_enabled = true
        mat.emission = colors[i]
        mat.emission_energy_multiplier = 1.5
        lamp.material_override = mat
        add_child(lamp)
