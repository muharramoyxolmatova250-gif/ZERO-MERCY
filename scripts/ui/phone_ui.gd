extends CanvasLayer
## Dara's in-world phone: live NPC social feed, contacts, world news, life stats and map.
var _panel: PanelContainer
var _content: VBoxContainer
var _active_tab := "home"
var _sms_target_id := ""
var _phone_clock_label: Label
var _phone_battery_label: Label
var _phone_network_label: Label
var _system_refresh_elapsed := 0.0
var _refresh_elapsed := 0.0
var _society: Node
var _life: Node
var _party_invites: Array[String] = []
var _party_game_id := "tactical_breach"
var _last_party_result: Dictionary = {}
var _phone_camera = preload("res://scripts/phone/phone_camera.gd").new()
var _phone_system = preload("res://scripts/phone/phone_system.gd").new()
var _phone_browser = preload("res://scripts/phone/phone_browser.gd").new()
var _browser_query := ""
var _browser_page_id := ""
var _browser_status := "READY"
var _browser_view_mode := "search"
var _last_camera_message := "READY TO CAPTURE"
var _last_call_message := ""
var _social_feed_mode := "all"
var _social_search_query := ""
var _social_comment_post_id := ""

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
    _system_refresh_elapsed += delta
    var system_interval := 2.0 if bool(_phone_system.get_setting("power_saver", false)) else 0.5
    if _system_refresh_elapsed >= system_interval:
        _system_refresh_elapsed = 0.0
        _update_phone_system_bar()
    _refresh_elapsed += delta
    if _refresh_elapsed >= 2.0:
        _refresh_elapsed = 0.0
        if _active_tab != "browser":
            _refresh_content()

func set_phone_open(open: bool) -> void:
    visible = open
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
    if open:
        _refresh_content()
        if _panel != null:
            _panel.pivot_offset = _panel.size * 0.5
            _panel.scale = Vector2(0.94, 0.94)
            _panel.modulate.a = 0.65
            var boot_tween := create_tween()
            boot_tween.set_parallel(true)
            boot_tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            boot_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
    if not open and _panel != null:
        _panel.scale = Vector2.ONE
        _panel.modulate.a = 1.0

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
    var viewport_size := get_viewport().get_visible_rect().size
    var phone_width := minf(450.0, viewport_size.x - 20.0)
    var phone_height := minf(660.0, viewport_size.y - 20.0)
    _panel.offset_left = -phone_width * 0.5
    _panel.offset_right = phone_width * 0.5
    _panel.offset_top = -phone_height * 0.5
    _panel.offset_bottom = phone_height * 0.5
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.006, 0.012, 0.027, 0.995)
    panel_style.border_color = Color(0.08, 0.92, 1.0, 0.96)
    panel_style.set_border_width_all(2)
    panel_style.border_width_bottom = 3
    panel_style.border_width_top = 3
    panel_style.border_color = Color(0.0, 0.82, 0.95, 0.9)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(24)
    panel_style.shadow_color = Color(0.0, 0.72, 1.0, 0.32)
    panel_style.shadow_size = 26
    panel_style.shadow_color = Color(0.0, 0.7, 0.95, 0.18)
    panel_style.shadow_size = 18
    _panel.add_theme_stylebox_override("panel", panel_style)
    overlay.add_child(_panel)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 10)
    _panel.add_child(outer)

    var device_strip := ColorRect.new()
    device_strip.custom_minimum_size = Vector2(0, 3)
    device_strip.color = Color(0.0, 0.9, 1.0, 0.95)
    outer.add_child(device_strip)

    var header := HBoxContainer.new()
    outer.add_child(header)
    var brand := Label.new()
    brand.text = "◈ ZERO LINK  /  DARA OS"
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_color_override("font_color", Color(0.15, 0.92, 1.0))
    brand.add_theme_font_size_override("font_size", 19)
    brand.add_theme_color_override("font_shadow_color", Color(0.0, 0.8, 1.0, 0.55))
    brand.add_theme_constant_override("shadow_offset_x", 1)
    brand.add_theme_constant_override("shadow_offset_y", 1)
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

    var system_bar := HBoxContainer.new()
    system_bar.add_theme_constant_override("separation", 8)
    outer.add_child(system_bar)
    _phone_clock_label = Label.new()
    _phone_clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _phone_clock_label.add_theme_color_override("font_color", Color(0.12, 0.94, 1.0))
    _phone_clock_label.add_theme_font_size_override("font_size", 12)
    system_bar.add_child(_phone_clock_label)
    _phone_network_label = Label.new()
    _phone_network_label.text = "▰ 5G"
    _phone_network_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.78))
    _phone_network_label.add_theme_font_size_override("font_size", 10)
    system_bar.add_child(_phone_network_label)
    _phone_battery_label = Label.new()
    _phone_battery_label.add_theme_color_override("font_color", Color(0.55, 0.94, 0.72))
    _phone_battery_label.add_theme_font_size_override("font_size", 10)
    system_bar.add_child(_phone_battery_label)
    _update_phone_system_bar()

    var tab_scroll := ScrollContainer.new()
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.custom_minimum_size.y = 38
    outer.add_child(tab_scroll)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 4)
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_scroll.add_child(tabs)
    for tab in ["home", "feed", "media", "games", "news", "contacts", "sms", "notifications", "life", "missions", "map", "camera", "gallery", "settings", "calls", "browser", "social"]:
        var button := Button.new()
        button.text = tab.to_upper()
        button.custom_minimum_size = Vector2(76, 36)
        button.add_theme_font_size_override("font_size", 10)
        button.add_theme_color_override("font_color", Color(0.48, 0.76, 0.84))
        button.add_theme_color_override("font_hover_color", Color(0.08, 0.98, 1.0))
        button.add_theme_stylebox_override("normal", _make_phone_button_style(Color(0.015, 0.04, 0.065, 0.98), Color(0.08, 0.35, 0.43, 0.8)))
        button.add_theme_stylebox_override("hover", _make_phone_button_style(Color(0.02, 0.12, 0.16, 1.0), Color(0.0, 0.92, 1.0, 0.95)))
        button.add_theme_stylebox_override("pressed", _make_phone_button_style(Color(0.0, 0.22, 0.27, 1.0), Color(0.0, 1.0, 1.0, 1.0)))
        button.add_theme_stylebox_override("focus", _make_phone_button_style(Color(0.02, 0.12, 0.16, 1.0), Color(0.0, 0.92, 1.0, 0.95)))
        button.pressed.connect(_set_tab.bind(tab))
        tabs.add_child(button)

    var separator := HSeparator.new()
    separator.add_theme_color_override("separator", Color(0.0, 0.72, 0.86, 0.55))
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
    footer.text = "◈ P  /  CLOSE DEVICE     •     NEURAL LINK ACTIVE"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_color_override("font_color", Color(0.12, 0.72, 0.82))
    footer.add_theme_font_size_override("font_size", 9)
    outer.add_child(footer)

