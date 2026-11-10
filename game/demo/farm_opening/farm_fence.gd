extends Node3D

signal life_absorbed(amount: float)

const Drainable = preload("res://game/draining/drainable.gd")
const DepletionEffect = preload("res://game/draining/depletion_effect.gd")
const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const WorldModel = preload("res://game/world/world_model.gd")

class FenceDrainable extends Drainable:
	var unlocked: bool = false

	func can_drain(source_volume: float) -> bool:
		return unlocked and super.can_drain(source_volume)

var dimensions: Vector3
var model_scene: PackedScene
var texture: Texture2D
var ground_position: Callable
var initial_capacity: float = 0.0
var _drainable: FenceDrainable
var _effect: DepletionEffect
var _barrier: CollisionShape3D


func _ready() -> void:
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model: Node3D = WorldModel.add_fitted(model_scene, visual, dimensions)
	WorldModel.bind_texture(model, texture)
	_drainable = FenceDrainable.new()
	_drainable.name = "Drainable"
	_drainable.collision_layer = 0
	_drainable.collision_mask = 0
	_drainable.monitoring = false
	add_child(_drainable)
	_drainable.configure_volume(dimensions)
	initial_capacity = _drainable.capacity
	_drainable.emission_offset = Vector3(0.0, dimensions.y * 0.55, 0.0)
	_drainable.emission_radius = maxf(0.25, minf(dimensions.x, dimensions.z) * 0.45)
	var drain_collision: CollisionShape3D = CollisionShape3D.new()
	var drain_shape: BoxShape3D = BoxShape3D.new()
	drain_shape.size = dimensions + Vector3(0.3, 0.1, 0.3)
	drain_collision.shape = drain_shape
	drain_collision.position.y = dimensions.y * 0.5
	_drainable.add_child(drain_collision)
	_drainable.drained.connect(_on_life_absorbed)
	_drainable.collapsed.connect(_on_collapsed)
	_effect = DEPLETION_EFFECT.instantiate() as DepletionEffect
	_effect.name = "DepletionEffect"
	_effect.style = DepletionEffect.Style.WOODEN
	add_child(_effect)
	_effect.configure(visual, dimensions, ground_position)
	_effect.life_absorbed.connect(_on_life_absorbed)
	_effect.flattened.connect(_clear_collision, CONNECT_ONE_SHOT)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Barrier"
	body.collision_layer = 1
	body.collision_mask = 6
	_barrier = CollisionShape3D.new()
	var barrier_shape: BoxShape3D = BoxShape3D.new()
	# Extra vertical coverage prevents grown capsules from stepping over the enclosure.
	barrier_shape.size = Vector3(dimensions.x + 0.05, 16.0, 0.6)
	_barrier.shape = barrier_shape
	_barrier.position.y = 6.0
	body.add_child(_barrier)
	add_child(body)


func unlock() -> void:
	if _drainable.unlocked:
		return
	_drainable.unlocked = true
	_drainable.set_deferred(&"collision_layer", 8)


func _on_life_absorbed(amount: float) -> void:
	life_absorbed.emit(amount)


func _on_collapsed() -> void:
	_start_depletion.call_deferred()


func _start_depletion() -> void:
	_effect.configure_reward(_drainable.take_collapse_life(), _drainable.collector)
	_effect.start()


func _clear_collision() -> void:
	_barrier.set_deferred(&"disabled", true)
