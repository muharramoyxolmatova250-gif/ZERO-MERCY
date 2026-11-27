extends CanvasLayer
## Dara's in-world phone: live NPC social feed, contacts, world news, life stats and map.
var _panel: PanelContainer
var _content: VBoxContainer
var _active_tab := "feed"
var _refresh_elapsed := 0.0
var _society: Node
var _life: Node
var _party_invites: Array[String] = []
var _party_game_id := "tactical_breach"
var _last_party_result: Dictionary = {}

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
    var viewport_size := get_viewport().get_visible_rect().size
    var phone_width := minf(450.0, viewport_size.x - 20.0)
    var phone_height := minf(660.0, viewport_size.y - 20.0)
    _panel.offset_left = -phone_width * 0.5
    _panel.offset_right = phone_width * 0.5
    _panel.offset_top = -phone_height * 0.5
    _panel.offset_bottom = phone_height * 0.5
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

    var tab_scroll := ScrollContainer.new()
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.custom_minimum_size.y = 38
    outer.add_child(tab_scroll)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 4)
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_scroll.add_child(tabs)
    for tab in ["feed", "media", "games", "news", "contacts", "life", "missions", "map"]:
        var button := Button.new()
        button.text = tab.to_upper()
        button.custom_minimum_size = Vector2(76, 34)
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
        "media":
            _build_media_hub()
        "games":
            _build_games_hub()
        "news":
            _build_news()
        "contacts":
            _build_contacts()
        "life":
            _build_life()
        "missions":
            _build_missions()
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

func _get_phone_owner_id() -> String:
    var player := get_parent().get_node_or_null("Dara")
    if player != null and player.has_method("get_ai_snapshot"):
        var snapshot: Dictionary = player.call("get_ai_snapshot")
        return str(snapshot.get("id", ""))
    return ""


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