func _update_phone_system_bar() -> void:
    if _phone_clock_label != null:
        _phone_clock_label.text = Time.get_time_string_from_system()
    if _phone_battery_label != null:
        var battery := 100.0
        var owner_id := _get_phone_owner_id()
        if owner_id != "" and _life != null and _life.has_method("get_phone_snapshot"):
            var phone: Dictionary = _life.call("get_phone_snapshot", owner_id)
            battery = clampf(float(phone.get("battery", 100.0)), 0.0, 100.0)
        _phone_battery_label.text = "▣ " + str(roundi(battery)) + "%"
        _phone_battery_label.add_theme_color_override("font_color", Color(1.0, 0.36, 0.32) if battery < 15.0 else Color(0.55, 0.94, 0.72))
    if _phone_network_label != null:
        var owner_id := _get_phone_owner_id()
        var connected := _life != null and owner_id != "" and bool(_phone_system.get_setting("wifi_enabled", true))
        _phone_network_label.text = "▰ 5G" if connected else "◌ OFFLINE"
        _phone_network_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.78) if connected else Color(1.0, 0.55, 0.35))


func _make_phone_button_style(fill: Color, edge: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    return style


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
        "home":
            _build_home_screen()
        "feed":
            _build_feed()
        "media":
            _build_media_hub()
        "games":
            _build_games_hub()
        "news":
            _build_news()
        "contacts":
            _build_contacts()
        "sms":
            _build_sms_inbox()
        "notifications":
            _build_notifications_center()
        "life":
            _build_life()
        "missions":
            _build_missions()
        "map":
            _build_map()
        "camera":
            _build_camera_app()
        "gallery":
            _build_phone_gallery()
        "settings":
            _build_phone_settings()
        "calls":
            _build_phone_calls()
        "browser":
            _build_browser()
        "social":
            _build_social_network()


func _build_home_screen() -> void:
    _add_section_title("ZERO LINK // HOME")
    _add_body("NEURAL INTERFACE  •  PERSONAL DEVICE")
    var owner_id := _get_phone_owner_id()
    if owner_id != "" and _life != null and _life.has_method("get_phone_snapshot"):
        var snapshot: Dictionary = _life.call("get_phone_snapshot", owner_id)
        _add_stat("DEVICE", str(snapshot.get("model", "Neon One")))
        _add_stat("PHONE NUMBER", str(snapshot.get("number", "UNASSIGNED")))
        _add_stat("UNREAD SMS", str(_life.call("get_phone_unread_count", owner_id)))
        var notifications: Array = snapshot.get("notifications", [])
        _add_stat("SYSTEM ALERTS", str(notifications.size()))
        if not notifications.is_empty():
            var latest: Dictionary = notifications[notifications.size() - 1]
            _add_body("LATEST ALERT  •  " + str(latest.get("text", latest.get("title", "New notification"))))
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    _content.add_child(grid)
    _add_phone_app_tile(grid, "SOCIAL", "◉", "social")
    _add_phone_app_tile(grid, "MEDIA", "▶", "media")
    _add_phone_app_tile(grid, "GAMES", "▣", "games")
    _add_phone_app_tile(grid, "NEWS", "⌁", "news")
    _add_phone_app_tile(grid, "CONTACTS", "◎", "contacts")
    _add_phone_app_tile(grid, "MESSAGES", "✉", "sms")
    _add_phone_app_tile(grid, "ALERTS", "⚑", "notifications")
    _add_phone_app_tile(grid, "LIFE", "◇", "life")
    _add_phone_app_tile(grid, "MISSIONS", "✦", "missions")
    _add_phone_app_tile(grid, "WORLD MAP", "⌖", "map")
    _add_phone_app_tile(grid, "CAMERA", "◎", "camera")
    _add_phone_app_tile(grid, "GALLERY", "▧", "gallery")
    _add_phone_app_tile(grid, "SETTINGS", "⚙", "settings")
    _add_phone_app_tile(grid, "CALLS", "☎", "calls")
    _add_phone_app_tile(grid, "BROWSER", "◎", "browser")


func _add_phone_app_tile(parent: GridContainer, title: String, glyph: String, target_tab: String) -> void:
    var tile := Button.new()
    tile.custom_minimum_size = Vector2(104, 88)
    tile.text = glyph + "\\n" + title
    if target_tab == "sms":
        var owner_id := _get_phone_owner_id()
        if owner_id != "" and _life != null and _life.has_method("get_phone_unread_count"):
            var unread := int(_life.call("get_phone_unread_count", owner_id))
            if unread > 0:
                tile.text += "  [" + str(unread) + "]"
    tile.add_theme_font_size_override("font_size", 14)
    tile.add_theme_color_override("font_color", Color(0.25, 0.94, 1.0))
    tile.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
    tile.add_theme_stylebox_override("normal", _make_phone_button_style(Color(0.012, 0.04, 0.065, 0.98), Color(0.0, 0.48, 0.62, 0.8)))
    tile.add_theme_stylebox_override("hover", _make_phone_button_style(Color(0.0, 0.16, 0.2, 1.0), Color(0.0, 0.95, 1.0, 1.0)))
    tile.pressed.connect(_set_tab.bind(target_tab))
    parent.add_child(tile)


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

func _get_phone_owner_id() -> String:
    var player := get_parent().get_node_or_null("Dara")
    if player != null and player.has_method("get_ai_snapshot"):
        var snapshot: Dictionary = player.call("get_ai_snapshot")
        return str(snapshot.get("id", ""))
    return ""


func _build_notifications_center() -> void:
    _add_section_title("SYSTEM // NOTIFICATION CENTER")
    var owner_id := _get_phone_owner_id()
    if owner_id.is_empty() or _life == null or not _life.has_method("get_phone_snapshot"):
        _add_body("Notification link unavailable.")
        return
    var snapshot: Dictionary = _life.call("get_phone_snapshot", owner_id)
    var notifications: Array = snapshot.get("notifications", [])
    if not bool(_phone_system.get_setting("notifications_enabled", true)):
        _add_body("Phone notifications are disabled in DARA OS settings.")
        return
    _add_stat("TOTAL ALERTS", str(notifications.size()))
    if notifications.is_empty():
        _add_body("No new system alerts.")
        return
    for alert in notifications:
        var title := str(alert.get("title", alert.get("kind", "WORLD ALERT")))
        var detail := str(alert.get("text", alert.get("message", "")))
        _add_stat(title, detail)


func _build_sms_inbox() -> void:
    _add_section_title("MESSAGES / INBOX")
    var owner_id := _get_phone_owner_id()
    if owner_id.is_empty() or _life == null or not _life.has_method("get_phone_inbox"):
        _add_body("SMS inbox is unavailable until the player phone is connected.")
        return
    var unread := int(_life.call("get_phone_unread_count", owner_id))
    _add_stat("UNREAD MESSAGES", str(unread))
    var messages: Array = _life.call("get_phone_inbox", owner_id, false, 40)
    if messages.is_empty():
        _add_body("Inbox is empty.")
        return
    for message in messages:
        var message_id := str(message.get("id", ""))
        var sender_id := str(message.get("sender_id", "Unknown"))
        var preview := str(message.get("text", ""))
        var status := "READ" if bool(message.get("read", false)) else "NEW"
        var entry := Button.new()
        entry.text = status + "  " + sender_id + "\n" + preview.left(90)
        entry.custom_minimum_size = Vector2(0, 58)
        entry.pressed.connect(func() -> void:
            _life.call("mark_phone_message_read", owner_id, message_id)
            _refresh_content()
        )
        _content.add_child(entry)


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
        var contact_id := str(person.get("id", ""))
        if not contact_id.is_empty():
            var call_button := Button.new()
            call_button.text = "☎  CALL " + str(person.get("name", "RESIDENT")).to_upper()
            call_button.custom_minimum_size.y = 38
            call_button.pressed.connect(_place_phone_call.bind(contact_id, str(person.get("name", "Resident"))))
            _content.add_child(call_button)


func _place_phone_call(contact_id: String, contact_name: String) -> void:
    var owner_id := _get_phone_owner_id()
    if owner_id.is_empty() or _life == null or not _life.has_method("make_phone_call"):
        _last_call_message = "CALL FAILED  •  PHONE SERVICE OFFLINE"
        _active_tab = "calls"
        _refresh_content()
        return
    var connected := bool(_life.call("make_phone_call", owner_id, contact_id, 30))
    _last_call_message = ("CALL COMPLETED  •  " + contact_name + "  •  00:30") if connected else ("CALL FAILED  •  " + contact_name + " UNAVAILABLE")
    _active_tab = "calls"
    _refresh_content()


func _build_phone_calls() -> void:
    _add_section_title("ZERO CALL // SECURE LINE")
    _add_body("Place an in-game simulated call to a resident. Calls update NPC relationship history and both phones' call logs.")
    if not _last_call_message.is_empty():
        _add_body(_last_call_message)
    var owner_id := _get_phone_owner_id()
    if owner_id.is_empty() or _life == null:
        _add_body("Phone identity is unavailable.")
        return
    var history: Array = _life.call("get_phone_call_history", owner_id, 30) if _life.has_method("get_phone_call_history") else []
    _add_stat("RECENT CALLS", str(history.size()))
    if history.is_empty():
        _add_body("No calls recorded yet. Open CONTACTS to call a resident.")
    for call_data in history:
        var direction := "OUTGOING" if str(call_data.get("from", "")) == owner_id else "INCOMING"
        var other_id := str(call_data.get("to", "")) if direction == "OUTGOING" else str(call_data.get("from", ""))
        var status := str(call_data.get("status", "completed")).to_upper()
        var duration := maxi(0, int(call_data.get("duration_seconds", 0)))
        _add_stat(direction + "  •  " + status, other_id + "  /  " + str(duration) + " sec")
    var contacts: Array = _life.call("get_phone_contacts", owner_id) if _life.has_method("get_phone_contacts") else []
    _add_section_title("SAVED CONTACTS")
    for contact in contacts.slice(0, 20):
        var target_id := str(contact.get("id", ""))
        if target_id.is_empty():
            continue
        var target_name := str(contact.get("name", target_id))
        var call_button := Button.new()
        call_button.text = "☎  " + target_name.to_upper()
        call_button.custom_minimum_size.y = 40
        call_button.pressed.connect(_place_phone_call.bind(target_id, target_name))
        _content.add_child(call_button)

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


func _build_missions() -> void:
    _add_section_title("CAMPAIGN CONTROL")
    var campaign_data: Dictionary = MissionManager.get_campaign_snapshot()
    _add_stat("MAIN STORY", str(campaign_data.get("main_completed", 0)) + " / " + str(campaign_data.get("main_total", 0)))
    _add_stat("SIDE MISSIONS", str(campaign_data.get("side_completed", 0)) + " / " + str(campaign_data.get("side_total", 0)))
    _add_stat("CREDITS", _format_number(int(campaign_data.get("credits", 0))))
    if MissionManager.active_mission_id != "":
        var mission: Dictionary = MissionManager.get_current_mission_data()
        var objective: Dictionary = MissionManager.get_current_objective()
        _add_body("ACTIVE: " + str(mission.get("title", MissionManager.active_mission_id)))
        _add_body("OBJECTIVE: " + str(objective.get("title", "In progress")))
        _add_body("PROGRESS: " + str(objective.get("current", 0)) + " / " + str(objective.get("target", 1)))
    else:
        _add_body("Main story continues from the mission HUD. Press ENTER after a completed mission.")
    _add_section_title("AVAILABLE SIDE OPERATIONS")
    var available: Array[Dictionary] = MissionManager.get_available_side_missions()
    if available.is_empty():
        _add_body("No side operations available.")
        return
    for item in available.slice(0, 10):
        var card := PanelContainer.new()
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025, 0.045, 0.07, 0.98)
        style.border_color = Color(0.0, 0.48, 0.62, 0.45)
        style.set_border_width_all(1)
        style.set_corner_radius_all(7)
        card.add_theme_stylebox_override("panel", style)
        _content.add_child(card)
        var body := VBoxContainer.new()
        card.add_child(body)
        var title := Label.new()
        title.text = str(item.get("title", "Side mission"))
        title.add_theme_color_override("font_color", Color(0.15, 0.88, 1.0))
        body.add_child(title)
        var description := Label.new()
        description.text = str(item.get("description", ""))
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        body.add_child(description)
        var launch := Button.new()
        launch.text = "START OPERATION"
        launch.disabled = MissionManager.active_mission_id != ""
        launch.pressed.connect(_start_side_mission.bind(str(item.get("id", ""))))
        body.add_child(launch)

