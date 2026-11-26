extends Node
## Validates recipes and calculates craftable output from an inventory-like dictionary.
var recipes: Dictionary = {}

func register_recipe(recipe_id: String, ingredients: Dictionary, output_id: String, output_count: int = 1, duration: float = 0.0) -> bool:
	if recipe_id.is_empty() or output_id.is_empty() or output_count <= 0 or ingredients.is_empty():
		return false
	for item_id in ingredients:
		if str(item_id).is_empty() or int(ingredients[item_id]) <= 0:
			return false
	recipes[recipe_id] = {"ingredients": ingredients.duplicate(true), "output_id": output_id, "output_count": output_count, "duration": maxf(0.0, duration)}
	return true

func can_craft(recipe_id: String, inventory: Dictionary) -> bool:
	if not recipes.has(recipe_id):
		return false
	var recipe: Dictionary = recipes[recipe_id]
	for item_id in recipe["ingredients"]:
		if int(inventory.get(item_id, 0)) < int(recipe["ingredients"][item_id]):
			return false
	return true

func craft(recipe_id: String, inventory: Dictionary) -> Dictionary:
	if not can_craft(recipe_id, inventory):
		return {"success": false, "reason": "missing_ingredients"}
	var recipe: Dictionary = recipes[recipe_id]
	var updated := inventory.duplicate(true)
	for item_id in recipe["ingredients"]:
		updated[item_id] = int(updated[item_id]) - int(recipe["ingredients"][item_id])
		if int(updated[item_id]) <= 0:
			updated.erase(item_id)
	var output_id: String = recipe["output_id"]
	updated[output_id] = int(updated.get(output_id, 0)) + int(recipe["output_count"])
	return {"success": true, "inventory": updated, "output_id": output_id, "output_count": recipe["output_count"], "duration": recipe["duration"]}

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}).duplicate(true)
