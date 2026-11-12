extends Node3D

const Drainable = preload("res://game/draining/drainable.gd")

var _source: Drainable
var _bar: ProgressBar
var _damaged: bool = false

func configure(source: Drainable, height: float) -> void:
	_source = source
	position.y = height
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	_bar = ProgressBar.new()
	_bar.size = Vector2(56.0, 6.0)
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bf554d")
	_bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("171c20")
	_bar.add_theme_stylebox_override("background", background)
	canvas.add_child(_bar)
	_bar.hide()
	_source.drained.connect(_on_drained)
	_source.collapsed.connect(_on_collapsed)
	set_process(false)

func _on_drained(amount: float) -> void:
	if amount <= 0.0 or _source.is_collapsed:
		return
	_damaged = true
	_bar.value = _source.drain_fraction()
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
	_bar.visible = not camera.is_position_behind(global_position) and camera.is_position_in_frustum(global_position)
	if _bar.visible:
		_bar.position = camera.unproject_position(global_position) - Vector2(28.0, 8.0)
