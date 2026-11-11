extends Node3D

const ENGINE_LOOP: AudioStreamOggVorbis = preload("res://available-assets/retro3d-assets/Vehicles/PSX_Style_Cars_by_GGBot_(September2022)/Sound effects/Car_Engine_Loop.ogg")
const ACCELERATION: AudioStream = preload("res://available-assets/retro3d-assets/Vehicles/PSX_Style_Cars_by_GGBot_(September2022)/Sound effects/Car_Acceleration.ogg")
const HORN: AudioStream = preload("res://available-assets/retro3d-assets/Vehicles/PSX_Style_Cars_by_GGBot_(September2022)/Sound effects/Car_Horn.ogg")
const ENGINE_BUDGET: int = 6
const TRANSIENT_BUDGET: int = 2
const AUDIBLE_DISTANCE: float = 48.0
const AUDIO_GROUP: StringName = &"traffic_car_audio"
const ENGINE_GROUP: StringName = &"traffic_car_engines"
const TRANSIENT_GROUP: StringName = &"traffic_car_transients"

static var _budget_frame: int = -1
static var _audible_engines: Dictionary[int, bool] = {}

var _engine: AudioStreamPlayer3D
var _acceleration: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _previous_speed: float = 0.0
var _blocked_time: float = 0.0
var _horn_cooldown: float = 0.0
var _acceleration_cooldown: float = 0.0
var _startup_left: float = 0.0
var _engine_gain: float = 0.0
var _acceleration_armed: bool = false
var _enabled: bool = false

func _ready() -> void:
	add_to_group(AUDIO_GROUP)
	_engine = _voice(ENGINE_LOOP, -60.0, AUDIBLE_DISTANCE, 3.0)
	_engine.max_db = -24.0
	_engine.add_to_group(ENGINE_GROUP)
	_engine.stream = ENGINE_LOOP.duplicate() as AudioStreamOggVorbis
	(_engine.stream as AudioStreamOggVorbis).loop = true
	_acceleration = _voice(ACCELERATION, -29.0, 32.0, 3.0)
	_horn = _voice(HORN, -25.0, 42.0, 3.0)
	_acceleration.add_to_group(TRANSIENT_GROUP)
	_horn.add_to_group(TRANSIENT_GROUP)

func update_speed(speed: float, delta: float) -> void:
	if not _enabled:
		return
	var safe_speed: float = maxf(speed, 0.0)
	var acceleration: float = (safe_speed - _previous_speed) / maxf(delta, 0.0001)
	_startup_left = maxf(0.0, _startup_left - delta)
	_horn_cooldown = maxf(0.0, _horn_cooldown - delta)
	_acceleration_cooldown = maxf(0.0, _acceleration_cooldown - delta)
	var audible: bool = _startup_left <= 0.0 and _has_engine_voice()
	if audible and not _engine.playing:
		audible = _has_voice(ENGINE_GROUP, ENGINE_BUDGET)
	_engine.pitch_scale = lerpf(0.75, 1.25, clampf(safe_speed / 9.5, 0.0, 1.0))
	_engine_gain = move_toward(_engine_gain, 1.0 if audible else 0.0, delta * 1.5)
	_engine.volume_db = linear_to_db(maxf(_engine_gain, 0.001)) + lerpf(-32.0, -24.0, clampf(safe_speed / 7.0, 0.0, 1.0))
	if audible and not _engine.playing:
		_engine.play(randf_range(0.0, maxf(0.0, _engine.stream.get_length() - 0.1)))
	elif not audible:
		_engine.stop()
		_engine_gain = 0.0
	if _startup_left <= 0.0 and safe_speed < 0.5:
		_acceleration_armed = true
	if _acceleration_armed and safe_speed >= 2.0 and acceleration > 1.0:
		_acceleration_armed = false
		if audible and _acceleration_cooldown <= 0.0 and _has_voice(TRANSIENT_GROUP, TRANSIENT_BUDGET):
			_acceleration.pitch_scale = randf_range(0.92, 1.08)
			_acceleration.play()
			_acceleration_cooldown = 8.0
	_previous_speed = safe_speed

func note_obstruction(delta: float) -> void:
	if not _enabled or _startup_left > 0.0:
		return
	_blocked_time += delta
	if _blocked_time >= 2.0 and _horn_cooldown <= 0.0 and _has_engine_voice() and _has_voice(TRANSIENT_GROUP, TRANSIENT_BUDGET):
		_horn.pitch_scale = randf_range(0.92, 1.08)
		_horn.play()
		_horn_cooldown = randf_range(9.0, 15.0)
		_blocked_time = 0.0

func clear_obstruction(delta: float) -> void:
	_blocked_time = maxf(0.0, _blocked_time - delta * 2.0)

func stop() -> void:
	set_enabled(false)

func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	_budget_frame = -1
	_previous_speed = 0.0
	_blocked_time = 0.0
	_engine_gain = 0.0
	_acceleration_armed = false
	_startup_left = 1.5 + float(get_instance_id() % 13) * 0.07
	_horn_cooldown = 4.0
	if _engine == null:
		return
	_engine.volume_db = -80.0
	if not enabled:
		_engine.stop()
		_acceleration.stop()
		_horn.stop()

func _has_engine_voice() -> bool:
	var frame: int = Engine.get_physics_frames()
	if _budget_frame != frame:
		_budget_frame = frame
		_audible_engines.clear()
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return false
		var listener_position: Vector3 = camera.global_position
		var candidates: Array[Node3D] = []
		for node: Node in get_tree().get_nodes_in_group(AUDIO_GROUP):
			var audio: Node3D = node as Node3D
			if audio != null and bool(audio.get("_enabled")) and float(audio.get("_startup_left")) <= 0.0:
				if audio.global_position.distance_squared_to(listener_position) < AUDIBLE_DISTANCE * AUDIBLE_DISTANCE:
					candidates.append(audio)
		candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_squared_to(listener_position) < b.global_position.distance_squared_to(listener_position)
		)
		for i: int in mini(ENGINE_BUDGET, candidates.size()):
			_audible_engines[candidates[i].get_instance_id()] = true
	return _audible_engines.has(get_instance_id())

func _has_voice(group: StringName, budget: int) -> bool:
	var playing: int = 0
	for node: Node in get_tree().get_nodes_in_group(group):
		var voice: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		if voice != null and voice.playing:
			playing += 1
	return playing < budget

func _voice(stream: AudioStream, volume: float, distance: float, size: float) -> AudioStreamPlayer3D:
	var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.volume_db = volume
	voice.max_db = volume
	voice.max_distance = distance
	voice.unit_size = size
	add_child(voice)
	return voice
