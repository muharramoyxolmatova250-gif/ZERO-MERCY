extends Control
## Mobile twin-stick controls for the tactical FPS prototype.
signal movement_changed(direction: Vector2)
signal aim_changed(delta: Vector2)
signal fire_pressed
signal fire_held_changed(held: bool)
signal sprint_held_changed(held: bool)
signal reload_pressed
signal jump_pressed
signal crouch_pressed
signal aim_toggle_pressed

var _move_touch := -1
var _aim_touch := -1
var _fire_touch := -1
var _sprint_touch := -1
var _move_origin := Vector2.ZERO
var _move_vector := Vector2.ZERO
var _fire_rect := Rect2()
var _reload_rect := Rect2()
var _jump_rect := Rect2()
const JOYSTICK_RADIUS := 76.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func _draw() -> void:
	var base := _move_center()
	draw_circle(base, JOYSTICK_RADIUS, Color(0.08, 0.12, 0.16, 0.42))
	draw_arc(base, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.55, 0.8, 0.9, 0.7), 3.0)
	draw_circle(base + _move_vector * 48.0, 27.0, Color(0.35, 0.75, 0.9, 0.75))
	var fire := _fire_center()
	var reload := _reload_center()
	var jump := _jump_center()
	var sprint := _sprint_center()
	var crouch := _crouch_center()
	var ads := _ads_center()
	draw_circle(fire, 48, Color(0.75, 0.12, 0.08, 0.7))
	draw_circle(reload, 31, Color(0.15, 0.4, 0.55, 0.75))
	draw_circle(jump, 31, Color(0.2, 0.55, 0.35, 0.75))
	draw_circle(sprint, 32, Color(0.55, 0.48, 0.12, 0.78))
	draw_circle(crouch, 31, Color(0.35, 0.35, 0.42, 0.78))
	draw_circle(ads, 31, Color(0.22, 0.36, 0.58, 0.78))
	draw_string(ThemeDB.fallback_font, fire + Vector2(-20, 6), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, reload + Vector2(-25, 5), "RELOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ThemeDB.fallback_font, jump + Vector2(-17, 5), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, sprint + Vector2(-24, 5), "SPRINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ThemeDB.fallback_font, crouch + Vector2(-26, 5), "CROUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ThemeDB.fallback_font, ads + Vector2(-13, 5), "ADS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			_reset_touches()
			accept_event()
			return
		if event.pressed:
			if event.position.distance_to(_sprint_center()) <= 38.0 and _sprint_touch == -1:
				_sprint_touch = event.index
				sprint_held_changed.emit(true)
				accept_event()
			elif event.position.x < size.x * 0.42 and _move_touch == -1:
				_move_touch = event.index
				_move_origin = event.position
				_move_vector = Vector2.ZERO
				accept_event()
			elif event.position.x >= size.x * 0.42 and _aim_touch == -1:
				_aim_touch = event.index
				if _is_near(event.position, _fire_center(), 52.0):
					_fire_touch = event.index
					fire_held_changed.emit(true)
					fire_pressed.emit()
				elif _is_near(event.position, _reload_center(), 38.0):
					reload_pressed.emit()
				elif _is_near(event.position, _jump_center(), 38.0):
					jump_pressed.emit()
				elif _is_near(event.position, _crouch_center(), 38.0):
					crouch_pressed.emit()
				elif _is_near(event.position, _ads_center(), 38.0):
					aim_toggle_pressed.emit()
				accept_event()
		else:
			if event.index == _sprint_touch:
				_sprint_touch = -1
				sprint_held_changed.emit(false)
			elif event.index == _move_touch:
				_move_touch = -1
				_move_vector = Vector2.ZERO
				movement_changed.emit(Vector2.ZERO)
				queue_redraw()
			elif event.index == _aim_touch:
				if event.index == _fire_touch:
					_fire_touch = -1
					fire_held_changed.emit(false)
				_aim_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == _move_touch:
			_move_vector = ((event.position - _move_origin) / JOYSTICK_RADIUS).limit_length(1.0)
			movement_changed.emit(_move_vector)
			queue_redraw()
		elif event.index == _aim_touch:
			aim_changed.emit(event.relative)

func _is_near(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_to(center) <= radius


func _move_center() -> Vector2:
	return Vector2(clampf(size.x * 0.22, 88.0, 132.0), size.y - 132.0)

func _fire_center() -> Vector2:
	return Vector2(size.x - 92.0, size.y - 142.0)

func _reload_center() -> Vector2:
	return Vector2(size.x - 190.0, size.y - 74.0)

func _jump_center() -> Vector2:
	return Vector2(size.x - 88.0, size.y - 292.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_touches()

func reset_controls() -> void:
	_reset_touches()

func _reset_touches() -> void:
	var was_firing := _fire_touch != -1
	_move_touch = -1
	_aim_touch = -1
	_sprint_touch = -1
	_fire_touch = -1
	_move_vector = Vector2.ZERO
	movement_changed.emit(Vector2.ZERO)
	if was_firing:
		fire_held_changed.emit(false)
	sprint_held_changed.emit(false)
	queue_redraw()

func _sprint_center() -> Vector2:
	return Vector2(size.x - 92.0, 72.0)

func _crouch_center() -> Vector2:
	return Vector2(size.x - 190.0, size.y - 142.0)

func _ads_center() -> Vector2:
	return Vector2(size.x - 190.0, size.y - 292.0)
