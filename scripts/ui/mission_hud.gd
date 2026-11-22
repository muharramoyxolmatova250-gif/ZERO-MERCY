extends CanvasLayer
## Compact cyberpunk HUD for mission objective, player vitals and ammunition.

var title_label: Label
var objective_label: Label
var status_label: Label
var health_label: Label
var stamina_label: Label
var ammo_label: Label
var player_ref: Node
var _last_failed_mission_id := ""


func _ready() -> void:
	_build_ui()
	if MissionManager.has_signal("mission_started"):
		MissionManager.mission_started.connect(_on_mission_started)
		MissionManager.objective_updated.connect(_on_objective_updated)
		MissionManager.mission_completed.connect(_on_mission_completed)
		MissionManager.mission_failed.connect(_on_mission_failed)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_bind_player(players[0])
	if MissionManager.active_mission_id == "":
		MissionManager.start_next_campaign_mission()
	else:
		var mission_data: Dictionary = MissionManager.get_current_mission_data()
		_on_mission_started(MissionManager.active_mission_id, str(mission_data.get("title", MissionManager.active_mission_id)))
		var objective: Dictionary = MissionManager.get_current_objective()
		if not objective.is_empty():
			_on_objective_updated(MissionManager.active_mission_id, str(objective.get("id", "")), int(objective.get("current", 0)), int(objective.get("target", 1)))


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 24)
	panel.custom_minimum_size = Vector2(410, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.045, 0.9)
	style.border_color = Color(0.0, 0.82, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	title_label = _make_label("ZERO MERCY  //  MISSION", 15, Color(0.0, 0.88, 1.0))
	column.add_child(title_label)
	objective_label = _make_label("Loading objective...", 17, Color(0.9, 0.94, 1.0))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective_label)
	status_label = _make_label("WASD MOVE  //  SHIFT SPRINT  //  E INTERACT", 10, Color(0.45, 0.62, 0.72))
	column.add_child(status_label)
	var separator := HSeparator.new()
	column.add_child(separator)
	health_label = _make_label("VITALS  100 / 100", 12, Color(1.0, 0.35, 0.42))
	column.add_child(health_label)
	stamina_label = _make_label("STAMINA  100 / 100", 12, Color(0.1, 0.9, 0.75))
	column.add_child(stamina_label)
	ammo_label = _make_label("AMMO  12 / 60", 12, Color(1.0, 0.78, 0.25))
	column.add_child(ammo_label)


func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _bind_player(target: Node) -> void:
	player_ref = target
	if player_ref.has_signal("health_changed"):
		player_ref.health_changed.connect(_on_health_changed)
	if player_ref.has_signal("stamina_changed"):
		player_ref.stamina_changed.connect(_on_stamina_changed)
	if player_ref.has_signal("ammo_changed"):
		player_ref.ammo_changed.connect(_on_ammo_changed)
	if player_ref.has_signal("player_died"):
		player_ref.player_died.connect(_on_player_died)
	if player_ref.has_method("get"):
		_on_health_changed(float(player_ref.get("health")), float(player_ref.get("max_health")))
		_on_stamina_changed(float(player_ref.get("stamina")), float(player_ref.get("stamina_max")))
		_on_ammo_changed(int(player_ref.get("ammo_in_magazine")), int(player_ref.get("reserve_ammo")))


func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "VITALS  %03d / %03d" % [roundi(current), roundi(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_label.text = "STAMINA  %03d / %03d" % [roundi(current), roundi(maximum)]


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	ammo_label.text = "AMMO  %02d / %02d" % [magazine, reserve]


func _on_player_died() -> void:
	objective_label.text = "DARA DOWN"
	status_label.text = "PLAYER VITALS DEPLETED"


func _on_mission_started(_mission_id: String, mission_title: String) -> void:
	title_label.text = "ZERO MERCY  //  " + mission_title.to_upper()


func _on_objective_updated(mission_id: String, objective_id: String, current: int, target: int) -> void:
	var objectives: Array = MissionManager.definitions.get(mission_id, {}).get("objectives", [])
	for objective in objectives:
		if str(objective.get("id", "")) == objective_id:
			objective_label.text = str(objective.get("title", objective_id))
			if target > 1:
				objective_label.text += "  [%d/%d]" % [current, target]
			return


func _on_mission_completed(_mission_id: String) -> void:
	objective_label.text = "MISSION COMPLETE"
	status_label.text = "ENTER TO CONTINUE  //  NEXT CHAPTER"


func _on_mission_failed(mission_id: String) -> void:
	_last_failed_mission_id = mission_id
	objective_label.text = "MISSION FAILED"
	status_label.text = "ENTER TO RETRY  //  MISSION DATA LOST"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		if MissionManager.active_mission_id == "":
			if not _last_failed_mission_id.is_empty():
				var retry_id := _last_failed_mission_id
				_last_failed_mission_id = ""
				MissionManager.start_mission(retry_id)
			else:
				MissionManager.start_next_campaign_mission()
			get_viewport().set_input_as_handled()