func _start_side_mission(mission_id: String) -> void:
    MissionManager.start_side_mission(mission_id)
    _refresh_content()

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
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.72, 1.0, 0.45))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
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
    style.bg_color = Color(0.012, 0.032, 0.052, 0.98)
    style.border_color = Color(0.0, 0.48, 0.62, 0.48)
    style.set_border_width_all(1)
    style.border_width_left = 2
    style.set_corner_radius_all(7)
    style.content_margin_left = 9
    style.content_margin_right = 9
    style.content_margin_top = 6
    style.content_margin_bottom = 6
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


func _build_phone_settings() -> void:
    _add_section_title("DARA OS // DEVICE SETTINGS")
    _add_body("Manage local device connections, sound and power preferences. Changes are saved on this device.")
    _add_section_title("WIRELESS CONNECTIONS")
    _add_phone_setting_toggle("WI-FI", "wifi_enabled", "Connect to the simulated ZERO LINK network")
    _add_phone_setting_toggle("BLUETOOTH", "bluetooth_enabled", "Nearby device connection preference")
    _add_section_title("SYSTEM")
    _add_phone_setting_toggle("SOUND", "sound_enabled", "Master game audio")
    _add_phone_setting_toggle("NOTIFICATIONS", "notifications_enabled", "Allow phone alert banners")
    _add_phone_setting_toggle("POWER SAVER", "power_saver", "Reduce phone refresh work when enabled")
    _add_section_title("AUDIO LEVEL")
    var volume := HSlider.new()
    volume.min_value = 0.0
    volume.max_value = 1.0
    volume.step = 0.05
    volume.value = float(_phone_system.get_setting("volume", 0.75))
    volume.value_changed.connect(func(value: float) -> void:
        _phone_system.set_setting("volume", value)
    )
    _content.add_child(volume)
    _add_stat("MASTER VOLUME", "%d%%" % roundi(volume.value * 100.0))
    _add_body("Settings are stored locally and restored when the game starts again.")


