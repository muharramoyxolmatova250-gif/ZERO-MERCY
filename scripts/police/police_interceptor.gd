extends CharacterBody3D
## Cyberpunk police interceptor: detects recent weapon fire and pursues the player.
@export var detection_range := 75.0
@export var pursuit_speed := 8.2
@export var turn_speed := 5.5
@export var arrest_range := 2.0
@export var contact_damage := 8.0
var _target: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _attack_cooldown := 0.0
var _siren_time := 0.0
var _red_light: StandardMaterial3D
var _blue_light: StandardMaterial3D

func _ready() -> void:
 add_to_group("police")
 add_to_group("damageable")
 var collision := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.42
 capsule.height = 1.9
 collision.shape = capsule
 collision.position.y = 0.95
 add_child(collision)
 _build_police_visual()
 var players := get_tree().get_nodes_in_group("player")
 if not players.is_empty():
  _target = players[0] as Node3D

func _build_police_visual() -> void:
 var armor := StandardMaterial3D.new()
 armor.albedo_color = Color(0.025, 0.045, 0.075)
 armor.metallic = 0.85
 armor.roughness = 0.24
 _red_light = _emissive(Color(1.0, 0.015, 0.025))
 _blue_light = _emissive(Color(0.015, 0.25, 1.0))
 _add_box("ArmoredVest", Vector3(0, 1.12, 0), Vector3(0.72, 0.78, 0.42), armor)
 _add_box("Helmet", Vector3(0, 1.78, 0), Vector3(0.48, 0.42, 0.46), armor)
 _add_box("Visor", Vector3(0, 1.79, -0.24), Vector3(0.36, 0.09, 0.035), _blue_light)
 _add_box("LeftLeg", Vector3(-0.17, 0.36, 0), Vector3(0.2, 0.7, 0.24), armor)
 _add_box("RightLeg", Vector3(0.17, 0.36, 0), Vector3(0.2, 0.7, 0.24), armor)
 _add_box("SirenRed", Vector3(-0.2, 2.03, 0), Vector3(0.18, 0.09, 0.14), _red_light)
 _add_box("SirenBlue", Vector3(0.2, 2.03, 0), Vector3(0.18, 0.09, 0.14), _blue_light)

func _emissive(color: Color) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.emission_enabled = true
 material.emission = color
 material.emission_energy_multiplier = 2.8
 return material

func _add_box(part_name: String, part_position: Vector3, part_size: Vector3, material: Material) -> void:
 var mesh_instance := MeshInstance3D.new()
 mesh_instance.name = part_name
 var mesh := BoxMesh.new()
 mesh.size = part_size
 mesh_instance.mesh = mesh
 mesh_instance.position = part_position
 mesh_instance.material_override = material
 add_child(mesh_instance)

func _physics_process(delta: float) -> void:
 _siren_time += delta
 _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
 if not is_instance_valid(_target):
  var players := get_tree().get_nodes_in_group("player")
  if not players.is_empty():
   _target = players[0] as Node3D
 if not is_instance_valid(_target):
  velocity.x = move_toward(velocity.x, 0.0, pursuit_speed * delta)
  velocity.z = move_toward(velocity.z, 0.0, pursuit_speed * delta)
  move_and_slide()
  return
 var wanted_until := int(_target.get_meta("wanted_until", 0))
 var is_wanted := Time.get_ticks_msec() < wanted_until
 var distance := global_position.distance_to(_target.global_position)
 var responding := is_wanted and distance <= detection_range
 var red_active := fmod(_siren_time, 0.8) < 0.4
 _red_light.emission_energy_multiplier = 3.2 if red_active and responding else 0.35
 _blue_light.emission_energy_multiplier = 3.2 if not red_active and responding else 0.35
 if responding:
  var direction := _target.global_position - global_position
  direction.y = 0.0
  if direction.length() > 0.1:
   var desired_yaw := atan2(-direction.x, -direction.z)
   rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * delta)
   velocity.x = move_toward(velocity.x, direction.normalized().x * pursuit_speed, pursuit_speed * delta * 2.0)
   velocity.z = move_toward(velocity.z, direction.normalized().z * pursuit_speed, pursuit_speed * delta * 2.0)
  if distance <= arrest_range and _attack_cooldown <= 0.0:
   if _target.has_method("take_damage"):
    _target.call("take_damage", contact_damage, self)
   _attack_cooldown = 1.2
 else:
  velocity.x = move_toward(velocity.x, 0.0, pursuit_speed * delta)
  velocity.z = move_toward(velocity.z, 0.0, pursuit_speed * delta)
 if not is_on_floor():
  velocity.y -= _gravity * delta
 else:
  velocity.y = 0.0
 move_and_slide()

func take_damage(amount: float, _source: Node = null) -> void:
 if amount > 0.0 and is_instance_valid(_target):
  _target.set_meta("wanted_until", Time.get_ticks_msec() + 60000)
