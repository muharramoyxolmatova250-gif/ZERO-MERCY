extends RefCounted
## Persistent local device preferences for ZERO LINK / DARA OS.
const CONFIG_PATH := "user://phone_settings.cfg"
const DEFAULTS := {
    "wifi_enabled": true,
    "bluetooth_enabled": true,
    "sound_enabled": true,
    "notifications_enabled": true,
    "power_saver": false,
    "volume": 0.75
}

var _settings: Dictionary = DEFAULTS.duplicate(true)

func _init() -> void:
    load_settings()

func load_settings() -> void:
    var config := ConfigFile.new()
    var error := config.load(CONFIG_PATH)
    if error == OK:
        for key in DEFAULTS:
            _settings[key] = config.get_value("device", key, DEFAULTS[key])
    _apply_audio()

func get_settings() -> Dictionary:
    return _settings.duplicate(true)

func get_setting(key: String, fallback: Variant = null) -> Variant:
    return _settings.get(key, fallback)

func set_setting(key: String, value: Variant) -> bool:
    if not DEFAULTS.has(key):
        return false
    if key == "volume":
        value = clampf(float(value), 0.0, 1.0)
    elif typeof(DEFAULTS[key]) == TYPE_BOOL:
        value = bool(value)
    _settings[key] = value
    var config := ConfigFile.new()
    for setting_key in _settings:
        config.set_value("device", setting_key, _settings[setting_key])
    var error := config.save(CONFIG_PATH)
    _apply_audio()
    return error == OK

func _apply_audio() -> void:
    if not _settings.get("sound_enabled", true):
        AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
        return
    var master := AudioServer.get_bus_index("Master")
    AudioServer.set_bus_mute(master, false)
    var volume := float(_settings.get("volume", 0.75))
    AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.001)))
