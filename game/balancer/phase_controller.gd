extends Node3D

signal phase_started()
signal phase_finished()
signal phase_completed()
signal state_changed(state: State)
signal cooldown_changed(remaining: float, duration: float)
signal void_changed(active: bool)

enum State { READY, TRAVELLING, COOLDOWN }

const PhaseVfx = preload("res://game/balancer/phase_vfx.gd")
const PhaseAudio = preload("res://game/balancer/phase_audio.gd")
const MIN_COOLDOWN: float = 1.0e-12
const MAX_COOLDOWN: float = 1.0e100

@export var travel_time: float = 0.18
@export var travel_distance: float = 3.5
@export var cooldown_seconds: float = 8.0

var _state: State = State.READY
var _travel_remaining: float = 0.0
var _travel_size: float = 1.0
var _travel_velocity: Vector3 = Vector3.ZERO
var _cooldown_remaining: float = 0.0
var _cooldown_multiplier: float = 1.0
var _distance_multiplier: float = 1.0
var _direction: Vector3 = Vector3.ZERO
var _reaper: Node3D
var _reaper_visible: bool = true
var _presentation_active: bool = false
var _vfx: PhaseVfx
var _audio: PhaseAudio
var _phase_return_enabled: bool = false
var _return_available: bool = false
var _landing_resolver: Callable
var _void_enabled: bool = false
var _void_duration: float = 0.0
var _void_remaining: float = 0.0

func _ready() -> void:
	_vfx = PhaseVfx.new()
	_vfx.name = "PhaseVfx"
	add_child(_vfx)
	_audio = PhaseAudio.new()
	_audio.name = "PhaseAudio"
	add_child(_audio)

func bind(reaper: Node3D) -> void:
	_reaper = reaper

func set_sizes(travel_size: float, presentation_size: float) -> void:
	_travel_size = maxf(travel_size, 0.001) if is_finite(travel_size) else 1.0
	if _vfx != null:
		_vfx.configure(maxf(presentation_size, 0.001) if is_finite(presentation_size) else 1.0)

func set_upgrade_multipliers(cooldown: float, distance: float) -> void:
	if not is_finite(cooldown) or not is_finite(distance):
		return
	_distance_multiplier = clampf(distance, 0.01, 1_000_000.0)
	var next_cooldown: float = clampf(cooldown, MIN_COOLDOWN, MAX_COOLDOWN)
	if next_cooldown == _cooldown_multiplier:
		return
	var remaining_ratio: float = get_cooldown_remaining_ratio()
	_cooldown_multiplier = next_cooldown
	if _state == State.COOLDOWN:
		_cooldown_remaining = remaining_ratio * get_cooldown_duration()
	cooldown_changed.emit(_cooldown_remaining, get_cooldown_duration())

func try_activate(direction: Vector3) -> bool:
	if _state != State.READY:
		return false
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx() or not flat.is_finite():
		return false
	_return_available = false
	_direction = flat.normalized()
	_travel_remaining = maxf(travel_time, 0.001)
	_travel_velocity = _direction * (maxf(travel_distance, 0.0) * _distance_multiplier * _travel_size / _travel_remaining)
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
	if _void_remaining > 0.0:
		_void_remaining = maxf(0.0, _void_remaining - delta)
		if _void_remaining <= 0.0:
			void_changed.emit(false)
	match _state:
		State.TRAVELLING:
			_travel_remaining -= delta
			if _travel_remaining <= 0.0:
				_finish_travel(true)
		State.COOLDOWN:
			_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
			if _cooldown_remaining <= 0.0:
				_return_available = false
				_state = State.READY
				state_changed.emit(_state)
				cooldown_changed.emit(0.0, get_cooldown_duration())

func cancel() -> void:
	_return_available = false
	if _audio != null:
		_audio.cancel()
	if _state == State.TRAVELLING:
		_travel_remaining = 0.0
		_direction = Vector3.ZERO
		_finish_travel(false)
	if _vfx != null:
		_vfx.clear()

func enable_phase_return() -> void:
	_phase_return_enabled = true

func is_return_available() -> bool:
	return _phase_return_enabled and _return_available and _state == State.COOLDOWN

func consume_return() -> void:
	_return_available = false

func is_travelling() -> bool:
	return _state == State.TRAVELLING

func is_invulnerable() -> bool:
	return _state == State.TRAVELLING or _void_remaining > 0.0

func enable_voidwalker(duration: float) -> void:
	if not is_finite(duration) or duration <= 0.0:
		return
	_void_enabled = true
	_void_duration = duration

func get_void_remaining() -> float:
	return _void_remaining

func clear_void() -> void:
	var was_active: bool = _void_remaining > 0.0
	_void_remaining = 0.0
	if was_active:
		void_changed.emit(false)

func set_landing_resolver(resolver: Callable) -> void:
	_landing_resolver = resolver

func is_phase_ready() -> bool:
	return _state == State.READY

func get_state() -> State:
	return _state

func get_travel_direction() -> Vector3:
	return _direction

func get_travel_remaining() -> float:
	return _travel_remaining

func get_travel_velocity() -> Vector3:
	return _travel_velocity

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func get_cooldown_duration() -> float:
	var base_duration: float = cooldown_seconds if is_finite(cooldown_seconds) else 8.0
	return clampf(base_duration * _cooldown_multiplier, MIN_COOLDOWN, MAX_COOLDOWN)

func get_cooldown_remaining_ratio() -> float:
	var duration: float = get_cooldown_duration()
	return _cooldown_remaining / duration if duration > 0.0 else 0.0

func _finish_travel(completed: bool) -> void:
	# Landing must be resolved before completion observers sample the balancer position.
	if _landing_resolver.is_valid():
		_landing_resolver.call()
	_end_presentation()
	_cooldown_remaining = get_cooldown_duration()
	_state = State.COOLDOWN
	_return_available = completed
	state_changed.emit(_state)
	cooldown_changed.emit(_cooldown_remaining, get_cooldown_duration())
	phase_finished.emit()
	if completed:
		_refresh_void()
		phase_completed.emit()

func _refresh_void() -> void:
	if not _void_enabled or _void_duration <= 0.0:
		return
	_void_remaining = _void_duration
	void_changed.emit(true)

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
