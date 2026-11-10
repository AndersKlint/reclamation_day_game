extends AudioStreamPlayer

const SOURCE: AudioStreamWAV = preload("res://available-assets/sfx/soundly/drain_life_combined_3.wav")
const LOOP_BEGIN_SECONDS: float = 1.090
const BASE_VOLUME_DB: float = -7.0774392864
const FADE_IN_SECONDS: float = 0.2
const GRACE_SECONDS: float = 2.0

var _enabled: bool = false
var _grace_remaining: float = 0.0
var _received_transfer: bool = false
var _level: float = 0.0

func _ready() -> void:
	var loop: AudioStreamWAV = SOURCE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = roundi(LOOP_BEGIN_SECONDS * loop.mix_rate)
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	stream = loop
	volume_linear = 0.0

func record_transfer(amount: float) -> void:
	if not _enabled or not is_finite(amount) or amount <= 0.0:
		return
	_grace_remaining = GRACE_SECONDS
	_received_transfer = true
	if not playing:
		play(0.0)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_grace_remaining = 0.0
		_received_transfer = false
		_level = 0.0
		volume_linear = 0.0
		stop()

func _process(delta: float) -> void:
	if not playing:
		return
	var previous_grace: float = _grace_remaining
	_grace_remaining = maxf(0.0, _grace_remaining - delta)
	if _grace_remaining <= 0.0:
		_received_transfer = false
		_level = 0.0
		volume_linear = 0.0
		stop()
		return
	if _received_transfer:
		_level = move_toward(_level, 1.0, delta / FADE_IN_SECONDS)
	else:
		_level *= _grace_remaining / previous_grace
	_received_transfer = false
	volume_linear = _level * db_to_linear(BASE_VOLUME_DB)
