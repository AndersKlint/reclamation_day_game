extends Node3D

const UpgradeOffer = preload("res://game/upgrades/upgrade_offer.gd")
const Tracker = preload("res://game/upgrades/upgrade_tracker.gd")
const GameplaySfx = preload("res://game/run/gameplay_sfx.gd")
const HitFeedback = preload("res://game/ui/hit_feedback.gd")
const PhaseController = preload("res://game/balancer/phase_controller.gd")
const VoidwalkerPresentation = preload("res://game/balancer/voidwalker_presentation.gd")

enum State { RUNNING, PAUSED, DEBUG_UPGRADES, CHOOSING, FAILED, REBIRTH, FINISHED }

@export_range(0.1, 1.0) var completion_ratio: float = 0.9
@export_range(0.5, 10.0) var rebirth_duration: float = 4.0
@export_range(0.0, 30.0, 0.1) var upgrade_delay_seconds: float = 5.0
@export var region: Node3D
@export var world_environment: WorldEnvironment
@export var ground_fog: FogVolume
@export var place_player_at_region_spawn: bool = false
@export var regional_encounters: bool = false
@export var civilian_population: Node3D
@export var city_traffic: Node3D
@export var tank_director: Node3D
var state: State = State.RUNNING
var _resolution_pending: bool = false
var _retry_pending: bool = false
var _opening: Node3D
var _opening_started: bool = false
var _escalation_started: bool = false
var _previous_health: float = 0.0
var _hit_feedback: HitFeedback
var _voidwalker_presentation: VoidwalkerPresentation
var _upgrade_delay_remaining: float = 0.0

@onready var balancer: CharacterBody3D = $Balancer
@onready var human_director: Node3D = $HumanDirector
@onready var upgrades: Tracker = $UpgradeTracker
@onready var interface: CanvasLayer = $Interface
@onready var life_release: Node3D = $LifeRelease

func _enter_tree() -> void:
	var sfx: Node3D = GameplaySfx.new()
	sfx.name = "GameplaySfx"
	sfx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sfx)

func _ready() -> void:
	get_tree().paused = false
	assert(region != null, "Run requires an injected region")
	_previous_health = balancer.health
	_hit_feedback = HitFeedback.new()
	_hit_feedback.name = "HitFeedback"
	add_child(_hit_feedback)
	_hit_feedback.configure(balancer.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D)
	if region.has_method(&"get_opening_encounter"):
		_opening = region.call(&"get_opening_encounter") as Node3D
	if _opening != null:
		_opening.completed.connect(_on_opening_completed)
	if place_player_at_region_spawn:
		balancer.global_position = region.get_player_spawn()
		balancer.reset_physics_interpolation()
	balancer.shockwave_controller.configure(balancer, self, Callable(region, "ground_position"))
	_configure_voidwalker_presentation()
	balancer.health_changed.connect(_on_health_changed)
	balancer.growth_changed.connect(_on_growth_changed)
	balancer.died.connect(_queue_resolution)
	region.progress_changed.connect(_on_progress_changed)
	interface.upgrade_selected.connect(_on_upgrade_selected)
	interface.debug_upgrade_selected.connect(_on_debug_upgrade_selected)
	interface.pause_requested.connect(_on_pause_requested)
	interface.resume_requested.connect(_on_resume_requested)
	interface.retry_requested.connect(_on_retry_requested)
	life_release.finished.connect(_finish_rebirth)
	var spawn_points: Array[Node3D] = []
	for point: Node in region.get_node("SpawnPoints").get_children():
		if point is Node3D:
			spawn_points.append(point)
	human_director.configure(balancer, spawn_points, Callable(region, "ground_position"))
	if regional_encounters:
		human_director.configure_region(region)
	_configure_city_managers()
	upgrades.configure()
	_on_health_changed(balancer.health, balancer.max_health)
	_on_growth_changed(balancer.life, balancer.size)
	_on_progress_changed(region.drained_capacity, region.initial_capacity)
	if civilian_population != null:
		civilian_population.configure(region, balancer)
		civilian_population.start()
	if city_traffic != null:
		city_traffic.call(&"start")
	_enable_initial_gameplay.call_deferred()

func _configure_city_managers() -> void:
	# Traffic registers its finite car capacity while configuring, so it must precede the first progress read.
	if city_traffic != null:
		city_traffic.call(&"configure", region, balancer)
	if tank_director != null:
		tank_director.call(&"configure", region, balancer)

func _configure_voidwalker_presentation() -> void:
	if world_environment == null or ground_fog == null or balancer.phase_controller == null:
		return
	_voidwalker_presentation = VoidwalkerPresentation.new()
	_voidwalker_presentation.name = "VoidwalkerPresentation"
	add_child(_voidwalker_presentation)
	_voidwalker_presentation.configure(world_environment, ground_fog, balancer, balancer.camera, balancer.phase_controller)

