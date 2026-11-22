extends CanvasLayer
## Dara's in-world phone: live NPC social feed, contacts, world news, life stats and map.
var _panel: PanelContainer
var _content: VBoxContainer
var _active_tab := "feed"
var _refresh_elapsed := 0.0
var _society: Node
var _life: Node

func _ready() -> void:
    layer = 30
    _build_phone()
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
        set_phone_open(not visible)
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_elapsed += delta
    if _refresh_elapsed >= 2.0:
        _refresh_elapsed = 0.0
        _refresh_content()

func set_phone_open(open: bool) -> void:
    visible = open
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
    if open:
        _refresh_content()

func is_phone_open() -> bool:
    return visible

func _build_phone() -> void:
    var overlay := Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.005, 0.01, 0.025, 0.78)
    overlay.add_child(dim)

    _panel = PanelContainer.new()
    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 0.5
    _panel.anchor_bottom = 0.5
    _panel.offset_left = -225
    _panel.offset_right = 225
    _panel.offset_top = -330
    _panel.offset_bottom = 330
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.012, 0.022, 0.04, 0.98)
    panel_style.border_color = Color(0.0, 0.82, 0.95, 0.9)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(18)
    panel_style.shadow_color = Color(0.0, 0.7, 0.95, 0.18)
    panel_style.shadow_size = 18
    _panel.add_theme_stylebox_override("panel", panel_style)
    overlay.add_child(_panel)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 10)
    _panel.add_child(outer)

    var header := HBoxContainer.new()
    outer.add_child(header)
    var brand := Label.new()
    brand.text = "ZERO LINK  //  DARA OS"
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_color_override("font_color", Color(0.15, 0.92, 1.0))
    brand.add_theme_font_size_override("font_size", 18)
    header.add_child(brand)
    var close := Button.new()
    close.text = "×"
    close.custom_minimum_size = Vector2(38, 34)
    close.pressed.connect(func(): set_phone_open(false))
    header.add_child(close)

    var status := Label.new()
    status.name = "PhoneStatus"
    status.text = "GLOBAL NETWORK  •  ENCRYPTED"
    status.add_theme_color_override("font_color", Color(0.35, 0.78, 0.88))
    status.add_theme_font_size_override("font_size", 10)
    outer.add_child(status)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 4)
    outer.add_child(tabs)
    for tab in ["feed", "news", "contacts", "life", "map"]:
        var button := Button.new()
        button.text = tab.to_upper()
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size = Vector2(0, 34)
        button.pressed.connect(_set_tab.bind(tab))
        tabs.add_child(button)

    var separator := HSeparator.new()
    outer.add_child(separator)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_child(scroll)
    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 9)
    scroll.add_child(_content)

    var footer := Label.new()
    footer.text = "P  •  CLOSE PHONE     |     WORLD SIMULATION CONTINUES"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_color_override("font_color", Color(0.3, 0.56, 0.66))
    footer.add_theme_font_size_override("font_size", 9)
    outer.add_child(footer)

func _set_tab(tab: String) -> void:
    _active_tab = tab
    _refresh_content()

func _refresh_content() -> void:
    if _content == null:
        return
    _society = get_tree().get_first_node_in_group("world_society_sim")
    _life = get_tree().get_first_node_in_group("world_life_sim")
    for child in _content.get_children():
        child.queue_free()
    match _active_tab:
        "feed":
            _build_feed()
        "news":
            _build_news()
        "contacts":
            _build_contacts()
        "life":
            _build_life()
        "map":
            _build_map()

func _build_feed() -> void:
    _add_section_title("LIVE SOCIAL FEED")
    if _society == null:
        _add_body("Connecting to the global network…")
        return
    var posts: Array = _society.call("get_social_feed", 24)
    if posts.is_empty():
        _add_body("No new posts yet. The world's residents are coming online.")
        return
    for post in posts:
        var card := PanelContainer.new()
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025, 0.045, 0.07, 0.98)
        style.border_color = Color(0.0, 0.48, 0.62, 0.5)
        style.set_border_width_all(1)
        style.set_corner_radius_all(8)
        card.add_theme_stylebox_override("panel", style)
        _content.add_child(card)
        var body := VBoxContainer.new()
        body.add_theme_constant_override("separation", 4)
        card.add_child(body)
        var author := Label.new()
        author.text = str(post.get("author_name", post.get("author_id", "Resident"))) + "  •  " + str(post.get("city", "Unknown city"))
        author.add_theme_color_override("font_color", Color(0.15, 0.88, 1.0))
        author.add_theme_font_size_override("font_size", 12)
        body.add_child(author)
        var caption := Label.new()
        caption.text = str(post.get("caption", ""))
        caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        caption.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
        body.add_child(caption)
        var meta := Label.new()
        meta.text = "♥ " + str(post.get("likes", 0)) + "     ◉ " + str(post.get("comments", 0)) + "     " + str(post.get("topic", ""))
        meta.add_theme_color_override("font_color", Color(0.35, 0.68, 0.76))
        meta.add_theme_font_size_override("font_size", 10)
        body.add_child(meta)

