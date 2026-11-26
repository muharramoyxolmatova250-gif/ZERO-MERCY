extends CharacterBody3D
## Lightweight cyber motorcycle with enter/exit, steering and lean animation.
@export var acceleration := 18.0
@export var max_speed := 27.0
@export var steering_rate := 2.0
@export var brake_strength := 26.0
var _driver: Node3D
var _driver_camera: Camera3D
var _bike_camera: Camera3D
var _speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _lean := 0.0

func _ready() -> void:
 add_to_group("drivable_vehicle")
 _build_bike()
 _bike_camera = Camera3D.new()
 _bike_camera.position = Vector3(0, 2.0, 4.8)
 _bike_camera.rotation_degrees = Vector3(-10, 0, 0)
 _bike_camera.current = false
 add_child(_bike_camera)

func _build_bike() -> void:
 var metal := StandardMaterial3D.new()
 metal.albedo_color = Color(0.025, 0.035, 0.055)
 metal.metallic = 0.9
 metal.roughness = 0.22
 var neon := StandardMaterial3D.new()
 neon.albedo_color = Color(0.0, 0.75, 1.0)
 neon.emission_enabled = true
 neon.emission = Color(0.0, 0.65, 1.0)
 neon.emission_energy_multiplier = 2.0
 _add_box("BikeFrame", Vector3(0, 0.85, 0), Vector3(0.28, 0.22, 1.65), metal)
 _add_box("FuelShell", Vector3(0, 1.12, -0.15), Vector3(0.58, 0.38, 0.7), metal)
 _add_box("Seat", Vector3(0, 1.22, 0.48), Vector3(0.42, 0.12, 0.62), metal)
 _add_box("FrontLight", Vector3(0, 1.0, -0.93), Vector3(0.32, 0.16, 0.05), neon)
 for z in [-0.78, 0.78]:
  var wheel := MeshInstance3D.new()
  wheel.name = "Wheel_%s" % z
  var mesh := CylinderMesh.new()
  mesh.top_radius = 0.42
  mesh.bottom_radius = 0.42
  mesh.height = 0.16
  mesh.radial_segments = 24
  wheel.mesh = mesh
  wheel.rotation_degrees.z = 90
  wheel.position = Vector3(0, 0.43, z)
  wheel.material_override = metal
  add_child(wheel)
 var collision := CollisionShape3D.new()
 var shape := CapsuleShape3D.new()
 shape.radius = 0.48
 shape.height = 1.65
 collision.shape = shape
 collision.position.y = 0.88
 add_child(collision)

func _add_box(label: String, pos: Vector3, size: Vector3, material: Material) -> void:
 var item := MeshInstance3D.new()
 item.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 item.mesh = mesh
 item.position = pos
 item.material_override = material
 add_child(item)

func interact() -> void:
 if is_instance_valid(_driver):
  _exit_bike()
  return
 var players := get_tree().get_nodes_in_group("player")
 if players.is_empty():
  return
 var candidate := players[0] as Node3D
 if candidate == null or candidate.global_position.distance_to(global_position) > 4.0:
  return
 _driver = candidate
 _driver.set_physics_process(false)
 _driver.set_process_unhandled_input(false)
 _driver.visible = false
 _driver_camera = _driver.get_node_or_null("CameraPivot/Camera3D") as Camera3D
 if _driver_camera != null:
  _driver_camera.current = false
 _bike_camera.current = true
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_bike() -> void:
 if not is_instance_valid(_driver):
  _driver = null
  return
 _bike_camera.current = false
 if _driver_camera != null:
  _driver_camera.current = true
 _driver.global_position = global_position + global_transform.basis.x * 1.7 + Vector3.UP * 0.2
 _driver.visible = true
 _driver.set_physics_process(true)
 _driver.set_process_unhandled_input(true)
 _driver = null
 _driver_camera = null
 _speed = 0.0

func _unhandled_input(event: InputEvent) -> void:
 if is_instance_valid(_driver) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
  _exit_bike()
  get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(_driver):
  return
 var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
 var steering := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
 if throttle > 0.0:
  _speed = move_toward(_speed, max_speed, acceleration * delta)
 elif throttle < 0.0:
  _speed = move_toward(_speed, -8.0, acceleration * 0.75 * delta)
 else:
  _speed = move_toward(_speed, 0.0, brake_strength * 0.22 * delta)
 if Input.is_key_pressed(KEY_SPACE):
  _speed = move_toward(_speed, 0.0, brake_strength * delta)
 var steer_factor := clampf(absf(_speed) / 7.0, 0.0, 1.0)
 rotation.y -= steering * steering_rate * steer_factor * delta * signf(_speed if absf(_speed) > 0.01 else 1.0)
 _lean = lerpf(_lean, -steering * 0.32 * steer_factor, delta * 5.0)
 rotation.z = _lean
 var forward := -global_transform.basis.z
 velocity.x = forward.x * _speed
 velocity.z = forward.z * _speed
 if not is_on_floor():
  velocity.y -= _gravity * delta
 else:
  velocity.y = -0.2
 move_and_slide()
