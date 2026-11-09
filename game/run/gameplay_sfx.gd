extends Node3D

const WOOD: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Wood/wood_tree_branch_break_03.wav")]
const RUBBLE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_smashable_falling_debris_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_smashable_falling_debris_02.wav")]
const MALE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_03.wav")]
const FEMALE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Female B/voice_female_b_scream_03.wav")]
const FLESH: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Punches/punch_grit_wet_impact_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Punches/punch_grit_wet_impact_02.wav")]
const BUILDING_RUMBLE: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Cinematic Sounds/cinematic_deep_bass_rumble_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Cinematic Sounds/cinematic_deep_bass_rumble_02.wav")]
const BUILDING_DEBRIS: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_avalanche_landslide_debris_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_avalanche_landslide_debris_02.wav")]
const BUILDING_GLASS: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/glass_smashable_debris_fall_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/glass_smashable_debris_fall_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/glass_smashable_debris_fall_03.wav")]
const RUBBLE_ABSORB: Array[AudioStream] = [preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Gravel Dirt Stones/dirt_rice_pouring_gravel_debris_01.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Gravel Dirt Stones/dirt_rice_pouring_gravel_debris_02.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Miscellaneous/Gravel Dirt Stones/dirt_rice_pouring_gravel_debris_03.wav"), preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Impacts_Smashable/rock_smashable_falling_debris_02.wav")]
const BUILDING_VOICES: int = 6
const BUILDING_REFERENCE_HEIGHT: float = 40.0
const RUBBLE_SOUND_INTERVAL_MSEC: int = 250

var _voices: Array[AudioStreamPlayer3D] = []
var _building_voices: Array[AudioStreamPlayer3D] = []
var _player: Node3D
var _last_rubble_sound_msec: int = -RUBBLE_SOUND_INTERVAL_MSEC

func _ready() -> void:
	for index: int in 12:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.max_distance = 35.0
		voice.unit_size = 5.0
		add_child(voice)
		_voices.append(voice)
	for building_index: int in BUILDING_VOICES:
		var building_voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		# City camera can sit kilometres from the player, so building voices attenuate by player distance instead.
		building_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(building_voice)
		_building_voices.append(building_voice)

func play_depletion(style: int, location: Vector3, female: bool, building_collapse: bool = false, size: Vector3 = Vector3.ZERO) -> void:
	match style:
		0:
			_play(WOOD, location, -12.0)
		1:
			_play(FEMALE if female else MALE, location, -10.0)
			_play(FLESH, location, -18.0)
		2:
			if building_collapse:
				_play_building_collapse(location, size)
			else:
				_play(RUBBLE, location, -14.0)
		_:
			pass

func play_rubble_absorb(size: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_rubble_sound_msec < RUBBLE_SOUND_INTERVAL_MSEC:
		return
	_last_rubble_sound_msec = now
	var weight: float = clampf(sqrt(maxf(size.y, 0.1) / BUILDING_REFERENCE_HEIGHT), 0.5, 1.0)
	_play(RUBBLE_ABSORB, _player_position(), -11.0 + linear_to_db(weight))

func _play(samples: Array[AudioStream], location: Vector3, volume: float) -> void:
	for voice: AudioStreamPlayer3D in _voices:
		if not voice.playing:
			voice.global_position = location
			voice.stream = samples.pick_random()
			voice.volume_db = volume
			voice.pitch_scale = randf_range(0.94, 1.06)
			voice.play()
			return

func _play_building_collapse(location: Vector3, size: Vector3) -> void:
	var weight: float = clampf(sqrt(maxf(size.y, 0.1) / BUILDING_REFERENCE_HEIGHT), 0.35, 1.0)
	var audible_range: float = clampf(maxf(maxf(size.x, size.y), size.z) * 6.0, 45.0, 650.0)
	var proximity: float = clampf(1.0 - _player_position().distance_to(location) / audible_range, 0.0, 1.0)
	if proximity <= 0.0:
		return
	var gain: float = proximity * proximity * weight
	var rumble: AudioStreamPlayer3D = _free_building_voice()
	if rumble != null:
		_start_building_voice(rumble, BUILDING_RUMBLE, location, -5.0 + linear_to_db(gain), randf_range(0.85, 0.95))
	var tween: Tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_callback(_play_building_debris.bind(location, gain, size))

func _play_building_debris(location: Vector3, gain: float, size: Vector3) -> void:
	var debris: AudioStreamPlayer3D = _free_building_voice()
	if debris == null:
		return
	_start_building_voice(debris, BUILDING_DEBRIS, location, -8.0 + linear_to_db(gain), randf_range(0.9, 1.02))
	if size.y < 20.0 or randf() > 0.6:
		return
	var glass: AudioStreamPlayer3D = _free_building_voice()
	if glass != null:
		_start_building_voice(glass, BUILDING_GLASS, location, -12.0 + linear_to_db(gain), randf_range(0.95, 1.08))

func _start_building_voice(voice: AudioStreamPlayer3D, samples: Array[AudioStream], location: Vector3, volume: float, pitch: float) -> void:
	voice.global_position = location
	voice.stream = samples.pick_random()
	voice.volume_db = volume
	voice.pitch_scale = pitch
	voice.play()

func _free_building_voice() -> AudioStreamPlayer3D:
	for voice: AudioStreamPlayer3D in _building_voices:
		if not voice.playing:
			return voice
	return null

func _player_position() -> Vector3:
	if is_instance_valid(_player):
		return _player.global_position
	var run: Node = get_parent()
	if run != null:
		var balancer: Node = run.get_node_or_null("Balancer")
		if balancer is Node3D:
			_player = balancer as Node3D
			return _player.global_position
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position if camera != null else global_position
