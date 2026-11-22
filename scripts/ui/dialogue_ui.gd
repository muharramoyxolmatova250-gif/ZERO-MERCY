extends CanvasLayer
## Branching cinematic dialogue panel driven by DialogueManager.
var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _choices: VBoxContainer

func _ready() -> void:
    layer = 40
    _build_ui()
    visible = false
    DialogueManager.dialogue_started.connect(_on_dialogue_started)
    DialogueManager.line_presented.connect(_on_line_presented)
    DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _build_ui() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.0, 0.005, 0.02, 0.35)
    root.add_child(shade)

    _panel = PanelContainer.new()
    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 1.0
    _panel.anchor_bottom = 1.0
    _panel.offset_left = -510
    _panel.offset_right = 510
    _panel.offset_top = -285
    _panel.offset_bottom = -24
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.008, 0.018, 0.035, 0.97)
    style.border_color = Color(0.0, 0.8, 1.0, 0.85)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    _panel.add_theme_stylebox_override("panel", style)
    root.add_child(_panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    _panel.add_child(column)
    _speaker = Label.new()
    _speaker.add_theme_color_override("font_color", Color(0.1, 0.9, 1.0))
    _speaker.add_theme_font_size_override("font_size", 17)
    column.add_child(_speaker)
    _line = Label.new()
    _line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _line.custom_minimum_size = Vector2(0, 78)
    _line.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
    _line.add_theme_font_size_override("font_size", 18)
    column.add_child(_line)
    var separator := HSeparator.new()
    column.add_child(separator)
    _choices = VBoxContainer.new()
    _choices.add_theme_constant_override("separation", 6)
    column.add_child(_choices)

func _on_dialogue_started(_dialogue_id: String) -> void:
    visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_line_presented(speaker: String, text: String, choices: Array) -> void:
    visible = true
    _speaker.text = speaker.to_upper()
    _line.text = text
    for child in _choices.get_children():
        child.queue_free()
    if choices.is_empty():
        var finish := Button.new()
        finish.text = "DAVOM ETISH"
        finish.custom_minimum_size = Vector2(0, 42)
        finish.pressed.connect(func(): DialogueManager.finish_dialogue())
        _choices.add_child(finish)
        return
    for index in range(choices.size()):
        var choice: Dictionary = choices[index]
        var button := Button.new()
        button.text = str(choice.get("text", "Tanlash"))
        button.custom_minimum_size = Vector2(0, 42)
        button.pressed.connect(_choose.bind(index))
        _choices.add_child(button)

func _choose(index: int) -> void:
    DialogueManager.choose(index)

func _on_dialogue_finished(_dialogue_id: String) -> void:
    visible = false
    var phone := get_parent().get_node_or_null("DaraPhone")
    if phone == null or not bool(phone.call("is_phone_open")):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
