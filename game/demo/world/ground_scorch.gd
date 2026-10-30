extends Node

const SCORCH_SHADER: Shader = preload("res://game/demo/world/drained_ground.gdshader")
const WIDTH: int = 512
const HEIGHT: int = 640
const PIXELS_PER_UNIT: float = 1.28
const SAMPLE_INTERVAL: float = 0.08
const MAX_PATH_DISTANCE: float = 32.0
const GROWTH_TIME: float = 12.0
const MAX_RADIUS_MULTIPLIER: float = 6.0
const MAX_STAMPS: int = 192

class Stamp:
	var position: Vector2
	var radius: float
	var start_radius: float
	var created_at: float

	func _init(at: Vector2, reach: float, footprint: float, time: float) -> void:
		position = at
		radius = reach
		start_radius = footprint
		created_at = time

@export var region: Node3D
@export var balancer: Node3D

var _pixels: PackedByteArray
var _texture: ImageTexture
var _material: ShaderMaterial
var _last_position: Vector2
var _last_radius: float = 0.0
var _last_footprint: float = 0.0
var _has_sample: bool = false
var _elapsed: float = 0.0
var _time: float = 0.0
var _stamps: Array[Stamp] = []
var _renewing: bool = false
var _renew_tween: Tween


func _ready() -> void:
	var terrain: MeshInstance3D = region.get_node("Landscape/RollingTerrain") as MeshInstance3D
	var original: BaseMaterial3D = terrain.material_override as BaseMaterial3D
	_pixels.resize(WIDTH * HEIGHT)
	var image: Image = Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_L8, _pixels)
	_texture = ImageTexture.create_from_image(image)
	_material = ShaderMaterial.new()
	_material.shader = SCORCH_SHADER
	_material.set_shader_parameter("grass_texture", original.albedo_texture)
	_material.set_shader_parameter("grass_color", original.albedo_color)
	_material.set_shader_parameter("grass_roughness", original.roughness)
	_material.set_shader_parameter("scorch_mask", _texture)
	terrain.material_override = _material


func _process(delta: float) -> void:
	if _renewing or not bool(balancer.get("gameplay_enabled")):
		_has_sample = false
		_elapsed = 0.0
		return
	_time += delta
	_elapsed += delta
	if _has_sample and _elapsed < SAMPLE_INTERVAL:
		return
	_elapsed = 0.0
	var local_position: Vector3 = region.to_local(balancer.global_position)
	var position: Vector2 = Vector2(local_position.x, local_position.z)
	var radius: float = maxf(float(balancer.get("effective_drain_reach")), 0.0)
	var footprint: float = minf(radius, maxf(float(balancer.get("size")), 0.0))
	var changed: bool = false
	for index: int in range(_stamps.size() - 1, -1, -1):
		var stamp: Stamp = _stamps[index]
		if _time - stamp.created_at >= GROWTH_TIME:
			_stamps.remove_at(index)
			changed = _stamp(stamp, GROWTH_TIME) or changed
	if radius > 0.0 and not _has_sample:
		_add_stamp(position, radius, footprint)
	elif radius > 0.0:
		var distance: float = _last_position.distance_to(position)
		if distance > MAX_PATH_DISTANCE:
			_add_stamp(position, radius, footprint)
		elif distance >= maxf(minf(footprint, _last_footprint), 0.25):
			var steps: int = mini(ceili(distance / maxf(minf(footprint, _last_footprint), 0.25)), MAX_STAMPS - _stamps.size())
			var start: Vector2 = _last_position
			var start_radius: float = _last_radius
			var start_footprint: float = _last_footprint
			var total_steps: int = ceili(distance / maxf(minf(footprint, _last_footprint), 0.25))
			for step: int in range(1, steps + 1):
				var weight: float = float(step) / float(total_steps)
				_add_stamp(start.lerp(position, weight), lerpf(start_radius, radius, weight), lerpf(start_footprint, footprint, weight))
		elif absf(radius - _last_radius) > 0.05 or absf(footprint - _last_footprint) > 0.05:
			_add_stamp(position, radius, footprint)
	for stamp: Stamp in _stamps:
		changed = _stamp(stamp, _time - stamp.created_at) or changed
	if changed:
		_texture.update(Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_L8, _pixels))


func _add_stamp(position: Vector2, radius: float, footprint: float) -> void:
	if _stamps.size() >= MAX_STAMPS:
		return
	_stamps.append(Stamp.new(position, radius, footprint, _time))
	_last_position = position
	_last_radius = radius
	_last_footprint = footprint
	_has_sample = true


func _stamp(stamp: Stamp, age: float) -> bool:
	var radius: float = lerpf(stamp.start_radius, stamp.radius * MAX_RADIUS_MULTIPLIER, clampf(age / GROWTH_TIME, 0.0, 1.0))
	if radius <= 0.0:
		return false
	var center: Vector2 = (stamp.position + Vector2(200.0, 250.0)) * PIXELS_PER_UNIT
	var pixel_radius: float = radius * PIXELS_PER_UNIT
	var min_x: int = maxi(0, floori(center.x - pixel_radius))
	var max_x: int = mini(WIDTH - 1, ceili(center.x + pixel_radius))
	var min_y: int = maxi(0, floori(center.y - pixel_radius))
	var max_y: int = mini(HEIGHT - 1, ceili(center.y + pixel_radius))
	var changed: bool = false
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / pixel_radius
			if distance >= 1.0:
				continue
			var value: int = roundi((1.0 - smoothstep(0.0, 1.0, distance)) * 255.0)
			var index: int = y * WIDTH + x
			if value > _pixels[index]:
				_pixels[index] = value
				changed = true
	return changed


func renew(duration: float) -> void:
	_renewing = true
	_has_sample = false
	_stamps.clear()
	if _renew_tween != null and _renew_tween.is_valid():
		_renew_tween.kill()
	_renew_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renew_tween.tween_property(_material, "shader_parameter/scorch_strength", 0.0, maxf(duration, 0.01))