func _build_news() -> void:
    _add_section_title("WORLD NEWS NETWORK")
    if _society != null:
        var news: Dictionary = _society.call("get_world_society_snapshot")
        _add_stat("WORLD CLOCK", "DAY " + str(news.get("simulation_day", 1)) + "  /  " + str(news.get("simulation_hour", 8)) + ":00")
        _add_stat("CONNECTED CITIES", str(news.get("cities", 0)))
        _add_stat("INSTITUTIONS", str(news.get("institutions", 0)))
        _add_stat("POSTS GENERATED", str(news.get("posts_generated", 0)))
    else:
        _add_body("World news satellite connection unavailable.")
    _add_body("Live reports are generated from city institutions, residents and events. News updates as the simulation advances.")

func _build_contacts() -> void:
    _add_section_title("NEARBY CONTACTS")
    var citizens := get_tree().get_nodes_in_group("city_citizen")
    if citizens.is_empty():
        _add_body("No residents in communication range.")
        return
    for citizen in citizens.slice(0, 30):
        if not is_instance_valid(citizen) or not citizen.has_method("get_ai_snapshot"):
            continue
        var person: Dictionary = citizen.call("get_ai_snapshot")
        _add_stat(str(person.get("name", person.get("id", "Resident"))),
            str(person.get("age_years", 0)) + " yrs  •  " + str(person.get("life_stage", "adult")) + "  •  " + str(person.get("occupation", "resident")))

func _build_life() -> void:
    _add_section_title("GLOBAL LIFE SIMULATION")
    if _life == null:
        _add_body("Life simulation is offline.")
        return
    var data: Dictionary = _life.call("get_world_life_snapshot")
    _add_stat("SIMULATION DATE", "YEAR " + str(data.get("simulation_year", 1)) + "  /  MONTH " + str(data.get("simulation_month", 1)))
    _add_stat("AGGREGATE POPULATION", _format_number(int(data.get("aggregate_population", 0))))
    _add_stat("ACTIVE RESIDENTS", _format_number(int(data.get("active_residents", 0))))
    _add_stat("STUDENTS / CHILDREN", _format_number(int(data.get("sample_students", 0))))
    _add_stat("WORKING RESIDENTS", _format_number(int(data.get("sample_workers", 0))))
    _add_stat("RETIRED RESIDENTS", _format_number(int(data.get("sample_retired", 0))))
    _add_stat("BIRTHS", _format_number(int(data.get("births_total", 0))))
    _add_stat("DEATHS", _format_number(int(data.get("deaths_total", 0))))
    _add_stat("MARRIAGES", _format_number(int(data.get("marriages_total", 0))))
    _add_stat("GRADUATIONS", _format_number(int(data.get("graduations_total", 0))))

func _build_map() -> void:
    _add_section_title("EARTH NAVIGATION")
    var player := get_parent().get_node_or_null("Dara") as Node3D
    if player != null:
        var lon := 72.3 + player.global_position.x / 111320.0
        var lat := 40.7 - player.global_position.z / 111320.0
        _add_stat("LATITUDE", "%.5f°" % lat)
        _add_stat("LONGITUDE", "%.5f°" % lon)
    var streamer := get_parent().get_node_or_null("EarthRegionStreamer")
    if streamer != null:
        _add_stat("INDEXED WORLD CELLS", str(streamer.get("indexed_tile_count")))
        _add_stat("LOADED CELLS", str(streamer.get("loaded_tile_count")))
    _add_body("Global coordinates use the current gameplay Earth projection. Travel between loaded regions is streamed as the world expands.")

func _add_section_title(value: String) -> void:
    var label := Label.new()
    label.text = value
    label.add_theme_color_override("font_color", Color(0.1, 0.9, 1.0))
    label.add_theme_font_size_override("font_size", 16)
    _content.add_child(label)

func _add_body(value: String) -> void:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_color_override("font_color", Color(0.75, 0.84, 0.9))
    _content.add_child(label)

func _add_stat(label_text: String, value: String) -> void:
    var row := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.045, 0.07, 0.96)
    style.set_corner_radius_all(6)
    row.add_theme_stylebox_override("panel", style)
    _content.add_child(row)
    var box := HBoxContainer.new()
    row.add_child(box)
    var left := Label.new()
    left.text = label_text
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_color_override("font_color", Color(0.35, 0.7, 0.78))
    box.add_child(left)
    var right := Label.new()
    right.text = value
    right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    right.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
    box.add_child(right)

func _format_number(value: int) -> String:
    var source := str(value)
    var result := ""
    for index in range(source.length()):
        if index > 0 and (source.length() - index) % 3 == 0:
            result += ","
        result += source[index]
    return result
