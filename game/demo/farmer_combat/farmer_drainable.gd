extends "res://game/humans/human_drainable.gd"

@export var required_player_volume: float = 0.0


func can_drain(source_volume: float) -> bool:
	var minimum: float = get_minimum_player_volume()
	return state == State.DRAINING and is_finite(source_volume) and (source_volume >= minimum or is_equal_approx(source_volume, minimum))


func get_minimum_player_volume() -> float:
	return required_player_volume if required_player_volume > 0.0 else required_volume
