extends CanvasLayer

const UpgradeOffer = preload("res://game/upgrades/upgrade_offer.gd")
const UpgradeVariant = preload("res://game/upgrades/upgrade_variant.gd")

signal upgrade_selected(offer: UpgradeOffer)
signal debug_upgrade_selected(offer: UpgradeOffer)
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
var _phase_label: Label
var _phase_bar: ProgressBar
var _void_label: Label
var _endurance_label: Label
var _endurance_bar: ProgressBar
var _opening_status: Label
var _controls_label: Label
var _overlay: ColorRect
var _menu: VBoxContainer
var _menu_panel: PanelContainer
var _menu_scroll: ScrollContainer
var _showing_upgrades: bool = false
var _debug_upgrades: bool = false
var _upgrade_timers: Label


func update_upgrade_timers(lines: PackedStringArray) -> void:
	_upgrade_timers.text = "\n".join(lines)

func _ready() -> void:
	_root = Control.new()
	_root.name = "Layout"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	_upgrade_timers = Label.new()
	_upgrade_timers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_upgrade_timers)
	_upgrade_timers.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_upgrade_timers.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_upgrade_timers.position = Vector2(-340.0, 20.0)
	_upgrade_timers.size.x = 320.0
	_upgrade_timers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_phase_label = _label(stats, "")
	_phase_bar = _bar(stats)
	_phase_label.hide()
	_phase_bar.hide()
	_void_label = _label(stats, "")
	_void_label.hide()
	_endurance_label = _label(stats, "")
	_endurance_bar = _bar(stats)
	hide_endurance()
	_opening_status = _label(stats, "")
	_opening_status.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_label(column, "Nearby life drains automatically. Grow to consume larger targets.")
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	_controls_label = _label(footer, "Mouse · Orbit     WASD / arrows · Move     Esc · Pause / cursor")
	_controls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(footer, "Pause", func() -> void: pause_requested.emit())
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0.025, 0.035, 0.035, 0.94)
	_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	_menu_scroll = scroll
	_overlay.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_top = 28
	scroll.offset_right = -28
	scroll.offset_bottom = -28
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	_menu_panel = card
	card.custom_minimum_size.x = 720.0
	card.custom_maximum_size.x = 820.0
	card.propagate_maximum_size = true
	center.add_child(card)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 16)
	card.add_child(_menu)
	_root.resized.connect(_resize_upgrade_menu)
	update_health(100.0, 100.0)
	update_growth(0.0, 1.0, 40.0)
	update_progress(0.0, 0.0)
	hide_overlays()


func update_health(current: float, maximum: float) -> void:
	_health_label.text = "VITALITY  %.0f / %.0f" % [current, maximum]
	_health_bar.value = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func update_growth(life: float, size: float, next_threshold: float, earned_tiers: int = 0, volume: float = 0.0, visible_locked: bool = false, visible_size: float = 1.0) -> void:
	var next_text: String = "NEXT CHOICE AT —" if is_inf(next_threshold) else "NEXT CHOICE AT %s" % _format_amount(next_threshold)
	if visible_locked:
		_growth_label.text = "LIFE  %s     VIRTUAL SIZE  %.2f×\nVIRTUAL VOLUME  %s m³     VISIBLE SIZE  %.2f×\nTIER  %d     %s" % [
			_format_amount(life), size, _format_amount(volume), visible_size, earned_tiers, next_text]
		return
	_growth_label.text = "LIFE  %s     SIZE  %.2f×     VOLUME  %s m³\nTIER  %d     %s" % [
		_format_amount(life), size, _format_amount(volume), earned_tiers, next_text]


func update_progress(drained: float, initial: float) -> void:
	var fraction: float = clampf(drained / initial, 0.0, 1.0) if initial > 0.0 else 0.0
	_progress_bar.value = fraction
	_progress_label.text = "REGION RECLAIMED  %.1f%%" % (fraction * 100.0)


func update_location(title: String, detail: String) -> void:
	_location_label.text = title.to_upper() + "\n" + detail
	_location_label.show()


func update_phase(ready: bool, remaining: float, duration: float, travelling: bool, void_remaining: float) -> void:
	_controls_label.text = "Mouse · Orbit     WASD / arrows · Move     Space · Phase     Esc · Pause / cursor"
	_phase_label.show()
	_phase_bar.show()
	if ready:
		_phase_label.text = "PHASE  READY · Space"
		_phase_bar.value = 1.0
	elif travelling:
		_phase_label.text = "PHASE  TRAVELLING"
		_phase_bar.value = 0.0
	else:
		_phase_label.text = "PHASE  %.1fs" % maxf(remaining, 0.0)
		_phase_bar.value = 1.0 - clampf(remaining / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	if void_remaining > 0.0:
		_void_label.text = "VOID  IMMUNE · %.1fs" % void_remaining
		_void_label.show()
	else:
		_void_label.hide()


func update_endurance(fraction: float) -> void:
	var value: float = clampf(fraction, 0.0, 1.0)
	_endurance_label.text = "FARMER ENDURANCE  %d%%" % roundi(value * 100.0)
	_endurance_bar.value = value
	_endurance_label.show()
	_endurance_bar.show()


func hide_endurance() -> void:
	_endurance_label.hide()
	_endurance_bar.hide()


func set_opening_status(text: String) -> void:
	_opening_status.text = text
	_opening_status.visible = not text.is_empty()


func show_upgrade_choices(offers: Array[UpgradeOffer], pending_count: int = 1) -> void:
	_clear_menu()
	_showing_upgrades = true
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_resize_upgrade_menu()
	_centered_label(_menu, "The shadow deepens", 28)
	if pending_count > 1:
		_centered_label(_menu, "%d growth choices are queued. Choose one upgrade for each growth." % pending_count)
	else:
		_centered_label(_menu, "Choose what remains with you.")
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	choices.custom_minimum_size.y = 360.0
	_menu.add_child(choices)
	var buttons: Array[Button] = []
	var focus_target: Button = null
	for offer: UpgradeOffer in offers:
		var choice: Button = _upgrade_card(choices, offer)
		buttons.append(choice)
		if focus_target == null:
			focus_target = choice
	for index: int in buttons.size():
		buttons[index].focus_neighbor_left = buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())])
		buttons[index].focus_neighbor_right = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
	_overlay.show()
	if focus_target != null:
		focus_target.grab_focus()


