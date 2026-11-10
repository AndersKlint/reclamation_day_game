extends CanvasLayer

const PlayerHurtAudio = preload("res://game/demo/farmer_combat/player_hurt_audio.gd")
const HIT_DURATION: float = 0.24
const HIT_CAMERA_OFFSET: float = 0.075
const HIT_FLASH_ALPHA: float = 0.18

var _camera: Camera3D
var _baseline: Vector2 = Vector2.ZERO
var _remaining: float = 0.0
var _flash: ColorRect
var _audio: PlayerHurtAudio


func _ready() -> void:
	layer = 2
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.75, 0.03, 0.02, 0.0)
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.hide()
	_audio = PlayerHurtAudio.new()
	add_child(_audio)
	set_process(false)


func configure(camera: Camera3D) -> void:
	cancel()
	_camera = camera
	_baseline = Vector2(camera.h_offset, camera.v_offset)


func play_hit() -> void:
	if _remaining <= 0.0 and is_instance_valid(_camera):
		_baseline = Vector2(_camera.h_offset, _camera.v_offset)
	_remaining = HIT_DURATION
	_flash.show()
	_audio.play_hurt()
	_apply_feedback()
	set_process(true)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_clear_visuals()
		return
	_apply_feedback()


func _apply_feedback() -> void:
	var fraction: float = _remaining / HIT_DURATION
	var strength: float = fraction * fraction
	var elapsed: float = HIT_DURATION - _remaining
	_flash.color.a = HIT_FLASH_ALPHA * strength
	if is_instance_valid(_camera):
		_camera.h_offset = _baseline.x + cos(elapsed * 95.0) * HIT_CAMERA_OFFSET * strength
		_camera.v_offset = _baseline.y - cos(elapsed * 120.0) * HIT_CAMERA_OFFSET * 0.65 * strength


func _clear_visuals() -> void:
	_remaining = 0.0
	set_process(false)
	if is_instance_valid(_camera):
		_camera.h_offset = _baseline.x
		_camera.v_offset = _baseline.y
	if is_instance_valid(_flash):
		_flash.hide()
		_flash.color.a = 0.0


func cancel() -> void:
	_clear_visuals()
	if is_instance_valid(_audio):
		_audio.cancel()


func _exit_tree() -> void:
	cancel()
