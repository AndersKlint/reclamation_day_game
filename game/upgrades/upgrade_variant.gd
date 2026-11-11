class_name UpgradeVariant
extends Resource

enum Rarity { COMMON, UNCOMMON, EPIC, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[UpgradeStatEffect] = []
@export var shockwave: ShockwaveEffect


func is_valid() -> bool:
	if not Rarity.values().has(rarity) or (effects.is_empty() and shockwave == null):
		return false
	if shockwave != null and not shockwave.is_valid():
		return false
	var seen_stats: Dictionary[int, bool] = {}
	for effect: UpgradeStatEffect in effects:
		if effect == null or not effect.is_valid() or seen_stats.has(effect.stat):
			return false
		seen_stats[effect.stat] = true
	return true


func get_description() -> String:
	if not is_valid():
		return ""
	var descriptions: PackedStringArray = PackedStringArray()
	for effect: UpgradeStatEffect in effects:
		descriptions.append(effect.get_description())
	if shockwave != null:
		descriptions.append(shockwave.get_description())
	return "\n".join(descriptions)


func get_effects() -> Dictionary[String, float]:
	var multipliers: Dictionary[String, float] = {}
	if not is_valid():
		return multipliers
	for effect: UpgradeStatEffect in effects:
		multipliers[effect.get_key()] = effect.get_multiplier()
	return multipliers
