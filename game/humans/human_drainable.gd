extends "res://game/draining/drainable.gd"

const POLICE_REFERENCE_HEIGHT: float = 5.4
const POLICE_DRAIN_SECONDS: float = 5.0

@export_range(0.001, 1.0, 0.001, "or_greater") var drain_efficiency: float = 1.0
@export_range(0.01, 100.0, 0.01) var reward_multiplier: float = 10.0

var _police_reference_volume: float = 0.0


func configure_police(base_volume: float, reference_height: float) -> void:
	assert(is_finite(base_volume) and base_volume > 0.0 and is_finite(reference_height) and reference_height > 0.0, "Police require positive player reference dimensions")
	_police_reference_volume = base_volume * pow(POLICE_REFERENCE_HEIGHT / reference_height, 3.0)


func configure_volume(dimensions: Vector3) -> void:
	super.configure_volume(dimensions)
	if _police_reference_volume <= 0.0 or state != State.DRAINING:
		return
	var reference_rate: float = Scaling.drain_rate_for_volume(_police_reference_volume)
	drain_efficiency = capacity * (1.0 - Scaling.COLLAPSE_LIFE_SHARE) / (reference_rate * POLICE_DRAIN_SECONDS) / 3.0


func _init() -> void:
	healing_per_life = 200.0
	pacifist_protected = true


func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not is_finite(drain_efficiency) or drain_efficiency <= 0.0 or not is_finite(reward_multiplier) or reward_multiplier <= 0.0:
		return 0.0
	var removed: float = super.drain(requested_amount * drain_efficiency, source_volume, recipient)
	return removed * reward_multiplier


func take_collapse_life() -> float:
	var life: float = super.take_collapse_life()
	if not is_finite(reward_multiplier) or reward_multiplier <= 0.0:
		return life
	return life * reward_multiplier
