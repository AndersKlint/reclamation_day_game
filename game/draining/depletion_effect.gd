extends Node3D

enum Style { WOODEN, HUMANOID, RUBBLE }

const ANIMATED_COLLAPSE_BUDGET: int = 12
const STATIC_BUILDING_PIECES: int = 48
const STATIC_PROP_PIECES: int = 12
const GROUND_SAMPLE_BUDGET: int = 32

static var _animated_collapses: int = 0

@export var style: Style = Style.RUBBLE
@export var building_collapse: bool = false
var female_voice: bool = false
@export_range(0.1, 5.0, 0.05) var building_collapse_duration: float = 0.8
@export_range(0.1, 5.0, 0.05) var plant_collapse_duration: float = 1.15
@export var dust_color: Color = Color(0.56, 0.49, 0.37, 0.48)
@export_range(0.0, 2.0, 0.05) var dust_spread_multiplier: float = 1.0

static var _flesh_material: StandardMaterial3D
static var _box_mesh: BoxMesh

var _visual: Node3D
var _visual_world_transform: Transform3D
var _visual_transform: Transform3D
var _materials: Array[Material] = []
var _size: Vector3 = Vector3.ONE
var _ground_position: Callable
var _base_y: float
var _started: bool = false
var _owns_animated_collapse: bool = false
var _ground_samples_remaining: int = GROUND_SAMPLE_BUDGET
var _fallback_ground_height: float


func _exit_tree() -> void:
	_release_animated_collapse()


func configure(source_visual: Node3D, fitted_size: Vector3, ground_position: Callable) -> void:
	_visual = source_visual
	_size = fitted_size.abs().max(Vector3.ONE * 0.05)
	_ground_position = ground_position
	_materials.clear()
	if is_instance_valid(_visual):
		_visual_world_transform = _visual.global_transform
		_collect_materials(_visual)
		_materials = _rubble_materials()


