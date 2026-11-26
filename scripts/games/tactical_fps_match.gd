extends Node3D
## Standalone playable tactical FPS foundation: movement, aiming, hits, bots and round objective.
const BOT_COUNT := 5
const ROUND_SECONDS := 240.0
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var health := 100.0
var ammo := 30
var reserve_ammo := 90
var score := 0
var time_left := ROUND_SECONDS
var reloading := false
var reload_left := 0.0
var bots: Array[CharacterBody3D] = []
var mouse_captured := false
var touch_move := Vector2.ZERO
var touch_controls: Control
var fire_cooldown := 0.0
var recoil_recovery := 0.0
var crouched := false
var sprinting := false
var rounds_won := 0
var rounds_lost := 0

func _ready() -> void:
	_build_arena()
	_build_player()
	_build_bots()
	_build_hud()
	_build_touch_controls()
	if not OS.has_feature("mobile"):
		_capture_mouse()
	for action in ["fps_forward", "fps_back", "fps_left", "fps_right", "fps_jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_bind_key("fps_forward", KEY_W)
	_bind_key("fps_back", KEY_S)
	_bind_key("fps_left", KEY_A)
	_bind_key("fps_right", KEY_D)
	_bind_key("fps_jump", KEY_SPACE)

func _build_touch_controls() -> void:
	var touch_script := load("res://scripts/games/fps_touch_controls.gd")
	touch_controls = Control.new()
	touch_controls.set_script(touch_script)
	touch_controls.name = "MobileControls"
	touch_controls.visible = OS.has_feature("mobile")
	var touch_layer := CanvasLayer.new()
	touch_layer.name = "TouchControlsLayer"
	add_child(touch_layer)
	touch_layer.add_child(touch_controls)
	touch_controls.movement_changed.connect(func(direction: Vector2) -> void: touch_move = direction)
	touch_controls.aim_changed.connect(_on_touch_aim)
	touch_controls.fire_pressed.connect(_fire)
	touch_controls.reload_pressed.connect(_start_reload)
	touch_controls.jump_pressed.connect(_jump)

func _on_touch_aim(delta: Vector2) -> void:
	player.rotate_y(-delta.x * 0.003)
	camera.rotate_x(-delta.y * 0.003)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)

func _toggle_crouch() -> void:
	crouched = not crouched
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	capsule.height = 1.15 if crouched else 1.8
	camera.position.y = 0.38 if crouched else 0.62

func _jump() -> void:
	if player.is_on_floor():
		player.velocity.y = 5.0

func _bind_key(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _build_arena() -> void:
	var floor := StaticBody3D.new()
	floor.name = "ArenaFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(48, 1, 48)
	var floor_visual := MeshInstance3D.new()
	floor_visual.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.075, 0.09, 0.12)
	floor_visual.material_override = floor_material
	floor.add_child(floor_visual)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = floor_mesh.size
	floor_shape.shape = box
	floor.add_child(floor_shape)
	floor.position.y = -0.5
	add_child(floor)
	for i in range(12):
		var cover := StaticBody3D.new()
		var mesh := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(2.8, 1.5, 1.2)
		mesh.mesh = block
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.19, 0.23)
		mat.metallic = 0.55
		mesh.material_override = mat
		cover.add_child(mesh)
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = block.size
		shape.shape = collision
		cover.add_child(shape)
		cover.position = Vector3(-15.0 + float(i % 4) * 10.0, 0.75, -12.0 + float(i / 4) * 10.0)
		add_child(cover)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.3
	add_child(light)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 19)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 0.62
	camera.current = true
	player.add_child(camera)
	add_child(player)