func _add_phone_setting_toggle(title: String, setting_key: String, description: String) -> void:
    var toggle := CheckButton.new()
    toggle.text = title
    toggle.button_pressed = bool(_phone_system.get_setting(setting_key, true))
    toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toggle.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
    toggle.toggled.connect(func(enabled: bool) -> void:
        _phone_system.set_setting(setting_key, enabled)
        if setting_key == "wifi_enabled":
            _update_phone_system_bar()
        if _active_tab == "settings":
            _refresh_content()
    )
    _content.add_child(toggle)
    _add_body(description)


func _build_camera_app() -> void:
    _add_section_title("ZERO CAMERA // WORLD CAPTURE")
    _add_body("Capture the live game view. Photos are saved locally in your ZERO LINK gallery.")
    _add_stat("CAMERA MODE", "WORLD VIEW")
    var shutter := Button.new()
    shutter.text = "◎   TAKE PHOTO"
    shutter.custom_minimum_size = Vector2(0, 58)
    shutter.add_theme_font_size_override("font_size", 18)
    shutter.pressed.connect(_capture_phone_photo)
    _content.add_child(shutter)
    _add_body(_last_camera_message)
    var gallery := Button.new()
    gallery.text = "OPEN PHOTO GALLERY"
    gallery.custom_minimum_size.y = 42
    gallery.pressed.connect(_set_tab.bind("gallery"))
    _content.add_child(gallery)


func _capture_phone_photo() -> void:
    set_phone_open(false)
    await get_tree().process_frame
    var result: Dictionary = _phone_camera.capture_viewport(get_viewport())
    set_phone_open(true)
    _active_tab = "camera"
    if bool(result.get("ok", false)):
        _last_camera_message = "SAVED  •  %s × %s" % [str(result.get("width", 0)), str(result.get("height", 0))]
    else:
        _last_camera_message = "CAPTURE FAILED  •  " + str(result.get("error", "unknown_error"))
    _refresh_content()


func _build_phone_gallery() -> void:
    _add_section_title("ZERO GALLERY // MY PHOTOS")
    var photos: Array[String] = _phone_camera.get_gallery_images()
    _add_stat("SAVED PHOTOS", str(photos.size()))
    if photos.is_empty():
        _add_body("Your gallery is empty. Open CAMERA and take your first world photo.")
        var camera_button := Button.new()
        camera_button.text = "OPEN CAMERA"
        camera_button.pressed.connect(_set_tab.bind("camera"))
        _content.add_child(camera_button)
        return
    for index in range(photos.size()):
        var photo_path := photos[index]
        var entry := Button.new()
        entry.text = "%02d   %s" % [index + 1, photo_path.get_file()]
        entry.custom_minimum_size = Vector2(0, 42)
        entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        entry.pressed.connect(_show_gallery_photo.bind(photo_path))
        _content.add_child(entry)


