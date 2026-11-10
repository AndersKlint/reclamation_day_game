extends AudioStreamPlayer

const SOURCE: AudioStreamWAV = preload("res://game/demo/farmer_combat/audio/ghost_hurt_counting.wav")
# Keep 10 ms before each sustained -12 dB relative RMS rise; preserve original tail boundaries.
const EXCERPTS: Array[Vector2] = [
	Vector2(0.845, 2.115),
	Vector2(4.800, 2.030),
	Vector2(8.820, 1.740),
	Vector2(12.890, 1.940),
	Vector2(16.710, 1.870),
	Vector2(20.665, 2.045),
	Vector2(24.735, 1.715),
	Vector2(28.700, 1.840),
	Vector2(32.570, 2.150),
	Vector2(36.695, 2.285),
	Vector2(41.030, 2.300),
]
const ATTACK: float = 0.005
const RELEASE: float = 0.03
const LEVEL_DB: float = -12.0

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _start: float = 0.0
var _duration: float = 0.0


func _ready() -> void:
	# Fatal-hit presentation must finish after the demo pauses gameplay for results.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sample: AudioStreamWAV = SOURCE.duplicate() as AudioStreamWAV
	sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream = sample
	bus = &"Master"
	max_polyphony = 1
	_random.randomize()
	set_process(false)


func play_hurt() -> void:
	cancel()
	var excerpt: Vector2 = EXCERPTS[_random.randi_range(0, EXCERPTS.size() - 1)]
	_start = excerpt.x
	_duration = excerpt.y
	volume_db = -80.0
	play(_start)
	set_process(true)


func cancel() -> void:
	stop()
	set_process(false)


func _process(_delta: float) -> void:
	var elapsed: float = maxf(0.0, get_playback_position() - _start)
	if elapsed >= _duration or not playing:
		cancel()
		return
	var envelope: float = minf(1.0, minf(elapsed / ATTACK, (_duration - elapsed) / RELEASE))
	volume_db = LEVEL_DB + linear_to_db(maxf(envelope, 0.0001))


func _exit_tree() -> void:
	cancel()
