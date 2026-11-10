extends Area3D

const Drainable = preload("res://game/draining/drainable.gd")
signal life_absorbed(amount: float)
signal transfer_effect_requested(source_id: int, source_position: Vector3, source_radius: float, actual_rate: float, proximity: float)

var source_volume: float = 0.0
var collector: Node3D
var drain_rate: float = 8.0
var enabled: bool = true
var _reach: float = 2.8
var _targets: Array[Drainable] = []
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	_collision.shape = _collision.shape.duplicate()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if not enabled or delta <= 0.0:
		return
	var eligible: Array[Drainable] = []
	for index: int in range(_targets.size() - 1, -1, -1):
		var target: Drainable = _targets[index]
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.is_collapsed:
			_targets.remove_at(index)
		elif target.can_drain(source_volume):
			eligible.append(target)
	if eligible.is_empty():
		return
	var request: float = drain_rate * delta
	var absorbed: float = 0.0
	for target: Drainable in eligible:
		if not enabled:
			break
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			var source_id: int = target.get_instance_id()
			var source_position: Vector3 = target.get_effect_position()
			var source_radius: float = target.get_effect_radius()
			var offset: Vector3 = target.global_position - global_position
			offset.y = 0.0
			var surface_distance: float = maxf(0.0, offset.length() - source_radius)
			var proximity: float = 1.0 - clampf(surface_distance / maxf(_reach, 0.001), 0.0, 1.0)
			var amount: float = target.drain(request, source_volume, collector)
			absorbed += amount
			if amount > 0.0:
				transfer_effect_requested.emit(source_id, source_position, source_radius, amount / delta, proximity)
	if absorbed > 0.0:
		life_absorbed.emit(absorbed)

func set_reach(reach: float) -> void:
	_reach = reach
	_collision.shape.set_deferred("radius", reach)

func _on_area_entered(area: Area3D) -> void:
	if area is Drainable and not _targets.has(area):
		_targets.append(area)

func _on_area_exited(area: Area3D) -> void:
	_targets.erase(area)