func _show_gallery_photo(photo_path: String) -> void:
    var photo: Image = _phone_camera.load_photo(photo_path)
    for child in _content.get_children():
        child.queue_free()
    _add_section_title("PHOTO VIEWER // ZERO GALLERY")
    if photo == null:
        _add_body("This photo could not be opened.")
        var retry := Button.new()
        retry.text = "BACK TO GALLERY"
        retry.pressed.connect(_set_tab.bind("gallery"))
        _content.add_child(retry)
        return
    var preview := TextureRect.new()
    preview.texture = ImageTexture.create_from_image(photo)
    preview.custom_minimum_size = Vector2(0, 260)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _content.add_child(preview)
    _add_body(photo_path.get_file())
    _add_stat("RESOLUTION", "%d × %d" % [photo.get_width(), photo.get_height()])
    var remove := Button.new()
    remove.text = "DELETE PHOTO"
    remove.pressed.connect(_delete_gallery_photo.bind(photo_path))
    _content.add_child(remove)
    var back := Button.new()
    back.text = "BACK TO GALLERY"
    back.pressed.connect(_set_tab.bind("gallery"))
    _content.add_child(back)


func _delete_gallery_photo(photo_path: String) -> void:
    _phone_camera.delete_photo(photo_path)
    _active_tab = "gallery"
    _refresh_content()


func _build_media_hub() -> void:
    _add_section_title("ZERO MEDIA // REAL ASSETS")
    _add_body("Open the media library. Only imported video and image files can play; feed entries without licensed local assets remain metadata.")
    var open := Button.new()
    open.text = "OPEN MEDIA PLAYER"
    open.custom_minimum_size = Vector2(0, 46)
    open.pressed.connect(_open_media_player)
    _content.add_child(open)
    if _life != null and _life.has_method("get_phone_media_feed"):
        var items: Array = _life.call("get_phone_media_feed", "all", 24)
        _add_stat("FEED ITEMS", str(items.size()))
        var playable := 0
        for item in items:
            var path := str(item.get("asset_path", item.get("file_path", "")))
            if not path.is_empty() and ResourceLoader.exists(path):
                playable += 1
        _add_stat("INSTALLED MEDIA ASSETS", str(playable))
    else:
        _add_body("Media feed is connecting…")

func _open_media_player() -> void:
    var layer := CanvasLayer.new()
    layer.name = "PhoneMediaPlayerLayer"
    layer.layer = 45
    var scene := load("res://scenes/ui/phone_media_player.tscn") as PackedScene
    if scene == null:
        _add_body("Media player scene could not be loaded.")
        return
    var player_ui := scene.instantiate()
    layer.add_child(player_ui)
    get_tree().root.add_child(layer)
    if _life != null and _life.has_method("get_phone_media_feed"):
        player_ui.call("load_feed", _life.call("get_phone_media_feed", "all", 60))
    if player_ui.has_signal("close_requested"):
        player_ui.close_requested.connect(func() -> void:
            layer.queue_free()
            set_phone_open(true)
        )
    set_phone_open(false)

func _build_games_hub() -> void:
    _add_section_title("ZERO PLAY // AAA GAME CENTER")
    _add_body("Every title is planned as a complete, large-scale 3D game—not a short mini-game. Only titles marked PLAYABLE can currently launch; other projects remain in development.")
    var catalog: Array = _life.call("get_phone_games_catalog") if _life != null and _life.has_method("get_phone_games_catalog") else []
    for game_data in catalog:
        var card := PanelContainer.new()
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.018, 0.045, 0.075, 0.98)
        style.border_color = Color(0.0, 0.72, 0.9, 0.62)
        style.set_border_width_all(1)
        style.set_corner_radius_all(10)
        style.set_content_margin_all(10)
        card.add_theme_stylebox_override("panel", style)
        _content.add_child(card)
        var body := VBoxContainer.new()
        body.add_theme_constant_override("separation", 5)
        card.add_child(body)
        var heading := Label.new()
        heading.text = str(game_data.get("title", "Game")) + "  //  " + str(game_data.get("production_tier", "AAA target"))
        heading.add_theme_color_override("font_color", Color(0.22, 0.9, 1.0))
        heading.add_theme_font_size_override("font_size", 15)
        body.add_child(heading)
        var description := Label.new()
        description.text = str(game_data.get("description", ""))
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        body.add_child(description)
        var scope := Label.new()
        scope.text = "SCALE: " + str(game_data.get("world_scale", "")) + "\nVISUAL TARGET: " + str(game_data.get("visual_target", ""))
        scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        scope.add_theme_font_size_override("font_size", 10)
        scope.add_theme_color_override("font_color", Color(0.55, 0.78, 0.86))
        body.add_child(scope)
        var systems := Label.new()
        systems.text = "SYSTEMS: " + ", ".join(game_data.get("systems", []))
        systems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        systems.add_theme_font_size_override("font_size", 10)
        body.add_child(systems)
        var status := Label.new()
        status.text = "● PLAYABLE PROTOTYPE" if bool(game_data.get("playable", false)) else "◌ IN DEVELOPMENT — FULL GAME NOT YET PLAYABLE"
        status.add_theme_color_override("font_color", Color(0.25, 0.95, 0.55) if bool(game_data.get("playable", false)) else Color(1.0, 0.72, 0.25))
        body.add_child(status)
        if str(game_data.get("id", "")) == "tactical_breach":
            var launch := Button.new()
            launch.text = "LAUNCH TACTICAL BREACH PROTOTYPE"
            launch.custom_minimum_size.y = 42
            launch.pressed.connect(_launch_tactical_breach)
            body.add_child(launch)
    _add_section_title("NPC PHONE PARTY")
    _add_body("NPC party invitations and match statistics are social simulation features; they are not a substitute for the full playable game modes.")
    var game_picker := OptionButton.new()
    game_picker.custom_minimum_size = Vector2(0, 40)
    for game_data in catalog:
        game_picker.add_item(str(game_data.get("title", "Game")))
        if str(game_data.get("id", "")) == _party_game_id:
            game_picker.select(game_picker.item_count - 1)
    game_picker.item_selected.connect(func(index: int) -> void:
        if index >= 0 and index < catalog.size():
            _party_game_id = str(catalog[index].get("id", "tactical_breach"))
    )
    _content.add_child(game_picker)
    _add_section_title("NEARBY PLAYERS  •  " + str(_party_invites.size()) + " INVITED")
    var player := get_parent().get_node_or_null("Dara") as Node3D
    var citizens := get_tree().get_nodes_in_group("city_citizen")
    var shown := 0
    for citizen in citizens:
        if not is_instance_valid(citizen) or not citizen.has_method("get_ai_snapshot"):
            continue
        if player != null and citizen.global_position.distance_to(player.global_position) > 120.0:
            continue
        var person: Dictionary = citizen.call("get_ai_snapshot")
        var citizen_id := str(person.get("id", person.get("citizen_id", "")))
        if citizen_id.is_empty():
            continue
        var person_name := str(person.get("name", "Resident"))
        var invite := Button.new()
        var selected := _party_invites.has(citizen_id)
        invite.text = ("✓  " if selected else "+  ") + person_name + "  •  " + str(person.get("occupation", "resident"))
        invite.custom_minimum_size = Vector2(0, 38)
        invite.toggle_mode = true
        invite.button_pressed = selected
        invite.pressed.connect(_toggle_party_invite.bind(citizen_id))
        _content.add_child(invite)
        shown += 1
        if shown >= 16:
            break
    if shown == 0:
        _add_body("No nearby NPC phones detected. Move closer to residents to invite them.")
    var party := Button.new()
    party.text = "START NPC SOCIAL MATCH  (" + str(_party_invites.size()) + " INVITES)"
    party.custom_minimum_size = Vector2(0, 48)
    party.pressed.connect(_start_phone_party_match)
    _content.add_child(party)
    if not _last_party_result.is_empty():
        _add_section_title("LAST NPC PARTY RESULT")
        _add_stat("GAME", str(_last_party_result.get("game_title", "Game")))
        _add_stat("TEAM RESULT", "VICTORY" if bool(_last_party_result.get("won", false)) else "DEFEAT")
        _add_stat("NPCs JOINED", str(_last_party_result.get("accepted_count", 0)) + " / " + str(_last_party_result.get("invited_count", 0)))
        for member in _last_party_result.get("roster", []):
            _add_body("• " + str(member.get("name", "NPC")) + "  |  skill " + str(member.get("skill", 0.0)))

