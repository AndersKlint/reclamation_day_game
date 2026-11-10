extends Node3D

enum State { RUNNING, PAUSED, SUCCESS, FAILED }

const PhaseController = preload("res://game/balancer/phase_controller.gd")
const PlayerHurtAudio = preload("res://game/demo/farmer_combat/player_hurt_audio.gd")

var state: State = State.RUNNING
var _farmer_consumed: bool = false
var _resolution_pending: bool = false
var _retry_pending: bool = false
var _previous_health: float = 0.0
var _hurt_audio: PlayerHurtAudio

@onready var balancer: CharacterBody3D = $Balancer
@onready var phase_controller: PhaseController = $Balancer/PhaseController
@onready var farmer: Node3D = $Farmer
@onready var wheat: Node3D = $WheatPatch
@onready var remains: Node3D = $FarmerRemains
@onready var interface: CanvasLayer = $CombatInterface
@onready var _camera: Camera3D = $Balancer/CameraRig/SpringArm3D/Camera3D


func _ready() -> void:
	get_tree().paused = false
	_previous_health = balancer.health
	_hurt_audio = PlayerHurtAudio.new()
	_hurt_audio.name = "PlayerHurtAudio"
	add_child(_hurt_audio)
	interface.configure_hit_feedback(_camera)
	balancer.health_changed.connect(_on_health_changed)
	balancer.died.connect(_queue_resolution)
	farmer.endurance_changed.connect(_on_endurance_changed)
	farmer.defeated.connect(_on_farmer_defeated)
	farmer.consumed.connect(_on_farmer_consumed)
	wheat.progress_changed.connect(_on_wheat_changed)
	interface.pause_requested.connect(_on_pause_requested)
	interface.resume_requested.connect(_on_resume_requested)
	interface.retry_requested.connect(_on_retry_requested)
	farmer.call(&"configure", balancer, remains)
	interface.update_health(balancer.health, balancer.max_health)
	interface.update_endurance(1.0)
	interface.update_wheat(0, int(wheat.get(&"total_clumps")))
	_refresh_phase()
	_enable_gameplay.call_deferred()


func _process(_delta: float) -> void:
	if state == State.RUNNING:
		_refresh_phase()


func _refresh_phase() -> void:
	interface.update_phase(
		phase_controller.is_phase_ready(),
		phase_controller.get_cooldown_remaining(),
		phase_controller.get_cooldown_duration(),
		phase_controller.is_travelling())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_on_pause_requested()


func _enable_gameplay() -> void:
	if state == State.RUNNING:
		balancer.set_gameplay_enabled(true)


func _on_health_changed(current: float, maximum: float) -> void:
	var took_damage: bool = current < _previous_health
	_previous_health = current
	interface.update_health(current, maximum)
	if took_damage and state == State.RUNNING:
		interface.show_hit_feedback()
		_hurt_audio.play_hurt()
	_queue_resolution()


func _on_endurance_changed(fraction: float) -> void:
	interface.update_endurance(fraction)


func _on_wheat_changed(harvested: int, total: int) -> void:
	interface.update_wheat(harvested, total)


func _on_farmer_defeated() -> void:
	interface.set_status("FARMER BROKEN — stay close until consumed")
	_queue_resolution()


func _on_farmer_consumed() -> void:
	_farmer_consumed = true
	interface.set_status("FARMER CONSUMED")
	_queue_resolution()


func _queue_resolution() -> void:
	if _resolution_pending or state in [State.SUCCESS, State.FAILED]:
		return
	_resolution_pending = true
	_resolve.call_deferred()


func _resolve() -> void:
	_resolution_pending = false
	if state in [State.SUCCESS, State.FAILED] or _retry_pending:
		return
	# Failure wins simultaneous outcomes after the final drain transfer completes.
	if balancer.health <= 0.0:
		_fail()
		return
	if _farmer_consumed:
		_succeed()


func _on_pause_requested() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	_hurt_audio.cancel()
	balancer.set_gameplay_enabled(false)
	get_tree().paused = true
	interface.show_pause()


func _on_resume_requested() -> void:
	if state != State.PAUSED:
		return
	state = State.RUNNING
	interface.hide_overlays()
	get_tree().paused = false
	balancer.set_gameplay_enabled(true)


func _on_retry_requested() -> void:
	if _retry_pending or state not in [State.PAUSED, State.SUCCESS, State.FAILED]:
		return
	_retry_pending = true
	_hurt_audio.cancel()
	interface.clear_hit_feedback()
	balancer.set_gameplay_enabled(false)
	get_tree().reload_current_scene.call_deferred()


func _succeed() -> void:
	state = State.SUCCESS
	balancer.set_gameplay_enabled(false)
	if is_instance_valid(farmer) and farmer.has_method(&"stop"):
		farmer.call(&"stop")
	get_tree().paused = true
	interface.show_results(true)


func _fail() -> void:
	state = State.FAILED
	balancer.set_gameplay_enabled(false)
	if is_instance_valid(farmer) and farmer.has_method(&"stop"):
		farmer.call(&"stop")
	get_tree().paused = true
	interface.show_results(false)


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
