extends Node3D

const GRUNTS: Array[AudioStream] = [
	preload("res://available-assets/sfx/soundly/male_swing_grunt_1.wav"),
	preload("res://available-assets/sfx/soundly/male_swing_grunt_2.wav"),
	preload("res://available-assets/sfx/soundly/male_swing_grunt_3.wav"),
]
const WEAPON_SWINGS: AudioStream = preload("res://game/demo/farmer_combat/audio/weapon_swings.wav")
const DEATH: AudioStream = preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Voice/Human Male D/voice_male_d_death_01.wav")
# 5 ms RMS at -60 dB, merging gaps up to 350 ms, preserves quiet tails and internal pauses.
const SWING_EXCERPTS: Array[Vector2] = [
	Vector2(0.405, 0.715),
	Vector2(2.335, 1.140),
	Vector2(4.695, 0.910),
	Vector2(6.770, 0.655),
	Vector2(8.430, 0.595),
	Vector2(10.205, 0.590),
	Vector2(11.955, 0.660),
	Vector2(13.735, 0.955),
	Vector2(15.565, 0.730),
	Vector2(17.325, 0.735),
	Vector2(19.010, 0.655),
	Vector2(20.925, 0.620),
	Vector2(22.555, 0.705),
	Vector2(23.770, 0.975),
	Vector2(25.950, 0.720),
	Vector2(27.675, 0.650),
	Vector2(29.775, 0.605),
	Vector2(31.725, 1.015),
]
const WEAPON_VOLUME_DB: float = -8.0
const EXCERPT_FADE_SECONDS: float = 0.005

var _excerpt_gate: Tween
var _defeated: bool = false

@onready var _grunt: AudioStreamPlayer3D = $Grunt
@onready var _weapon: AudioStreamPlayer3D = $Weapon
@onready var _death: AudioStreamPlayer3D = $Death


func _ready() -> void:
	_weapon.stream = WEAPON_SWINGS
	_death.stream = DEATH


func play_swing() -> void:
	if _defeated:
		return
	stop_swing()
	_grunt.stream = GRUNTS.pick_random()
	_grunt.play()
	var excerpt: Vector2 = SWING_EXCERPTS.pick_random()
	_weapon.volume_db = -60.0
	_weapon.play(excerpt.x)
	_excerpt_gate = create_tween()
	_excerpt_gate.tween_property(_weapon, "volume_db", WEAPON_VOLUME_DB, EXCERPT_FADE_SECONDS)
	_excerpt_gate.tween_interval(excerpt.y - EXCERPT_FADE_SECONDS * 2.0)
	_excerpt_gate.tween_property(_weapon, "volume_db", -60.0, EXCERPT_FADE_SECONDS)
	_excerpt_gate.tween_callback(_weapon.stop)


func stop_swing() -> void:
	if _excerpt_gate != null:
		_excerpt_gate.kill()
		_excerpt_gate = null
	_grunt.stop()
	_weapon.stop()


func play_death(tail_parent: Node) -> void:
	if _defeated:
		return
	_defeated = true
	stop_swing()
	# Consumption frees the farmer before this voice finishes.
	reparent(tail_parent, true)
	_death.finished.connect(queue_free, CONNECT_ONE_SHOT)
	_death.play()
