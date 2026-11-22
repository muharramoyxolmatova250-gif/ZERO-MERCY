extends Node
## Lightweight branching dialogue data loader.
## Dialogue files are JSON dictionaries with a start node and node map.

signal dialogue_started(dialogue_id: String)
signal line_presented(speaker: String, text: String, choices: Array)
signal dialogue_finished(dialogue_id: String)

var dialogue_id := ""
var dialogue_data: Dictionary = {}
var current_node_id := ""


func start_dialogue(id: String, path: String) -> bool:
	if dialogue_id != "":
		return false
	if not FileAccess.file_exists(path):
		push_warning("Dialogue file not found: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("nodes"):
		push_error("Dialogue file must contain a nodes object.")
		return false
	dialogue_id = id
	dialogue_data = parsed
	current_node_id = str(parsed.get("start", ""))
	dialogue_started.emit(dialogue_id)
	_present_current_node()
	return true


func choose(choice_index: int) -> void:
	if dialogue_id == "":
		return
	var nodes: Dictionary = dialogue_data.get("nodes", {})
	if not nodes.has(current_node_id):
		finish_dialogue()
		return
	var node: Dictionary = nodes[current_node_id]
	var choices: Array = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var next_id := str(choices[choice_index].get("next", ""))
	if next_id == "" or not nodes.has(next_id):
		finish_dialogue()
		return
	current_node_id = next_id
	_present_current_node()


func finish_dialogue() -> void:
	if dialogue_id == "":
		return
	var finished_id := dialogue_id
	dialogue_id = ""
	dialogue_data.clear()
	current_node_id = ""
	dialogue_finished.emit(finished_id)


func _present_current_node() -> void:
	var nodes: Dictionary = dialogue_data.get("nodes", {})
	if not nodes.has(current_node_id):
		finish_dialogue()
		return
	var node: Dictionary = nodes[current_node_id]
	line_presented.emit(
		str(node.get("speaker", "Unknown")),
		str(node.get("text", "")),
		node.get("choices", [])
	)
