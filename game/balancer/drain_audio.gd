extends AudioStreamPlayer

const SOURCE: AudioStreamWAV = preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Magic_Spells/dark_portal_wind_loop_01.wav")

var _enabled: bool = false
var _recent_transfer: float = 0.0
var _level: float = 0.0

func _ready() -> void:
	var loop: AudioStreamWAV = SOURCE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	stream = loop
	volume_db = -80.0

func record_transfer(amount: float) -> void:
	if _enabled and amount > 0.0:
		_recent_transfer = 0.12
		if not playing:
			play()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_recent_transfer = 0.0
		_level = 0.0
		volume_db = -80.0
		stop()

func _process(delta: float) -> void:
	_recent_transfer = maxf(0.0, _recent_transfer - delta)
	_level = move_toward(_level, 1.0 if _enabled and _recent_transfer > 0.0 else 0.0, delta / 0.2)
	volume_db = linear_to_db(maxf(_level, 0.0001)) - 18.0
	if playing and _level <= 0.0:
		stop()