func _toggle_party_invite(citizen_id: String) -> void:
    if _party_invites.has(citizen_id):
        _party_invites.erase(citizen_id)
    else:
        _party_invites.append(citizen_id)
    _refresh_content()

func _start_phone_party_match() -> void:
    if _life == null or not _life.has_method("play_phone_party_game"):
        _last_party_result = {"started": false, "reason": "life_sim_offline"}
        _add_body("Phone party service is offline.")
        return
    _last_party_result = _life.call("play_phone_party_game", _party_game_id, _party_invites, 12)
    _party_invites.clear()
    _refresh_content()

func _launch_tactical_breach() -> void:
    var scene := load("res://scenes/games/tactical_fps_match.tscn") as PackedScene
    if scene == null:
        _add_body("Tactical Breach scene could not be loaded.")
        return
    var game := scene.instantiate()
    var roster: Array[Dictionary] = []
    for citizen in get_tree().get_nodes_in_group("city_citizen"):
        if not is_instance_valid(citizen) or not citizen.has_method("get_ai_snapshot"):
            continue
        var snapshot: Dictionary = citizen.call("get_ai_snapshot")
        var citizen_id := str(snapshot.get("id", ""))
        if not _party_invites.has(citizen_id):
            continue
        var traits: Dictionary = snapshot.get("personality_traits", {})
        var courage := float(traits.get("courage", 0.55))
        var discipline := float(traits.get("discipline", 0.55))
        var skill := clampf(0.5 + courage * 0.28 + discipline * 0.17, 0.45, 0.95)
        roster.append({"id": citizen_id, "name": str(snapshot.get("name", "Squadmate")), "occupation": str(snapshot.get("occupation", "resident")), "skill": skill})
        if roster.size() >= 4:
            break
    if game.has_method("set_party_roster"):
        game.call("set_party_roster", roster)
    _party_invites.clear()
    var player := get_parent().get_node_or_null("Dara") as CharacterBody3D
    if player != null:
        player.set_physics_process(false)
        var player_camera := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
        if player_camera != null:
            player_camera.current = false
    game.name = "PhoneTacticalBreach"
    if game.has_signal("game_exited"):
        game.game_exited.connect(func() -> void:
            if is_instance_valid(player):
                player.set_physics_process(true)
                var player_camera := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
                if player_camera != null:
                    player_camera.current = true
            game.queue_free()
            set_phone_open(true)
        )
    get_parent().add_child(game)
    set_phone_open(false)


func _build_browser() -> void:
    _add_section_title("ZERO SEARCH // WORLD WEB")
    _add_body("OFFLINE WORLD DATABASE  •  " + str(_phone_browser.get_page_count()) + " VERIFIED GAME PAGES")
    _add_body("This prototype searches the simulated ZERO MERCY network. It does not access the real internet.")
    var search_row := HBoxContainer.new()
    var query_input := LineEdit.new()
    query_input.placeholder_text = "Search jobs, cars, news, health..."
    query_input.text = _browser_query
    query_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    query_input.custom_minimum_size.y = 42
    query_input.text_submitted.connect(_submit_browser_search)
    search_row.add_child(query_input)
    var search_button := Button.new()
    search_button.text = "GO"
    search_button.custom_minimum_size = Vector2(54, 42)
    search_button.pressed.connect(func() -> void: _submit_browser_search(query_input.text))
    search_row.add_child(search_button)
    _content.add_child(search_row)
    var quick_row := HBoxContainer.new()
    var home_button := Button.new()
    home_button.text = "HOME"
    home_button.pressed.connect(func() -> void:
        _browser_page_id = ""
        _browser_query = ""
        _browser_view_mode = "search"
        _refresh_content()
    )
    quick_row.add_child(home_button)
    var history_button := Button.new()
    history_button.text = "HISTORY"
    history_button.pressed.connect(_show_browser_history)
    quick_row.add_child(history_button)
    var saved_button := Button.new()
    saved_button.text = "BOOKMARKS"
    saved_button.pressed.connect(_show_browser_bookmarks)
    quick_row.add_child(saved_button)
    _content.add_child(quick_row)
    if not _browser_page_id.is_empty():
        _render_browser_page(_browser_page_id)
        return
    if _browser_view_mode == "history":
        _add_section_title("RECENTLY VISITED")
        var history_items: Array = _phone_browser.get_history()
        if history_items.is_empty():
            _add_body("No browsing history yet.")
        for history_item in history_items:
            _add_browser_result(_phone_browser.get_page(str(history_item.get("id", ""))))
    elif _browser_view_mode == "bookmarks":
        _add_section_title("SAVED PAGES")
        var saved_items: Array = _phone_browser.get_bookmarks()
        if saved_items.is_empty():
            _add_body("No saved pages yet.")
        for saved_item in saved_items:
            _add_browser_result(saved_item)
    elif not _browser_query.is_empty():
        _add_section_title("SEARCH RESULTS // " + _browser_query.to_upper())
        var results: Array = _phone_browser.search(_browser_query, 12)
        if results.is_empty():
            _add_body("No matching pages found. Try a shorter keyword.")
        for result in results:
            _add_browser_result(result)
    else:
        _add_section_title("TRENDING NETWORK DESTINATIONS")
        for result in _phone_browser.search("", 8):
            _add_browser_result(result)
    _add_stat("NETWORK", "LOCAL SIMULATION")
    _add_stat("PRIVACY", "NO EXTERNAL REQUESTS")


