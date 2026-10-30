class_name UpgradeTracker
extends Node

const UpgradeDefinition = preload("res://game/upgrades/upgrade_definition.gd")

@export var thresholds: PackedFloat32Array = PackedFloat32Array([40.0, 100.0, 180.0, 280.0, 400.0])
@export var options: Array[UpgradeDefinition] = [
	preload("res://game/upgrades/reach.tres"),
	preload("res://game/upgrades/rate.tres"),
	preload("res://game/upgrades/movement.tres"),
]

var pending_rewards: int = 0
var _next_index: int = 0
var next_threshold: float:
	get:
		return thresholds[_next_index] if _next_index < thresholds.size() else INF


func record_life(life: float) -> void:
	while _next_index < thresholds.size() and life >= thresholds[_next_index]:
		pending_rewards += 1
		_next_index += 1


func has_pending() -> bool:
	return pending_rewards > 0


func consume_pending() -> bool:
	if not has_pending():
		return false
	pending_rewards -= 1
	return true
