extends CharacterBody3D
## Arcade-styled drivable cyberpunk coupe. Press E nearby to enter/exit.
@export var acceleration := 22.0
@export var reverse_acceleration := 12.0
@export var max_speed := 34.0
@export var reverse_speed := 10.0
@export var steering_rate := 1.7
@export var brake_strength := 30.0
var _driver: Node3D
var _driver_camera: Camera3D
var _vehicle_camera: Camera3D
var _speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body_mesh: MeshInstance3D

func _ready() -> void:
 add_to_group("drivable_vehicle")
 _build_vehicle()
 _vehicle_camera = Camera3D.new()
 _vehicle_camera.name = "VehicleCamera"
 _vehicle_camera.position = Vector3(0, 3.1, 7.2)
 _vehicle_camera.rotation_degrees = Vector3(-13, 0, 0)
 _vehicle_camera.current = false
 add_child(_vehicle_camera)

func _build_vehicle() -> void:
 var shell := StandardMaterial3D.new()
 shell.albedo_color = Color(0.018, 0.035, 0.055)
 shell.metallic = 0.92
 shell.roughness = 0.2
 var glass := StandardMaterial3D.new()
 glass.albedo_color = Color(0.005, 0.18, 0.23, 0.82)
 glass.metallic = 0.55
 glass.roughness = 0.12
 glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 var cyan := StandardMaterial3D.new()
 cyan.albedo_color = Color(0.0, 0.8, 1.0)
 cyan.emission_enabled = true
 cyan.emission = Color(0.0, 0.7, 1.0)
 cyan.emission_energy_multiplier = 2.2
 var red := StandardMaterial3D.new()
 red.albedo_color = Color(1.0, 0.025, 0.08)
 red.emission_enabled = true
 red.emission = Color(1.0, 0.01, 0.04)
 red.emission_energy_multiplier = 1.8
 _add_box("Chassis", Vector3(0, 0.72, 0), Vector3(2.05, 0.48, 4.25), shell)
 _add_box("Cabin", Vector3(0, 1.18, 0.12), Vector3(1.55, 0.68, 1.9), glass)
 _add_box("FrontSplitter", Vector3(0, 0.48, -2.12), Vector3(2.12, 0.12, 0.34), shell)
 _add_box("NeonFront", Vector3(0, 0.79, -2.145), Vector3(1.5, 0.07, 0.035), cyan)
 _add_box("NeonRear", Vector3(0, 0.84, 2.14), Vector3(1.55, 0.07, 0.04), red)
 for side in [-1.0, 1.0]:
  for z in [-1.35, 1.35]:
   var wheel := MeshInstance3D.new()
   wheel.name = "Wheel_%s_%s" % [side, z]
   var mesh := CylinderMesh.new()
   mesh.top_radius = 0.39
   mesh.bottom_radius = 0.39
   mesh.height = 0.22
   mesh.radial_segments = 20
   wheel.mesh = mesh
   wheel.position = Vector3(side * 1.02, 0.43, z)
   wheel.rotation_degrees.z = 90
   wheel.material_override = shell
   add_child(wheel)
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(2.0, 1.2, 4.2)
 collision.shape = shape
 collision.position.y = 0.72
 add_child(collision)

func _add_box(label: String, pos: Vector3, size: Vector3, material: Material) -> void:
 var mesh_instance := MeshInstance3D.new()
 mesh_instance.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 mesh_instance.mesh = mesh
 mesh_instance.position = pos
 mesh_instance.material_override = material
 add_child(mesh_instance)

func interact() -> void:
 if is_instance_valid(_driver):
  _exit_vehicle()
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
 _vehicle_camera.current = true
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_vehicle() -> void:
 if not is_instance_valid(_driver):
  _driver = null
  return
 _vehicle_camera.current = false
 if _driver_camera != null:
  _driver_camera.current = true
 _driver.global_position = global_position + global_transform.basis.x * 2.4 + Vector3.UP * 0.2
 _driver.visible = true
 _driver.set_physics_process(true)
 _driver.set_process_unhandled_input(true)
 _driver = null
 _driver_camera = null
 _speed = 0.0

func _unhandled_input(event: InputEvent) -> void:
 if is_instance_valid(_driver) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
  _exit_vehicle()
  get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(_driver):
  return
 var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
 var steering := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
 if throttle > 0.0:
  _speed = move_toward(_speed, max_speed, acceleration * delta)
 elif throttle < 0.0:
  _speed = move_toward(_speed, -reverse_speed, reverse_acceleration * delta)
 else:
  _speed = move_toward(_speed, 0.0, brake_strength * 0.32 * delta)
 if Input.is_key_pressed(KEY_SPACE):
  _speed = move_toward(_speed, 0.0, brake_strength * delta)
 var steer_factor := clampf(absf(_speed) / 8.0, 0.0, 1.0)
 rotation.y -= steering * steering_rate * steer_factor * delta * signf(_speed if absf(_speed) > 0.01 else 1.0)
 var forward := -global_transform.basis.z
 velocity.x = forward.x * _speed
 velocity.z = forward.z * _speed
 if not is_on_floor():
  velocity.y -= _gravity * delta
 else:
  velocity.y = -0.2
 move_and_slide()
 for collision_index in range(get_slide_collision_count()):
  var impact := get_slide_collision(collision_index)
  var obstacle := impact.get_collider()
  if obstacle is Node and obstacle.is_in_group("traffic_obstacle") and absf(_speed) > 9.0:
   var driver := get_tree().get_first_node_in_group("player")
   if driver != null:
    driver.set_meta("wanted_until", Time.get_ticks_msec() + 60000)
				 var previous_wanted_until := int(driver.get_meta("wanted_until", 0))
				 var old_level := int(driver.get_meta("wanted_level", 0)) if Time.get_ticks_msec() < previous_wanted_until else 0
				 driver.set_meta("wanted_level", mini(5, old_level + 1))
   _speed *= 0.35
   break
