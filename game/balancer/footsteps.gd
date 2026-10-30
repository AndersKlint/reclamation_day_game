extends Node

const STEPS: Array[AudioStream] = [
	preload("res://available-assets/sfx/footsteps_krotosaudio/Grass/Grass_Boots_FullStep_01.wav"),
	preload("res://available-assets/sfx/footsteps_krotosaudio/Grass/Grass_Boots_FullStep_02.wav"),
	preload("res://available-assets/sfx/footsteps_krotosaudio/Grass/Grass_Boots_FullStep_03.wav"),
	preload("res://available-assets/sfx/footsteps_krotosaudio/Grass/Grass_Boots_FullStep_04.wav"),
]
const STRIDE: float = 2.2

@export var movement_body: CharacterBody3D

var _enabled: bool = false
var _distance: float = 0.0
var _voice_index: int = 0
@onready var _voices: Array[AudioStreamPlayer] = [$VoiceA, $VoiceB]

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	reset_cadence()
	if not enabled:
		for voice: AudioStreamPlayer in _voices:
			voice.stop()

func reset_cadence() -> void:
	_distance = 0.0

func record_movement(previous_position: Vector3) -> void:
	if not _enabled or not movement_body.is_on_floor():
		reset_cadence()
		return
	var displacement: Vector3 = movement_body.global_position - previous_position
	_distance += Vector2(displacement.x, displacement.z).length()
	if _distance < STRIDE:
		return
	_distance = fmod(_distance, STRIDE)
	var voice: AudioStreamPlayer = _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = STEPS[randi() % STEPS.size()]
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.play()
