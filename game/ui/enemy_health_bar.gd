extends Node3D

const Drainable = preload("res://game/draining/drainable.gd")

class HealthStrip extends Control:
	var fraction: float = 1.0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 34, 4), Color("120d10"))
		draw_rect(Rect2(1, 1, 32, 2), Color("34151b"))
		var fill_width: int = clampi(ceili(fraction * 32.0), 0, 32)
		if fill_width > 0:
			draw_rect(Rect2(1, 1, fill_width, 2), Color("a4202b"))
			draw_rect(Rect2(1, 1, fill_width, 1), Color("d04444"))

var _source: Drainable
var _bar: HealthStrip
var _damaged: bool = false

func configure(source: Drainable, height: float) -> void:
	_source = source
	position.y = height
	# Screen projection must follow the camera rig's frame update.
	process_priority = 100
	get_global_transform_interpolated()
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	_bar = HealthStrip.new()
	_bar.size = Vector2(34.0, 4.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_bar)
	_bar.hide()
	_source.drained.connect(_on_drained)
	_source.collapsed.connect(_on_collapsed)
	set_process(false)

func _on_drained(amount: float) -> void:
	if amount <= 0.0 or _source.is_collapsed:
		return
	_damaged = true
	_bar.fraction = _source.drain_fraction()
	_bar.queue_redraw()
	set_process(true)
	_process(0.0)

func _on_collapsed() -> void:
	_bar.hide()
	set_process(false)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_bar.visible = _damaged and is_visible_in_tree() and is_instance_valid(_source) and not _source.is_collapsed and camera != null
	if not _bar.visible:
		return
	var rendered_position: Vector3 = get_global_transform_interpolated().origin
	_bar.visible = not camera.is_position_behind(rendered_position) and camera.is_position_in_frustum(rendered_position)
	if _bar.visible:
		_bar.position = (camera.unproject_position(rendered_position) - Vector2(17.0, 10.0)).round()
