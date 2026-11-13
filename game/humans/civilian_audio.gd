extends Node3D

const FEMALE_SCREAMS: Array[AudioStream] = [
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_01.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_02.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_03.wav"),
	preload("res://game/humans/audio/female_panic_scream_1.wav"),
	preload("res://game/humans/audio/female_panic_scream_2.wav"),
	preload("res://game/humans/audio/female_panic_scream_3.wav"),
	preload("res://game/humans/audio/female_panic_scream_4.wav"),
	preload("res://game/humans/audio/female_panic_scream_5.wav"),
]
const MALE_SCREAMS: Array[AudioStream] = [
	preload("res://game/humans/audio/male_panic_scream_1.wav"),
	preload("res://game/humans/audio/male_panic_scream_2.wav"),
	preload("res://game/humans/audio/male_panic_scream_3.wav"),
	preload("res://game/humans/audio/male_panic_scream_4.wav"),
]
const VOICE_LIMIT: int = 6
const FEMALE_DEATH_GRUNTS: Array[AudioStream] = [
	preload("res://game/humans/audio/female_death_grunts_1.wav"),
	preload("res://game/humans/audio/female_death_grunts_2.wav"),
	preload("res://game/humans/audio/female_death_grunts_3.wav"),
]
const MALE_DEATH_GRUNTS: Array[AudioStream] = [
	preload("res://game/humans/audio/male_death_grunts_1.wav"),
	preload("res://game/humans/audio/male_death_grunts_2.wav"),
]
const START_INTERVAL: float = 0.35
const REUSE_DELAY: float = 2.0
const SCREAM_RANGE: float = 250.0
const SCREAM_UNIT_SIZE: float = 25.0
const SCREAM_FILTER_CUTOFF_HZ: float = 8000.0
const SCREAM_FILTER_DB: float = -6.0

var _voices: Array[AudioStreamPlayer3D] = []
var _speakers: Array[Node3D] = []
var _reuse_left: Array[float] = []
var _death_voices: Array[bool] = []
var _start_left: float = 2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for index: int in VOICE_LIMIT:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.volume_db = -13.0
		voice.max_db = -6.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.attenuation_filter_cutoff_hz = SCREAM_FILTER_CUTOFF_HZ
		voice.attenuation_filter_db = SCREAM_FILTER_DB
		voice.max_distance = SCREAM_RANGE
		voice.unit_size = SCREAM_UNIT_SIZE
		voice.max_polyphony = 1
		voice.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(voice)
		_voices.append(voice)
		_speakers.append(null)
		_reuse_left.append(0.0)
		_death_voices.append(false)

func _physics_process(delta: float) -> void:
	_start_left = maxf(0.0, _start_left - delta)
	for index: int in _voices.size():
		_reuse_left[index] = maxf(0.0, _reuse_left[index] - delta)
		if _death_voices[index]:
			if not _voices[index].playing:
				_release_voice(index)
			continue
		var speaker: Node3D = _speakers[index]
		if speaker == null:
			continue
		if not is_instance_valid(speaker) or speaker.is_queued_for_deletion() or not bool(speaker.get(&"active")) or not _voices[index].playing:
			_release_voice(index)
			continue
		_voices[index].global_position = speaker.global_position + Vector3.UP * 1.5

func play_scream(speaker: Node3D, female_voice: bool) -> bool:
	if _start_left > 0.0 or not is_instance_valid(speaker) or _speakers.has(speaker):
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_squared_to(speaker.global_position) > SCREAM_RANGE * SCREAM_RANGE:
		return false
	for index: int in _voices.size():
		if _voices[index].playing or _speakers[index] != null or _death_voices[index] or _reuse_left[index] > 0.0:
			continue
		_speakers[index] = speaker
		_voices[index].global_position = speaker.global_position + Vector3.UP * 1.5
		_voices[index].stream = FEMALE_SCREAMS.pick_random() if female_voice else MALE_SCREAMS.pick_random()
		_voices[index].play()
		_start_left = START_INTERVAL
		return true
	return false

func play_death_grunt(speaker: Node3D, female_voice: bool) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_squared_to(speaker.global_position) > SCREAM_RANGE * SCREAM_RANGE:
		return
	var slot: int = _speakers.find(speaker)
	if slot < 0:
		if _start_left > 0.0:
			return
		for index: int in _voices.size():
			if not _voices[index].playing and _speakers[index] == null and not _death_voices[index] and _reuse_left[index] <= 0.0:
				slot = index
				break
	if slot < 0:
		return
	_speakers[slot] = null
	_death_voices[slot] = true
	_voices[slot].global_position = speaker.global_position + Vector3.UP * 1.5
	_voices[slot].stream = FEMALE_DEATH_GRUNTS.pick_random() if female_voice else MALE_DEATH_GRUNTS.pick_random()
	_voices[slot].play()
	_start_left = START_INTERVAL

func _release_voice(index: int) -> void:
	_voices[index].stop()
	_speakers[index] = null
	_death_voices[index] = false
	_reuse_left[index] = REUSE_DELAY

func stop_speaker(speaker: Node3D) -> void:
	for index: int in _speakers.size():
		if _speakers[index] == speaker:
			_release_voice(index)

func stop_all() -> void:
	for index: int in _voices.size():
		_release_voice(index)
