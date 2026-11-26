extends Node
## Small versioned JSON save manager. Add as Autoload named SaveManager.

const SAVE_PATH := "user://zero_mercy_save.json"
const SAVE_VERSION := 1


func save_game(payload: Dictionary) -> bool:
	var document := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"payload": payload
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing. Error: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(document, "\t"))
	return file.get_error() == OK


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open save file. Error: " + str(FileAccess.get_open_error()))
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is invalid JSON.")
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("Save version is not supported by this build.")
		return {}
	var payload: Variant = parsed.get("payload", {})
	return payload if typeof(payload) == TYPE_DICTIONARY else {}


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK


func save_player_state(player: Node3D) -> bool:
	if not is_instance_valid(player):
		return false
	var payload := load_game()
	payload["player_state"] = {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rotation": [player.global_rotation.x, player.global_rotation.y, player.global_rotation.z],
		"health": float(player.get("health")),
		"stamina": float(player.get("stamina")),
		"ammo_in_magazine": int(player.get("ammo_in_magazine")),
		"reserve_ammo": int(player.get("reserve_ammo"))
	}
	if get_node_or_null("/root/GameSession") != null:
		payload["world_session"] = {
			"day_time_hours": float(GameSession.day_time_hours),
			"time_scale": float(GameSession.time_scale),
			"wanted_level": int(GameSession.wanted_level),
			"wanted_remaining_ms": maxi(0, int(GameSession.wanted_until_ms) - Time.get_ticks_msec())
		}
	return save_game(payload)


func restore_player_state(player: Node3D) -> bool:
	if not is_instance_valid(player):
		return false
	var payload := load_game()
	var state: Variant = payload.get("player_state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var position_data: Variant = state.get("position", [])
	var rotation_data: Variant = state.get("rotation", [])
	if typeof(position_data) != TYPE_ARRAY or typeof(rotation_data) != TYPE_ARRAY:
		return false
	if position_data.size() != 3 or rotation_data.size() != 3:
		return false
	for value in position_data + rotation_data:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		if not is_finite(float(value)):
			return false
	var saved_health: Variant = state.get("health", player.get("max_health"))
	var saved_stamina: Variant = state.get("stamina", player.get("stamina_max"))
	var saved_magazine: Variant = state.get("ammo_in_magazine", player.get("magazine_size"))
	var saved_reserve: Variant = state.get("reserve_ammo", 0)
	for value in [saved_health, saved_stamina, saved_magazine, saved_reserve]:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		if not is_finite(float(value)):
			return false
	if bool(player.get("is_dead")):
		player.call("respawn")
	player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	player.global_rotation = Vector3(float(rotation_data[0]), float(rotation_data[1]), float(rotation_data[2]))
	player.set("velocity", Vector3.ZERO)
	player.set("_spawn_transform", player.global_transform)
	player.set("health", clampf(float(saved_health), 1.0, float(player.get("max_health"))))
	player.set("stamina", clampf(float(saved_stamina), 0.0, float(player.get("stamina_max"))))
	player.set("ammo_in_magazine", clampi(int(saved_magazine), 0, int(player.get("magazine_size"))))
	player.set("reserve_ammo", maxi(0, int(saved_reserve)))
	player.emit_signal("health_changed", player.get("health"), player.get("max_health"))
	player.emit_signal("stamina_changed", player.get("stamina"), player.get("stamina_max"))
	player.emit_signal("ammo_changed", player.get("ammo_in_magazine"), player.get("reserve_ammo"))
	var session_data: Variant = payload.get("world_session", {})
	if typeof(session_data) == TYPE_DICTIONARY and get_node_or_null("/root/GameSession") != null:
		var saved_hour := float(session_data.get("day_time_hours", GameSession.day_time_hours))
		var saved_scale := float(session_data.get("time_scale", GameSession.time_scale))
		var saved_wanted := int(session_data.get("wanted_level", 0))
		var remaining_ms := int(session_data.get("wanted_remaining_ms", 0))
		if is_finite(saved_hour) and is_finite(saved_scale):
			GameSession.day_time_hours = fposmod(saved_hour, 24.0)
			GameSession.time_scale = clampf(saved_scale, 0.0, 20.0)
			GameSession.wanted_level = clampi(saved_wanted, 0, GameSession.MAX_WANTED_LEVEL)
			GameSession.wanted_until_ms = Time.get_ticks_msec() + clampi(remaining_ms, 0, GameSession.WANTED_DURATION_MS)
			GameSession.call("_sync_wanted_to_player")
	return true