func _process(delta: float) -> void:
	if state == State.RUNNING and not get_tree().paused:
		_refresh_phase()
		_refresh_upgrade_timers()
		if upgrades.has_pending():
			_upgrade_delay_remaining = maxf(0.0, _upgrade_delay_remaining - delta)
			if _upgrade_delay_remaining <= 0.0:
				_queue_resolution()

func _enable_initial_gameplay() -> void:
	if state == State.RUNNING and not _retry_pending:
		balancer.set_gameplay_enabled(true)
		_start_opening()
		_queue_resolution()

func _start_opening() -> void:
	if _opening == null or _opening_started:
		return
	_opening_started = true
	_opening.call(&"configure", balancer)
	_opening.call(&"start")

func _on_opening_completed() -> void:
	balancer.activate_volume_drain()
	_queue_resolution()

func _start_escalation() -> void:
	if _escalation_started or balancer.health <= 0.0 or state != State.RUNNING or get_tree().paused or _retry_pending:
		return
	if _opening != null and (not _opening_started or not bool(_opening.get(&"is_completed"))):
		return
	_escalation_started = true
	human_director.start()
	if region.has_method(&"start_field_encounters"):
		region.call(&"start_field_encounters", balancer)
	if tank_director != null:
		tank_director.call(&"start")

func _refresh_upgrade_timers() -> void:
	var lines: PackedStringArray = balancer.shockwave_controller.get_timer_lines()
	var owned: Array[StringName] = upgrades.get_owned_definitions()
	var phase: PhaseController = balancer.phase_controller
	if phase != null:
		if owned.has(&"phase_cooldown") or owned.has(&"phase_return") or owned.has(&"touche"):
			lines.append("Phase · %.1fs" % phase.get_cooldown_remaining() if not phase.is_phase_ready() else "Phase · Ready")
		if owned.has(&"voidwalker"):
			lines.append("Voidwalker · %.1fs" % phase.get_void_remaining() if phase.get_void_remaining() > 0.0 else "Voidwalker · Ready on phase")
		elif phase.get_void_remaining() > 0.0:
			lines.append("Void · %.1fs" % phase.get_void_remaining())
		if balancer.last_stand:
			var status: String = "Armed"
			if balancer.last_stand_spent:
				status = "Active %.1fs" % balancer.last_stand_remaining if balancer.last_stand_remaining > 0.0 else "Spent"
			lines.append("Last Stand · " + status)
	interface.update_upgrade_timers(lines)

func _refresh_phase() -> void:
	var phase: PhaseController = balancer.phase_controller
	if phase != null:
		interface.update_phase(phase.is_phase_ready(), phase.get_cooldown_remaining(), phase.get_cooldown_duration(), phase.is_travelling())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_on_pause_requested()

# End is consumed by the focused ScrollContainer, so debug input runs before UI.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_upgrades") and not event.is_echo():
		if state == State.RUNNING:
			_open_debug_upgrades()
		elif state == State.DEBUG_UPGRADES:
			_on_resume_requested()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and not event.is_echo() and state == State.DEBUG_UPGRADES:
		_on_resume_requested()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		if state == State.RUNNING:
			_on_pause_requested()
		elif state == State.PAUSED:
			_on_resume_requested()
		get_viewport().set_input_as_handled()

func _on_health_changed(current: float, maximum: float) -> void:
	var took_damage: bool = current < _previous_health
	_previous_health = current
	interface.update_health(current, maximum)
	if took_damage and state == State.RUNNING and not get_tree().paused:
		_hit_feedback.play_hit()
	_queue_resolution()

func _on_growth_changed(life: float, size: float) -> void:
	var had_pending: bool = upgrades.has_pending()
	upgrades.record_life(life)
	if not had_pending and upgrades.has_pending():
		_upgrade_delay_remaining = upgrade_delay_seconds
	interface.update_growth(life, size, upgrades.next_threshold)
	_queue_resolution()

func _on_progress_changed(drained: float, initial: float) -> void:
	human_director.set_progress(drained, initial)
	_queue_resolution()

func _queue_resolution() -> void:
	if _resolution_pending or state in [State.FAILED, State.REBIRTH, State.FINISHED]:
		return
	_resolution_pending = true
	_resolve_update.call_deferred()

func _resolve_update() -> void:
	_resolution_pending = false
	if state in [State.FAILED, State.REBIRTH, State.FINISHED] or _retry_pending:
		return
	# Failure wins simultaneous outcomes after the final actual drain transfer completes.
	if balancer.health <= 0.0:
		_fail_run()
		return
	if region.initial_capacity > 0.0 and region.drained_capacity >= region.initial_capacity * completion_ratio:
		_begin_rebirth()
		return
	if state != State.RUNNING:
		return
	var travelling: bool = balancer.phase_controller != null and balancer.phase_controller.is_travelling()
	if upgrades.has_pending() and _upgrade_delay_remaining <= 0.0 and not travelling:
		state = State.CHOOSING
		_hit_feedback.cancel()
		balancer.set_gameplay_enabled(false)
		get_tree().paused = true
		interface.show_upgrade_choices(upgrades.get_or_create_offers(), upgrades.pending_rewards)
	elif get_tree().paused:
		_enter_running()
	else:
		_start_escalation()

