extends Node

const PhaseController = preload("res://game/balancer/phase_controller.gd")
const BURST_SCENE: PackedScene = preload("res://game/upgrades/shockwave/shockwave_burst.tscn")
const SOUL_BURST_SCENE: PackedScene = preload("res://game/upgrades/soul_burst/soul_burst.tscn")

class ActiveShockwave:
	var effect: ShockwaveEffect
	var remaining: float
	var accumulated_seconds: float
	var cooldown_remaining: float = 0.0

	func _init(configuration: ShockwaveEffect) -> void:
		effect = configuration
		remaining = configuration.interval_seconds
		accumulated_seconds = configuration.drain_seconds

class PendingShockwave:
	var active: ActiveShockwave
	var origin: Vector3
	var remaining: float

	func _init(shockwave: ActiveShockwave, landing_position: Vector3) -> void:
		active = shockwave
		origin = landing_position
		remaining = shockwave.effect.delay_seconds

var _balancer: CharacterBody3D
var _world: Node3D
var _ground_position: Callable
var _phase: PhaseController
var _active: Array[ActiveShockwave] = []
var _pending: Array[PendingShockwave] = []


func _ready() -> void:
	set_process(false)


func configure(balancer: CharacterBody3D, world: Node3D, ground_position: Callable) -> void:
	_clear_pending()
	if is_instance_valid(_balancer) and _balancer.died.is_connected(_clear_pending):
		_balancer.died.disconnect(_clear_pending)
	if _phase != null and _phase.phase_completed.is_connected(_on_phase_completed):
		_phase.phase_completed.disconnect(_on_phase_completed)
	_balancer = balancer
	_balancer.died.connect(_clear_pending)
	_world = world
	_ground_position = ground_position
	_phase = balancer.phase_controller
	if _phase != null:
		_phase.phase_completed.connect(_on_phase_completed)


func grant(effect: ShockwaveEffect) -> void:
	if effect == null or not effect.is_valid():
		return
	if effect.stacking_key != &"":
		for active: ActiveShockwave in _active:
			if active.effect.stacking_key == effect.stacking_key:
				active.accumulated_seconds += effect.drain_seconds
				return
	_active.append(ActiveShockwave.new(effect))
	if effect.trigger == ShockwaveEffect.Trigger.PERIODIC or effect.cooldown_seconds > 0.0:
		set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_balancer) or not is_instance_valid(_world) or _balancer.health <= 0.0:
		_clear_pending()
		return
	if not _can_activate():
		return
	for index: int in range(_pending.size() - 1, -1, -1):
		var pending: PendingShockwave = _pending[index]
		pending.remaining -= delta
		if pending.remaining <= 0.0:
			_pending.remove_at(index)
			_emit_shockwave(pending.active, pending.origin)
	for active: ActiveShockwave in _active:
		active.cooldown_remaining = maxf(0.0, active.cooldown_remaining - delta)
		if active.effect.trigger != ShockwaveEffect.Trigger.PERIODIC:
			continue
		active.remaining -= delta
		if active.remaining <= 0.0:
			active.remaining += active.effect.interval_seconds
			_trigger_shockwave(active)
	_refresh_processing()


func _on_phase_completed() -> void:
	if not _can_activate():
		return
	for active: ActiveShockwave in _active:
		if active.effect.trigger == ShockwaveEffect.Trigger.PHASE_COMPLETED:
			_trigger_shockwave(active)


func _trigger_shockwave(active: ActiveShockwave) -> void:
	var origin: Vector3 = _balancer.global_position
	if _ground_position.is_valid():
		origin = _ground_position.call(origin)
	if not origin.is_finite():
		return
	if active.effect.delay_seconds > 0.0:
		_pending.append(PendingShockwave.new(active, origin))
		set_process(true)
	else:
		_emit_shockwave(active, origin)


func _clear_pending() -> void:
	_pending.clear()
	_refresh_processing()


func _refresh_processing() -> void:
	for active: ActiveShockwave in _active:
		if active.effect.trigger == ShockwaveEffect.Trigger.PERIODIC or active.effect.cooldown_seconds > 0.0:
			set_process(true)
			return
	set_process(not _pending.is_empty())


func _can_activate() -> bool:
	return is_instance_valid(_balancer) and is_instance_valid(_world) \
		and _balancer.gameplay_enabled and _balancer.health > 0.0 and not get_tree().paused


func _emit_shockwave(active: ActiveShockwave, origin: Vector3) -> void:
	var effect: ShockwaveEffect = active.effect
	if not _can_activate() or not effect.is_valid() or active.cooldown_remaining > 0.0:
		return
	if _balancer.life < effect.life_cost:
		return
	var radius: float = _balancer.effective_drain_reach * effect.radius_multiplier
	if not is_finite(radius) or radius <= 0.0:
		return
	if not origin.is_finite():
		return
	var radius_squared: float = radius * radius
	var source_volume: float = _balancer.volume
	var requested_drain: float = _balancer.effective_drain_rate * active.accumulated_seconds
	var buildings: Array[Node3D] = []
	var enemies: Array[Node3D] = []
	# Costs and rewards change size, so snapshot recipients and drain power before either.
	if effect.topple_buildings:
		for candidate: Node in get_tree().get_nodes_in_group(&"shockwave_buildings"):
			if not candidate is Node3D or candidate.is_queued_for_deletion():
				continue
			var bounds: AABB = candidate.call(&"get_shockwave_bounds")
			var closest: Vector3 = origin.clamp(bounds.position, bounds.end)
			if origin.distance_squared_to(closest) <= radius_squared:
				buildings.append(candidate)
	if effect.stun_seconds > 0.0 or active.accumulated_seconds > 0.0:
		for candidate: Node in get_tree().get_nodes_in_group(&"shockwave_enemies"):
			if candidate is Node3D and not candidate.is_queued_for_deletion():
				if origin.distance_squared_to(candidate.global_position) <= radius_squared:
					enemies.append(candidate)
	active.cooldown_remaining = effect.cooldown_seconds
	if effect.life_cost > 0.0:
		_balancer.adjust_life(-effect.life_cost)
	for building: Node3D in buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			building.call(&"topple_from_shockwave", _balancer)
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if effect.stun_seconds > 0.0:
				enemy.call(&"apply_stun", effect.stun_seconds)
			if requested_drain > 0.0 and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				enemy.call(&"receive_drain_burst", requested_drain, source_volume, _balancer)
	var burst_scene: PackedScene = SOUL_BURST_SCENE if effect.presentation == ShockwaveEffect.Presentation.SOUL_BURST else BURST_SCENE
	var burst: Node3D = burst_scene.instantiate() as Node3D
	_world.add_child(burst)
	burst.global_position = origin
	burst.call(&"play", radius)
