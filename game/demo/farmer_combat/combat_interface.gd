extends CanvasLayer

signal pause_requested()
signal resume_requested()
signal retry_requested()

const HIT_DURATION: float = 0.24
const HIT_CAMERA_OFFSET: float = 0.075
const HIT_FLASH_ALPHA: float = 0.18

var _root: Control
var _health_label: Label
var _health_bar: ProgressBar
var _endurance_label: Label
var _endurance_bar: ProgressBar
var _phase_label: Label
var _phase_bar: ProgressBar
var _wheat_label: Label
var _status_label: Label
var _overlay: ColorRect
var _menu: VBoxContainer
var _paused: bool = false
var _results: bool = false
var _hit_flash: ColorRect
var _hit_camera: Camera3D
var _camera_baseline: Vector2 = Vector2.ZERO
var _hit_remaining: float = 0.0


func _ready() -> void:
	_root = Control.new()
	_root.name = "Layout"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	var margins := MarginContainer.new()
	_root.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 20)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(column)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_maximum_size.x = 420.0
	panel.propagate_maximum_size = true
	column.add_child(panel)
	var stats := VBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stats)
	_health_label = _label(stats, "")
	_health_bar = _bar(stats, Color("91a882"))
	_endurance_label = _label(stats, "")
	_endurance_bar = _bar(stats, Color("b98a5e"))
	_phase_label = _label(stats, "PHASE  —")
	_phase_bar = _bar(stats, Color("6f97a8"))
	_wheat_label = _label(stats, "")
	_status_label = _label(stats, "")
	_status_label.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_label(column, "Wheat and the farmer drain automatically when close. Break the farmer, then stay close to consume it.")
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var controls := _label(footer, "WASD / arrows · Move     Mouse · Look     Space · Phase     Esc · Pause")
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(footer, "Pause", func() -> void: pause_requested.emit())
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0.025, 0.035, 0.035, 0.94)
	_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	_overlay.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_top = 28
	scroll.offset_right = -28
	scroll.offset_bottom = -28
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 16)
	card.add_child(_menu)
	update_health(100.0, 100.0)
	update_endurance(1.0)
	update_wheat(0, 0)
	hide_overlays()
	_hit_flash = ColorRect.new()
	_hit_flash.name = "HitFlash"
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_flash.color = Color(0.75, 0.03, 0.02, 0.0)
	_root.add_child(_hit_flash)
	_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit_flash.hide()
	set_process(false)


func configure_hit_feedback(camera: Camera3D) -> void:
	clear_hit_feedback()
	_hit_camera = camera
	if is_instance_valid(_hit_camera):
		_camera_baseline = Vector2(_hit_camera.h_offset, _hit_camera.v_offset)


func show_hit_feedback() -> void:
	if _paused or _results:
		return
	if _hit_remaining <= 0.0 and is_instance_valid(_hit_camera):
		_camera_baseline = Vector2(_hit_camera.h_offset, _hit_camera.v_offset)
	_hit_remaining = HIT_DURATION
	_hit_flash.show()
	_apply_hit_feedback()
	set_process(true)


func _process(delta: float) -> void:
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	if _hit_remaining <= 0.0:
		clear_hit_feedback()
		return
	_apply_hit_feedback()


func _apply_hit_feedback() -> void:
	var fraction: float = _hit_remaining / HIT_DURATION
	var strength: float = fraction * fraction
	var elapsed: float = HIT_DURATION - _hit_remaining
	_hit_flash.color.a = HIT_FLASH_ALPHA * strength
	if is_instance_valid(_hit_camera):
		_hit_camera.h_offset = _camera_baseline.x + cos(elapsed * 95.0) * HIT_CAMERA_OFFSET * strength
		_hit_camera.v_offset = _camera_baseline.y - cos(elapsed * 120.0) * HIT_CAMERA_OFFSET * 0.65 * strength


