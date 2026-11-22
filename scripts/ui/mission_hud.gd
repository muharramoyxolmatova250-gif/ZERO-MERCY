extends CanvasLayer
## Minimal mission HUD. Connects to MissionManager autoload.

var title_label: Label
var objective_label: Label
var status_label: Label


func _ready() -> void:
	_build_ui()
	if MissionManager.has_signal("mission_started"):
		MissionManager.mission_started.connect(_on_mission_started)
		MissionManager.objective_updated.connect(_on_objective_updated)
		MissionManager.mission_completed.connect(_on_mission_completed)
		MissionManager.mission_failed.connect(_on_mission_failed)
	if MissionManager.active_mission_id == "":
		MissionManager.start_mission("prologue_signal")


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(32, 28)
	panel.custom_minimum_size = Vector2(390, 112)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.045, 0.88)
	style.border_color = Color(0.0, 0.82, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	title_label = Label.new()
	title_label.text = "ZERO MERCY  //  MISSION"
	title_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	title_label.add_theme_font_size_override("font_size", 15)
	column.add_child(title_label)

	objective_label = Label.new()
	objective_label.text = "Loading objective..."
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	objective_label.add_theme_font_size_override("font_size", 18)
	column.add_child(objective_label)

	status_label = Label.new()
	status_label.text = "WASD MOVE  //  SHIFT SPRINT  //  E INTERACT"
	status_label.add_theme_color_override("font_color", Color(0.45, 0.62, 0.72))
	status_label.add_theme_font_size_override("font_size", 11)
	column.add_child(status_label)


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
	status_label.text = "OBJECTIVES CLEARED"


func _on_mission_failed(_mission_id: String) -> void:
	objective_label.text = "MISSION FAILED"
	status_label.text = "MISSION DATA LOST"
