extends Node
## Local market stock, demand and price pressure model.
var _goods: Dictionary = {}

func register_good(good_id: String, base_price: float, stock: int, restock_per_day: int = 0) -> bool:
	if good_id.is_empty():
		return false
	_goods[good_id] = {"base_price": maxf(0.01, base_price), "stock": maxi(0, stock), "demand": 0, "restock_per_day": maxi(0, restock_per_day), "sales": 0}
	return true

func request_purchase(good_id: String, quantity: int = 1) -> Dictionary:
	if not _goods.has(good_id) or quantity <= 0:
		return {"success": false, "reason": "invalid_request"}
	var good: Dictionary = _goods[good_id]
	if int(good.get("stock", 0)) < quantity:
		good["demand"] = int(good.get("demand", 0)) + quantity
		_goods[good_id] = good
		return {"success": false, "reason": "out_of_stock", "available": int(good.get("stock", 0))}
	var price := get_current_price(good_id)
	good["stock"] = int(good["stock"]) - quantity
	good["sales"] = int(good.get("sales", 0)) + quantity
	good["demand"] = maxi(0, int(good.get("demand", 0)) - quantity)
	_goods[good_id] = good
	return {"success": true, "quantity": quantity, "unit_price": price, "total": price * float(quantity)}

func get_current_price(good_id: String) -> float:
	if not _goods.has(good_id):
		return 0.0
	var good: Dictionary = _goods[good_id]
	var base := float(good.get("base_price", 1.0))
	var stock := int(good.get("stock", 0))
	var demand := int(good.get("demand", 0))
	var pressure := clampf(float(demand + 1) / float(stock + 1), 0.25, 3.0)
	return base * pressure

func restock_all() -> void:
	for good_id in _goods:
		var good: Dictionary = _goods[good_id]
		good["stock"] = int(good.get("stock", 0)) + int(good.get("restock_per_day", 0))
		_goods[good_id] = good

func get_market_snapshot() -> Dictionary:
	var total_stock := 0
	var total_sales := 0
	for good in _goods.values():
		total_stock += int(good.get("stock", 0))
		total_sales += int(good.get("sales", 0))
	return {"goods": _goods.size(), "total_stock": total_stock, "total_sales": total_sales}
