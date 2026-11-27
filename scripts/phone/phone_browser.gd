extends RefCounted
## Offline in-world browser. Pages are fictional ZERO MERCY network records, not live internet.
const CONFIG_PATH := "user://zero_link_browser.cfg"
const PAGES := [
    {"id":"net_news","title":"NEO WORLD NEWS","domain":"news.zero","category":"news","tags":["news","city","world","politics","weather","crime"],"snippet":"Reports from connected cities, public institutions and residents.","body":"NEO WORLD NEWS\\n\\nThe global city network publishes verified public bulletins, local reports and resident stories. Updates in this prototype are generated from the simulated world; this page does not connect to real news services."},
    {"id":"net_jobs","title":"WORKFORCE EXCHANGE","domain":"jobs.zero","category":"work","tags":["job","jobs","work","career","salary","hiring"],"snippet":"Browse simulated vacancies and career information across the city network.","body":"WORKFORCE EXCHANGE\\n\\nResidents can explore career paths, training and fictional vacancies. Job listings are world-simulation data, not real employment offers."},
    {"id":"net_market","title":"GLOBAL MARKET INDEX","domain":"market.zero","category":"economy","tags":["market","economy","prices","trade","business","money"],"snippet":"Commodity prices, local supply and demand, and trade indicators.","body":"GLOBAL MARKET INDEX\\n\\nFood, water, medicine, electronics, clothing and fuel prices are driven by the local economy simulation. Values may change as the world advances."},
    {"id":"net_transit","title":"CITY TRANSIT GRID","domain":"transit.zero","category":"travel","tags":["bus","taxi","transport","travel","route","metro"],"snippet":"Public transport, mobility services and city travel information.","body":"CITY TRANSIT GRID\\n\\nThe transit directory describes simulated mobility services. Routes and availability depend on which transport systems are active in the current build."},
    {"id":"net_education","title":"OPEN KNOWLEDGE CAMPUS","domain":"learn.zero","category":"education","tags":["school","study","education","university","science","learn"],"snippet":"Schools, learning paths and public research resources.","body":"OPEN KNOWLEDGE CAMPUS\\n\\nExplore education stages, technical institutes and research topics in the fictional network."},
    {"id":"net_health","title":"CIVIC HEALTH DIRECTORY","domain":"health.zero","category":"health","tags":["health","hospital","doctor","medicine","clinic"],"snippet":"Public clinic directory and general wellness information.","body":"CIVIC HEALTH DIRECTORY\\n\\nA fictional directory of clinics and public health services. It is not medical advice or a real emergency service."},
    {"id":"net_culture","title":"CULTURE STREAM","domain":"culture.zero","category":"culture","tags":["music","art","film","culture","events","festival"],"snippet":"Music, art, exhibitions and events across the neon cities.","body":"CULTURE STREAM\\n\\nDiscover simulated cultural events and creative communities from the ZERO MERCY world."},
    {"id":"net_vehicles","title":"MOTOR DISTRICT","domain":"motor.zero","category":"vehicles","tags":["car","cars","vehicle","motor","racing","garage"],"snippet":"Vehicle technology, ownership guides and motor district updates.","body":"MOTOR DISTRICT\\n\\nVehicle listings and stories are fictional world content. Real-world purchasing is not available through this browser."},
    {"id":"net_tech","title":"TECHNOLOGY FRONTIER","domain":"tech.zero","category":"technology","tags":["technology","ai","robot","cyber","computer","research"],"snippet":"Artificial intelligence, robotics and city infrastructure research.","body":"TECHNOLOGY FRONTIER\\n\\nResearch briefings cover synthetic intelligence, robotics, energy grids and connected infrastructure inside the game world."},
    {"id":"net_safety","title":"CIVIC SAFETY ALERTS","domain":"safety.zero","category":"public safety","tags":["police","safety","emergency","alert","security","crime"],"snippet":"Simulated public safety notices and community guidance.","body":"CIVIC SAFETY ALERTS\\n\\nThis is a fictional public information page. Real emergencies must be reported through real local emergency services."},
    {"id":"net_realestate","title":"URBAN PROPERTY EXCHANGE","domain":"homes.zero","category":"property","tags":["house","home","property","rent","apartment","real estate"],"snippet":"Residential districts, housing and simulated rental market information.","body":"URBAN PROPERTY EXCHANGE\\n\\nExplore the simulated housing market, neighbourhood profiles and resident property activity."},
    {"id":"net_wildlife","title":"PLANET BIOSPHERE","domain":"bio.zero","category":"nature","tags":["animal","wildlife","forest","nature","climate","river"],"snippet":"Wildlife, ecosystems, climate and conservation reports.","body":"PLANET BIOSPHERE\\n\\nA field guide to the simulated planet's animals, habitats, climate regions and conservation events."}
]
var _history: Array = []
var _bookmarks: Array[String] = []

func _init() -> void:
    _load_state()

func search(query: String, limit: int = 10) -> Array:
    var normalized := query.strip_edges().to_lower()
    if normalized.is_empty():
        return PAGES.duplicate(true).slice(0, mini(limit, PAGES.size()))
    var terms := normalized.split(" ", false)
    var ranked: Array = []
    for page in PAGES:
        var score := 0
        var title := str(page.get("title", "")).to_lower()
        var domain := str(page.get("domain", "")).to_lower()
        var tags: Array = page.get("tags", [])
        for term in terms:
            if term.length() < 2:
                continue
            if title.contains(term):
                score += 5
            if domain.contains(term):
                score += 4
            if str(page.get("category", "")).to_lower().contains(term):
                score += 3
            for tag in tags:
                if str(tag).to_lower().contains(term):
                    score += 2
        if score > 0:
            var result: Dictionary = page.duplicate(true)
            result["score"] = score
            ranked.append(result)
    ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
    return ranked.slice(0, mini(maxi(1, limit), ranked.size()))

func get_page(page_id: String) -> Dictionary:
    for page in PAGES:
        if str(page.get("id", "")) == page_id:
            return page.duplicate(true)
    return {}

func visit(page_id: String) -> Dictionary:
    var page := get_page(page_id)
    if page.is_empty():
        return {}
    _history.push_front({"id":page_id,"title":str(page.get("title", "")),"domain":str(page.get("domain", "")),"visited_at":Time.get_datetime_string_from_system()})
    while _history.size() > 60:
        _history.pop_back()
    _save_state()
    return page

func toggle_bookmark(page_id: String) -> bool:
    if get_page(page_id).is_empty():
        return false
    if _bookmarks.has(page_id):
        _bookmarks.erase(page_id)
    else:
        _bookmarks.push_front(page_id)
    while _bookmarks.size() > 40:
        _bookmarks.pop_back()
    _save_state()
    return _bookmarks.has(page_id)

func get_history() -> Array:
    return _history.duplicate(true)

func get_bookmarks() -> Array:
    var result: Array = []
    for page_id in _bookmarks:
        var page := get_page(page_id)
        if not page.is_empty():
            result.append(page)
    return result

func get_page_count() -> int:
    return PAGES.size()

func _load_state() -> void:
    var config := ConfigFile.new()
    if config.load(CONFIG_PATH) != OK:
        return
    _history = config.get_value("browser", "history", [])
    _bookmarks = config.get_value("browser", "bookmarks", [])

func _save_state() -> void:
    var config := ConfigFile.new()
    config.set_value("browser", "history", _history)
    config.set_value("browser", "bookmarks", _bookmarks)
    config.save(CONFIG_PATH)
