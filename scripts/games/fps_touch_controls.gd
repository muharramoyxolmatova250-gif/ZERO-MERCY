extends Control
## Mobile twin-stick controls for the tactical FPS prototype.
signal movement_changed(direction: Vector2)
signal aim_changed(delta: Vector2)
signal fire_pressed
signal reload_pressed
signal jump_pressed

var _move_touch := -1
var _aim_touch := -1
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
	var base := Vector2(118, size.y - 132)
	draw_circle(base, JOYSTICK_RADIUS, Color(0.08, 0.12, 0.16, 0.42))
	draw_arc(base, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(0.55, 0.8, 0.9, 0.7), 3.0)
	draw_circle(base + _move_vector * 48.0, 27.0, Color(0.35, 0.75, 0.9, 0.75))
	var fire := Vector2(size.x - 100, size.y - 145)
	var reload := Vector2(size.x - 205, size.y - 76)
	var jump := Vector2(size.x - 95, size.y - 300)
	draw_circle(fire, 48, Color(0.75, 0.12, 0.08, 0.7))
	draw_circle(reload, 31, Color(0.15, 0.4, 0.55, 0.75))
	draw_circle(jump, 31, Color(0.2, 0.55, 0.35, 0.75))
	draw_string(ThemeDB.fallback_font, fire + Vector2(-20, 6), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, reload + Vector2(-25, 5), "RELOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(ThemeDB.fallback_font, jump + Vector2(-17, 5), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.42 and _move_touch == -1:
				_move_touch = event.index
				_move_origin = event.position
				_move_vector = Vector2.ZERO
				accept_event()
			elif event.position.x >= size.x * 0.42 and _aim_touch == -1:
				_aim_touch = event.index
				if _is_near(event.position, Vector2(size.x - 100, size.y - 145), 52.0):
					fire_pressed.emit()
				elif _is_near(event.position, Vector2(size.x - 205, size.y - 76), 38.0):
					reload_pressed.emit()
				elif _is_near(event.position, Vector2(size.x - 95, size.y - 300), 38.0):
					jump_pressed.emit()
				accept_event()
		else:
			if event.index == _move_touch:
				_move_touch = -1
				_move_vector = Vector2.ZERO
				movement_changed.emit(Vector2.ZERO)
				queue_redraw()
			elif event.index == _aim_touch:
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
