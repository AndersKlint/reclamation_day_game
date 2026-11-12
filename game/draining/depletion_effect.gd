extends Node3D

signal life_absorbed(amount: float)
signal flattened()

enum Style { WOODEN, HUMANOID, RUBBLE }

const ANIMATED_COLLAPSE_BUDGET: int = 12
const STATIC_BUILDING_PIECES: int = 48
const STATIC_PROP_PIECES: int = 12
const GROUND_SAMPLE_BUDGET: int = 32
const MAGNET_FALL_GRAVITY: float = 14.0
const MAGNET_BASE_ACCELERATION: float = 12.0
const MAGNET_PULL: float = 900.0
const MAGNET_MAX_ACCELERATION: float = 180.0
const MAGNET_MAX_SPEED: float = 55.0
const MAGNET_CONSUME_RADIUS: float = 0.6
const MAGNET_SHRINK_DISTANCE: float = 1.4
const MAGNET_MIN_SCALE: float = 0.18
const MAGNET_CAPTURE_DISTANCE: float = 6.0
const MAGNET_ORBIT_DECAY_SECONDS: float = 3.0
const MAGNET_ORBIT_DAMPING: float = 2.2
const MAGNET_RADIAL_DAMPING: float = 0.65
const MAGNET_RECOVERY_SECONDS: float = 8.0
const ABSORPTION_SEGMENT_SAMPLES: int = 8
const AUTOMATIC_ABSORB_SECONDS: float = 1.0

static var _animated_collapses: int = 0

class AbsorptionCone:
	var base_center: Vector3
	var height: float
	var base_radius: float
	var top_radius: float

	func contains(point: Vector3) -> bool:
		var t: float = (point.y - base_center.y) / maxf(height, 0.0001)
		if t < 0.0 or t > 1.0:
			return false
		var radius: float = lerpf(base_radius, top_radius, t)
		var dx: float = point.x - base_center.x
		var dz: float = point.z - base_center.z
		return dx * dx + dz * dz <= radius * radius


class MagnetPiece:
	var batch: MultiMesh
	var slot: int = 0
	var position: Vector3
	var basis: Basis
	var landing_basis: Basis
	var velocity: Vector3
	var landing_y: float = 0.0
	var age: float = 0.0
	var pull_age: float = 0.0
	var capture_age: float = -1.0
	var delay: float = 0.0
	var spin: float = 0.0
	var life_share: float = 0.0
	var settled: bool = false
	var consumed: bool = false

@export var style: Style = Style.RUBBLE
@export var building_collapse: bool = false
var female_voice: bool = false
var reserved_life: float = 0.0
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
var _magnet_enabled: bool = false
var _magnet_target: Node3D
var _magnet_pieces: Array[MagnetPiece] = []
var _previous_magnet_target: Vector3 = Vector3.INF
var _pending_life: float = 0.0
var _healing_per_life: float = 0.0
var _absorb_sound_played: bool = false
var _flattened: bool = false
var _remaining_life: float = 0.0
var _automatic_life: float = 0.0
var _automatic_time_left: float = 0.0


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	_release_animated_collapse()


func configure_reward(amount: float, recipient: Node3D, healing_per_life: float = 0.0) -> void:
	assert(not _started and is_finite(amount) and amount >= 0.0 and is_instance_valid(recipient))
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reserved_life = amount
	_remaining_life = amount
	_healing_per_life = healing_per_life if is_finite(healing_per_life) and healing_per_life > 0.0 else 0.0
	_magnet_target = recipient


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
	var sfx: Node = _find_gameplay_sfx()
	if sfx != null:
		sfx.play_depletion(style, global_position, female_voice, building_collapse, _size)
	_base_y = global_position.y
	_fallback_ground_height = _ground_height(Vector3.ZERO)
	var has_visual: bool = is_instance_valid(_visual)
	if has_visual:
		_visual_world_transform = _visual.global_transform
		_visual_transform = global_transform.affine_inverse() * _visual_world_transform
	_owns_animated_collapse = has_visual and _animated_collapses < ANIMATED_COLLAPSE_BUDGET
	if _owns_animated_collapse:
		_animated_collapses += 1
	_magnet_enabled = style == Style.RUBBLE and _remaining_life > 0.0 and is_instance_valid(_magnet_target)
	if not _magnet_enabled and _remaining_life > 0.0:
		_start_automatic_transfer()
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


