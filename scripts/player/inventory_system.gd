extends Node
## Stack-based inventory with capacity, transfer and snapshot helpers.
signal inventory_changed
@export var slot_capacity := 36
var _stacks: Dictionary = {}

func add_item(item_id: String, amount: int = 1, max_stack: int = 99) -> int:
	if item_id.is_empty() or amount <= 0 or max_stack <= 0:
		return amount
	var remaining := amount
	var current: Dictionary = _stacks.get(item_id, {"count": 0, "max_stack": max_stack})
	var count := int(current.get("count", 0))
	var room := maxi(0, max_stack - count)
	var moved := mini(room, remaining)
	current["count"] = count + moved
	current["max_stack"] = max_stack
	_stacks[item_id] = current
	remaining -= moved
	while remaining > 0 and _stacks.size() < slot_capacity:
		moved = mini(max_stack, remaining)
		_stacks[item_id + "#" + str(_stacks.size())] = {"item_id": item_id, "count": moved, "max_stack": max_stack}
		remaining -= moved
	inventory_changed.emit()
	return remaining

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_item_count(item_id) < amount:
		return false
	var remaining := amount
	for key in _stacks.keys():
		var stack: Dictionary = _stacks[key]
		if str(stack.get("item_id", key)) != item_id:
			continue
		var take := mini(remaining, int(stack.get("count", 0)))
		stack["count"] = int(stack.get("count", 0)) - take
		remaining -= take
		if int(stack["count"]) <= 0:
			_stacks.erase(key)
		else:
			_stacks[key] = stack
		if remaining == 0:
			break
	inventory_changed.emit()
	return true

func get_item_count(item_id: String) -> int:
	var total := 0
	for key in _stacks:
		var stack: Dictionary = _stacks[key]
		if str(stack.get("item_id", key)) == item_id:
			total += int(stack.get("count", 0))
	return total

func has_item(item_id: String, amount: int = 1) -> bool:
	return amount > 0 and get_item_count(item_id) >= amount

func get_snapshot() -> Dictionary:
	return {"capacity": slot_capacity, "used_slots": _stacks.size(), "stacks": _stacks.duplicate(true)}