func _build_bots() -> void:
	for i in range(BOT_COUNT):
		var bot := CharacterBody3D.new()
		bot.name = "Enemy_%02d" % i
		bot.set_meta("health", 100.0)
		bot.set_meta("fire_wait", 1.0 + float(i) * 0.3)
		bot.position = Vector3(-13.0 + float(i) * 6.5, 1, -10.0 - float(i % 2) * 8.0)
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.38
		mesh.height = 1.8
		body.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65, 0.12, 0.09)
		mat.emission_enabled = true
		mat.emission = Color(0.18, 0.025, 0.01)
		body.material_override = mat
		bot.add_child(body)
		var collision := CollisionShape3D.new()
		var bot_capsule := CapsuleShape3D.new()
		bot_capsule.height = 1.8
		collision.shape = bot_capsule
		bot.add_child(collision)
		add_child(bot)
		bots.append(bot)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	elif event is InputEventMouseMotion and mouse_captured:
		player.rotate_y(-event.relative.x * 0.0025)
		camera.rotate_x(-event.relative.y * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_start_reload()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_toggle_crouch()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _physics_process(delta: float) -> void:
	if health <= 0.0 or time_left <= 0.0:
		_update_hud()
		return
	time_left = maxf(0.0, time_left - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	recoil_recovery = move_toward(recoil_recovery, 0.0, delta * 2.8)
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			var needed := 30 - ammo
			var loaded := mini(needed, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			reloading = false
	var input := Vector2(Input.get_action_strength("fps_right") - Input.get_action_strength("fps_left"), Input.get_action_strength("fps_back") - Input.get_action_strength("fps_forward")) + touch_move
	var wish := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
	sprinting = Input.is_key_pressed(KEY_SHIFT) and input.length() > 0.1 and not crouched
	var move_speed := 7.2 if sprinting else (2.8 if crouched else 5.2)
	player.velocity.x = wish.x * move_speed
	player.velocity.z = wish.z * move_speed
	if player.is_on_floor():
		player.velocity.y = 0.0
		if Input.is_action_just_pressed("fps_jump"):
			player.velocity.y = 5.0
	else:
		player.velocity.y -= 18.0 * delta
	player.move_and_slide()
	_update_bots(delta)
	_update_hud()

func _fire() -> void:
	if ammo <= 0 or reloading or health <= 0.0 or fire_cooldown > 0.0:
		return
	ammo -= 1
	fire_cooldown = 0.105
	recoil_recovery = minf(0.7, recoil_recovery + 0.12)
	camera.rotation.x = clampf(camera.rotation.x - 0.012, -1.45, 1.45)
	var origin := camera.global_position
	var end := origin + (-camera.global_transform.basis.z * 120.0)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.get("collider")
		if target is CharacterBody3D and bots.has(target):
			var remaining := float(target.get_meta("health", 100.0)) - 34.0
			target.set_meta("health", remaining)
			if remaining <= 0.0:
				target.queue_free()
				bots.erase(target)
				score += 1
	_update_hud()

func _start_reload() -> void:
	if not reloading and ammo < 30 and reserve_ammo > 0:
		reloading = true
		reload_left = 1.8

func _update_bots(delta: float) -> void:
	for bot in bots:
		if not is_instance_valid(bot):
			continue
		var offset := player.global_position - bot.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 7.0:
			var direction := offset.normalized()
			var side := Vector3(-direction.z, 0.0, direction.x) * sin(float(Time.get_ticks_msec()) * 0.0012 + float(bot.get_instance_id() % 17))
			var pursuit := (direction + side * 0.48).normalized()
			bot.velocity.x = pursuit.x * 2.0
			bot.velocity.z = pursuit.z * 2.0
			bot.move_and_slide()
		else:
			bot.velocity = Vector3.ZERO
		var wait := float(bot.get_meta("fire_wait", 1.0)) - delta
		if wait <= 0.0 and distance < 24.0:
			var eye := bot.global_position + Vector3.UP * 0.55
			var target := camera.global_position
			var sight := PhysicsRayQueryParameters3D.create(eye, target)
			sight.exclude = [bot.get_rid()]
			var obstruction := get_world_3d().direct_space_state.intersect_ray(sight)
			if not obstruction.is_empty() and obstruction.get("collider") == player:
				health = maxf(0.0, health - 4.0)
			wait = 1.5 + float(bot.get_instance_id() % 10) * 0.08
		bot.set_meta("fire_wait", wait)

func _update_hud() -> void:
	if hud == null:
		return
	var state := ("RELOADING %.1fs" % reload_left) if reloading else ("AMMO %d / %d" % [ammo, reserve_ammo])
	var outcome := " • YOU ARE DOWN" if health <= 0.0 else (" • TIME EXPIRED" if time_left <= 0.0 else "")
	hud.text = "ZERO MERCY // TACTICAL BREACH\nHP %.0f   %s\nENEMIES %d   ELIMINATIONS %d\nTIME %03d:%02d%s\nWASD move • Shift sprint • C crouch • Mouse aim/fire • R reload • Space jump • Esc release mouse" % [health, state, bots.size(), score, int(time_left) / 60, int(time_left) % 60, outcome]