class_name ShockwaveEffect
extends Resource

enum Trigger { PERIODIC, PHASE_COMPLETED }
enum Presentation { SHOCKWAVE, SOUL_BURST }

@export var trigger: Trigger = Trigger.PERIODIC
@export var presentation: Presentation = Presentation.SHOCKWAVE
@export var interval_seconds: float = 120.0
@export var delay_seconds: float = 0.0
@export var radius_multiplier: float = 1.0
@export var stun_seconds: float = 0.0
@export var topple_buildings: bool = true
@export var life_cost: float = 0.0
@export var cooldown_seconds: float = 0.0
@export var drain_seconds: float = 0.0
@export var stacking_key: StringName = &""


func is_valid() -> bool:
	return Trigger.values().has(trigger) \
		and Presentation.values().has(presentation) \
		and is_finite(interval_seconds) and interval_seconds > 0.0 \
		and is_finite(delay_seconds) and delay_seconds >= 0.0 \
		and is_finite(radius_multiplier) and radius_multiplier > 0.0 \
		and is_finite(stun_seconds) and stun_seconds >= 0.0 \
		and is_finite(life_cost) and life_cost >= 0.0 \
		and is_finite(cooldown_seconds) and cooldown_seconds >= 0.0 \
		and is_finite(drain_seconds) and drain_seconds >= 0.0 \
		and (topple_buildings or stun_seconds > 0.0 or drain_seconds > 0.0)


func get_description() -> String:
	if not is_valid():
		return ""
	var timing: String = "Every %s seconds" % String.num(interval_seconds) if trigger == Trigger.PERIODIC else "After completing a phase"
	var actions: PackedStringArray = PackedStringArray()
	if topple_buildings:
		actions.append("topple buildings")
	if stun_seconds > 0.0:
		actions.append("stun enemies for %s seconds" % String.num(stun_seconds))
	if drain_seconds > 0.0:
		actions.append("drain enemies for %s seconds of current drain power" % String.num(drain_seconds))
	var reach: String = "drain radius" if radius_multiplier == 1.0 else "%s× drain radius" % String.num(radius_multiplier)
	var description: String = "%s, %s within %s." % [timing, " and ".join(actions), reach]
	if delay_seconds > 0.0:
		description += " Activates after a %s-second delay." % String.num(delay_seconds)
	if life_cost > 0.0:
		description += " Costs %s life per activation." % String.num(life_cost)
	if cooldown_seconds > 0.0:
		description += " %s-second cooldown." % String.num(cooldown_seconds)
	return description