func clear_hit_feedback() -> void:
	_hit_remaining = 0.0
	set_process(false)
	if is_instance_valid(_hit_camera):
		_hit_camera.h_offset = _camera_baseline.x
		_hit_camera.v_offset = _camera_baseline.y
	if is_instance_valid(_hit_flash):
		_hit_flash.hide()
		_hit_flash.color.a = 0.0


func _exit_tree() -> void:
	clear_hit_feedback()


func update_health(current: float, maximum: float) -> void:
	_health_label.text = "VITALITY  %.0f / %.0f" % [current, maximum]
	_health_bar.value = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func update_endurance(fraction: float) -> void:
	var value: float = clampf(fraction, 0.0, 1.0)
	_endurance_label.text = "FARMER ENDURANCE  %d%%" % roundi(value * 100.0)
	_endurance_bar.value = value


func update_phase(ready: bool, remaining: float, duration: float, travelling: bool) -> void:
	if ready:
		_phase_label.text = "PHASE  READY"
		_phase_bar.value = 1.0
	elif travelling:
		_phase_label.text = "PHASE  TRAVELLING"
		_phase_bar.value = 0.0
	else:
		_phase_label.text = "PHASE  %.1fs" % maxf(remaining, 0.0)
		_phase_bar.value = (1.0 - clampf(remaining / duration, 0.0, 1.0)) if duration > 0.0 else 0.0


func update_wheat(harvested: int, total: int) -> void:
	_wheat_label.text = "WHEAT  %d / %d" % [harvested, total]


func set_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = not text.is_empty()


func show_pause() -> void:
	clear_hit_feedback()
	_paused = true
	_results = false
	_clear_menu()
	_label(_menu, "A moment of stillness", 28)
	_label(_menu, "Wheat and the farmer drain automatically. Break the farmer's endurance, then keep the Balancer close until the farmer is consumed.\nEsc pauses and releases the cursor; Esc or Resume returns to play.")
	var resume := _button(_menu, "Resume", func() -> void: _emit_menu_request(resume_requested))
	_button(_menu, "Retry encounter", func() -> void: _emit_menu_request(retry_requested))
	_overlay.show()
	resume.grab_focus()


func show_results(success: bool) -> void:
	if success:
		clear_hit_feedback()
	_paused = false
	_results = true
	set_status("")
	_clear_menu()
	_label(_menu, "The farmer is reclaimed" if success else "The shadow falls silent", 28)
	_label(_menu, "The field is quiet again." if success else "The farmer endured. Try the encounter again.")
	var retry := _button(_menu, "Try again", func() -> void: _emit_menu_request(retry_requested))
	_overlay.show()
	retry.grab_focus()


func hide_overlays() -> void:
	_overlay.hide()
	_paused = false
	_results = false
	var focused: Control = _root.get_viewport().gui_get_focus_owner()
	if focused != null and _overlay.is_ancestor_of(focused):
		focused.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or event.is_echo():
		return
	if _results:
		return
	if _paused:
		resume_requested.emit()
	else:
		pause_requested.emit()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not _paused and not _results:
		pause_requested.emit()


func _clear_menu() -> void:
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _emit_menu_request(request: Signal) -> void:
	for child: Node in _menu.get_children():
		if child is Button:
			child.disabled = true
	request.emit()


func _label(parent: Node, text: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _bar(parent: Node, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48.0
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("d8dfd1"))
	theme.set_color("font_color", "Button", Color("e4e8dc"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("172120")
	panel.content_margin_left = 18.0
	panel.content_margin_right = 18.0
	panel.content_margin_top = 14.0
	panel.content_margin_bottom = 14.0
	theme.set_stylebox("panel", "PanelContainer", panel)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("35483e") if state in ["hover", "pressed"] else Color("24312d")
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("bdcba3")
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0c1413")
	theme.set_stylebox("background", "ProgressBar", background)
	return theme