func _start_automatic_transfer() -> void:
	_automatic_life = _remaining_life
	_automatic_time_left = AUTOMATIC_ABSORB_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_magnet_target):
		queue_free()
		return
	if not bool(_magnet_target.get("gameplay_enabled")):
		_previous_magnet_target = Vector3.INF
		return
	if _automatic_time_left > 0.0:
		var elapsed: float = minf(delta, _automatic_time_left)
		_automatic_time_left = maxf(0.0, _automatic_time_left - elapsed)
		_pending_life += _remaining_life if _automatic_time_left <= 0.0 else _automatic_life * elapsed / AUTOMATIC_ABSORB_SECONDS
		_flush_absorbed_life()
		if _automatic_time_left <= 0.0:
			set_process(false)
			if _magnet_enabled:
				queue_free()
		return
	if _magnet_pieces.is_empty():
		return
	var step: float = minf(delta, 1.0 / 30.0)
	var collecting: bool = not _magnet_target.has_method(&"can_collect_rubble") or bool(_magnet_target.call(&"can_collect_rubble"))
	if not collecting:
		_previous_magnet_target = Vector3.INF
	var target_global: Vector3 = _magnet_global_position()
	var has_target: bool = collecting and target_global.is_finite()
	var target: Vector3 = to_local(target_global) if has_target else Vector3.ZERO
	var target_start: Vector3 = _previous_magnet_target if _previous_magnet_target.is_finite() else target
	_previous_magnet_target = target if has_target else Vector3.INF
	var target_velocity: Vector3 = Vector3.ZERO
	if _magnet_target is CharacterBody3D:
		target_velocity = global_basis.inverse() * (_magnet_target as CharacterBody3D).get_real_velocity()
	var absorption_inverse: Transform3D = Transform3D.IDENTITY
	var absorption_cone: AbsorptionCone = null
	var has_absorption: bool = collecting and _magnet_target.has_method(&"get_absorption_bounds") and _magnet_target.has_method(&"get_absorption_transform")
	if has_absorption:
		var absorption_transform: Transform3D = _magnet_target.call(&"get_absorption_transform")
		absorption_inverse = absorption_transform.affine_inverse()
		var bounds: AABB = _magnet_target.call(&"get_absorption_bounds")
		absorption_cone = AbsorptionCone.new()
		absorption_cone.base_center = Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		absorption_cone.height = bounds.size.y
		absorption_cone.base_radius = maxf(bounds.size.x, bounds.size.z) * 0.5
		absorption_cone.top_radius = absorption_cone.base_radius * 0.5
	var alive: bool = false
	for piece: MagnetPiece in _magnet_pieces:
		if piece.consumed:
			continue
		alive = true
		piece.age += step
		var from: Vector3 = piece.position
		if not piece.settled:
			piece.velocity.y -= MAGNET_FALL_GRAVITY * step
			piece.position += piece.velocity * step
			if piece.position.y <= piece.landing_y:
				piece.position.y = piece.landing_y
				piece.basis = piece.landing_basis
				piece.velocity = Vector3.ZERO
				piece.settled = true
			_write_magnet_piece(piece, 1.0)
		elif has_target and piece.age >= piece.delay:
			_advance_magnet_piece(piece, target_start, target, target_velocity, step)
		if has_absorption:
			_absorb_if_touching(piece, from, piece.position, absorption_inverse, absorption_cone)
	if _pending_life > 0.0:
		_flush_absorbed_life()
	if not alive and _flattened:
		_pending_life += _remaining_life
		_flush_absorbed_life()
		_magnet_pieces.clear()
		queue_free()


func _advance_magnet_piece(piece: MagnetPiece, target_start: Vector3, target: Vector3, target_velocity: Vector3, step: float) -> void:
	piece.pull_age += step
	var relative_start: Vector3 = piece.position - target_start
	var distance: float = relative_start.length()
	var direction: Vector3 = -relative_start / maxf(distance, 0.0001)
	if piece.capture_age >= 0.0:
		piece.capture_age += step
	elif distance <= MAGNET_CAPTURE_DISTANCE:
		piece.capture_age = 0.0
	var recovery: float = smoothstep(MAGNET_RECOVERY_SECONDS, MAGNET_RECOVERY_SECONDS * 2.0, piece.pull_age)
	var convergence: float = maxf(smoothstep(0.0, MAGNET_ORBIT_DECAY_SECONDS, piece.capture_age), recovery)
	var drag_strength: float = lerpf(0.05, 1.0, convergence)
	var relative_velocity: Vector3 = piece.velocity - target_velocity
	var radial_velocity: Vector3 = direction * relative_velocity.dot(direction)
	var tangential_velocity: Vector3 = relative_velocity - radial_velocity
	relative_velocity = radial_velocity * exp(-MAGNET_RADIAL_DAMPING * drag_strength * step) + tangential_velocity * exp(-MAGNET_ORBIT_DAMPING * drag_strength * step)
	var acceleration: float = minf(MAGNET_BASE_ACCELERATION + MAGNET_PULL / maxf(distance * distance, 0.04), MAGNET_MAX_ACCELERATION)
	acceleration *= lerpf(1.0, 2.0, recovery)
	piece.velocity = (target_velocity + relative_velocity + direction * acceleration * step).limit_length(MAGNET_MAX_SPEED)
	piece.position += piece.velocity * step
	var relative_end: Vector3 = piece.position - target
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3.ZERO, relative_start, relative_end)
	if piece.capture_age < 0.0 and closest.length_squared() <= MAGNET_CAPTURE_DISTANCE * MAGNET_CAPTURE_DISTANCE:
		piece.capture_age = 0.0
	piece.basis = piece.basis.rotated(Vector3.UP, piece.spin * step)
	var shrink: float = clampf((relative_end.length() - MAGNET_CONSUME_RADIUS) / MAGNET_SHRINK_DISTANCE, MAGNET_MIN_SCALE, 1.0)
	_write_magnet_piece(piece, shrink)


