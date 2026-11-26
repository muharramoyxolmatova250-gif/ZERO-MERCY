extends Node
## Lightweight branching dialogue runner; dialogue content is supplied as dictionaries.
signal dialogue_started(dialogue_id: String)
signal line_presented(speaker: String, text: String, choices: Array)
signal dialogue_finished(dialogue_id: String)
var _dialogues: Dictionary = {}
var _active_id := ""
var _active_node := ""

func register_dialogue(dialogue_id: String, nodes: Dictionary, start_node: String) -> bool:
	if dialogue_id.is_empty() or nodes.is_empty() or not nodes.has(start_node):
		return false
	_dialogues[dialogue_id] = {"nodes": nodes.duplicate(true), "start": start_node}
	return true

func start_dialogue(dialogue_id: String) -> bool:
	if not _dialogues.has(dialogue_id):
		return false
	_active_id = dialogue_id
	_active_node = str(_dialogues[dialogue_id]["start"])
	dialogue_started.emit(dialogue_id)
	_present_current()
	return true

func choose(choice_index: int) -> bool:
	if _active_id.is_empty():
		return false
	var node: Dictionary = _dialogues[_active_id]["nodes"].get(_active_node, {})
	var choices: Array = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return false
	var choice: Dictionary = choices[choice_index]
	var next_node := str(choice.get("next", ""))
	if next_node.is_empty() or not _dialogues[_active_id]["nodes"].has(next_node):
		finish_dialogue()
		return true
	_active_node = next_node
	_present_current()
	return true

func _present_current() -> void:
	var node: Dictionary = _dialogues[_active_id]["nodes"].get(_active_node, {})
	line_presented.emit(str(node.get("speaker", "")), str(node.get("text", "")), node.get("choices", []))

func finish_dialogue() -> void:
	if _active_id.is_empty():
		return
	var finished_id := _active_id
	_active_id = ""
	_active_node = ""
	dialogue_finished.emit(finished_id)

func is_active() -> bool:
	return not _active_id.is_empty()
