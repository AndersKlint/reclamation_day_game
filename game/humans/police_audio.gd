extends RefCounted

const SHOT: AudioStream = preload("res://game/humans/audio/police_pistol.wav")
const FLYBY: AudioStream = preload("res://game/humans/audio/police_bullet_flyby.wav")

static func play_shot(parent: Node, position: Vector3) -> void:
	_play(parent, position, SHOT, -6.0, 64.0, 16.0)

static func play_flyby(parent: Node, position: Vector3) -> void:
	var playback_position: Vector3 = position
	var listener: Node3D = _audio_listener(parent)
	if listener != null:
		var listener_position: Vector3 = listener.global_position
		playback_position = listener_position + (position - listener_position).limit_length(4.0)
	_play(parent, playback_position, FLYBY, -10.0, 12.0)

static func _audio_listener(parent: Node) -> Node3D:
	var viewport: Viewport = parent.get_viewport()
	if viewport == null:
		return null
	var listener: AudioListener3D = viewport.get_audio_listener_3d()
	if listener != null:
		return listener
	return viewport.get_camera_3d()

static func _play(parent: Node, position: Vector3, sound: AudioStream, level: float, distance: float, unit_size: float = 8.0) -> void:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = sound
	player.bus = &"Master"
	player.volume_db = level
	player.unit_size = unit_size
	player.max_distance = distance
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
