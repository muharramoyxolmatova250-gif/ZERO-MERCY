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
