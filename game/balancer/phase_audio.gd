extends AudioStreamPlayer

const SOURCE: AudioStreamWAV = preload("res://game/balancer/audio/player_phase_1.wav")
# Keep 10 ms before the first sustained -12 dB relative RMS rise, not the quiet windup.
const START_OFFSET: float = 0.65
const ATTACK: float = 0.005
const RELEASE: float = 0.04
const LEVEL_DB: float = -11.9794

var _duration: float = 0.0

func _ready() -> void:
	var sample: AudioStreamWAV = SOURCE.duplicate() as AudioStreamWAV
	sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream = sample
	_duration = sample.get_length() - START_OFFSET
	bus = &"Master"
	set_process(false)

func play_swoop() -> void:
	volume_db = -80.0
	play(START_OFFSET)
	set_process(true)

func cancel() -> void:
	stop()
	set_process(false)

func _process(_delta: float) -> void:
	var elapsed: float = maxf(0.0, get_playback_position() - START_OFFSET)
	if elapsed >= _duration or not playing:
		cancel()
		return
	var envelope: float = minf(1.0, minf(elapsed / ATTACK, (_duration - elapsed) / RELEASE))
	volume_db = LEVEL_DB + linear_to_db(maxf(envelope, 0.0001))
