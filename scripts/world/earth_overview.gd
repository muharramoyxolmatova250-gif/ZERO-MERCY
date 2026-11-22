extends Node3D
## Orbit camera for inspecting the Earth overview scene.
@export var rotation_speed := 0.025
@export var zoom_speed := 12.0
@export var min_camera_distance := 145.0
@export var max_camera_distance := 420.0
@onready var globe: Node3D = $EarthGlobe
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
	globe.rotate_y(rotation_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.z = maxf(min_camera_distance, camera.position.z - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.z = minf(max_camera_distance, camera.position.z + zoom_speed)
		camera.look_at(Vector3.ZERO, Vector3.UP)
