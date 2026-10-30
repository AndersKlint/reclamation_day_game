extends Node3D

signal finished()

var _tween: Tween
var _starting_radius: float = 1.0
var _material: StandardMaterial3D
@onready var ring: MeshInstance3D = $Ring
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	_material = ring.material_override.duplicate() as StandardMaterial3D
	ring.material_override = _material
	hide()

func begin(origin: Vector3, spirit_visuals: Node3D, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	global_position = origin
	_starting_radius = maxf(1.0, spirit_visuals.scale.x)
	show()
	_update_release(0.0)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_update_release, 0.0, 1.0, duration)
	for visual: Node in spirit_visuals.find_children("*", "GeometryInstance3D", true, false):
		_tween.tween_property(visual, "transparency", 1.0, duration * 0.8)
	_tween.chain().tween_callback(_finish)

func _update_release(fraction: float) -> void:
	var radius: float = lerpf(_starting_radius, 90.0, fraction)
	ring.scale = Vector3(radius, 1.0, radius)
	_material.albedo_color = Color(0.65, 0.9, 0.67, 1.0 - fraction)
	light.light_energy = sin(fraction * PI) * 4.0

func _finish() -> void:
	hide()
	finished.emit()
