extends "res://game/draining/drainable.gd"

@export_range(0.001, 1.0, 0.001) var drain_efficiency: float = 1.0
@export_range(0.01, 100.0, 0.01) var reward_multiplier: float = 10.0


func _init() -> void:
	healing_per_life = 200.0


func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not is_finite(drain_efficiency) or drain_efficiency <= 0.0 or not is_finite(reward_multiplier) or reward_multiplier <= 0.0:
		return 0.0
	var removed: float = super.drain(requested_amount * minf(drain_efficiency, 1.0), source_volume, recipient)
	return removed * reward_multiplier


func take_collapse_life() -> float:
	var life: float = super.take_collapse_life()
	if not is_finite(reward_multiplier) or reward_multiplier <= 0.0:
		return life
	return life * reward_multiplier
