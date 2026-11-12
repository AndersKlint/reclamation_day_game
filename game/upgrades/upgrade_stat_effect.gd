class_name UpgradeStatEffect
extends Resource

enum Stat { DRAIN_SPEED, DRAIN_RADIUS, MOVEMENT_SPEED, PHASE_COOLDOWN, RESISTANCE, PHASE_DISTANCE }

@export var stat: Stat = Stat.DRAIN_SPEED
@export_range(-99.9, 100.0, 0.1, "or_greater", "suffix:%") var percentage: float = 0.0


func is_valid() -> bool:
	if not Stat.values().has(stat) or not is_finite(percentage):
		return false
	if _is_reduction():
		return percentage >= 0.0 and percentage < 100.0
	return percentage > -100.0


func get_key() -> String:
	match stat:
		Stat.DRAIN_SPEED:
			return "rate_multiplier"
		Stat.DRAIN_RADIUS:
			return "reach_multiplier"
		Stat.MOVEMENT_SPEED:
			return "movement_multiplier"
		Stat.PHASE_COOLDOWN:
			return "cooldown_multiplier"
		Stat.RESISTANCE:
			return "damage_taken_multiplier"
		Stat.PHASE_DISTANCE:
			return "phase_distance_multiplier"
		_:
			return ""


func get_multiplier() -> float:
	return 1.0 - percentage / 100.0 if _is_reduction() else 1.0 + percentage / 100.0


func get_description() -> String:
	var label: String
	match stat:
		Stat.DRAIN_SPEED:
			label = "drain speed"
		Stat.DRAIN_RADIUS:
			label = "drain radius"
		Stat.MOVEMENT_SPEED:
			label = "movement speed and acceleration"
		Stat.PHASE_COOLDOWN:
			label = "phase cooldown"
		Stat.RESISTANCE:
			label = "damage taken"
		Stat.PHASE_DISTANCE:
			label = "phase distance"
		_:
			return ""
	return "%s%s%% %s." % ["-" if _is_reduction() or percentage < 0.0 else "+", str(absf(percentage)), label]


func _is_reduction() -> bool:
	return stat == Stat.PHASE_COOLDOWN or stat == Stat.RESISTANCE
