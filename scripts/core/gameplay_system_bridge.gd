extends Node
## Connects the standalone gameplay modules to the live player and world.
const INVENTORY_SCRIPT := preload("res://scripts/player/inventory_system.gd")
const NEEDS_SCRIPT := preload("res://scripts/player/player_needs_system.gd")
const SKILLS_SCRIPT := preload("res://scripts/player/skill_progression_system.gd")
const CYBERNETICS_SCRIPT := preload("res://scripts/player/cybernetic_upgrade_system.gd")
const HACKING_SCRIPT := preload("res://scripts/world/hacking_network_system.gd")
const MISSION_TRACKER_SCRIPT := preload("res://scripts/world/mission_objective_tracker.gd")
const EVENT_SCHEDULER_SCRIPT := preload("res://scripts/world/dynamic_event_scheduler.gd")

var player: Node
var inventory: Node
var needs: Node
var skills: Node
var cybernetics: Node
var hacking: Node
var mission_tracker: Node
var event_scheduler: Node

func _process(_delta: float) -> void:
	if is_instance_valid(event_scheduler) and get_node_or_null("/root/GameSession") != null:
		event_scheduler.call("update_simulation_time", float(GameSession.day_time_hours))

func bind_player(target: Node) -> void:
	player = target
	var player_systems := Node.new()
	player_systems.name = "GameplaySystems"
	player.add_child(player_systems)
	inventory = _attach_system(player_systems, "Inventory", INVENTORY_SCRIPT)
	needs = _attach_system(player_systems, "Needs", NEEDS_SCRIPT)
	skills = _attach_system(player_systems, "Skills", SKILLS_SCRIPT)
	cybernetics = _attach_system(player_systems, "Cybernetics", CYBERNETICS_SCRIPT)
	hacking = _attach_system(player_systems, "HackingNetwork", HACKING_SCRIPT)
	for skill_id in ["combat", "hacking", "driving", "stealth", "crafting", "engineering"]:
		skills.call("register_skill", skill_id)

func bind_world(world: Node) -> void:
	var world_systems := Node.new()
	world_systems.name = "WorldGameplaySystems"
	world.add_child(world_systems)
	mission_tracker = _attach_system(world_systems, "ObjectiveTracker", MISSION_TRACKER_SCRIPT)
	event_scheduler = _attach_system(world_systems, "DynamicEvents", EVENT_SCHEDULER_SCRIPT)

func award_skill_xp(skill_id: String, amount: float) -> int:
	if not is_instance_valid(skills):
		return 0
	return int(skills.call("add_xp", skill_id, amount))

func give_item(item_id: String, amount: int = 1) -> int:
	if not is_instance_valid(inventory):
		return amount
	return int(inventory.call("add_item", item_id, amount))

func consume_supplies(nutrition: float, hydration: float = 0.0) -> void:
	if is_instance_valid(needs):
		needs.call("consume_food", nutrition, hydration)

func get_player_performance() -> float:
	if not is_instance_valid(needs):
		return 1.0
	return float(needs.call("get_performance_multiplier"))

func _attach_system(parent: Node, node_name: String, script_resource: Script) -> Node:
	var system := Node.new()
	system.name = node_name
	system.set_script(script_resource)
	parent.add_child(system)
	return system

func get_inventory_snapshot() -> Dictionary:
	if not is_instance_valid(inventory):
		return {}
	return inventory.call("get_snapshot")

func restore_inventory_snapshot(snapshot: Dictionary) -> bool:
	if not is_instance_valid(inventory):
		return false
	return bool(inventory.call("restore_snapshot", snapshot))

func get_item_count(item_id: String) -> int:
	if not is_instance_valid(inventory):
		return 0
	return int(inventory.call("get_item_count", item_id))

func get_needs_snapshot() -> Dictionary:
	if not is_instance_valid(needs):
		return {}
	return needs.call("get_snapshot")

func restore_needs_snapshot(snapshot: Dictionary) -> bool:
	if not is_instance_valid(needs):
		return false
	return bool(needs.call("restore_snapshot", snapshot))

func use_inventory_item(item_id: String) -> bool:
	if not is_instance_valid(inventory):
		return false
	var nutrition := 0.0
	var hydration := 0.0
	var health_restore := 0.0
	match item_id:
		"food_ration":
			nutrition = 35.0
			hydration = 3.0
		"water_bottle":
			hydration = 40.0
		"medkit":
			health_restore = 45.0
		_:
			return false
	if not bool(inventory.call("has_item", item_id, 1)):
		return false
	if not bool(inventory.call("remove_item", item_id, 1)):
		return false
	if nutrition > 0.0 or hydration > 0.0:
		needs.call("consume_food", nutrition, hydration)
	if health_restore > 0.0 and is_instance_valid(player):
		player.set("health", minf(float(player.get("max_health")), float(player.get("health")) + health_restore))
		player.emit_signal("health_changed", player.get("health"), player.get("max_health"))
	return true
