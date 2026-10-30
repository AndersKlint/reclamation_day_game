extends AudioStreamPlayer

const TRACKS: Array[AudioStreamWAV] = [
	preload("res://available-assets/music/PSX Ambient Pack/Tracks/Glow.wav"),
	preload("res://available-assets/music/PSX Ambient Pack/Tracks/Lost.wav"),
	preload("res://available-assets/music/PSX Ambient Pack/Tracks/Veil.wav"),
	preload("res://available-assets/music/PSX Ambient Pack/Tracks/Still.wav"),
]

var _remaining: Array[AudioStreamWAV] = []
var _last_track: AudioStreamWAV


func _ready() -> void:
	finished.connect(_play_next)
	_play_next()


func _exit_tree() -> void:
	stop()
	stream = null


func _play_next() -> void:
	if _remaining.is_empty():
		_remaining.assign(TRACKS)
		_remaining.shuffle()
		if _remaining.back() == _last_track:
			var swap_index: int = randi_range(0, _remaining.size() - 2)
			var next_track: AudioStreamWAV = _remaining[swap_index]
			_remaining[swap_index] = _remaining.back()
			_remaining[_remaining.size() - 1] = next_track
	_last_track = _remaining.pop_back()
	var track: AudioStreamWAV = _last_track.duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream = track
	play()
