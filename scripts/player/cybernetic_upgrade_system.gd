extends Node
## Player cyberware slots, upgrade levels and rechargeable implant energy.
signal energy_changed(current: float, maximum: float)
const IMPLANT_SLOTS := ["optic", "neural", "arm_left", "arm_right", "legs", "dermal"]
var maximum_energy := 100.0
var energy := 100.0
var installed_implants: Dictionary = {}
var upgrade_levels: Dictionary = {}

func install_implant(slot: String, implant_id: String, energy_cost: float = 0.0) -> bool:
	if not IMPLANT_SLOTS.has(slot) or implant_id.is_empty() or energy < energy_cost:
		return false
	energy = maxf(0.0, energy - energy_cost)
	installed_implants[slot] = implant_id
	energy_changed.emit(energy, maximum_energy)
	return true

func remove_implant(slot: String) -> bool:
	if not installed_implants.has(slot):
		return false
	installed_implants.erase(slot)
	return true

func upgrade_implant(implant_id: String, max_level: int = 5) -> int:
	if implant_id.is_empty():
		return 0
	var next_level := mini(maxi(1, max_level), int(upgrade_levels.get(implant_id, 0)) + 1)
	upgrade_levels[implant_id] = next_level
	return next_level

func consume_energy(amount: float) -> bool:
	if amount < 0.0 or energy < amount:
		return false
	energy = maxf(0.0, energy - amount)
	energy_changed.emit(energy, maximum_energy)
	return true

func recharge(amount: float) -> void:
	energy = clampf(energy + maxf(0.0, amount), 0.0, maximum_energy)
	energy_changed.emit(energy, maximum_energy)

func get_snapshot() -> Dictionary:
	return {"energy": energy, "maximum_energy": maximum_energy, "implants": installed_implants.duplicate(true), "upgrade_levels": upgrade_levels.duplicate(true)}
