extends Node

const PhaseController = preload("res://game/balancer/phase_controller.gd")
const BURST_SCENE: PackedScene = preload("res://game/upgrades/shockwave/shockwave_burst.tscn")

class ActiveShockwave:
	var effect: ShockwaveEffect
	var remaining: float

	func _init(configuration: ShockwaveEffect) -> void:
		effect = configuration
		remaining = configuration.interval_seconds

var _balancer: CharacterBody3D
var _world: Node3D
var _ground_position: Callable
var _phase: PhaseController
var _active: Array[ActiveShockwave] = []


func _ready() -> void:
	set_process(false)


func configure(balancer: CharacterBody3D, world: Node3D, ground_position: Callable) -> void:
	if _phase != null and _phase.phase_completed.is_connected(_on_phase_completed):
		_phase.phase_completed.disconnect(_on_phase_completed)
	_balancer = balancer
	_world = world
	_ground_position = ground_position
	_phase = balancer.phase_controller
	if _phase != null:
		_phase.phase_completed.connect(_on_phase_completed)


func grant(effect: ShockwaveEffect) -> void:
	if effect == null or not effect.is_valid():
		return
	_active.append(ActiveShockwave.new(effect))
	if effect.trigger == ShockwaveEffect.Trigger.PERIODIC:
		set_process(true)


func _process(delta: float) -> void:
	if not _can_activate():
		return
	for active: ActiveShockwave in _active:
		if active.effect.trigger != ShockwaveEffect.Trigger.PERIODIC:
			continue
		active.remaining -= delta
		if active.remaining <= 0.0:
			active.remaining += active.effect.interval_seconds
			_emit_shockwave(active.effect)


func _on_phase_completed() -> void:
	if not _can_activate():
		return
	for active: ActiveShockwave in _active:
		if active.effect.trigger == ShockwaveEffect.Trigger.PHASE_COMPLETED:
			_emit_shockwave(active.effect)


func _can_activate() -> bool:
	return is_instance_valid(_balancer) and is_instance_valid(_world) \
		and _balancer.gameplay_enabled and _balancer.health > 0.0 and not get_tree().paused


func _emit_shockwave(effect: ShockwaveEffect) -> void:
	if not _can_activate() or not effect.is_valid():
		return
	var radius: float = _balancer.effective_drain_reach * effect.radius_multiplier
	if not is_finite(radius) or radius <= 0.0:
		return
	var origin: Vector3 = _balancer.global_position
	if _ground_position.is_valid():
		origin = _ground_position.call(origin)
	if not origin.is_finite():
		return
	var radius_squared: float = radius * radius
	var buildings: Array[Node3D] = []
	var enemies: Array[Node3D] = []
	# Rewards can grow drain reach, so every recipient is fixed before dispatch.
	if effect.topple_buildings:
		for candidate: Node in get_tree().get_nodes_in_group(&"shockwave_buildings"):
			if not candidate is Node3D or candidate.is_queued_for_deletion():
				continue
			var bounds: AABB = candidate.call(&"get_shockwave_bounds")
			var closest: Vector3 = origin.clamp(bounds.position, bounds.end)
			if origin.distance_squared_to(closest) <= radius_squared:
				buildings.append(candidate)
	if effect.stun_seconds > 0.0:
		for candidate: Node in get_tree().get_nodes_in_group(&"shockwave_enemies"):
			if candidate is Node3D and not candidate.is_queued_for_deletion():
				if origin.distance_squared_to(candidate.global_position) <= radius_squared:
					enemies.append(candidate)
	for building: Node3D in buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			building.call(&"topple_from_shockwave", _balancer)
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.call(&"apply_stun", effect.stun_seconds)
	var burst: Node3D = BURST_SCENE.instantiate() as Node3D
	_world.add_child(burst)
	burst.global_position = origin
	burst.call(&"play", radius)
