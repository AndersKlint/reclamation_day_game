extends CanvasLayer

const UpgradeDefinition = preload("res://game/upgrades/upgrade_definition.gd")

signal upgrade_selected(definition: UpgradeDefinition)
signal upgrade_batch_selected(definition: UpgradeDefinition)
signal pause_requested()
signal resume_requested()
signal retry_requested()

var _root: Control
var _health_label: Label
var _health_bar: ProgressBar
var _growth_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _location_label: Label
var _overlay: ColorRect
var _menu: VBoxContainer


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
	_health_bar = _bar(stats)
	_growth_label = _label(stats, "")
	_progress_label = _label(stats, "")
	_progress_bar = _bar(stats)
	_location_label = _label(stats, "")
	_location_label.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_label(column, "Nearby life drains automatically. Grow to consume larger targets.")
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var controls := _label(footer, "Mouse · Orbit     WASD / arrows · Move     Esc · Pause / cursor")
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
	update_growth(0.0, 1.0, 40.0)
	update_progress(0.0, 0.0)
	hide_overlays()


func update_health(current: float, maximum: float) -> void:
	_health_label.text = "VITALITY  %.0f / %.0f" % [current, maximum]
	_health_bar.value = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func update_growth(life: float, size: float, next_threshold: float, earned_tiers: int = 0) -> void:
	var next_text: String = "NEXT CHOICE AT —" if is_inf(next_threshold) else "NEXT CHOICE AT %s" % _format_amount(next_threshold)
	_growth_label.text = "LIFE  %s     SIZE  %.2f×\nTIER  %d     %s" % [
		_format_amount(life), size, earned_tiers, next_text]


func update_progress(drained: float, initial: float) -> void:
	var fraction: float = clampf(drained / initial, 0.0, 1.0) if initial > 0.0 else 0.0
	_progress_bar.value = fraction
	_progress_label.text = "REGION RECLAIMED  %.1f%%" % (fraction * 100.0)


func update_location(title: String, detail: String) -> void:
	_location_label.text = title.to_upper() + "\n" + detail
	_location_label.show()


func show_upgrade_choices(definitions: Array[UpgradeDefinition], pending_count: int = 1) -> void:
	_clear_menu()
	_label(_menu, "The shadow deepens", 28)
	if pending_count > 1:
		_label(_menu, "%d growth choices are queued. Take one, or apply a single path to all %d." % [pending_count, pending_count])
	else:
		_label(_menu, "Choose what remains with you. Each choice stacks multiplicatively.")
	var focus_target: Button = null
	for definition: UpgradeDefinition in definitions:
		if definition == null:
			continue
		var choice := _button(_menu, definition.title + "\n" + definition.description,
			_select_upgrade.bind(definition))
		if focus_target == null:
			focus_target = choice
		if pending_count > 1:
			_button(_menu, "Apply %s to all %d queued growths" % [definition.title, pending_count],
				_select_upgrade_batch.bind(definition))
	_overlay.show()
	if focus_target != null:
		focus_target.grab_focus()


func show_pause() -> void:
	_clear_menu()
	_label(_menu, "A moment of stillness", 28)
	_label(_menu, "Mouse to look / orbit. WASD / arrows move relative to the camera.\nThe Balancer turns toward movement. Nearby life drains automatically.\nEsc pauses and releases the cursor; Esc or Resume returns to play.\nGrow before approaching larger life.")
	var resume := _button(_menu, "Resume", func() -> void: _emit_menu_request(resume_requested))
	_button(_menu, "Retry region", func() -> void: _emit_menu_request(retry_requested))
	_overlay.show()
	resume.grab_focus()


func show_results(success: bool, life: float = 0.0, size: float = 1.0, drained: float = 0.0, initial: float = 0.0) -> void:
	_clear_menu()
	_label(_menu, "What was taken returns" if success else "The shadow falls silent", 28)
	_label(_menu, "The fields breathe again." if success else "The living have endured. Wander once more.")
	var percent: float = clampf(drained / initial, 0.0, 1.0) * 100.0 if initial > 0.0 else 0.0
	_label(_menu, "Life gathered: %.0f\nFinal size: %.2f×\nRegion reclaimed: %.1f%%" % [life, size, percent])
	var retry := _button(_menu, "Begin again", func() -> void: _emit_menu_request(retry_requested))
	_overlay.show()
	retry.grab_focus()


func hide_overlays() -> void:
	_overlay.hide()
	var focused: Control = _root.get_viewport().gui_get_focus_owner()
	if focused != null and _overlay.is_ancestor_of(focused):
		focused.release_focus()


func _clear_menu() -> void:
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _select_upgrade(definition: UpgradeDefinition) -> void:
	_disable_choice_buttons()
	upgrade_selected.emit(definition)


func _select_upgrade_batch(definition: UpgradeDefinition) -> void:
	_disable_choice_buttons()
	upgrade_batch_selected.emit(definition)


func _disable_choice_buttons() -> void:
	for child: Node in _menu.get_children():
		if child is Button:
			child.disabled = true


func _format_amount(value: float) -> String:
	if is_nan(value):
		return "—"
	var magnitude: float = absf(value)
	if magnitude < 10_000.0:
		return "%.0f" % value
	if magnitude < 1_000_000.0:
		return "%.1fK" % (value / 1_000.0)
	if magnitude < 1_000_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if magnitude < 1_000_000_000_000.0:
		return "%.2fB" % (value / 1_000_000_000.0)
	return "%.2e" % value


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


func _bar(parent: Node) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("91a882")
	theme.set_stylebox("fill", "ProgressBar", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0c1413")
	theme.set_stylebox("background", "ProgressBar", background)
	return theme
