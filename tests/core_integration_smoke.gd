extends SceneTree
## Integration smoke test for the live ZERO MERCY main scene and its core system wiring.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main gameplay scene could not be loaded.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player := main.get_node_or_null("Dara")
	if player == null:
		_fail("Main scene did not create the Dara player.")
		return
	var game_session := root.get_node_or_null("GameSession")
	if game_session == null or game_session.get("player") != player:
		_fail("GameSession did not register the active player.")
		return

	var bridge := main.get_node_or_null("GameplaySystemBridge")
	if bridge == null:
		_fail("GameplaySystemBridge is missing from the live main scene.")
		return
	for path in [
		"Dara/GameplaySystems/Inventory",
		"Dara/GameplaySystems/Needs",
		"Dara/GameplaySystems/Skills",
		"Dara/GameplaySystems/Cybernetics",
		"Dara/GameplaySystems/HackingNetwork",
		"WorldGameplaySystems/ObjectiveTracker",
		"WorldGameplaySystems/DynamicEvents"
	]:
		if main.get_node_or_null(path) == null:
			_fail("Core gameplay module was not attached: " + path)
			return

	for node_name in [
		"DaraPhone",
		"DialogueUI",
		"MissionObjectiveDirector",
		"WorldLifeSimulation",
		"CitizenSpatialIndex",
		"SimulationAwarenessNetwork",
		"GlobalPopulationSimulation",
		"GlobalAirTraffic",
		"WorldSocietySimulation",
		"EarthRegionStreamer"
	]:
		if main.get_node_or_null(node_name) == null:
			_fail("Expected world/gameplay service is missing: " + node_name)
			return

	if get_root().get_node_or_null("MissionManager") == null:
		_fail("MissionManager autoload is unavailable.")
		return
	if get_root().get_node_or_null("DialogueManager") == null:
		_fail("DialogueManager autoload is unavailable.")
		return
	if get_root().get_node_or_null("SaveManager") == null:
		_fail("SaveManager autoload is unavailable.")
		return

	print("PASS Core integration: main scene, player registration, gameplay bridge, player modules, world services and core autoloads are connected.")
	main.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error("FAIL Core integration: " + message)
	quit(1)
