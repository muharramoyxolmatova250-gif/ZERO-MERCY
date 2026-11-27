extends Node3D

signal game_exited
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
var touch_fire_held := false
var touch_sprinting := false
var touch_controls: Control
var fire_cooldown := 0.0
var recoil_recovery := 0.0
var crouched := false
var sprinting := false
var rounds_won := 0
var rounds_lost := 0
var aiming := false
var round_finished := false
var crosshair: Label
var restart_button: Button
var weapon_pivot: Node3D
var muzzle_flash: OmniLight3D

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
	touch_controls.fire_held_changed.connect(func(held: bool) -> void: touch_fire_held = held)
	touch_controls.sprint_held_changed.connect(func(held: bool) -> void: touch_sprinting = held)
	touch_controls.reload_pressed.connect(_start_reload)
	touch_controls.jump_pressed.connect(_jump)
	touch_controls.crouch_pressed.connect(_toggle_crouch)
	touch_controls.aim_toggle_pressed.connect(func() -> void: _set_aiming(not aiming))

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
	_build_weapon_viewmodel()
	add_child(player)

func _build_weapon_viewmodel() -> void:
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "FirstPersonRifle"
	weapon_pivot.position = Vector3(0.32, -0.28, -0.58)
	camera.add_child(weapon_pivot)
	var receiver := MeshInstance3D.new()
	var receiver_mesh := BoxMesh.new()
	receiver_mesh.size = Vector3(0.16, 0.18, 0.48)
	receiver.mesh = receiver_mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.075, 0.09, 0.105)
	metal.metallic = 0.86
	metal.roughness = 0.24
	receiver.material_override = metal
	weapon_pivot.add_child(receiver)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.035
	barrel_mesh.bottom_radius = 0.035
	barrel_mesh.height = 0.48
	barrel_mesh.radial_segments = 12
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI / 2.0
	barrel.position.z = -0.38
	barrel.material_override = metal
	weapon_pivot.add_child(barrel)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.11, 0.24, 0.13)
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.17, 0.08)
	grip.rotation.x = -0.18
	grip.material_override = metal
	weapon_pivot.add_child(grip)
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color(1.0, 0.62, 0.2)
	muzzle_flash.light_energy = 3.5
	muzzle_flash.omni_range = 3.0
	muzzle_flash.position.z = -0.66
	muzzle_flash.visible = false
	weapon_pivot.add_child(muzzle_flash)

func _build_bots() -> void:
	for i in range(BOT_COUNT):
		var bot := CharacterBody3D.new()
		bot.name = "Enemy_%02d" % i
		bot.set_meta("health", 100.0)
		bot.set_meta("fire_wait", 0.8 + float(i) * 0.25)
		bot.set_meta("strafe_phase", float(i) * 1.7)
		bot.set_meta("combat_skill", 0.75 + float(i % 3) * 0.12)
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
	crosshair = Label.new()
	crosshair.text = "＋"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-10, -17)
	crosshair.add_theme_font_size_override("font_size", 28)
	layer.add_child(crosshair)
	_update_hud()
	var exit_button := Button.new()
	exit_button.text = "EXIT TO PHONE"
	exit_button.anchor_left = 1.0
	exit_button.anchor_right = 1.0
	exit_button.offset_left = -190.0
	exit_button.offset_right = -24.0
	exit_button.offset_top = 22.0
	exit_button.offset_bottom = 66.0
	exit_button.pressed.connect(_exit_to_phone)
	layer.add_child(exit_button)
	restart_button = Button.new()
	restart_button.text = "PLAY AGAIN"
	restart_button.anchor_left = 0.5
	restart_button.anchor_right = 0.5
	restart_button.anchor_top = 0.5
	restart_button.anchor_bottom = 0.5
	restart_button.offset_left = -105.0
	restart_button.offset_right = 105.0
	restart_button.offset_top = 64.0
	restart_button.offset_bottom = 116.0
	restart_button.visible = false
	restart_button.pressed.connect(_restart_round)
	layer.add_child(restart_button)

func _exit_to_phone() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_exited.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not mouse_captured:
		_capture_mouse()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	elif event is InputEventMouseMotion and mouse_captured:
		var sensitivity := 0.00135 if aiming else 0.0025
		player.rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_set_aiming(event.pressed)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_start_reload()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_toggle_crouch()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_T and round_finished:
		_restart_round()

