extends CharacterBody3D
## Pursuit vehicle with alternating emergency lights and simple arcade steering.
@export var pursuit_speed := 15.0
@export var acceleration := 10.0
@export var turn_rate := 2.2
var _target: Node3D
var _speed := 0.0
var _siren_clock := 0.0
var _red: StandardMaterial3D
var _blue: StandardMaterial3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _siren_player: AudioStreamPlayer3D
var _siren_playback: AudioStreamGeneratorPlayback
var _audio_clock := 0.0
var _audio_sample_index := 0

func _ready() -> void:
 add_to_group("police_vehicle")
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(2.0, 1.2, 4.4)
 shape.shape = box
 shape.position.y = 0.75
 add_child(shape)
 _build_car()
 var siren_stream := AudioStreamGenerator.new()
 siren_stream.mix_rate = 22050.0
 siren_stream.buffer_length = 0.25
 _siren_player = AudioStreamPlayer3D.new()
 _siren_player.name = "ProceduralPoliceSiren"
 _siren_player.stream = siren_stream
 _siren_player.volume_db = -9.0
 _siren_player.max_distance = 65.0
 add_child(_siren_player)
 _siren_player.play()
 _siren_playback = _siren_player.get_stream_playback() as AudioStreamGeneratorPlayback
 var players := get_tree().get_nodes_in_group("player")
 if not players.is_empty():
  _target = players[0] as Node3D

func _material(color: Color, metallic: float = 0.5) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.metallic = metallic
 material.roughness = 0.28
 return material

func _emergency(color: Color) -> StandardMaterial3D:
 var material := _material(color, 0.25)
 material.emission_enabled = true
 material.emission = color
 material.emission_energy_multiplier = 3.0
 return material

func _add_box(label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
 var instance := MeshInstance3D.new()
 instance.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 instance.mesh = mesh
 instance.position = pos
 instance.material_override = material
 add_child(instance)
 return instance

func _build_car() -> void:
 var body := _material(Color(0.018, 0.035, 0.065), 0.88)
 var white := _material(Color(0.72, 0.78, 0.86), 0.55)
 _red = _emergency(Color(1.0, 0.015, 0.025))
 _blue = _emergency(Color(0.015, 0.22, 1.0))
 _add_box("ArmoredChassis", Vector3(0, 0.62, 0), Vector3(1.9, 0.62, 4.2), body)
 _add_box("WhiteDoorPanel", Vector3(0, 0.78, -0.15), Vector3(1.94, 0.36, 1.55), white)
 _add_box("Cabin", Vector3(0, 1.18, 0.2), Vector3(1.48, 0.72, 1.9), body)
 _add_box("Windshield", Vector3(0, 1.2, -0.78), Vector3(1.34, 0.48, 0.045), _blue)
 _add_box("LightbarRed", Vector3(-0.28, 1.62, 0.12), Vector3(0.48, 0.12, 0.18), _red)
 _add_box("LightbarBlue", Vector3(0.28, 1.62, 0.12), Vector3(0.48, 0.12, 0.18), _blue)
 for x in [-0.92, 0.92]:
  for z in [-1.35, 1.35]:
   var wheel := MeshInstance3D.new()
   var wheel_mesh := CylinderMesh.new()
   wheel_mesh.top_radius = 0.38
   wheel_mesh.bottom_radius = 0.38
   wheel_mesh.height = 0.22
   wheel.mesh = wheel_mesh
   wheel.position = Vector3(x, 0.38, z)
   wheel.rotation.z = PI * 0.5
   wheel.material_override = _material(Color(0.008, 0.01, 0.015), 0.1)
   add_child(wheel)

func _process(delta: float) -> void:
 _audio_clock += delta
 if _audio_clock >= 0.1 and _siren_playback != null:
  _audio_clock = 0.0
  var samples := PackedVector2Array()
  for sample_index in range(2205):
   var sweep := fposmod(float(_audio_sample_index) / 22050.0, 1.6)
   var frequency := 620.0 if sweep < 0.8 else 880.0
   var value := sin(TAU * frequency * float(_audio_sample_index) / 22050.0) * 0.16
   samples.append(Vector2(value, value))
   _audio_sample_index += 1
  _siren_playback.push_buffer(samples)

func _physics_process(delta: float) -> void:
 _siren_clock += delta
 var flashing := fmod(_siren_clock, 0.45) < 0.22
 _red.emission_energy_multiplier = 3.5 if flashing else 0.35
 _blue.emission_energy_multiplier = 0.35 if flashing else 3.5
 if not is_instance_valid(_target):
  var players := get_tree().get_nodes_in_group("player")
  if not players.is_empty():
   _target = players[0] as Node3D
 if is_instance_valid(_target):
  var wanted := Time.get_ticks_msec() < int(_target.get_meta("wanted_until", 0))
  if wanted:
   var to_target := _target.global_position - global_position
   to_target.y = 0.0
   if to_target.length() > 4.5:
    var local_direction := global_transform.basis.inverse() * to_target.normalized()
    var steering := clampf(-local_direction.x, -1.0, 1.0)
    rotation.y -= steering * turn_rate * delta * clampf(_speed / 5.0, 0.25, 1.0)
    _speed = move_toward(_speed, pursuit_speed, acceleration * delta)
   else:
    _speed = move_toward(_speed, 0.0, acceleration * delta * 2.0)
  else:
   _speed = move_toward(_speed, 0.0, acceleration * delta)
 var forward := -global_transform.basis.z
 velocity.x = forward.x * _speed
 velocity.z = forward.z * _speed
 if not is_on_floor():
  velocity.y -= _gravity * delta
 else:
  velocity.y = -0.2
 move_and_slide()

func take_damage(_amount: float, _source: Node = null) -> void:
 pass
