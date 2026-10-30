extends Node3D

const WOOD: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_03.wav")]
const RUBBLE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_smashable_falling_debris_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_smashable_falling_debris_02.wav")]
const MALE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_03.wav")]
const FEMALE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_03.wav")]
const FLESH: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Punches/punch_grit_wet_impact_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Punches/punch_grit_wet_impact_02.wav")]

var _voices: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	for index: int in 12:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.max_distance = 35.0
		voice.unit_size = 5.0
		add_child(voice)
		_voices.append(voice)

func play_depletion(style: int, location: Vector3, female: bool) -> void:
	match style:
		0:
			_play(WOOD, location, -12.0)
		1:
			_play(FEMALE if female else MALE, location, -10.0)
			_play(FLESH, location, -18.0)
		2:
			_play(RUBBLE, location, -14.0)

func _play(samples: Array[AudioStream], location: Vector3, volume: float) -> void:
	for voice: AudioStreamPlayer3D in _voices:
		if not voice.playing:
			voice.global_position = location
			voice.stream = samples.pick_random()
			voice.volume_db = volume
			voice.pitch_scale = randf_range(0.94, 1.06)
			voice.play()
			return
