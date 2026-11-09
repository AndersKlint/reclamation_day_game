extends Node3D

var ground_position: Callable
var visual: Node3D
var _opacity: float = 1.0
var _renewal: Tween

func configure() -> void:
	visual = Node3D.new()
	add_child(visual)

func _set_opacity(opacity: float) -> void:
	_opacity = clampf(opacity, 0.0, 1.0)
	for child: Node in visual.get_children():
		(child as MultiMeshInstance3D).set_instance_shader_parameter(&"patch_opacity", _opacity)

func renew(duration: float) -> void:
	if _renewal != null and _renewal.is_valid():
		_renewal.kill()
	if is_equal_approx(_opacity, 1.0):
		return
	if duration <= 0.0:
		_set_opacity(1.0)
		return
	_renewal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renewal.tween_method(_set_opacity, _opacity, 1.0, duration)
