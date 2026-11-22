extends StaticBody3D
## Physical mission marker that can be activated with the player's interact key.
@export var event_id := ""
@export var display_title := "MISSION OBJECTIVE"
@export var current := 0
@export var target := 1
var _cooldown := 0.0
var _label: Label3D
var _progress_label: Label3D

func _ready() -> void:
    add_to_group("mission_objective")
    collision_layer = 1
    collision_mask = 1
    var shape_node := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.25
    shape_node.position.y = 1.0
    shape_node.shape = sphere
    add_child(shape_node)

    var color := Color(0.05, 0.9, 1.0)
    if event_id.contains("defeat") or event_id.contains("disable") or event_id.contains("destroy"):
        color = Color(1.0, 0.18, 0.32)
    elif event_id.contains("escort") or event_id.contains("rescue"):
        color = Color(0.2, 1.0, 0.55)
    var core := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.45
    cylinder.bottom_radius = 0.7
    cylinder.height = 1.8
    core.mesh = cylinder
    core.position.y = 1.0
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.2
    material.metallic = 0.55
    material.roughness = 0.22
    core.material_override = material
    add_child(core)

    var beam := MeshInstance3D.new()
    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.04
    beam_mesh.bottom_radius = 0.12
    beam_mesh.height = 5.0
    beam.mesh = beam_mesh
    beam.position.y = 3.4
    var beam_material := StandardMaterial3D.new()
    beam_material.albedo_color = Color(color.r, color.g, color.b, 0.28)
    beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_material.emission_enabled = true
    beam_material.emission = color
    beam_material.emission_energy_multiplier = 1.5
    beam.material_override = beam_material
    add_child(beam)

    _label = Label3D.new()
    _label.text = "E  //  " + display_title
    _label.position = Vector3(0, 2.3, 0)
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.font_size = 30
    _label.outline_size = 8
    _label.modulate = color
    add_child(_label)

    _progress_label = Label3D.new()
    _progress_label.position = Vector3(0, 1.8, 0)
    _progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _progress_label.font_size = 22
    _progress_label.modulate = Color(0.85, 0.95, 1.0)
    add_child(_progress_label)
    set_progress(current, target)

func _process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    rotate_y(delta * 0.55)

func interact() -> void:
    if _cooldown > 0.0 or event_id.is_empty():
        return
    _cooldown = 0.8
    MissionManager.report_event(event_id, 1)

func set_progress(value: int, total: int) -> void:
    current = value
    target = maxi(1, total)
    if _progress_label != null:
        _progress_label.text = str(current) + " / " + str(target)
