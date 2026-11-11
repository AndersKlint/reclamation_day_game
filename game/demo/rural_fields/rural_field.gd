extends Node3D

const Catalog = preload("res://game/demo/targets/demo_asset_catalog.gd")
const Target = preload("res://game/demo/targets/demo_target.gd")
const WheatPatch = preload("res://game/demo/farmer_combat/wheat_patch.gd")
const FARMER: PackedScene = preload("res://game/demo/farmer_combat/farmer.tscn")
const FENCE: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/fences/fence1_01.fbx")
const FENCE_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/textures/textures2.png")

const HEADLAND: float = 4.0
const WHEAT_HEIGHT: float = 1.8
const WHEAT_CAPACITY_PER_SQUARE_METER: float = 680.0 / 6400.0
const WHEAT_DRAIN_EFFICIENCY: float = 1.0 / 3.0
const FENCE_HEIGHT: float = 1.2
const FENCE_DEPTH: float = 0.35
# fence1_01 native bounds are 110 wide by 95 tall; the ratio keeps panels unstretched.
const PANEL_ASPECT: float = 110.0 / 95.0
const PANEL_WIDTH: float = FENCE_HEIGHT * PANEL_ASPECT
const SEAM_OVERLAP: float = 0.04
const FENCE_SINK: float = 0.1
const OPENING_WIDTH: float = 6.0
const FARMER_HOME_OFFSET: float = 0.22
const FARMER_SPAWN_LIFT: float = 0.05
const FARMER_LEASH: float = 65.0

@export var footprint_size: Vector2 = Vector2(60.0, 80.0)
@export var generation_seed: int = 3171

var wheat: WheatPatch
var initial_wheat_capacity: float = 0.0
var fence_targets: Array[Node3D] = []

var _region: Node3D
var _farmers: Array[CharacterBody3D] = []
var _remains: Node3D
var _active: bool = false
var _built: bool = false


func prepare(region: Node3D) -> void:
	_region = region


func footprint() -> Rect2:
	return Rect2(-footprint_size * 0.5, footprint_size)


func _ready() -> void:
	assert(is_instance_valid(_region), "Rural field requires the region before entering the tree")
	if _built:
		return
	_built = true
	if not footprint_size.is_finite() or footprint_size.x <= HEADLAND * 2.0 or footprint_size.y <= HEADLAND * 2.0:
		push_error("Rural field footprint must be larger than two headlands")
		return
	_remains = Node3D.new()
	_remains.name = "Remains"
	add_child(_remains)
	_build_wheat()
	_build_fences()
	_build_farmers()


func start(player: CharacterBody3D) -> void:
	if _active or not is_instance_valid(player):
		return
	_active = true
	for farmer: CharacterBody3D in _farmers:
		if not is_instance_valid(farmer) or farmer.is_queued_for_deletion():
			continue
		var matching_size: float = float(farmer.call(&"get_model_height")) / float(player.call(&"get_reference_model_height"))
		farmer.call(&"set_minimum_player_volume", float(player.get(&"base_volume")) * pow(matching_size, 3.0))
		farmer.call(&"configure_region", _region, farmer.global_position, FARMER_LEASH)
		farmer.call(&"configure", player, _remains)


func stop() -> void:
	_active = false
	for farmer: CharacterBody3D in _farmers:
		if is_instance_valid(farmer) and not farmer.is_queued_for_deletion():
			farmer.call(&"stop")


func _build_wheat() -> void:
	wheat = WheatPatch.new()
	wheat.name = "Wheat"
	var planted: Vector2 = footprint_size - Vector2.ONE * HEADLAND * 2.0
	wheat.field_size = planted
	wheat.visual_height = WHEAT_HEIGHT
	wheat.total_life_capacity = planted.x * planted.y * WHEAT_CAPACITY_PER_SQUARE_METER
	wheat.drain_efficiency = WHEAT_DRAIN_EFFICIENCY
	wheat.generation_seed = generation_seed
	wheat.ground_height = _wheat_ground_height
	add_child(wheat)
	initial_wheat_capacity = wheat.initial_capacity


