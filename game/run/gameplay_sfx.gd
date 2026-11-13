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
const VOICES: int = 12
const WOOD_RANGE: float = 70.0
const HUMAN_RANGE: float = 90.0
const FLESH_RANGE: float = 60.0
const RUBBLE_RANGE: float = 80.0
const WOOD_UNIT_SIZE: float = 20.0
const HUMAN_UNIT_SIZE: float = 25.0
const FLESH_UNIT_SIZE: float = 17.0
const RUBBLE_UNIT_SIZE: float = 22.0
const IMPORTANT_FILTER_CUTOFF_HZ: float = 8000.0
const IMPORTANT_FILTER_DB: float = -6.0
const DEFAULT_FILTER_CUTOFF_HZ: float = 5000.0
# Engine default; pooled voices must reset it after an important sound.
const DEFAULT_FILTER_DB: float = -24.0

var _voices: Array[AudioStreamPlayer3D] = []
var _wheat_voices: Array[AudioStreamPlayer3D] = []
var _wheat_reserved: Array[bool] = []
var _wheat_samples: Array[AudioStream] = []
var _building_voices: Array[AudioStreamPlayer3D] = []
var _player: Node3D
var _last_rubble_sound_msec: int = -RUBBLE_SOUND_INTERVAL_MSEC

func _ready() -> void:
	_player = _player_node()
	for index: int in range(1, 10):
		_wheat_samples.append(load("res://game/run/audio/wheat_crunch_%d.wav" % index) as AudioStream)
	for index: int in 6:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.bus = &"SFX"
		voice.volume_db = -12.0
		# Player-distance gain avoids double attenuation from the zoomed-out camera.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.max_distance = 0.0
		voice.max_polyphony = 1
		add_child(voice)
		_wheat_voices.append(voice)
		_wheat_reserved.append(false)
	for index: int in VOICES:
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		add_child(voice)
		_voices.append(voice)
	for building_index: int in BUILDING_VOICES:
		var building_voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		# City camera can sit kilometres from the player, so building voices attenuate by player distance instead.
		building_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		add_child(building_voice)
		_building_voices.append(building_voice)

func play_depletion(style: int, location: Vector3, female: bool, building_collapse: bool = false, size: Vector3 = Vector3.ZERO, play_voice: bool = true) -> void:
	match style:
		0:
			_play_important(WOOD, location, -12.0, WOOD_UNIT_SIZE, WOOD_RANGE)
		1:
			if play_voice:
				_play_important(FEMALE if female else MALE, location, -10.0, HUMAN_UNIT_SIZE, HUMAN_RANGE)
			_play_important(FLESH, location, -18.0, FLESH_UNIT_SIZE, FLESH_RANGE)
		2:
			if building_collapse:
				_play_building_collapse(location, size)
			else:
				_play_important(RUBBLE, location, -7.0, RUBBLE_UNIT_SIZE, RUBBLE_RANGE)
		_:
			pass

func play_wheat_crunch(location: Vector3) -> void:
	if location.distance_squared_to(_player_position()) > 60.0 * 60.0:
		return
	for index: int in _wheat_voices.size():
		if _wheat_reserved[index] or _wheat_voices[index].playing:
			continue
		_wheat_reserved[index] = true
		_wheat_voices[index].global_position = location
		_wheat_voices[index].stream = _wheat_samples.pick_random()
		var delay: Tween = create_tween()
		delay.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		delay.tween_interval(randf_range(0.0, 0.2))
		delay.tween_callback(_start_wheat_crunch.bind(index))
		return

func _start_wheat_crunch(index: int) -> void:
	_wheat_reserved[index] = false
	var distance: float = _wheat_voices[index].global_position.distance_to(_player_position())
	var gain: float = clampf(1.0 - distance / 60.0, 0.0, 1.0)
	if gain <= 0.0:
		return
	_wheat_voices[index].volume_db = -12.0 + linear_to_db(gain)
	_wheat_voices[index].play()

func play_rubble_absorb(size: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_rubble_sound_msec < RUBBLE_SOUND_INTERVAL_MSEC:
		return
	_last_rubble_sound_msec = now
	var weight: float = clampf(sqrt(maxf(size.y, 0.1) / BUILDING_REFERENCE_HEIGHT), 0.5, 1.0)
	_play(RUBBLE_ABSORB, _player_position(), -11.0 + linear_to_db(weight))

func _play(samples: Array[AudioStream], location: Vector3, volume: float, unit_size: float = 5.0, max_distance: float = 35.0) -> void:
	_start_voice(samples, location, volume, unit_size, max_distance, false)

func _play_important(samples: Array[AudioStream], location: Vector3, volume: float, unit_size: float, max_distance: float) -> void:
	_start_voice(samples, location, volume, unit_size, max_distance, true)

func _start_voice(samples: Array[AudioStream], location: Vector3, volume: float, unit_size: float, max_distance: float, important: bool) -> void:
	for index: int in _voices.size():
		var voice: AudioStreamPlayer3D = _voices[index]
		if voice.playing:
			continue
		voice.global_position = location
		voice.stream = samples.pick_random()
		voice.volume_db = volume
		voice.pitch_scale = randf_range(0.94, 1.06)
		voice.unit_size = unit_size
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.attenuation_filter_cutoff_hz = IMPORTANT_FILTER_CUTOFF_HZ if important else DEFAULT_FILTER_CUTOFF_HZ
		voice.attenuation_filter_db = IMPORTANT_FILTER_DB if important else DEFAULT_FILTER_DB
		voice.max_distance = max_distance
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
		_start_building_voice(rumble, BUILDING_RUMBLE, location, -2.0 + linear_to_db(gain), randf_range(0.85, 0.95))
	var tween: Tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_callback(_play_building_debris.bind(location, gain, size))

func _play_building_debris(location: Vector3, gain: float, size: Vector3) -> void:
	var debris: AudioStreamPlayer3D = _free_building_voice()
	if debris == null:
		return
	_start_building_voice(debris, BUILDING_DEBRIS, location, -5.0 + linear_to_db(gain), randf_range(0.9, 1.02))
	if size.y < 20.0 or randf() > 0.6:
		return
	var glass: AudioStreamPlayer3D = _free_building_voice()
	if glass != null:
		_start_building_voice(glass, BUILDING_GLASS, location, -9.0 + linear_to_db(gain), randf_range(0.95, 1.08))

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

func _player_node() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var run: Node = get_parent()
	if run != null:
		var balancer: Node = run.get_node_or_null("Balancer")
		if balancer is Node3D:
			_player = balancer as Node3D
			return _player
	return null

func _player_position() -> Vector3:
	var player: Node3D = _player_node()
	if player != null:
		return player.global_position
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position if camera != null else global_position
