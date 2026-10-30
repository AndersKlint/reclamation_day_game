extends Node3D

const UpgradeDefinition = preload("res://game/upgrades/upgrade_definition.gd")
const Tracker = preload("res://game/upgrades/upgrade_tracker.gd")
const GameplaySfx = preload("res://game/run/gameplay_sfx.gd")

enum State { RUNNING, PAUSED, CHOOSING, FAILED, REBIRTH, FINISHED }

@export_range(0.1, 1.0) var completion_ratio: float = 0.9
@export_range(0.5, 10.0) var rebirth_duration: float = 4.0
@export var region: Node3D
@export var place_player_at_region_spawn: bool = false
@export var regional_encounters: bool = false
@export var demo_guidance: bool = false
@export var civilian_population: Node3D
var state: State = State.RUNNING
var _guidance_elapsed: float = 0.0
var _resolution_pending: bool = false
var _retry_pending: bool = false

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
	if place_player_at_region_spawn:
		balancer.global_position = region.get_player_spawn()
	balancer.health_changed.connect(_on_health_changed)
	balancer.growth_changed.connect(_on_growth_changed)
	balancer.died.connect(_queue_resolution)
	region.progress_changed.connect(_on_progress_changed)
	interface.upgrade_selected.connect(_on_upgrade_selected)
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
	_on_health_changed(balancer.health, balancer.max_health)
	_on_growth_changed(balancer.life, balancer.size)
	_on_progress_changed(region.drained_capacity, region.initial_capacity)
	human_director.start()
	if civilian_population != null:
		civilian_population.configure(region, balancer)
		civilian_population.start()
	if demo_guidance:
		_update_location()
	_enable_initial_gameplay.call_deferred()

func _process(delta: float) -> void:
	if not demo_guidance or state != State.RUNNING or get_tree().paused:
		return
	_guidance_elapsed += delta
	if _guidance_elapsed >= 0.5:
		_guidance_elapsed = 0.0
		_update_location()

func _update_location() -> void:
	match region.get_zone_at(balancer.global_position):
		&"field":
			interface.update_location("Southern fields", "Gather life among the hedgerows. Follow the road north toward the village.")
		&"approach":
			interface.update_location("Village approach", "The lamps mark the way north. Grow in the fields before facing the village resistance.")
		&"village":
			interface.update_location("Village", "Resistance is strongest here. Return to the fields if you need more life and reach.")

func _enable_initial_gameplay() -> void:
	if state == State.RUNNING and not _retry_pending:
		balancer.set_gameplay_enabled(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_on_pause_requested()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo():
		if state == State.RUNNING:
			_on_pause_requested()
		elif state == State.PAUSED:
			_on_resume_requested()
		get_viewport().set_input_as_handled()

func _on_health_changed(current: float, maximum: float) -> void:
	interface.update_health(current, maximum)
	_queue_resolution()

func _on_growth_changed(life: float, size: float) -> void:
	upgrades.record_life(life)
	interface.update_growth(life, size, upgrades.next_threshold)
	_queue_resolution()

func _on_progress_changed(drained: float, initial: float) -> void:
	interface.update_progress(drained, initial)
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
	if upgrades.has_pending():
		state = State.CHOOSING
		balancer.set_gameplay_enabled(false)
		get_tree().paused = true
		interface.show_upgrade_choices(upgrades.options)
	elif get_tree().paused:
		_enter_running()

func _on_upgrade_selected(definition: UpgradeDefinition) -> void:
	if state != State.CHOOSING or definition == null or not upgrades.options.has(definition):
		return
	if not upgrades.consume_pending():
		return
	state = State.RUNNING
	balancer.apply_upgrade(definition.effects)
	interface.hide_overlays()
	_queue_resolution()

func _on_pause_requested() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	balancer.set_gameplay_enabled(false)
	get_tree().paused = true
	interface.show_pause()

func _on_resume_requested() -> void:
	if state != State.PAUSED:
		return
	state = State.RUNNING
	interface.hide_overlays()
	_queue_resolution()

func _enter_running() -> void:
	state = State.RUNNING
	interface.hide_overlays()
	get_tree().paused = false
	balancer.set_gameplay_enabled(true)

func _fail_run() -> void:
	state = State.FAILED
	balancer.set_gameplay_enabled(false)
	human_director.stop()
	if civilian_population != null:
		civilian_population.stop()
	get_tree().paused = true
	interface.hide_overlays()
	interface.show_results(false, balancer.life, balancer.size, region.drained_capacity, region.initial_capacity)

func _begin_rebirth() -> void:
	state = State.REBIRTH
	interface.hide_overlays()
	balancer.set_gameplay_enabled(false)
	human_director.stop()
	if civilian_population != null:
		civilian_population.stop()
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
	human_director.stop()
	if civilian_population != null:
		civilian_population.stop()
	_reload_run.call_deferred()

func _reload_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