func _set_aiming(enabled: bool) -> void:
	aiming = enabled
	camera.fov = 48.0 if aiming else 75.0
	if weapon_pivot != null:
		weapon_pivot.position.x = 0.18 if aiming else 0.32
		weapon_pivot.position.y = -0.22 if aiming else -0.28
	if crosshair != null:
		crosshair.visible = not aiming

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _physics_process(delta: float) -> void:
	if health <= 0.0 or time_left <= 0.0 or bots.is_empty():
		if not round_finished:
			_finish_round()
		_update_hud()
		return
	time_left = maxf(0.0, time_left - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if touch_fire_held:
		_fire()
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
	sprinting = (Input.is_key_pressed(KEY_SHIFT) or touch_sprinting) and input.length() > 0.1 and not crouched
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
	if weapon_pivot != null:
		weapon_pivot.position.z = -0.49
		var kick := create_tween()
		kick.tween_property(weapon_pivot, "position:z", -0.58, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		muzzle_flash.visible = true
		get_tree().create_timer(0.045).timeout.connect(func() -> void:
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false)
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
		var direction := offset.normalized()
		var phase := float(bot.get_meta("strafe_phase", 0.0))
		var side := Vector3(-direction.z, 0.0, direction.x) * sin(float(Time.get_ticks_msec()) * 0.0012 + phase)
		var desired_range := 10.0 + float(int(bot.get_instance_id()) % 4)
		var approach := direction * clampf((distance - desired_range) / 5.0, -0.65, 1.0)
		var separation := Vector3.ZERO
		for other in bots:
			if other == bot or not is_instance_valid(other):
				continue
			var gap := bot.global_position - other.global_position
			gap.y = 0.0
			if gap.length() > 0.01 and gap.length() < 2.8:
				separation += gap.normalized() * (2.8 - gap.length())
		var pursuit := (approach + side * 0.58 + separation * 0.9).normalized()
		bot.velocity.x = pursuit.x * 2.15
		bot.velocity.z = pursuit.z * 2.15
		bot.move_and_slide()
		var wait := float(bot.get_meta("fire_wait", 1.0)) - delta
		if wait <= 0.0 and distance < 24.0:
			var eye := bot.global_position + Vector3.UP * 0.55
			var target := camera.global_position
			var sight := PhysicsRayQueryParameters3D.create(eye, target)
			sight.exclude = [bot.get_rid()]
			var obstruction := get_world_3d().direct_space_state.intersect_ray(sight)
			if not obstruction.is_empty() and obstruction.get("collider") == player:
				var skill := float(bot.get_meta("combat_skill", 0.8))
				var damage := 2.5 + skill * 2.5
				health = maxf(0.0, health - damage)
				wait = 1.15 + (1.0 - skill) * 0.9
			else:
				wait = 0.3
		bot.set_meta("fire_wait", wait)

	# Round outcome is also actionable on touch-only devices.
func _finish_round() -> void:
	round_finished = true
	if restart_button != null:
		restart_button.visible = true
	if bots.is_empty():
		rounds_won += 1
	else:
		rounds_lost += 1

func _restart_round() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.queue_free()
	bots.clear()
	health = 100.0
	ammo = 30
	reserve_ammo = 90
	score = 0
	time_left = ROUND_SECONDS
	reloading = false
	reload_left = 0.0
	fire_cooldown = 0.0
	recoil_recovery = 0.0
	if touch_controls != null:
		touch_controls.reset_controls()
	player.global_position = Vector3(0, 1, 19)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = 75.0
	aiming = false
	crouched = false
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	capsule.height = 1.8
	camera.position.y = 0.62
	if crosshair != null:
		crosshair.visible = true
	if weapon_pivot != null:
		weapon_pivot.position = Vector3(0.32, -0.28, -0.58)
	round_finished = false
	if restart_button != null:
		restart_button.visible = false
	touch_fire_held = false
	touch_sprinting = false
	touch_move = Vector2.ZERO
	_build_bots()

func _update_hud() -> void:
	if hud == null:
		return
	var state := ("RELOADING %.1fs" % reload_left) if reloading else ("AMMO %d / %d" % [ammo, reserve_ammo])
	var outcome := " • YOU ARE DOWN" if health <= 0.0 else (" • TIME EXPIRED" if time_left <= 0.0 else (" • ROUND WON" if bots.is_empty() else ""))
	hud.text = "ZERO MERCY // TACTICAL BREACH\nHP %.0f   %s\nENEMIES %d   ELIMINATIONS %d   W/L %d/%d\nTIME %03d:%02d%s\nWASD move • Shift sprint • C crouch • Right-click ADS • Mouse aim/fire • R reload • Space jump • T restart after round • Esc release mouse" % [health, state, bots.size(), score, rounds_won, rounds_lost, int(time_left) / 60, int(time_left) % 60, outcome]