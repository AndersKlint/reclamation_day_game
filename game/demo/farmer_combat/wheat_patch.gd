extends Node3D

signal progress_changed(harvested: int, total: int)

const Drainable = preload("res://game/draining/drainable.gd")
const StalkMesh = preload("res://game/demo/farmer_combat/wheat_stalk_mesh.gd")
const STALK_SHADER: Shader = preload("res://game/demo/farmer_combat/wheat_stalk.gdshader")
const CLUMP_HEIGHT: float = 0.95
const CELL_SIZE: float = 2.0
const CHUNK_CELLS: int = 4
const ROW_SPACING: float = 0.36
const REWARD_SECONDS: float = 1.0

class CropCell:
	var drainable: Drainable
	var collision: CollisionShape3D
	var batch: MultiMesh
	var first_instance: int
	var instance_count: int
	var harvested: bool = false

class ReserveTransfer:
	var recipient: Node3D
	var total: float
	var remaining: float
	var time_left: float = REWARD_SECONDS

@export var field_size: Vector2 = Vector2(58.0, 58.0)
@export var exclusion_regions: Array[Rect2] = []
@export_range(2.0, 12.0, 0.5) var stalks_per_square_meter: float = 8.0
@export var generation_seed: int = 4170

var total_clumps: int = 0
var harvested_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stalk_mesh: ArrayMesh
var _material: ShaderMaterial
var _transfers: Array[ReserveTransfer] = []


func _ready() -> void:
	_rng.seed = generation_seed
	_stalk_mesh = StalkMesh.build()
	_material = ShaderMaterial.new()
	_material.shader = STALK_SHADER
	_build_field()
	set_process(false)


func _process(delta: float) -> void:
	for index: int in range(_transfers.size() - 1, -1, -1):
		var transfer: ReserveTransfer = _transfers[index]
		if not is_instance_valid(transfer.recipient) or float(transfer.recipient.get(&"health")) <= 0.0:
			_transfers.remove_at(index)
			continue
		if not bool(transfer.recipient.get(&"gameplay_enabled")):
			continue
		var elapsed: float = minf(maxf(delta, 0.0), transfer.time_left)
		transfer.time_left = maxf(0.0, transfer.time_left - elapsed)
		var amount: float = transfer.remaining if transfer.time_left <= 0.0 else minf(transfer.remaining, transfer.total * elapsed / REWARD_SECONDS)
		transfer.remaining = maxf(0.0, transfer.remaining - amount)
		transfer.recipient.call(&"gain_life", amount)
		if transfer.time_left <= 0.0:
			_transfers.remove_at(index)
	set_process(not _transfers.is_empty())


func _build_field() -> void:
	if not field_size.is_finite() or field_size.x <= 0.0 or field_size.y <= 0.0:
		push_error("Wheat field dimensions must be finite and positive")
		return
	var field := Rect2(-field_size * 0.5, field_size)
	var cell_counts := Vector2i(ceili(field_size.x / CELL_SIZE), ceili(field_size.y / CELL_SIZE))
	for chunk_z: int in range(0, cell_counts.y, CHUNK_CELLS):
		for chunk_x: int in range(0, cell_counts.x, CHUNK_CELLS):
			_build_chunk(field, cell_counts, Vector2i(chunk_x, chunk_z))


func _build_chunk(field: Rect2, cell_counts: Vector2i, first_cell: Vector2i) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var custom_data: Array[Color] = []
	var cells: Array[CropCell] = []
	var chunk_origin: Vector2 = field.position + Vector2(first_cell) * CELL_SIZE
	for z: int in range(first_cell.y, mini(first_cell.y + CHUNK_CELLS, cell_counts.y)):
		for x: int in range(first_cell.x, mini(first_cell.x + CHUNK_CELLS, cell_counts.x)):
			var cell_rect := Rect2(field.position + Vector2(x, z) * CELL_SIZE, Vector2.ONE * CELL_SIZE).intersection(field)
			var crop_area: float = _crop_area(cell_rect)
			if crop_area <= 0.001:
				continue
			var cell := CropCell.new()
			cell.first_instance = transforms.size()
			_append_stalks(cell_rect, field, chunk_origin, transforms, colors, custom_data)
			cell.instance_count = transforms.size() - cell.first_instance
			_add_drain_cell(cell, cell_rect, crop_area)
			cells.append(cell)
	if transforms.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = _stalk_mesh
	batch.instance_count = transforms.size()
	for index: int in transforms.size():
		batch.set_instance_transform(index, transforms[index])
		batch.set_instance_color(index, colors[index])
		batch.set_instance_custom_data(index, custom_data[index])
	var chunk_size: Vector2 = (field.end - chunk_origin).min(Vector2.ONE * CELL_SIZE * CHUNK_CELLS)
	batch.custom_aabb = AABB(Vector3(-0.65, -0.05, -0.65), Vector3(chunk_size.x + 1.3, 1.6, chunk_size.y + 1.3))
	var visual := MultiMeshInstance3D.new()
	visual.name = "WheatChunk%d_%d" % [first_cell.x, first_cell.y]
	visual.position = Vector3(chunk_origin.x, 0.0, chunk_origin.y)
	visual.multimesh = batch
	visual.material_override = _material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	for cell: CropCell in cells:
		cell.batch = batch


