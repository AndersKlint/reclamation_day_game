extends Node3D

const Drainable = preload("res://game/draining/drainable.gd")

var ground_position: Callable
var visual: Node3D
var drainable: Drainable
var _opacity: float = 1.0
var _renewal: Tween

func configure(capacity: float) -> void:
	drainable = Drainable.new()
	drainable.name = "Drainable"
	drainable.capacity = capacity
	drainable.required_size = 1.0
	drainable.collision_layer = 8
	drainable.collision_mask = 0
	drainable.monitoring = false
	drainable.emission_offset = Vector3(0, 0.4, 0)
	drainable.emission_radius = 1.0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(8, 3, 8)
	shape.shape = box
	shape.position.y = 0.5
	drainable.add_child(shape)
	add_child(drainable)
	visual = Node3D.new()
	add_child(visual)
	drainable.drained.connect(_on_drained)
	drainable.depleted.connect(_depleted)

func _on_drained(_amount: float) -> void:
	if _renewal != null and _renewal.is_valid():
		_renewal.kill()
	_set_opacity(drainable.remaining_capacity / drainable.capacity)

func _depleted() -> void:
	visual.hide()
	drainable.set_deferred("monitorable", false)

func _set_opacity(opacity: float) -> void:
	_opacity = clampf(opacity, 0.0, 1.0)
	for child: Node in visual.get_children():
		(child as MultiMeshInstance3D).set_instance_shader_parameter(&"patch_opacity", _opacity)

func renew(duration: float) -> void:
	if drainable.is_depleted:
		return
	if _renewal != null and _renewal.is_valid():
		_renewal.kill()
	if is_equal_approx(_opacity, 1.0):
		return
	if duration <= 0.0:
		_set_opacity(1.0)
		return
	_renewal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renewal.tween_method(_set_opacity, _opacity, 1.0, duration)