func _on_upgrade_selected(offer: UpgradeOffer) -> void:
	if state != State.CHOOSING or offer == null:
		return
	if not upgrades.select_offer(offer):
		return
	state = State.RUNNING
	_upgrade_delay_remaining = upgrade_delay_seconds
	_apply_upgrade(offer)
	interface.hide_overlays()
	_queue_resolution()

func _on_debug_upgrade_selected(offer: UpgradeOffer) -> void:
	if state != State.DEBUG_UPGRADES or offer == null:
		return
	if not upgrades.grant_debug_offer(offer):
		return
	_apply_upgrade(offer)
	_on_resume_requested()

func _apply_upgrade(offer: UpgradeOffer) -> void:
	var growth_changed: bool = balancer.apply_upgrade_variant(
		offer.variant.get_effects(), offer.variant.size_multiplier,
		offer.variant.healing_disabled, offer.variant.pacifist,
		offer.variant.proximity_drain_bonus_percent, offer.variant.lock_visible_size,
		offer.variant.growth_bonus_retention, offer.variant.phase_size_multiplier)
	balancer.phase_reflection = balancer.phase_reflection or offer.variant.phase_reflection
	balancer.last_stand = balancer.last_stand or offer.variant.last_stand
	balancer.shockwave_controller.grant(offer.variant.shockwave, offer.definition.title)
	if offer.variant.phase_return:
		balancer.enable_phase_return()
	if offer.variant.projectile_reflection > 0.0:
		balancer.set_projectile_reflection_chance(offer.variant.projectile_reflection / 100.0)
	if offer.variant.phase_through_objects:
		balancer.enable_phase_through_objects()
	if offer.variant.voidwalker_duration > 0.0:
		balancer.enable_voidwalker(offer.variant.voidwalker_duration)
	if growth_changed:
		balancer.emit_growth_changed()
	else:
		_refresh_growth_display()

func _refresh_growth_display() -> void:
	interface.update_growth(balancer.life, balancer.size, upgrades.next_threshold)

func _open_debug_upgrades() -> void:
	if state != State.RUNNING or _retry_pending or get_tree().paused:
		return
	state = State.DEBUG_UPGRADES
	_hit_feedback.cancel()
	balancer.set_gameplay_enabled(false)
	get_tree().paused = true
	interface.show_debug_upgrades(upgrades.get_debug_offers(), upgrades.get_owned_definitions())

func _on_pause_requested() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	_hit_feedback.cancel()
	balancer.set_gameplay_enabled(false)
	get_tree().paused = true
	interface.show_pause()

func _on_resume_requested() -> void:
	if state not in [State.PAUSED, State.DEBUG_UPGRADES]:
		return
	state = State.RUNNING
	interface.hide_overlays()
	_queue_resolution()

func _enter_running() -> void:
	state = State.RUNNING
	interface.hide_overlays()
	get_tree().paused = false
	balancer.set_gameplay_enabled(true)
	_start_opening()
	_start_escalation()

func _fail_run() -> void:
	state = State.FAILED
	balancer.set_gameplay_enabled(false)
	_stop_managers()
	get_tree().paused = true
	interface.hide_overlays()
	interface.show_results(false, balancer.life, balancer.size, region.drained_capacity, region.initial_capacity)

func _begin_rebirth() -> void:
	state = State.REBIRTH
	interface.hide_overlays()
	balancer.set_gameplay_enabled(false)
	_stop_managers()
	get_tree().paused = false
	region.renew(rebirth_duration)
	life_release.begin(balancer.global_position, balancer.get_node("Visuals"), rebirth_duration)

func _finish_rebirth() -> void:
	if state != State.REBIRTH:
		return
	state = State.FINISHED
	get_tree().paused = true
	interface.show_results(true, balancer.life, balancer.size, region.drained_capacity, region.initial_capacity)

func _on_retry_requested() -> void:
	if _retry_pending or state not in [State.PAUSED, State.FAILED, State.FINISHED]:
		return
	_retry_pending = true
	balancer.set_gameplay_enabled(false)
	_stop_managers()
	_reload_run.call_deferred()

func _clear_void() -> void:
	if balancer.phase_controller != null:
		balancer.phase_controller.clear_void()
	if _voidwalker_presentation != null:
		_voidwalker_presentation.set_active(false)

func _stop_managers() -> void:
	_clear_void()
	_hit_feedback.cancel()
	if _opening != null:
		_opening.call(&"stop")
	if region.has_method(&"stop_field_encounters"):
		region.call(&"stop_field_encounters")
	human_director.stop()
	if civilian_population != null:
		civilian_population.stop()
	if city_traffic != null:
		city_traffic.call(&"stop")
	if tank_director != null:
		tank_director.call(&"stop")

func _reload_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
