extends Node3D

const SCREAMS: Array[AudioStream] = [
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_01.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_02.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_03.wav"),
]
const VOICE_LIMIT: int = 6
const START_INTERVAL: float = 0.35

var _voices: Array[AudioStreamPlayer3D] = []
var _speakers: Array[Node3D] = []
var _start_left: float = 2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for index: int in VOICE_LIMIT:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.volume_db = -11.0
		voice.max_db = -4.0
		voice.unit_size = 14.0
		voice.max_distance = 80.0
		voice.max_polyphony = 1
		voice.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(voice)
		_voices.append(voice)
		_speakers.append(null)

func _physics_process(delta: float) -> void:
	_start_left = maxf(0.0, _start_left - delta)
	for index: int in _voices.size():
		var speaker: Node3D = _speakers[index]
		if not is_instance_valid(speaker) or speaker.is_queued_for_deletion() or not bool(speaker.get(&"active")) or not _voices[index].playing:
			_voices[index].stop()
			_speakers[index] = null
			continue
		_voices[index].global_position = speaker.global_position + Vector3.UP * 1.5

func play_scream(speaker: Node3D) -> void:
	if _start_left > 0.0 or not is_instance_valid(speaker) or _speakers.has(speaker):
		return
	for index: int in _voices.size():
		if _voices[index].playing:
			continue
		_speakers[index] = speaker
		_voices[index].global_position = speaker.global_position + Vector3.UP * 1.5
		_voices[index].stream = SCREAMS.pick_random()
		_voices[index].play()
		_start_left = START_INTERVAL
		return

func stop_speaker(speaker: Node3D) -> void:
	for index: int in _speakers.size():
		if _speakers[index] == speaker:
			_voices[index].stop()
			_speakers[index] = null

func stop_all() -> void:
	for index: int in _voices.size():
		_voices[index].stop()
		_speakers[index] = null
