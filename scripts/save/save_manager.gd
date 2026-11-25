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
	if bool(player.get("is_dead")):
		player.call("respawn")
	player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	player.global_rotation = Vector3(float(rotation_data[0]), float(rotation_data[1]), float(rotation_data[2]))
	player.set("velocity", Vector3.ZERO)
	player.set("_spawn_transform", player.global_transform)
	player.set("health", clampf(float(state.get("health", player.get("max_health"))), 1.0, float(player.get("max_health"))))
	player.set("stamina", clampf(float(state.get("stamina", player.get("stamina_max"))), 0.0, float(player.get("stamina_max"))))
	player.set("ammo_in_magazine", clampi(int(state.get("ammo_in_magazine", player.get("magazine_size"))), 0, int(player.get("magazine_size"))))
	player.set("reserve_ammo", maxi(0, int(state.get("reserve_ammo", 0))))
	player.emit_signal("health_changed", player.get("health"), player.get("max_health"))
	player.emit_signal("stamina_changed", player.get("stamina"), player.get("stamina_max"))
	player.emit_signal("ammo_changed", player.get("ammo_in_magazine"), player.get("reserve_ammo"))
	return true
