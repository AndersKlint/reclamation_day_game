extends Node3D

signal completed()
signal endurance_changed(fraction: float)
signal status_changed(text: String)
signal fence_life_absorbed(amount: float)

const WheatPatch = preload("res://game/demo/farmer_combat/wheat_patch.gd")
const FarmFence = preload("res://game/demo/farm_opening/farm_fence.gd")
const FARMER: PackedScene = preload("res://game/demo/farmer_combat/farmer.tscn")
const FENCE: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/fences/fence1_01.fbx")
const GATE: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/fences/fence1_double_gate.fbx")
const FENCE_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/textures/textures2.png")
const WorldModel = preload("res://game/world/world_model.gd")
const FIELD_SIZE: Vector2 = Vector2(80.0, 80.0)
const FENCE_HALF: float = 48.0
const GATE_HALF: float = 8.0
const FARMER_DELAY: float = 30.0
const WHEAT_LIFE: float = 680.0

var is_completed: bool = false
var initial_wheat_capacity: float = 0.0
var initial_fence_capacity: float = 0.0
var _fences: Array[FarmFence] = []
var wheat: WheatPatch
var _ground_height: Callable
var _player: CharacterBody3D
var _farmer: CharacterBody3D
var _gate: Node3D
var _remains: Node3D
var _active: bool = false
var _elapsed: float = 0.0
var _farmer_spawned: bool = false
var _farmer_consumed: bool = false


func prepare(terrain_height: Callable) -> void:
	_ground_height = terrain_height


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	assert(_ground_height.is_valid(), "Farm opening requires local terrain heights before entering the tree")
	wheat = WheatPatch.new()
	wheat.name = "Wheat"
	wheat.field_size = FIELD_SIZE
	wheat.visual_height = 1.8
	wheat.total_life_capacity = WHEAT_LIFE
	wheat.drain_efficiency = 1.0 / 3.0
	wheat.ground_height = _ground_height
	add_child(wheat)
	initial_wheat_capacity = wheat.initial_capacity
	_remains = Node3D.new()
	_remains.name = "Remains"
	add_child(_remains)
	_build_enclosure()


func configure(player: CharacterBody3D) -> void:
	_player = player


func start() -> void:
	if is_completed or not is_instance_valid(_player):
		return
	_active = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)
	if is_instance_valid(_farmer):
		_farmer.configure(_player, _remains)
	status_changed.emit("Drain the wheat to grow. The northern gate is locked." if not _farmer_spawned else "Drain the farmer to open the northern gate.")


func stop() -> void:
	_active = false
	set_process(false)
	if is_instance_valid(_farmer):
		_farmer.stop()
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if not _active or is_completed or not is_instance_valid(_player):
		return
	if not bool(_player.get(&"gameplay_enabled")) or float(_player.get(&"health")) <= 0.0:
		return
	if _farmer_consumed:
		_open_gate()
		return
	if not _farmer_spawned:
		_elapsed += maxf(delta, 0.0)
		if _elapsed >= FARMER_DELAY:
			_spawn_farmer()


func _spawn_farmer() -> void:
	_farmer_spawned = true
	_farmer = FARMER.instantiate() as CharacterBody3D
	_farmer.name = "Farmer"
	var player_local: Vector3 = to_local(_player.global_position)
	var spawn_z: float = -34.0 if player_local.z >= 0.0 else 34.0
	_farmer.position = Vector3(0.0, _height(0.0, spawn_z) + 0.05, spawn_z)
	_farmer.defeated.connect(_on_farmer_defeated)
	_farmer.consumed.connect(_on_farmer_consumed)
	_farmer.endurance_changed.connect(_on_endurance_changed)
	add_child(_farmer)
	var matching_size: float = _farmer.get_model_height() / _player.get_reference_model_height()
	_farmer.set_minimum_player_volume(float(_player.get(&"base_volume")) * pow(matching_size, 3.0))
	_farmer.configure(_player, _remains)
	status_changed.emit("The farmer has arrived. Drain wheat until you can drain him.")


func _on_endurance_changed(fraction: float) -> void:
	endurance_changed.emit(fraction)


func _on_farmer_defeated() -> void:
	status_changed.emit("Absorb the farmer's remaining life to unlock the gate.")


func _on_farmer_consumed() -> void:
	_farmer_consumed = true


func _open_gate() -> void:
	if is_completed:
		return
	is_completed = true
	_active = false
	_gate.queue_free()
	for fence: FarmFence in _fences:
		fence.unlock()
	set_process(false)
	status_changed.emit("The northern gate is open. Follow the lane to the village.")
	completed.emit()


func _height(x: float, z: float) -> float:
	return float(_ground_height.call(x, z))


func _build_enclosure() -> void:
	var enclosure: Node3D = Node3D.new()
	enclosure.name = "Enclosure"
	add_child(enclosure)
	for coordinate: int in range(-48, 48, 4):
		var center: float = coordinate + 2.0
		_fence_segment(enclosure, Vector2(center, FENCE_HALF), 4.0, false)
		_fence_segment(enclosure, Vector2(-FENCE_HALF, center), 4.0, true)
		_fence_segment(enclosure, Vector2(FENCE_HALF, center), 4.0, true)
		if absf(center) > GATE_HALF:
			_fence_segment(enclosure, Vector2(center, -FENCE_HALF), 4.0, false)
	_gate = Node3D.new()
	_gate.name = "NorthernGate"
	enclosure.add_child(_gate)
	_fence_segment(_gate, Vector2(0.0, -FENCE_HALF), GATE_HALF * 2.0, false, GATE)


func _fence_segment(parent: Node3D, center: Vector2, width: float, sideways: bool, scene: PackedScene = FENCE) -> void:
	if scene == FENCE:
		var fence: FarmFence = FarmFence.new()
		fence.name = "Fence%02d" % _fences.size()
		fence.position = Vector3(center.x, _height(center.x, center.y) - 0.15, center.y)
		fence.rotation.y = PI * 0.5 if sideways else 0.0
		fence.dimensions = Vector3(width + 0.1, 4.0, 0.45)
		fence.model_scene = scene
		fence.texture = FENCE_TEXTURE
		fence.ground_position = _fence_ground_position
		fence.life_absorbed.connect(_on_fence_life_absorbed)
		parent.add_child(fence)
		_fences.append(fence)
		initial_fence_capacity += fence.initial_capacity
		return
	var anchor: Node3D = Node3D.new()
	anchor.position = Vector3(center.x, _height(center.x, center.y) - 0.15, center.y)
	anchor.rotation.y = PI * 0.5 if sideways else 0.0
	parent.add_child(anchor)
	var model: Node3D = WorldModel.add_fitted(scene, anchor, Vector3(width + 0.1, 4.0, 0.45))
	WorldModel.bind_texture(model, FENCE_TEXTURE)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "UndrainableBarrier"
	body.collision_layer = 1
	body.collision_mask = 6
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	# Extra vertical coverage prevents grown capsules from stepping over the enclosure.
	shape.size = Vector3(width + 0.15, 16.0, 0.6)
	collision.shape = shape
	collision.position.y = 6.0
	body.add_child(collision)
	anchor.add_child(body)


func _fence_ground_position(world_point: Vector3) -> Vector3:
	var local_point: Vector3 = to_local(world_point)
	local_point.y = _height(local_point.x, local_point.z)
	return to_global(local_point)


func _on_fence_life_absorbed(amount: float) -> void:
	fence_life_absorbed.emit(amount)
