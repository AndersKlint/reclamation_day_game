extends Area3D

signal drained(amount: float)
signal collapsed()

const Scaling = preload("res://game/draining/drain_scaling.gd")

enum State { UNCONFIGURED, DRAINING, COLLAPSED, TRANSFERRED }

@export_range(0.01, 100.0) var life_modifier: float = 1.0
@export_range(0.0, 1000.0, 0.01, "or_greater") var healing_per_life: float = 0.0
@export var emission_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 100.0) var emission_radius: float = 0.4
var capacity: float = 0.0
var remaining_capacity: float = 0.0
var original_volume: float = 0.0
var collector: Node3D
var state: State = State.UNCONFIGURED
var is_collapsed: bool:
	get:
		return state in [State.COLLAPSED, State.TRANSFERRED]
var required_volume: float:
	get:
		return original_volume * Scaling.REQUIRED_VOLUME_RATIO

func configure_volume(dimensions: Vector3) -> void:
	assert(state == State.UNCONFIGURED, "Drainable volume must be configured exactly once")
	original_volume = Scaling.volume(dimensions)
	if original_volume <= 0.0 or not is_finite(life_modifier) or life_modifier <= 0.0:
		push_error("Drainable requires finite, positive model dimensions and life modifier: %s" % get_path())
		return
	capacity = Scaling.life_for_volume(original_volume) * life_modifier
	if not is_finite(capacity) or capacity <= 0.0:
		push_error("Drainable life exceeds the finite range: %s" % get_path())
		capacity = 0.0
		return
	remaining_capacity = capacity
	state = State.DRAINING

func can_drain(source_volume: float) -> bool:
	return state == State.DRAINING and is_finite(source_volume) and (source_volume >= required_volume or is_equal_approx(source_volume, required_volume))

func drain_fraction() -> float:
	if capacity <= 0.0 or is_collapsed:
		return 0.0
	return clampf((remaining_capacity / capacity - Scaling.COLLAPSE_LIFE_SHARE) / (1.0 - Scaling.COLLAPSE_LIFE_SHARE), 0.0, 1.0)

func take_collapse_life() -> float:
	if state != State.COLLAPSED:
		return 0.0
	state = State.TRANSFERRED
	var amount: float = remaining_capacity
	remaining_capacity = 0.0
	return amount

func get_effect_position() -> Vector3:
	return to_global(emission_offset)

func healing_for(amount: float) -> float:
	if not is_finite(healing_per_life) or healing_per_life <= 0.0:
		return 0.0
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var healing: float = amount * healing_per_life
	return healing if is_finite(healing) else 0.0

func get_effect_radius() -> float:
	return maxf(0.0, emission_radius)

func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not can_drain(source_volume) or not is_finite(requested_amount) or requested_amount <= 0.0 or not is_instance_valid(recipient):
		return 0.0
	collector = recipient
	var boundary: float = capacity * Scaling.COLLAPSE_LIFE_SHARE
	var available: float = remaining_capacity - boundary
	var removed: float = minf(requested_amount, available)
	remaining_capacity = maxf(boundary, remaining_capacity - removed)
	var collapsed_now: bool = requested_amount >= available
	if collapsed_now:
		remaining_capacity = boundary
		state = State.COLLAPSED
	drained.emit(removed)
	if collapsed_now:
		collapsed.emit()
	return removed
