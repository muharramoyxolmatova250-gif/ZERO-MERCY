extends Node
## Safehouse registry with ownership, storage and upgrade levels.
signal safehouse_updated(safehouse_id: String)
var _safehouses: Dictionary = {}

func register_safehouse(safehouse_id: String, position: Vector3, price: int = 0) -> bool:
	if safehouse_id.is_empty() or _safehouses.has(safehouse_id) or price < 0:
		return false
	_safehouses[safehouse_id] = {"position": position, "price": price, "owned": false, "upgrade_level": 0, "storage": {}}
	return true

func purchase(safehouse_id: String, credits: int) -> int:
	if not _safehouses.has(safehouse_id):
		return credits
	var home: Dictionary = _safehouses[safehouse_id]
	if bool(home["owned"]) or credits < int(home["price"]):
		return credits
	home["owned"] = true
	_safehouses[safehouse_id] = home
	safehouse_updated.emit(safehouse_id)
	return credits - int(home["price"])

func upgrade(safehouse_id: String, cost: int, credits: int) -> int:
	if not _safehouses.has(safehouse_id) or cost < 0 or credits < cost:
		return credits
	var home: Dictionary = _safehouses[safehouse_id]
	if not bool(home["owned"]):
		return credits
	home["upgrade_level"] = int(home["upgrade_level"]) + 1
	_safehouses[safehouse_id] = home
	safehouse_updated.emit(safehouse_id)
	return credits - cost

func store_item(safehouse_id: String, item_id: String, amount: int) -> bool:
	if not _safehouses.has(safehouse_id) or item_id.is_empty() or amount <= 0:
		return false
	var home: Dictionary = _safehouses[safehouse_id]
	if not bool(home["owned"]):
		return false
	var storage: Dictionary = home["storage"]
	storage[item_id] = int(storage.get(item_id, 0)) + amount
	home["storage"] = storage
	_safehouses[safehouse_id] = home
	safehouse_updated.emit(safehouse_id)
	return true

func get_snapshot(safehouse_id: String) -> Dictionary:
	return _safehouses.get(safehouse_id, {}).duplicate(true)