func _build_fences() -> void:
	var fences: Node3D = Node3D.new()
	fences.name = "Fences"
	add_child(fences)
	var half: Vector2 = footprint_size * 0.5
	# The lane runs near region x zero, so the opening faces inward toward that lane.
	var opening_side: float = -1.0 if position.x > 0.0 else 1.0
	_tile_side(fences, &"x", half.y, -half.x, half.x, 0.0, false)
	_tile_side(fences, &"x", -half.y, -half.x, half.x, 0.0, false)
	_tile_side(fences, &"z", half.x, -half.y, half.y, PI * 0.5, opening_side > 0.0)
	_tile_side(fences, &"z", -half.x, -half.y, half.y, PI * 0.5, opening_side < 0.0)


func _tile_side(parent: Node3D, axis: StringName, fixed: float, start: float, end: float, yaw: float, opening: bool) -> void:
	if opening:
		var gap: float = minf(OPENING_WIDTH * 0.5, (end - start) * 0.5)
		_tile_span(parent, axis, fixed, start, -gap, yaw)
		_tile_span(parent, axis, fixed, gap, end, yaw)
		return
	_tile_span(parent, axis, fixed, start, end, yaw)


func _tile_span(parent: Node3D, axis: StringName, fixed: float, start: float, end: float, yaw: float) -> void:
	var length: float = end - start
	if length <= 0.001:
		return
	var count: int = maxi(1, ceili(length / PANEL_WIDTH))
	var pitch: float = length / count
	var width: float = minf(pitch + SEAM_OVERLAP, PANEL_WIDTH)
	for index: int in count:
		var center: float = start + (index + 0.5) * pitch
		var local: Vector2 = Vector2(center, fixed) if axis == &"x" else Vector2(fixed, center)
		_add_fence(parent, local, yaw, width)


func _add_fence(parent: Node3D, local: Vector2, yaw: float, width: float) -> void:
	var target: Target = Catalog.instantiate_model(&"fence", FENCE, FENCE_TEXTURE, Vector3(width, FENCE_HEIGHT, FENCE_DEPTH), true) as Target
	target.name = "Fence%03d" % fence_targets.size()
	target.blocking = true
	target.ground_position = _fence_ground_position
	target.position = Vector3(local.x, _height(local.x, local.y) - FENCE_SINK, local.y)
	target.rotation.y = yaw
	parent.add_child(target)
	fence_targets.append(target)


func _build_farmers() -> void:
	var farmers: Node3D = Node3D.new()
	farmers.name = "Farmers"
	add_child(farmers)
	var detection_radius: float = minf(footprint_size.x, footprint_size.y) / 3.0
	var homes: Array[float] = [-footprint_size.y * FARMER_HOME_OFFSET, footprint_size.y * FARMER_HOME_OFFSET]
	for index: int in homes.size():
		var home: Vector2 = Vector2(0.0, homes[index])
		var farmer: CharacterBody3D = FARMER.instantiate() as CharacterBody3D
		farmer.name = "Farmer%d" % (index + 1)
		farmer.position = Vector3(home.x, _height(home.x, home.y) + FARMER_SPAWN_LIFT, home.y)
		farmers.add_child(farmer)
		farmer.call(&"configure_field", self, footprint(), detection_radius)
		_farmers.append(farmer)


func _height(x: float, z: float) -> float:
	var region_local: Vector3 = _region.to_local(to_global(Vector3(x, 0.0, z)))
	return float(_region.call(&"ground_height", region_local.x, region_local.z))


func _wheat_ground_height(x: float, z: float) -> float:
	return _height(x, z)


func _fence_ground_position(world_point: Vector3) -> Vector3:
	var local_point: Vector3 = to_local(world_point)
	local_point.y = _height(local_point.x, local_point.z)
	return to_global(local_point)