func _submit_browser_search(query: String) -> void:
    _browser_query = query.strip_edges()
    _browser_view_mode = "search"
    _browser_page_id = ""
    _browser_status = "SEARCH COMPLETE"
    _refresh_content()


func _add_browser_result(page: Dictionary) -> void:
    var result_button := Button.new()
    result_button.text = str(page.get("title", "PAGE")) + "\\n" + str(page.get("domain", "world.zero")) + "  •  " + str(page.get("snippet", ""))
    result_button.custom_minimum_size = Vector2(0, 72)
    result_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    result_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result_button.pressed.connect(_open_browser_page.bind(str(page.get("id", ""))))
    _content.add_child(result_button)


func _open_browser_page(page_id: String) -> void:
    var page: Dictionary = _phone_browser.visit(page_id)
    if page.is_empty():
        return
    _browser_page_id = page_id
    _refresh_content()


func _render_browser_page(page_id: String) -> void:
    var page: Dictionary = _phone_browser.get_page(page_id)
    if page.is_empty():
        _browser_page_id = ""
        _add_body("This page is no longer available.")
        return
    _add_section_title(str(page.get("title", "WORLD PAGE")))
    _add_stat("ADDRESS", str(page.get("domain", "world.zero")))
    _add_stat("CATEGORY", str(page.get("category", "general")).to_upper())
    _add_body(str(page.get("body", "")))
    var saved := false
    for item in _phone_browser.get_bookmarks():
        if str(item.get("id", "")) == page_id:
            saved = true
            break
    var bookmark_button := Button.new()
    bookmark_button.text = "REMOVE BOOKMARK" if saved else "SAVE BOOKMARK"
    bookmark_button.pressed.connect(func() -> void:
        _phone_browser.toggle_bookmark(page_id)
        _refresh_content()
    )
    _content.add_child(bookmark_button)
    var back := Button.new()
    back.text = "BACK TO SEARCH"
    back.pressed.connect(func() -> void:
        _browser_page_id = ""
        _refresh_content()
    )
    _content.add_child(back)


func _show_browser_history() -> void:
    _browser_page_id = ""
    _browser_query = ""
    _browser_view_mode = "history"
    _refresh_content()


func _show_browser_bookmarks() -> void:
    _browser_page_id = ""
    _browser_query = ""
    _browser_view_mode = "bookmarks"
    _refresh_content()


func _build_social_network() -> void:
    _add_section_title("ZERO SOCIAL // GLOBAL NETWORK")
    var owner_id := _get_phone_owner_id()
    if owner_id.is_empty() or _life == null or not _life.has_method("get_phone_social_profile"):
        _add_body("Social identity is unavailable. Connect the player profile first.")
        return
    var profile: Dictionary = _life.call("get_phone_social_profile", owner_id)
    _add_body("IDENTITY VERIFIED  •  " + str(profile.get("name", "RESIDENT")).to_upper())
    _add_stat("FOLLOWERS", str((profile.get("followers", []) as Array).size()))
    _add_stat("FOLLOWING", str((profile.get("following", []) as Array).size()))
    _add_stat("POSTS", str(profile.get("post_count", 0)))
    _add_stat("SOCIAL INFLUENCE", str(profile.get("influence_score", 0)))
    var modes := HBoxContainer.new()
    for mode in ["all", "following", "trending", "search", "discover", "profile"]:
        var button := Button.new()
        button.text = mode.to_upper()
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func() -> void:
            _social_feed_mode = mode
            _refresh_content()
        )
        modes.add_child(button)
    _content.add_child(modes)
    if _social_feed_mode == "search":
        var search_row := HBoxContainer.new()
        var search_input := LineEdit.new()
        search_input.placeholder_text = "Search residents, topics or posts..."
        search_input.text = _social_search_query
        search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        search_row.add_child(search_input)
        var search_button := Button.new()
        search_button.text = "SEARCH"
        search_button.pressed.connect(func() -> void:
            _social_search_query = search_input.text.strip_edges()
            _refresh_content()
        )
        search_row.add_child(search_button)
        _content.add_child(search_row)
        _add_section_title("SEARCH RESULTS")
        var search_results: Array = _life.call("search_phone_social_posts", owner_id, _social_search_query, 30) if _life.has_method("search_phone_social_posts") else []
        if search_results.is_empty():
            _add_body("No matching resident posts. Try a name, topic or keyword.")
        for result in search_results:
            _render_social_post(result, owner_id, true)
        return
    if _social_feed_mode == "trending":
        _add_section_title("TRENDING RESIDENT POSTS")
        var trending_posts: Array = _life.call("get_phone_trending_feed", owner_id, 30) if _life.has_method("get_phone_trending_feed") else []
        if trending_posts.is_empty():
            _add_body("The network is quiet. Trending posts will appear as residents interact.")
        for trending_post in trending_posts:
            _render_social_post(trending_post, owner_id, true)
        return
    if _social_feed_mode == "discover":
        _build_social_discover(owner_id)
        return
    if _social_feed_mode == "profile":
        _add_section_title("MY PROFILE")
        _add_stat("RESIDENT ID", owner_id)
        _add_stat("OCCUPATION", str(profile.get("occupation", "Resident")))
        _add_stat("CITY", str(profile.get("city", "Unknown")))
        var own_standing: Dictionary = _life.call("get_resident_reputation", owner_id) if _life.has_method("get_resident_reputation") else {}
        _add_stat("PUBLIC STANDING", str(own_standing.get("standing", "ordinary")).to_upper())
        _add_stat("REPUTATION", str(snappedf(float(own_standing.get("reputation", 0.0)), 0.01)))
        _add_stat("COMMUNITY RESPECT", str(snappedf(float(own_standing.get("respect", 0.0)), 0.01)))
        _add_stat("TOTAL LIKES", str(profile.get("total_likes", 0)))
        _add_stat("TOTAL COMMENTS", str(profile.get("total_comments", 0)))
        _add_section_title("FOLLOWING")
        var following_ids: Array = profile.get("following", [])
        if following_ids.is_empty():
            _add_body("You are not following anyone yet. Open DISCOVER to find residents.")
        for followed_id_value in following_ids:
            var followed_id := str(followed_id_value)
            var followed_profile: Dictionary = _life.call("get_phone_social_profile", followed_id)
            var following_row := HBoxContainer.new()
            var following_name := Label.new()
            following_name.text = str(followed_profile.get("name", followed_id))
            following_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            following_row.add_child(following_name)
            var unfollow_button := Button.new()
            unfollow_button.text = "UNFOLLOW"
            unfollow_button.pressed.connect(func() -> void:
                _life.call("unfollow_phone_resident", owner_id, followed_id)
                _refresh_content()
            )
            following_row.add_child(unfollow_button)
            _content.add_child(following_row)
        _add_section_title("MY POSTS")
        var own_posts: Array = profile.get("posts", [])
        own_posts.reverse()
        for post in own_posts:
            _render_social_post(post, owner_id, false)
        if own_posts.is_empty():
            _add_body("You have not published anything yet.")
        return
    _add_section_title("PUBLISH A POST")
    var composer := TextEdit.new()
    composer.placeholder_text = "What's happening in your world?"
    composer.custom_minimum_size = Vector2(0, 76)
    composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_child(composer)
    var publish := Button.new()
    publish.text = "PUBLISH TO ZERO SOCIAL"
    publish.custom_minimum_size.y = 42
    publish.pressed.connect(func() -> void:
        var message := composer.text.strip_edges()
        if not message.is_empty() and _life.has_method("publish_phone_post"):
            if _life.call("publish_phone_post", owner_id, message, "resident"):
                _refresh_content()
    )
    _content.add_child(publish)
    _add_section_title("FOLLOWING FEED" if _social_feed_mode == "following" else "GLOBAL RESIDENT FEED")
    var posts: Array = _life.call("get_phone_network_feed", owner_id, 35, _social_feed_mode == "following")
    if posts.is_empty():
        _add_body("No posts in this feed yet. Follow residents or publish the first update.")
    for post in posts:
        _render_social_post(post, owner_id, true)