func _absorb_if_touching(piece: MagnetPiece, from: Vector3, to: Vector3, absorption_inverse: Transform3D, cone: AbsorptionCone) -> void:
	var local_from: Vector3 = absorption_inverse * to_global(from)
	var local_to: Vector3 = absorption_inverse * to_global(to)
	if not _segment_hits_cone(local_from, local_to, cone):
		return
	piece.consumed = true
	_pending_life += piece.life_share
	piece.batch.set_instance_transform(piece.slot, Transform3D(Basis.from_scale(Vector3.ZERO), piece.position))
	if not _absorb_sound_played:
		_absorb_sound_played = true
		_play_absorb_sound()


func _segment_hits_cone(from: Vector3, to: Vector3, cone: AbsorptionCone) -> bool:
	for sample: int in ABSORPTION_SEGMENT_SAMPLES + 1:
		if cone.contains(from.lerp(to, float(sample) / float(ABSORPTION_SEGMENT_SAMPLES))):
			return true
	return false


func _flush_absorbed_life() -> void:
	var amount: float = minf(_pending_life, _remaining_life)
	_pending_life = 0.0
	if amount <= 0.0:
		return
	_remaining_life = maxf(0.0, _remaining_life - amount)
	_magnet_target.call(&"gain_life", amount)
	_request_healing(amount)
	life_absorbed.emit(amount)

func _request_healing(amount: float) -> void:
	if _healing_per_life <= 0.0 or not is_instance_valid(_magnet_target) or not _magnet_target.has_method(&"request_healing"):
		return
	var healing: float = amount * _healing_per_life
	if not is_finite(healing) or healing <= 0.0:
		return
	_magnet_target.call(&"request_healing", healing)


func _play_absorb_sound() -> void:
	var sfx: Node = _find_gameplay_sfx()
	if sfx != null and sfx.has_method(&"play_rubble_absorb"):
		sfx.call(&"play_rubble_absorb", _size)


func _find_gameplay_sfx() -> Node:
	var ancestor: Node = get_parent()
	while ancestor != null:
		var sfx: Node = ancestor.get_node_or_null("GameplaySfx")
		if sfx != null:
			return sfx
		ancestor = ancestor.get_parent()
	return null


func _magnet_global_position() -> Vector3:
	if not is_instance_valid(_magnet_target):
		return Vector3.INF
	if _magnet_target.has_method(&"get_collection_position"):
		var value: Variant = _magnet_target.call(&"get_collection_position")
		if value is Vector3 and (value as Vector3).is_finite():
			return value
	return _magnet_target.global_position


func _write_magnet_piece(piece: MagnetPiece, scale_factor: float) -> void:
	piece.batch.set_instance_transform(piece.slot, Transform3D(piece.basis.scaled(Vector3.ONE * scale_factor), piece.position))


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
	if not _flattened:
		_flattened = true
		flattened.emit()


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
	var assigned_life: float = 0.0
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
		var spawn_height: float = rng.randf_range(0.2, maxf(0.25, _size.y * 0.65))
		if _magnet_enabled:
			spawn_height = rng.randf_range(0.2, clampf(_size.y * 0.65, 0.25, 5.0))
		var fragment_transform: Transform3D = Transform3D(basis, destination + Vector3.UP * spawn_height)
		if _magnet_enabled:
			var slot: int = indices[material_index]
			batches[material_index].set_instance_transform(slot, fragment_transform)
			batches[material_index].visible_instance_count = slot + 1
			var piece: MagnetPiece = MagnetPiece.new()
			piece.batch = batches[material_index]
			piece.slot = slot
			piece.position = fragment_transform.origin
			piece.basis = basis
			piece.landing_basis = basis
			piece.landing_y = destination.y
			piece.delay = 0.45 + building_collapse_duration + rng.randf_range(0.0, 0.35)
			piece.spin = rng.randf_range(-4.5, 4.5)
			piece.life_share = reserved_life - assigned_life if i == count - 1 else reserved_life / float(count)
			assigned_life += piece.life_share
			_magnet_pieces.append(piece)
			indices[material_index] += 1
			continue
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
	if not _magnet_pieces.is_empty():
		set_process(true)


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