func _append_stalks(rect: Rect2, field: Rect2, chunk_origin: Vector2, transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color]) -> void:
	var along_spacing: float = 1.0 / (clampf(stalks_per_square_meter, 2.0, 12.0) * ROW_SPACING)
	for row: int in range(ceili(rect.position.y / ROW_SPACING), ceili(rect.end.y / ROW_SPACING)):
		for column: int in range(ceili(rect.position.x / along_spacing), ceili(rect.end.x / along_spacing)):
			var point := Vector2(column * along_spacing, row * ROW_SPACING)
			point += Vector2(_rng.randf_range(-0.11, 0.11), _rng.randf_range(-0.07, 0.07))
			point.y += sin(point.x * 0.24 + row * 0.05) * 0.055
			if not field.has_point(point) or _is_excluded(point):
				continue
			var patchiness: float = sin(point.x * 0.7 + sin(point.y * 0.3)) * sin(point.y * 0.53)
			if _rng.randf() < 0.055 + maxf(patchiness, 0.0) * 0.12:
				continue
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			basis = basis.scaled(Vector3(1.0, _rng.randf_range(0.78, 1.24), 1.0))
			transforms.append(Transform3D(basis, Vector3(point.x - chunk_origin.x, 0.0, point.y - chunk_origin.y)))
			colors.append(Color("bca65e").lerp(Color("d2b779"), _rng.randf()))
			custom_data.append(Color(0.0, _rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.16, 0.16), 0.0))


func _is_excluded(point: Vector2) -> bool:
	for region: Rect2 in exclusion_regions:
		if region.has_point(point):
			return true
	return false


func _crop_area(rect: Rect2) -> float:
	var pieces: Array[Rect2] = [rect]
	for region: Rect2 in exclusion_regions:
		var remainder: Array[Rect2] = []
		for piece: Rect2 in pieces:
			var cut: Rect2 = piece.intersection(region)
			if not cut.has_area():
				remainder.append(piece)
				continue
			var strips: Array[Rect2] = [
				Rect2(piece.position, Vector2(piece.size.x, cut.position.y - piece.position.y)),
				Rect2(Vector2(piece.position.x, cut.end.y), Vector2(piece.size.x, piece.end.y - cut.end.y)),
				Rect2(Vector2(piece.position.x, cut.position.y), Vector2(cut.position.x - piece.position.x, cut.size.y)),
				Rect2(Vector2(cut.end.x, cut.position.y), Vector2(piece.end.x - cut.end.x, cut.size.y))]
			for strip: Rect2 in strips:
				if strip.has_area():
					remainder.append(strip)
		pieces = remainder
	var area: float = 0.0
	for piece: Rect2 in pieces:
		area += piece.get_area()
	return area


func _add_drain_cell(cell: CropCell, rect: Rect2, crop_area: float) -> void:
	cell.drainable = Drainable.new()
	cell.drainable.name = "CropCell%d" % total_clumps
	cell.drainable.position = Vector3(rect.get_center().x, CLUMP_HEIGHT * 0.5, rect.get_center().y)
	cell.drainable.collision_layer = 8
	cell.drainable.collision_mask = 0
	cell.drainable.monitoring = false
	add_child(cell.drainable)
	cell.collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x, CLUMP_HEIGHT, rect.size.y)
	cell.collision.shape = shape
	cell.drainable.add_child(cell.collision)
	cell.drainable.emission_offset = Vector3(0.0, CLUMP_HEIGHT * 0.05, 0.0)
	cell.drainable.emission_radius = minf(rect.size.x, rect.size.y) * 0.5
	# Sparse crop volume excludes planting gaps so render density cannot change eligibility or life.
	var crop_width: float = sqrt(crop_area / (CELL_SIZE * CELL_SIZE))
	cell.drainable.configure_volume(Vector3(crop_width, CLUMP_HEIGHT, crop_width))
	cell.drainable.drained.connect(_on_cell_drained.bind(cell))
	cell.drainable.collapsed.connect(_on_cell_collapsed.bind(cell))
	total_clumps += 1


func _set_withering(cell: CropCell, amount: float) -> void:
	if cell.batch == null:
		return
	for index: int in range(cell.first_instance, cell.first_instance + cell.instance_count):
		var data: Color = cell.batch.get_instance_custom_data(index)
		data.r = amount
		cell.batch.set_instance_custom_data(index, data)


func _on_cell_drained(_amount: float, cell: CropCell) -> void:
	_set_withering(cell, 1.0 - cell.drainable.drain_fraction())


func _on_cell_collapsed(cell: CropCell) -> void:
	if cell.harvested:
		return
	cell.harvested = true
	_set_withering(cell, 1.0)
	cell.collision.set_deferred(&"disabled", true)
	var reward: float = cell.drainable.take_collapse_life()
	if reward > 0.0 and is_instance_valid(cell.drainable.collector):
		var transfer: ReserveTransfer = ReserveTransfer.new()
		transfer.recipient = cell.drainable.collector
		transfer.total = reward
		transfer.remaining = reward
		_transfers.append(transfer)
		set_process(true)
	harvested_count += 1
	progress_changed.emit(harvested_count, total_clumps)