func _render_social_post(post: Dictionary, owner_id: String, allow_reactions: bool) -> void:
    var card := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.075, 0.98)
    style.border_color = Color(0.0, 0.72, 0.88, 0.62)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    card.add_theme_stylebox_override("panel", style)
    _content.add_child(card)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 5)
    card.add_child(body)
    var author := Label.new()
    author.text = str(post.get("author", post.get("author_name", post.get("author_id", "Resident")))) + "  •  DAY " + str(post.get("day", 1))
    author.add_theme_color_override("font_color", Color(0.1, 0.9, 1.0))
    body.add_child(author)
    var message := Label.new()
    message.text = str(post.get("text", post.get("caption", post.get("title", ""))))
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98))
    body.add_child(message)
    var stats := Label.new()
    stats.text = "♥ " + str(post.get("likes", 0)) + "     COMMENTS " + str(post.get("comments", 0)) + "     " + str(post.get("mood", post.get("topic", "WORLD")))
    stats.add_theme_color_override("font_color", Color(0.35, 0.72, 0.82))
    stats.add_theme_font_size_override("font_size", 10)
    body.add_child(stats)
    if allow_reactions:
        var actions := HBoxContainer.new()
        var like := Button.new()
        like.text = "♥ LIKE"
        like.pressed.connect(func() -> void:
            if _life.has_method("react_to_phone_post"):
                _life.call("react_to_phone_post", owner_id, str(post.get("id", "")))
                _refresh_content()
        )
        actions.add_child(like)
        var comment_input := LineEdit.new()
        comment_input.placeholder_text = "Write a comment..."
        comment_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actions.add_child(comment_input)
        var send_comment := Button.new()
        send_comment.text = "SEND"
        send_comment.pressed.connect(func() -> void:
            if _life.has_method("add_phone_social_comment") and _life.call("add_phone_social_comment", owner_id, str(post.get("id", "")), comment_input.text):
                _refresh_content()
        )
        actions.add_child(send_comment)
        body.add_child(actions)
    var comments: Array = post.get("comment_list", [])
    for comment in comments.slice(maxi(0, comments.size() - 3)):
        var comment_label := Label.new()
        comment_label.text = "↳ " + str(comment.get("author", comment.get("author_id", "Resident"))) + ": " + str(comment.get("text", ""))
        comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        comment_label.add_theme_color_override("font_color", Color(0.58, 0.72, 0.8))
        body.add_child(comment_label)


func _build_social_discover(owner_id: String) -> void:
    _add_section_title("DISCOVER RESIDENTS")
    var suggestions: Array = _life.call("get_phone_suggested_residents", owner_id, 24)
    if suggestions.is_empty():
        _add_body("No new residents to recommend.")
    for resident in suggestions:
        var row := HBoxContainer.new()
        var details := Label.new()
        var resident_id := str(resident.get("id", ""))
        var standing: Dictionary = _life.call("get_resident_reputation", resident_id) if _life.has_method("get_resident_reputation") else {}
        details.text = str(resident.get("name", "Resident")) + "\\n" + str(resident.get("occupation", "Resident")) + "  •  " + str(resident.get("followers", 0)) + " followers" + "\\n" + str(standing.get("standing", "ordinary")).to_upper() + "  •  INFLUENCE " + str(standing.get("influence", 0))
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(details)
        var follow := Button.new()
        follow.text = "FOLLOW"
        follow.pressed.connect(func() -> void:
            _life.call("follow_phone_resident", owner_id, str(resident.get("id", "")))
            _refresh_content()
        )
        row.add_child(follow)
        _content.add_child(row)
