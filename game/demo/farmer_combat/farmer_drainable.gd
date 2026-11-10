extends "res://game/draining/drainable.gd"

@export_range(0.001, 1.0, 0.001) var drain_efficiency: float = 0.01


func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not is_finite(drain_efficiency) or drain_efficiency <= 0.0:
		return 0.0
	return super.drain(requested_amount * minf(drain_efficiency, 1.0), source_volume, recipient)
