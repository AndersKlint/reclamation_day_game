extends Area3D

signal drained(amount: float)
signal collapsed()

const Scaling = preload("res://game/draining/drain_scaling.gd")

enum State { UNCONFIGURED, DRAINING, COLLAPSED, TRANSFERRED }

@export_range(0.01, 100.0) var life_modifier: float = 1.0
@export_range(0.0, 1000.0, 0.01, "or_greater") var healing_per_life: float = 0.0
@export var emission_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 100.0) var emission_radius: float = 0.4
@export_range(0.01, 100.0, 0.01, "or_greater") var drain_speed_multiplier: float = 1.0
@export var pacifist_protected: bool = false
var capacity: float = 0.0
var remaining_capacity: float = 0.0
var original_volume: float = 0.0
var collector: Node3D
var state: State = State.UNCONFIGURED
var _grant_collapse_rewards: bool = true
var _proximity_shape: CollisionShape3D
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
	return amount if _grant_collapse_rewards else 0.0

func force_collapse(recipient: Node3D, grant_rewards: bool = true) -> bool:
	if not _begin_collapse(recipient):
		return false
	_grant_collapse_rewards = grant_rewards
	collapsed.emit()
	return true

func _begin_collapse(recipient: Node3D) -> bool:
	if state != State.DRAINING or not is_instance_valid(recipient):
		return false
	collector = recipient
	state = State.COLLAPSED
	return true

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

func get_proximity(origin: Vector3, reach: float) -> float:
	var surface_distance: float = _surface_distance(origin)
	return 1.0 - clampf(surface_distance / maxf(reach, 0.001), 0.0, 1.0)

func _surface_distance(origin: Vector3) -> float:
	if not is_instance_valid(_proximity_shape) or _proximity_shape.is_queued_for_deletion():
		_proximity_shape = null
		for child: Node in get_children():
			if child is CollisionShape3D and not child.is_queued_for_deletion():
				_proximity_shape = child as CollisionShape3D
				break
	if is_instance_valid(_proximity_shape) and not _proximity_shape.is_queued_for_deletion() and not _proximity_shape.disabled:
		var shape: Shape3D = _proximity_shape.shape
		var shape_transform: Transform3D = _proximity_shape.global_transform
		if shape is BoxShape3D and absf(shape_transform.basis.determinant()) > 0.000001:
			var point: Vector3 = origin
			point.y = shape_transform.origin.y
			var local: Vector3 = shape_transform.affine_inverse() * point
			var half_size: Vector3 = (shape as BoxShape3D).size * 0.5
			local.x = clampf(local.x, -half_size.x, half_size.x)
			local.y = 0.0
			local.z = clampf(local.z, -half_size.z, half_size.z)
			var closest: Vector3 = shape_transform * local
			return Vector2(origin.x - closest.x, origin.z - closest.z).length()
		if shape is SphereShape3D or shape is CapsuleShape3D:
			var radius: float = (shape as SphereShape3D).radius if shape is SphereShape3D else (shape as CapsuleShape3D).radius
			var basis: Basis = shape_transform.basis
			var radius_scale: float = maxf(Vector2(basis.x.x, basis.x.z).length(), Vector2(basis.z.x, basis.z.z).length())
			radius_scale = maxf(radius_scale, Vector2(basis.y.x, basis.y.z).length())
			var center: Vector2 = Vector2(shape_transform.origin.x, shape_transform.origin.z)
			var point: Vector2 = Vector2(origin.x, origin.z)
			if shape is CapsuleShape3D:
				var half_axis: float = maxf(0.0, (shape as CapsuleShape3D).height * 0.5 - radius)
				var axis: Vector2 = Vector2(basis.y.x, basis.y.z) * half_axis
				center = Geometry2D.get_closest_point_to_segment(point, center - axis, center + axis)
			return maxf(0.0, point.distance_to(center) - radius * radius_scale)
	var offset: Vector3 = global_position - origin
	return maxf(0.0, Vector2(offset.x, offset.z).length() - get_effect_radius())

func drain(requested_amount: float, source_volume: float, recipient: Node3D) -> float:
	if not is_finite(drain_speed_multiplier) or drain_speed_multiplier <= 0.0:
		return 0.0
	var effective_amount: float = requested_amount * drain_speed_multiplier
	if not can_drain(source_volume) or not is_finite(effective_amount) or effective_amount <= 0.0 or not is_instance_valid(recipient) or recipient.is_queued_for_deletion():
		return 0.0
	if recipient.has_method(&"can_drain_target") and not bool(recipient.call(&"can_drain_target", self)):
		return 0.0
	collector = recipient
	var boundary: float = capacity * Scaling.COLLAPSE_LIFE_SHARE
	var available: float = remaining_capacity - boundary
	var removed: float = minf(effective_amount, available)
	remaining_capacity = maxf(boundary, remaining_capacity - removed)
	var collapsed_now: bool = effective_amount >= available
	if collapsed_now:
		remaining_capacity = boundary
		_begin_collapse(recipient)
	drained.emit(removed)
	if collapsed_now:
		collapsed.emit()
	return removed
