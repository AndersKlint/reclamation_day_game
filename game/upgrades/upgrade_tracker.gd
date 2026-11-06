class_name UpgradeTracker
extends Node

const UpgradeDefinition = preload("res://game/upgrades/upgrade_definition.gd")
const GAP_GROWTH: float = 1.2

@export var thresholds: PackedFloat32Array = PackedFloat32Array([40.0, 100.0, 180.0, 280.0, 400.0])
@export var options: Array[UpgradeDefinition] = [
	preload("res://game/upgrades/reach.tres"),
	preload("res://game/upgrades/rate.tres"),
	preload("res://game/upgrades/movement.tres"),
]

var pending_rewards: int = 0
var earned_tiers: int = 0
var _base_thresholds: PackedFloat32Array = PackedFloat32Array()
var _next_index: int = 0
var _next_threshold: float = 0.0
var _gap: float = 0.0
var _configured: bool = false

var next_threshold: float:
	get:
		_ensure_configured()
		return _next_threshold


func _ready() -> void:
	_ensure_configured()


func record_life(life: float) -> void:
	if not is_finite(life):
		return
	_ensure_configured()
	while life >= _next_threshold:
		pending_rewards += 1
		earned_tiers += 1
		_next_index += 1
		_advance_threshold()


func has_pending() -> bool:
	return pending_rewards > 0


func consume_pending() -> bool:
	if not has_pending():
		return false
	pending_rewards -= 1
	return true


func consume_all_pending() -> int:
	var consumed: int = pending_rewards
	pending_rewards = 0
	return consumed


func _ensure_configured() -> void:
	if _configured:
		return
	_configured = true
	_base_thresholds.clear()
	var previous: float = 0.0
	for value: float in thresholds:
		if not is_finite(value) or value <= previous:
			continue
		_base_thresholds.append(value)
		previous = value
	if _base_thresholds.is_empty():
		_base_thresholds = PackedFloat32Array([100.0, 300.0, 650.0, 1100.0, 1800.0, 2700.0])
	_next_index = 0
	_next_threshold = _base_thresholds[0]
	_gap = _base_thresholds[-1] - (_base_thresholds[-2] if _base_thresholds.size() > 1 else 0.0)
	if _gap <= 0.0:
		_gap = _base_thresholds[-1]


func _advance_threshold() -> void:
	if _next_index < _base_thresholds.size():
		_next_threshold = _base_thresholds[_next_index]
		return
	_gap *= GAP_GROWTH
	_next_threshold += _gap
