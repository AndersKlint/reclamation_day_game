class_name UpgradeVariant
extends Resource

enum Rarity { COMMON, UNCOMMON, EPIC, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[UpgradeStatEffect] = []
@export var shockwave: ShockwaveEffect
@export var phase_return: bool = false
@export_range(0.0, 100.0, 0.1, "suffix:%") var projectile_reflection: float = 0.0
@export var phase_through_objects: bool = false
@export_range(0.0, 60.0, 0.1, "suffix:s") var voidwalker_duration: float = 0.0


func is_valid() -> bool:
	if not Rarity.values().has(rarity):
		return false
	if not _has_effect():
		return false
	if not is_finite(projectile_reflection) or projectile_reflection < 0.0 or projectile_reflection > 100.0:
		return false
	if not is_finite(voidwalker_duration) or voidwalker_duration < 0.0:
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
	if phase_return:
		descriptions.append("Press Space during phase cooldown to return once to the phase starting position.")
	if projectile_reflection > 0.0:
		descriptions.append("Reflect projectiles back at their shooter with a %s%% chance; a reflected projectile kills the shooter." % _format_value(projectile_reflection))
	if phase_through_objects:
		descriptions.append("Phase through objects and land at the nearest safe position along the phase path.")
	if voidwalker_duration > 0.0:
		descriptions.append("After each completed phase, gain %s seconds of automatic damage immunity at no cost." % _format_value(voidwalker_duration))
	return "\n".join(descriptions)


func _has_effect() -> bool:
	return not effects.is_empty() or shockwave != null or phase_return or projectile_reflection > 0.0 or phase_through_objects or voidwalker_duration > 0.0


func _format_value(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func get_effects() -> Dictionary[String, float]:
	var multipliers: Dictionary[String, float] = {}
	if not is_valid():
		return multipliers
	for effect: UpgradeStatEffect in effects:
		multipliers[effect.get_key()] = effect.get_multiplier()
	return multipliers