func start() -> void:
	if _started:
		return
	_started = true
	var ancestor: Node = get_parent()
	while ancestor != null:
		var sfx: Node = ancestor.get_node_or_null("GameplaySfx")
		if sfx != null:
			sfx.play_depletion(style, global_position, female_voice, building_collapse, _size)
			break
		ancestor = ancestor.get_parent()
	_base_y = global_position.y
	_fallback_ground_height = _ground_height(Vector3.ZERO)
	var has_visual: bool = is_instance_valid(_visual)
	if has_visual:
		_visual_world_transform = _visual.global_transform
		_visual_transform = global_transform.affine_inverse() * _visual_world_transform
	_owns_animated_collapse = has_visual and _animated_collapses < ANIMATED_COLLAPSE_BUDGET
	if _owns_animated_collapse:
		_animated_collapses += 1
	if _owns_animated_collapse and style != Style.HUMANOID:
		_spawn_dust()
	_spawn_fragments(_owns_animated_collapse)
	if style == Style.HUMANOID:
		_spawn_blood_puddle()
	if not _owns_animated_collapse:
		_hide_visual()
		return
	var tween: Tween = create_tween()
	if style == Style.RUBBLE:
		tween.tween_method(_shudder, 0.0, 1.0, 0.45)
		tween.tween_method(_collapse, 0.0, 1.0, building_collapse_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		tween.tween_method(_collapse, 0.0, 1.0, plant_collapse_duration if style == Style.WOODEN else 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_visual)
	tween.tween_callback(_release_animated_collapse)


func _release_animated_collapse() -> void:
	if _owns_animated_collapse:
		_owns_animated_collapse = false
		_animated_collapses = maxi(_animated_collapses - 1, 0)


func _collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh:
			for surface: int in instance.mesh.get_surface_count():
				var source: Material = instance.get_active_material(surface)
				if source and not _materials.has(source) and _materials.size() < 8:
					_materials.append(source)
	for child: Node in node.get_children():
		_collect_materials(child)


func _rubble_materials() -> Array[Material]:
	var result: Array[Material] = []
	for source: Material in _materials:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.roughness = 1.0
		if source is BaseMaterial3D:
			var base: BaseMaterial3D = source as BaseMaterial3D
			material.albedo_color = base.albedo_color
			material.albedo_texture = base.albedo_texture
			material.uv1_scale = base.uv1_scale
			material.uv1_offset = base.uv1_offset
		elif source is ShaderMaterial:
			var shader: ShaderMaterial = source as ShaderMaterial
			var color: Variant = shader.get_shader_parameter("base_color")
			var texture: Variant = shader.get_shader_parameter("albedo_texture")
			var uv_scale: Variant = shader.get_shader_parameter("uv_scale")
			var uv_offset: Variant = shader.get_shader_parameter("uv_offset")
			if color is Color:
				material.albedo_color = color
			if texture is Texture2D:
				material.albedo_texture = texture
			if uv_scale is Vector3:
				material.uv1_scale = uv_scale
			elif uv_scale is Vector2:
				material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
			if uv_offset is Vector3:
				material.uv1_offset = uv_offset
			elif uv_offset is Vector2:
				material.uv1_offset = Vector3(uv_offset.x, uv_offset.y, 0.0)
		else:
			continue
		result.append(material)
	if result.is_empty():
		result.append(StandardMaterial3D.new())
	return result


func _shudder(progress: float) -> void:
	_apply_visual(Transform3D(Basis(Vector3.FORWARD, sin(progress * TAU * 4.0) * 0.018 * progress), Vector3.ZERO))


func _collapse(progress: float) -> void:
	var basis: Basis
	if style == Style.RUBBLE:
		basis = Basis.from_scale(Vector3(1.0, lerpf(1.0, 0.04, progress), 1.0))
	else:
		basis = Basis(Vector3.FORWARD, progress * 0.38) * Basis.from_scale(Vector3.ONE * lerpf(1.0, 0.18, progress))
	_apply_visual(Transform3D(basis, Vector3.ZERO))


func _apply_visual(animation: Transform3D) -> void:
	if is_instance_valid(_visual):
		_visual.global_transform = global_transform * animation * _visual_transform


func _hide_visual() -> void:
	if is_instance_valid(_visual):
		if style == Style.HUMANOID:
			_visual.queue_free()
		else:
			_visual.visible = false


func _spawn_fragments(animated: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var volume: float = _size.x * _size.y * _size.z
	var retained: float = volume * (0.0015 if style == Style.WOODEN else (0.16 if style == Style.HUMANOID else 0.12))
	var target_piece_volume: float = 0.004 if style == Style.WOODEN else (0.012 if style == Style.HUMANOID else 3.0)
	var piece_limit: int = STATIC_BUILDING_PIECES if building_collapse and style == Style.RUBBLE else STATIC_PROP_PIECES
	var count: int = clampi(ceili(retained / target_piece_volume), 6, piece_limit)
	var unit: float = pow(retained / float(count), 1.0 / 3.0)
	var materials: Array[Material] = []
	if style == Style.RUBBLE:
		materials = _materials if not _materials.is_empty() else _rubble_materials()
	elif style == Style.HUMANOID:
		materials.append(_get_flesh_material())
	else:
		for color: Color in [Color(0.055, 0.047, 0.042), Color(0.11, 0.10, 0.09), Color(0.18, 0.17, 0.15)]:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 1.0
			materials.append(mat)
	if not _box_mesh:
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3.ONE
	var batches: Array[MultiMesh] = []
	var indices: Array[int] = []
	for material: Material in materials:
		var batch: MultiMesh = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _box_mesh
		batch.instance_count = count
		for slot: int in count:
			batch.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		batch.visible_instance_count = 0
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = material
		add_child(instance)
		batches.append(batch)
		indices.append(0)
	for i: int in count:
		var material_index: int = i % materials.size()
		var dimensions: Vector3
		if style == Style.WOODEN:
			dimensions = Vector3(unit * 0.38, unit * rng.randf_range(1.8, 4.0), unit * 0.38)
		else:
			dimensions = Vector3(unit * rng.randf_range(0.7, 1.35), unit * rng.randf_range(0.55, 1.1), unit * rng.randf_range(0.7, 1.35))
		var spread: float = 0.13 if style == Style.WOODEN else (0.28 if style == Style.HUMANOID else 0.43)
		var destination: Vector3 = Vector3(rng.randf_range(-spread, spread) * _size.x, 0.0, rng.randf_range(-spread, spread) * _size.z)
		var rotation: Vector3 = Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(-PI, PI), rng.randf_range(-1.1, 1.1))
		if style == Style.WOODEN:
			rotation.x += PI * 0.5
		var basis: Basis = Basis.from_euler(rotation).scaled_local(dimensions)
		destination.y = _fragment_ground_height(destination, basis)
		var fragment_transform: Transform3D = Transform3D(basis, destination + Vector3.UP * rng.randf_range(0.2, maxf(0.25, _size.y * 0.65)))
		if not animated:
			batches[material_index].set_instance_transform(indices[material_index], Transform3D(basis, destination))
			batches[material_index].visible_instance_count = indices[material_index] + 1
			indices[material_index] += 1
			continue
		var fragment: MeshInstance3D = MeshInstance3D.new()
		fragment.mesh = _box_mesh
		fragment.material_override = materials[material_index]
		add_child(fragment)
		fragment.transform = fragment_transform
		var tween: Tween = create_tween()
		tween.tween_property(fragment, "position", destination, rng.randf_range(0.55, 1.15)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_settle_fragment.bind(fragment, batches[material_index], indices[material_index]))
		indices[material_index] += 1


func _settle_fragment(fragment: MeshInstance3D, batch: MultiMesh, index: int) -> void:
	batch.set_instance_transform(index, fragment.transform)
	batch.visible_instance_count = maxi(batch.visible_instance_count, index + 1)
	fragment.queue_free()


func _get_flesh_material() -> StandardMaterial3D:
	if _flesh_material:
		return _flesh_material
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 4182
	noise.frequency = 0.09
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			var value: float = clampf(noise.get_noise_2d(x, y) * 1.5 + 0.5, 0.0, 1.0)
			var vein: float = 1.0 - smoothstep(0.02, 0.16, absf(noise.get_noise_2d(x * 0.7 + 31.0, y * 0.7)))
			image.set_pixel(x, y, Color(0.29, 0.025, 0.035).lerp(Color(0.76, 0.36, 0.37), clampf(value * 0.75 + vein * 0.3, 0.0, 1.0)))
	_flesh_material = StandardMaterial3D.new()
	_flesh_material.albedo_texture = ImageTexture.create_from_image(image)
	_flesh_material.roughness = 0.68
	return _flesh_material


func _spawn_blood_puddle() -> void:
	var radius: float = clampf(maxf(_size.x, _size.z) * 0.65, 0.35, 1.1)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var rings: int = 3
	var segments: int = 24
	for ring: int in rings + 1:
		for i: int in segments:
			var angle: float = TAU * float(i) / float(segments)
			var irregular: float = 1.0 + 0.16 * sin(angle * 5.0) + 0.09 * sin(angle * 9.0 + 1.0)
			var point: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius * irregular * float(ring) / float(rings)
			point.y = _ground_height(point) + 0.025
			vertices.append(point)
	for ring: int in rings:
		for i: int in segments:
			var a: int = ring * segments + i
			var b: int = ring * segments + (i + 1) % segments
			indices.append_array(PackedInt32Array([a, b, a + segments, b, b + segments, a + segments]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.008, 0.015)
	material.roughness = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


func _fragment_ground_height(center: Vector3, basis: Basis) -> float:
	if _ground_samples_remaining <= 0:
		return _fallback_ground_height
	var height: float = -INF
	for x: float in [-0.5, 0.5]:
		for y: float in [-0.5, 0.5]:
			for z: float in [-0.5, 0.5]:
				if _ground_samples_remaining <= 0:
					return maxf(height, _fallback_ground_height)
				_ground_samples_remaining -= 1
				var offset: Vector3 = basis * Vector3(x, y, z)
				height = maxf(height, _ground_height(center + offset) - offset.y)
	return height


func _ground_height(local_point: Vector3) -> float:
	var world_point: Vector3 = to_global(local_point)
	world_point.y = _base_y
	if _ground_position.is_valid():
		var result: Variant = _ground_position.call(world_point)
		if result is Vector3 and result.is_finite():
			world_point = result
	return to_local(world_point).y


func _spawn_dust() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.75
	particles.amount = 36 if style == Style.RUBBLE else 22
	particles.lifetime = 1.8
	particles.local_coords = true
	var extent: Vector3 = Vector3(maxf(_size.x * 0.45, 0.15), maxf(_size.y * 0.25, 0.15), maxf(_size.z * 0.45, 0.15))
	particles.position.y = extent.y
	particles.visibility_aabb = AABB(-extent * 3.0 - Vector3.ONE * 2.0, extent * 6.0 + Vector3.ONE * 4.0)
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extent
	process.direction = Vector3.UP
	process.spread = clampf(80.0 * dust_spread_multiplier, 0.0, 180.0)
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = minf(0.8, _size.y * 0.25 + 0.15)
	process.gravity = Vector3(0.0, -0.15, 0.0)
	process.scale_min = maxf(0.12, minf(_size.x, _size.z) * 0.12)
	process.scale_max = process.scale_min * 2.2
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, dust_color)
	gradient.set_color(1, Color(dust_color.r, dust_color.g, dust_color.b, 0.0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var alpha_gradient: Gradient = Gradient.new()
	alpha_gradient.set_color(0, Color.WHITE)
	alpha_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var dust_texture: GradientTexture2D = GradientTexture2D.new()
	dust_texture.width = 64
	dust_texture.height = 64
	dust_texture.fill = GradientTexture2D.FILL_RADIAL
	dust_texture.fill_from = Vector2(0.5, 0.5)
	dust_texture.fill_to = Vector2(1.0, 0.5)
	dust_texture.gradient = alpha_gradient
	material.albedo_texture = dust_texture
	var mesh: QuadMesh = QuadMesh.new()
	mesh.material = material
	particles.draw_pass_1 = mesh
	add_child(particles)
	particles.emitting = true
	var cleanup: Tween = create_tween()
	cleanup.tween_interval(particles.lifetime * 2.0 + 0.2)
	cleanup.tween_callback(particles.queue_free)
