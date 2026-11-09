extends Area3D

signal drained(amount: float)
signal depleted()

@export_range(0.1, 10000.0) var capacity: float = 20.0
@export_range(0.1, 10.0) var required_size: float = 1.0
@export_range(0.0, 1.0) var direct_life_share: float = 1.0
@export var emission_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 100.0) var emission_radius: float = 0.4
var remaining_capacity: float
var absorbed_capacity: float = 0.0
var is_depleted: bool = false

static func gate_to_size(gate: float) -> float:
	return pow(maxf(gate, 1.0), 1.0 / 3.0)

func _ready() -> void:
	remaining_capacity = capacity

func get_effect_position() -> Vector3:
	return to_global(emission_offset)

func get_effect_radius() -> float:
	return maxf(0.0, emission_radius)

func drain(requested_amount: float, source_size: float) -> float:
	if is_depleted or (source_size < required_size and not is_equal_approx(source_size, required_size)) or requested_amount <= 0.0:
		return 0.0
	var removed: float = minf(requested_amount, remaining_capacity)
	remaining_capacity = maxf(0.0, remaining_capacity - removed)
	var awarded: float = removed * direct_life_share
	absorbed_capacity += removed - awarded
	var depleted_now: bool = remaining_capacity <= 0.0
	is_depleted = depleted_now
	drained.emit(awarded)
	if depleted_now:
		depleted.emit()
	return awarded
