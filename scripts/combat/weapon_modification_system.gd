extends Node
## Data-driven weapon attachments with bounded stat modifiers.
const SLOT_NAMES := ["optic", "muzzle", "underbarrel", "magazine", "utility"]
var _weapons: Dictionary = {}

func register_weapon(weapon_id: String, base_stats: Dictionary) -> bool:
	if weapon_id.is_empty() or _weapons.has(weapon_id):
		return false
	_weapons[weapon_id] = {"base": base_stats.duplicate(true), "attachments": {}}
	return true

func install_attachment(weapon_id: String, slot: String, attachment: Dictionary) -> bool:
	if not _weapons.has(weapon_id) or not SLOT_NAMES.has(slot):
		return false
	if not attachment.has("id") or not attachment.has("modifiers"):
		return false
	var weapon: Dictionary = _weapons[weapon_id]
	var attachments: Dictionary = weapon.get("attachments", {})
	attachments[slot] = attachment.duplicate(true)
	weapon["attachments"] = attachments
	_weapons[weapon_id] = weapon
	return true

func remove_attachment(weapon_id: String, slot: String) -> bool:
	if not _weapons.has(weapon_id):
		return false
	var weapon: Dictionary = _weapons[weapon_id]
	var attachments: Dictionary = weapon.get("attachments", {})
	if not attachments.has(slot):
		return false
	attachments.erase(slot)
	weapon["attachments"] = attachments
	_weapons[weapon_id] = weapon
	return true

func get_weapon_stats(weapon_id: String) -> Dictionary:
	if not _weapons.has(weapon_id):
		return {}
	var weapon: Dictionary = _weapons[weapon_id]
	var stats: Dictionary = weapon.get("base", {}).duplicate(true)
	for attachment in weapon.get("attachments", {}).values():
		var modifiers: Dictionary = attachment.get("modifiers", {})
		for stat in modifiers:
			stats[stat] = float(stats.get(stat, 0.0)) + float(modifiers[stat])
	return stats

func get_attachment_snapshot(weapon_id: String) -> Dictionary:
	if not _weapons.has(weapon_id):
		return {}
	return ( _weapons[weapon_id].get("attachments", {}) as Dictionary).duplicate(true)