func show_debug_upgrades(offers: Array[UpgradeOffer], owned: Array[StringName]) -> void:
	_clear_menu()
	_showing_upgrades = true
	_debug_upgrades = true
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_resize_upgrade_menu()
	_centered_label(_menu, "Debug upgrades", 28)
	_centered_label(_menu, "All catalog upgrades. Select one to apply and close.")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_menu.add_child(grid)
	var focus_target: Button = null
	for offer: UpgradeOffer in offers:
		var owned_unique: bool = not offer.definition.repeatable and owned.has(offer.definition.id)
		var card: Button = _upgrade_card(grid, offer, owned_unique)
		card.custom_minimum_size.y = 360.0
		if not owned_unique and focus_target == null:
			focus_target = card
	_overlay.show()
	if focus_target != null:
		focus_target.grab_focus()
	_menu_scroll.set_deferred(&"scroll_vertical", 0)


func show_pause() -> void:
	_clear_menu()
	_label(_menu, "A moment of stillness", 28)
	var phase_controls: String = "\nSpace phases in the movement direction, avoiding damage during travel." if _phase_label.visible else ""
	_label(_menu, "Mouse to look / orbit. WASD / arrows move relative to the camera.\nThe Balancer turns toward movement. Nearby life drains automatically." + phase_controls + "\nEsc pauses and releases the cursor; Esc or Resume returns to play.\nGrow before approaching larger life.")
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
	_showing_upgrades = false
	_debug_upgrades = false
	_menu_panel.custom_minimum_size.x = 720.0
	_menu_panel.custom_maximum_size.x = 820.0
	_menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for child: Node in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()


func _resize_upgrade_menu() -> void:
	if not _showing_upgrades:
		return
	var width: float = minf(1120.0, _root.size.x - 56.0)
	_menu_panel.custom_minimum_size.x = width
	_menu_panel.custom_maximum_size.x = width


func _select_upgrade(offer: UpgradeOffer) -> void:
	_disable_choice_buttons()
	if _debug_upgrades:
		debug_upgrade_selected.emit(offer)
	else:
		upgrade_selected.emit(offer)


func _disable_choice_buttons() -> void:
	for child: Node in _menu.find_children("*", "BaseButton", true, false):
		(child as BaseButton).disabled = true


func _upgrade_card(parent: Container, offer: UpgradeOffer, owned: bool = false) -> Button:
	var rarity_name: String
	var rarity_color: Color
	match offer.variant.rarity:
		UpgradeVariant.Rarity.COMMON:
			rarity_name = "Common"
			rarity_color = Color("a6adb4")
		UpgradeVariant.Rarity.UNCOMMON:
			rarity_name = "Uncommon"
			rarity_color = Color("75c98b")
		UpgradeVariant.Rarity.EPIC:
			rarity_name = "Epic"
			rarity_color = Color("bf90ef")
		UpgradeVariant.Rarity.LEGENDARY:
			rarity_name = "Legendary"
			rarity_color = Color("e8c35f")
		_:
			rarity_name = "Unknown"
			rarity_color = Color.WHITE
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(_select_upgrade.bind(offer))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1d2926")
		if state == "hover":
			style.bg_color = Color("35483e")
		elif state == "pressed":
			style.bg_color = Color("111c19")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
		style.border_color = rarity_color
		style.set_border_width_all(5 if state == "focus" else 3)
		card.add_theme_stylebox_override(state, style)
	parent.add_child(card)
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 20)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margins.add_child(content)
	_centered_label(content, offer.definition.title, 22)
	var rarity_label: Label = _centered_label(content, rarity_name, 16)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	_centered_label(content, offer.definition.flavor_text, 16)
	_centered_label(content, offer.variant.get_description())
	if owned:
		card.disabled = true
		card.tooltip_text = "Already owned"
		var owned_label: Label = _centered_label(content, "OWNED", 16)
		owned_label.add_theme_color_override("font_color", rarity_color)
	return card


func _centered_label(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = _label(parent, text, font_size)
	label.custom_minimum_size.x = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _format_amount(value: float) -> String:
	if is_nan(value):
		return "—"
	var magnitude: float = absf(value)
	if magnitude > 0.0 and magnitude < 0.01:
		return String.num_scientific(value)
	if magnitude < 10.0:
		return "%.2f" % value
	if magnitude < 10_000.0:
		return "%.0f" % value
	if magnitude < 1_000_000.0:
		return "%.1fK" % (value / 1_000.0)
	if magnitude < 1_000_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if magnitude < 1_000_000_000_000.0:
		return "%.2fB" % (value / 1_000_000_000.0)
	return String.num_scientific(value)


func _emit_menu_request(request: Signal) -> void:
	_disable_choice_buttons()
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
