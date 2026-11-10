extends "res://game/draining/drainable.gd"

@export_range(0.001, 1.0, 0.001) var drain_efficiency: float = 0.03
@export var required_player_volume: float = 0.0


func can_drain(source_volume: float) -> bool:
	var minimum: float = get_minimum_player_volume()
	return state == State.DRAINING and is_finite(source_volume) and (source_volume >= minimum or is_equal_approx(source_volume, minimum))


func get_minimum_player_volume() -> float:
	return required_player_volume if required_player_volume > 0.0 else required_volume


func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not is_finite(drain_efficiency) or drain_efficiency <= 0.0:
		return 0.0
	return super.drain(requested_amount * minf(drain_efficiency, 1.0), source_volume, recipient)
