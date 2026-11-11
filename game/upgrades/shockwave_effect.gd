class_name ShockwaveEffect
extends Resource

enum Trigger { PERIODIC, PHASE_COMPLETED }

@export var trigger: Trigger = Trigger.PERIODIC
@export var interval_seconds: float = 120.0
@export var radius_multiplier: float = 1.0
@export var stun_seconds: float = 0.0
@export var topple_buildings: bool = true


func is_valid() -> bool:
	return Trigger.values().has(trigger) \
		and is_finite(interval_seconds) and interval_seconds > 0.0 \
		and is_finite(radius_multiplier) and radius_multiplier > 0.0 \
		and is_finite(stun_seconds) and stun_seconds >= 0.0 \
		and (topple_buildings or stun_seconds > 0.0)


func get_description() -> String:
	if not is_valid():
		return ""
	var timing: String = "Every %s seconds" % String.num(interval_seconds) if trigger == Trigger.PERIODIC else "After completing a phase"
	var actions: PackedStringArray = PackedStringArray()
	if topple_buildings:
		actions.append("topple buildings")
	if stun_seconds > 0.0:
		actions.append("stun enemies for %s seconds" % String.num(stun_seconds))
	var reach: String = "drain radius" if radius_multiplier == 1.0 else "%s× drain radius" % String.num(radius_multiplier)
	return "%s, %s within %s." % [timing, " and ".join(actions), reach]
