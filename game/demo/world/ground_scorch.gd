extends Node

const SCORCH_SHADER: Shader = preload("res://game/demo/world/drained_ground.gdshader")
const SAMPLE_INTERVAL: float = 0.08
const STAMP_INTERVAL: float = 0.35
const MAX_PATH_DISTANCE: float = 32.0
const GROWTH_TIME: float = 12.0
const MAX_RADIUS_MULTIPLIER: float = 6.0
const MAX_STAMPS: int = 192
const MAX_TEXTURE_EDGE: int = 1024
const MAX_TEXTURE_PIXELS: float = 650000.0
const MIN_PIXELS_PER_UNIT: float = 0.05
const MAX_RASTER_SAMPLES_PER_FRAME: int = 16000
const TEXTURE_UPLOAD_INTERVAL: float = 0.1

class Stamp:
	var position: Vector2
	var radius: float
	var start_radius: float
	var created_at: float
	var next_update: float
	var final_queued: bool = false
	var full_map: bool = false

	func _init(at: Vector2, reach: float, footprint: float, time: float) -> void:
		position = at
		radius = reach
		start_radius = footprint
		created_at = time
		next_update = time

class RasterJob:
	var stamp: Stamp
	var center: Vector2
	var radius: float
	var pixel_radius: float
	var min_x: int
	var max_x: int
	var min_y: int
	var max_y: int
	var cursor: int

	func _init(owner: Stamp, at: Vector2, reach: float, bounds: Rect2i) -> void:
		stamp = owner
		center = at
		pixel_radius = reach
		min_x = bounds.position.x
		max_x = bounds.end.x - 1
		min_y = bounds.position.y
		max_y = bounds.end.y - 1
		radius = reach

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
var _width: int = 1
var _height: int = 1
var _pixels_per_unit: float = 1.0
var _mask_min: Vector2 = Vector2.ZERO
var _raster_jobs: Array[RasterJob] = []
var _raster_cursor_x: int = 0
var _raster_cursor_y: int = 0
var _upload_elapsed: float = 0.0
var _dirty: bool = false
var _max_mask_radius: float = 0.0


func _ready() -> void:
	var bounds: Rect2 = region.get_world_bounds()
	var largest: float = maxf(bounds.size.x, bounds.size.y)
	var area: float = maxf(bounds.size.x * bounds.size.y, 1.0)
	_pixels_per_unit = minf(sqrt(MAX_TEXTURE_PIXELS / area), float(MAX_TEXTURE_EDGE) / largest)
	_pixels_per_unit = maxf(_pixels_per_unit, MIN_PIXELS_PER_UNIT)
	_width = maxi(1, ceili(bounds.size.x * _pixels_per_unit))
	_height = maxi(1, ceili(bounds.size.y * _pixels_per_unit))
	_mask_min = bounds.position
	_max_mask_radius = maxf(Vector2.ZERO.distance_to(Vector2(bounds.size.x, bounds.size.y)), 1.0) * _pixels_per_unit
	var terrain: MeshInstance3D = region.get_node("Landscape/RollingTerrain") as MeshInstance3D
	var original: BaseMaterial3D = terrain.material_override as BaseMaterial3D
	_pixels.resize(_width * _height)
	var image: Image = Image.create_from_data(_width, _height, false, Image.FORMAT_L8, _pixels)
	_texture = ImageTexture.create_from_image(image)
	_material = ShaderMaterial.new()
	_material.shader = SCORCH_SHADER
	_material.set_shader_parameter("grass_texture", original.albedo_texture)
	_material.set_shader_parameter("grass_color", original.albedo_color)
	_material.set_shader_parameter("grass_roughness", original.roughness)
	_material.set_shader_parameter("scorch_mask", _texture)
	_material.set_shader_parameter("mask_min", _mask_min)
	_material.set_shader_parameter("mask_size", bounds.size)
	terrain.material_override = _material


