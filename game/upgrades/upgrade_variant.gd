class_name UpgradeVariant
extends Resource

enum Rarity { COMMON, UNCOMMON, EPIC, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[UpgradeStatEffect] = []
@export var shockwave: ShockwaveEffect
@export var phase_return: bool = false
@export var phase_reflection: bool = false
@export var last_stand: bool = false
@export_range(0.0, 100.0, 0.1, "suffix:%") var projectile_reflection: float = 0.0
@export var phase_through_objects: bool = false
@export_range(0.0, 60.0, 0.1, "suffix:s") var voidwalker_duration: float = 0.0
@export_range(0.0, 10.0, 0.05, "or_greater") var size_multiplier: float = 1.0
@export var healing_disabled: bool = false
@export var pacifist: bool = false
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:%") var proximity_drain_bonus_percent: float = 0.0
@export var lock_visible_size: bool = false
@export_range(0.0, 1.0, 0.01) var growth_bonus_retention: float = 1.0
@export_range(0.0, 10.0, 0.05, "or_greater") var phase_size_multiplier: float = 1.0


func is_valid() -> bool:
	if not Rarity.values().has(rarity):
		return false
	if not _has_effect():
		return false
	if not is_finite(projectile_reflection) or projectile_reflection < 0.0 or projectile_reflection > 100.0:
		return false
	if not is_finite(voidwalker_duration) or voidwalker_duration < 0.0:
		return false
	if not is_finite(size_multiplier) or size_multiplier <= 0.0:
		return false
	if not is_finite(proximity_drain_bonus_percent) or proximity_drain_bonus_percent < 0.0:
		return false
	if not is_finite(growth_bonus_retention) or growth_bonus_retention < 0.0 or growth_bonus_retention > 1.0:
		return false
	if not is_finite(phase_size_multiplier) or phase_size_multiplier <= 0.0:
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
	if phase_reflection:
		descriptions.append("Phase into incoming bullets within ±90° to reflect them with 100% chance.")
	if last_stand:
		descriptions.append("Once per run, survive lethal damage at 1% maximum health and gain 10 seconds of Voidwalker.")
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
	if not is_equal_approx(size_multiplier, 1.0):
		descriptions.append("Size and size growth ×%s, including size-based drain reach, drain power, movement and phase distance. Movement penalties apply afterward." % _format_value(size_multiplier))
	if healing_disabled:
		descriptions.append("You can no longer heal.")
	if pacifist:
		descriptions.append("Cannot drain NPCs, enemies or occupied vehicles. Reflected shots can still kill, but grant no life.")
	if proximity_drain_bonus_percent > 0.0:
		descriptions.append("Drain speed rises with proximity, up to +%s%%." % _format_value(proximity_drain_bonus_percent))
	if lock_visible_size:
		descriptions.append("Visible size stays at its starting size.")
	if growth_bonus_retention < 1.0:
		descriptions.append("Growth-derived radius bonuses are reduced by %s%%." % _format_value((1.0 - growth_bonus_retention) * 100.0))
	if not is_equal_approx(phase_size_multiplier, 1.0):
		descriptions.append("Phase distance based on virtual size ×%s." % _format_value(phase_size_multiplier))
	return "\n".join(descriptions)


func _has_effect() -> bool:
	if phase_reflection or last_stand:
		return true
	return not effects.is_empty() or shockwave != null or phase_return or projectile_reflection > 0.0 or phase_through_objects or voidwalker_duration > 0.0 or not is_equal_approx(size_multiplier, 1.0) or healing_disabled or pacifist or proximity_drain_bonus_percent > 0.0 or lock_visible_size or not is_equal_approx(growth_bonus_retention, 1.0) or not is_equal_approx(phase_size_multiplier, 1.0)


func _format_value(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func get_effects() -> Dictionary[String, float]:
	var multipliers: Dictionary[String, float] = {}
	if not is_valid():
		return multipliers
	for effect: UpgradeStatEffect in effects:
		multipliers[effect.get_key()] = effect.get_multiplier()
	return multipliers
