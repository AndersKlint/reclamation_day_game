extends Node3D

signal phase_started()
signal phase_finished()
signal state_changed(state: State)
signal cooldown_changed(remaining: float, duration: float)

enum State { READY, TRAVELLING, COOLDOWN }

const PhaseVfx = preload("res://game/balancer/phase_vfx.gd")
const PhaseAudio = preload("res://game/balancer/phase_audio.gd")

@export var travel_time: float = 0.18
@export var travel_distance: float = 3.5
@export var cooldown_seconds: float = 1.0

var _state: State = State.READY
var _travel_remaining: float = 0.0
var _cooldown_remaining: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _reaper: Node3D
var _reaper_visible: bool = true
var _presentation_active: bool = false
var _vfx: PhaseVfx
var _audio: PhaseAudio

func _ready() -> void:
	_vfx = PhaseVfx.new()
	_vfx.name = "PhaseVfx"
	add_child(_vfx)
	_audio = PhaseAudio.new()
	_audio.name = "PhaseAudio"
	add_child(_audio)

func bind(reaper: Node3D) -> void:
	_reaper = reaper

func try_activate(direction: Vector3) -> bool:
	if _state != State.READY:
		return false
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx() or not flat.is_finite():
		return false
	_direction = flat.normalized()
	_travel_remaining = maxf(travel_time, 0.001)
	_state = State.TRAVELLING
	_begin_presentation()
	if _audio != null:
		_audio.play_swoop()
	state_changed.emit(_state)
	phase_started.emit()
	return true

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	match _state:
		State.TRAVELLING:
			_travel_remaining -= delta
			if _travel_remaining <= 0.0:
				_finish_travel()
		State.COOLDOWN:
			_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
			if _cooldown_remaining <= 0.0:
				_state = State.READY
				state_changed.emit(_state)
				cooldown_changed.emit(0.0, get_cooldown_duration())

func cancel() -> void:
	if _audio != null:
		_audio.cancel()
	if _state == State.TRAVELLING:
		_travel_remaining = 0.0
		_direction = Vector3.ZERO
		_finish_travel()

func is_travelling() -> bool:
	return _state == State.TRAVELLING

func is_invulnerable() -> bool:
	return _state == State.TRAVELLING

func is_phase_ready() -> bool:
	return _state == State.READY

func get_state() -> State:
	return _state

func get_travel_direction() -> Vector3:
	return _direction

func get_travel_remaining() -> float:
	return _travel_remaining

func get_travel_velocity() -> Vector3:
	return _direction * (maxf(travel_distance, 0.0) / maxf(travel_time, 0.001))

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func get_cooldown_duration() -> float:
	return maxf(cooldown_seconds, 0.0)

func get_cooldown_remaining_ratio() -> float:
	var duration: float = get_cooldown_duration()
	return _cooldown_remaining / duration if duration > 0.0 else 0.0

func _finish_travel() -> void:
	_end_presentation()
	_cooldown_remaining = get_cooldown_duration()
	_state = State.COOLDOWN
	state_changed.emit(_state)
	cooldown_changed.emit(_cooldown_remaining, get_cooldown_duration())
	phase_finished.emit()

func _begin_presentation() -> void:
	if _presentation_active:
		return
	_presentation_active = true
	if _reaper != null:
		_reaper_visible = _reaper.visible
		_reaper.visible = false
	if _vfx != null:
		_vfx.set_active(true)

func _end_presentation() -> void:
	if not _presentation_active:
		return
	_presentation_active = false
	if _reaper != null:
		_reaper.visible = _reaper_visible
	if _vfx != null:
		_vfx.set_active(false)