func _process(delta: float) -> void:
	_upload_elapsed += delta
	_process_raster_budget()
	if _dirty and _upload_elapsed >= TEXTURE_UPLOAD_INTERVAL:
		_texture.update(Image.create_from_data(_width, _height, false, Image.FORMAT_L8, _pixels))
		_dirty = false
		_upload_elapsed = 0.0
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
	var footprint: float = minf(radius, maxf(float(balancer.get("visible_size")), 0.0))
	var changed: bool = false
	if radius > 0.0 and not _has_sample:
		changed = _add_stamp(position, radius, footprint) or changed
	elif radius > 0.0:
		var distance: float = _last_position.distance_to(position)
		if distance > MAX_PATH_DISTANCE:
			changed = _add_stamp(position, radius, footprint) or changed
		elif distance >= maxf(minf(footprint, _last_footprint), 0.25):
			var total_steps: int = ceili(distance / maxf(minf(footprint, _last_footprint), 0.25))
			var steps: int = mini(total_steps, MAX_STAMPS - _stamps.size())
			var start: Vector2 = _last_position
			var start_radius: float = _last_radius
			var start_footprint: float = _last_footprint
			for step: int in range(1, steps + 1):
				var weight: float = float(step) / float(total_steps)
				changed = _add_stamp(start.lerp(position, weight), lerpf(start_radius, radius, weight), lerpf(start_footprint, footprint, weight)) or changed
		elif absf(radius - _last_radius) > 0.05 or absf(footprint - _last_footprint) > 0.05:
			changed = _add_stamp(position, radius, footprint) or changed
	for index: int in range(_stamps.size() - 1, -1, -1):
		var stamp: Stamp = _stamps[index]
		var age: float = _time - stamp.created_at
		if age >= GROWTH_TIME:
			if not stamp.final_queued:
				if not stamp.full_map:
					_enqueue_stamp(stamp, GROWTH_TIME)
				stamp.final_queued = true
				stamp.next_update = INF
		elif not stamp.full_map and _time >= stamp.next_update:
			_enqueue_stamp(stamp, age)
			stamp.next_update = _time + STAMP_INTERVAL
	for index: int in range(_stamps.size() - 1, -1, -1):
		if _stamps[index].final_queued and not _has_pending_stamp(_stamps[index]):
			_stamps.remove_at(index)


func _add_stamp(position: Vector2, radius: float, footprint: float) -> bool:
	var reaches_map: bool = radius * MAX_RADIUS_MULTIPLIER * _pixels_per_unit >= _max_mask_radius
	if reaches_map:
		for existing: Stamp in _stamps:
			if existing.full_map or existing.radius * MAX_RADIUS_MULTIPLIER * _pixels_per_unit >= _max_mask_radius:
				_last_position = position
				_last_radius = radius
				_last_footprint = footprint
				_has_sample = true
				return false
	if _stamps.size() >= MAX_STAMPS:
		return false
	var stamp: Stamp = Stamp.new(position, radius, footprint, _time)
	stamp.next_update = _time + STAMP_INTERVAL
	_stamps.append(stamp)
	_last_position = position
	_last_radius = radius
	_last_footprint = footprint
	_has_sample = true
	_enqueue_stamp(stamp, 0.0)
	return true


func _enqueue_stamp(stamp: Stamp, age: float) -> void:
	var radius: float = lerpf(stamp.start_radius, stamp.radius * MAX_RADIUS_MULTIPLIER, clampf(age / GROWTH_TIME, 0.0, 1.0))
	var pixel_radius: float = minf(radius * _pixels_per_unit, _max_mask_radius)
	if stamp.full_map:
		pixel_radius = _max_mask_radius
	if radius * _pixels_per_unit >= _max_mask_radius:
		stamp.full_map = true
	var center: Vector2 = (stamp.position - _mask_min) * _pixels_per_unit
	var min_x: int = maxi(0, floori(center.x - pixel_radius))
	var max_x: int = mini(_width - 1, ceili(center.x + pixel_radius))
	var min_y: int = maxi(0, floori(center.y - pixel_radius))
	var max_y: int = mini(_height - 1, ceili(center.y + pixel_radius))
	if min_x > max_x or min_y > max_y:
		return
	_raster_jobs.append(RasterJob.new(stamp, center, pixel_radius, Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)))


func _has_pending_stamp(stamp: Stamp) -> bool:
	for job: RasterJob in _raster_jobs:
		if job.stamp == stamp:
			return true
	return false


func _process_raster_budget() -> void:
	var budget: int = MAX_RASTER_SAMPLES_PER_FRAME
	while budget > 0 and not _raster_jobs.is_empty():
		var job: RasterJob = _raster_jobs[0]
		var row_width: int = job.max_x - job.min_x + 1
		var end_cursor: int = mini(job.cursor + budget, row_width * (job.max_y - job.min_y + 1))
		var processed: int = end_cursor - job.cursor
		while job.cursor < end_cursor:
			var x: int = job.min_x + job.cursor % row_width
			var y: int = job.min_y + job.cursor / row_width
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(job.center) / job.pixel_radius
			if distance < 1.0:
				var value: int = roundi((1.0 - smoothstep(0.0, 1.0, distance)) * 255.0)
				var pixel_index: int = y * _width + x
				if value > _pixels[pixel_index]:
					_pixels[pixel_index] = value
					_dirty = true
			job.cursor += 1
		budget -= processed
		if job.cursor >= row_width * (job.max_y - job.min_y + 1):
			_raster_jobs.pop_front()
		else:
			break


func renew(duration: float) -> void:
	_renewing = true
	_has_sample = false
	_stamps.clear()
	if _renew_tween != null and _renew_tween.is_valid():
		_renew_tween.kill()
	_renew_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renew_tween.tween_property(_material, "shader_parameter/scorch_strength", 0.0, maxf(duration, 0.01))
