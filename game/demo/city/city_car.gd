extends "res://game/demo/targets/demo_target.gd"

const CarAssets = preload("res://game/demo/city/car_assets.gd")

const FIT_BOUNDS: Vector3 = Vector3(6.0, 6.0, 4.6)

const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const HUMAN_LAYER: int = 4
const CAR_LAYER: int = 16
const OBSTACLE_MASK: int = WORLD_LAYER | PLAYER_LAYER | HUMAN_LAYER | CAR_LAYER

const CRUISE_SPEED: float = 7.0
const THREAT_SPEED: float = 9.5
const THREAT_ACCELERATION: float = 3.0
const BRAKE: float = 18.0
const ACCELERATION: float = 6.0
const WAYPOINT_RADIUS: float = 1.6
const PROBE_HEIGHT: float = 0.7
const PROBE_MARGIN: float = 0.1
const STOP_MARGIN: float = 0.35
const THREAT_RADIUS: float = 10.0
const TURN_YIELD_DOT: float = 0.94
const CarAudioScript = preload("res://game/demo/city/car_audio.gd")

enum Motion { PARKED, CRUISE, YIELD }

var _route: PackedVector3Array = PackedVector3Array()
var _route_index: int = 0
var _route_started: bool = false
var _active_requested: bool = true
var _car_speed: float = 0.0
var _yield_left: float = 0.0
var _yield_delay: float = 0.3
var _priority: int = 0
var _query_body: Area3D
var _probe_query: PhysicsRayQueryParameters3D
var _player: CharacterBody3D
var _motion: Motion = Motion.PARKED
var _car_audio: Node3D

func configure_car(variant: int, route: PackedVector3Array = PackedVector3Array()) -> void:
	if drainable != null:
		return
	var index: int = CarAssets.normalize(variant)
	_route = route.duplicate()
	name = "CityCar"
	kind = &"city_car"
	model_scene = CarAssets.scene(index)
	texture = CarAssets.texture(index)
	dimensions = FIT_BOUNDS
	model_yaw = PI
	blocking = _route.size() < 2
	configure_drain()
	drainable.drain_speed_multiplier = 2.0

func configure_traffic(player: CharacterBody3D) -> void:
	_player = player

func set_active(enabled: bool) -> void:
	_active_requested = enabled
	var can_move: bool = enabled and not _is_depleted() and _route.size() >= 2
	if is_instance_valid(_car_audio):
		_car_audio.call(&"set_enabled", can_move)
	if _is_depleted() or _route.size() < 2:
		_car_speed = 0.0
		_motion = Motion.PARKED
		set_physics_process(false)
		return
	_motion = Motion.CRUISE if enabled else Motion.PARKED
	if not enabled:
		_car_speed = 0.0
	set_physics_process(enabled)

func _ready() -> void:
	if drainable == null:
		configure_car(0)
	super()
	if visual == null:
		return
	_priority = get_instance_id()
	_yield_delay = 0.3 + float(_priority % 5) * 0.12
	_configure_body()
	_car_audio = CarAudioScript.new()
	_car_audio.name = "CarAudio"
	add_child(_car_audio)
	drainable.collapsed.connect(_on_car_depleted)
	var start_active: bool = _route.size() >= 2 and _active_requested
	_car_audio.call(&"set_enabled", start_active)
	_motion = Motion.CRUISE if start_active else Motion.PARKED
	set_physics_process(start_active)

func _physics_process(delta: float) -> void:
	if _motion == Motion.PARKED or _is_depleted():
		return
	if _route.size() < 2:
		return
	if _player != null and (not is_instance_valid(_player) or not bool(_player.get("gameplay_enabled"))):
		_car_speed = 0.0
		_car_audio.call(&"set_enabled", false)
		return
	_car_audio.call(&"set_enabled", true)
	if not _route_started:
		_start_route()
	_move_along_route(delta)
	_sync_query_body()
	_car_audio.call(&"update_speed", _car_speed, delta)

func _configure_body() -> void:
	var parked_body: StaticBody3D = get_node_or_null("Body") as StaticBody3D
	if parked_body != null:
		parked_body.set_meta(&"city_car", self)
		return
	var area: Area3D = Area3D.new()
	area.name = "Body"
	area.collision_layer = CAR_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = fitted_size
	collision.shape = box
	collision.position.y = fitted_size.y * 0.5
	area.add_child(collision)
	area.set_meta(&"city_car", self)
	add_child(area)
	_query_body = area

func _start_route() -> void:
	_route_started = true
	_car_speed = 0.0
	var count: int = _route.size()
	var nearest_segment: int = 0
	var nearest_distance: float = INF
	for i: int in count:
		var start: Vector3 = _route[i]
		var end: Vector3 = _route[(i + 1) % count]
		var segment: Vector3 = end - start
		segment.y = 0.0
		var offset: Vector3 = global_position - start
		offset.y = 0.0
		var length_squared: float = segment.length_squared()
		var t: float = 0.0
		if length_squared > 0.0001:
			t = clampf(offset.dot(segment) / length_squared, 0.0, 1.0)
		var closest: Vector3 = start + segment * t
		var distance: float = _flat_distance(global_position, closest)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_segment = i
	_route_index = (nearest_segment + 1) % count

func _move_along_route(delta: float) -> void:
	var target: Vector3 = _route[_route_index]
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= WAYPOINT_RADIUS:
		_advance_waypoint()
		target = _route[_route_index]
		offset = target - global_position
		offset.y = 0.0
		distance = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.001 else -global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var desired: float = _desired_speed(delta, direction)
	var rate: float = BRAKE if desired < _car_speed else ACCELERATION
	if desired > _car_speed and _is_player_threat(direction):
		rate = THREAT_ACCELERATION
	_car_speed = move_toward(_car_speed, desired, rate * delta)
	if _car_speed <= 0.01:
		_car_speed = 0.0
		return
	if distance <= 0.001:
		return
	var travel: float = minf(_car_speed * delta, distance)
	var next_position: Vector3 = global_position + direction * travel
	next_position.y = lerpf(global_position.y, target.y, clampf(travel / distance, 0.0, 1.0))
	if ground_position.is_valid():
		next_position = ground_position.call(next_position)
	global_position = next_position
	var yaw: float = atan2(-direction.x, -direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, yaw, minf(1.0, delta * 6.0))

func _advance_waypoint() -> void:
	var count: int = _route.size()
	var current: Vector3 = _route[_route_index]
	var previous: Vector3 = _route[posmod(_route_index - 1, count)]
	var next: Vector3 = _route[(_route_index + 1) % count]
	var incoming: Vector3 = current - previous
	incoming.y = 0.0
	var outgoing: Vector3 = next - current
	outgoing.y = 0.0
	if incoming.length() > 0.01 and outgoing.length() > 0.01:
		if incoming.normalized().dot(outgoing.normalized()) < TURN_YIELD_DOT:
			_yield_left = maxf(_yield_left, _yield_delay)
			_motion = Motion.YIELD
	_route_index = (_route_index + 1) % count

func _desired_speed(delta: float, forward: Vector3) -> float:
	_yield_left = maxf(0.0, _yield_left - delta)
	var obstacle: Dictionary = _probe(forward)
	if not obstacle.is_empty():
		_note_obstacle(obstacle)
		if _is_player_threat(forward):
			_car_audio.call(&"note_obstruction", delta)
		else:
			_car_audio.call(&"clear_obstruction", delta)
		var hit_position: Vector3 = obstacle.get("position", global_position)
		var clearance: float = maxf(0.0, (hit_position - global_position).dot(forward) - _footprint_extent(forward) - STOP_MARGIN)
		var safe_speed: float = sqrt(2.0 * BRAKE * clearance)
		_motion = Motion.YIELD if safe_speed < CRUISE_SPEED else Motion.CRUISE
		return minf(CRUISE_SPEED, safe_speed)
	_car_audio.call(&"clear_obstruction", delta)
	if _yield_left > 0.0:
		_motion = Motion.YIELD
		return 0.0
	if _is_player_threat(forward):
		var combat_target: Vector3 = _player.call("get_combat_target", global_position)
		var to_target: Vector3 = combat_target - global_position
		to_target.y = 0.0
		var distance_to_footprint: float = to_target.length()
		var radius: float = float(_player.call("get_combat_radius"))
		if distance_to_footprint <= radius + FIT_BOUNDS.x * 0.5 + 1.0:
			_motion = Motion.YIELD
			return 0.0
		if distance_to_footprint < THREAT_RADIUS + radius and to_target.dot(forward) <= 0.0:
			_motion = Motion.CRUISE
			return THREAT_SPEED
	_motion = Motion.CRUISE
	return CRUISE_SPEED

func _is_player_threat(forward: Vector3) -> bool:
	if not is_instance_valid(_player) or not _player.has_method(&"get_combat_target") or not _player.has_method(&"get_combat_radius"):
		return false
	var target: Vector3 = _player.call("get_combat_target", global_position)
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	return offset.length() < THREAT_RADIUS + float(_player.call("get_combat_radius"))

func _probe(forward: Vector3) -> Dictionary:
	if _query_body == null:
		return {}
	if _probe_query == null:
		_probe_query = PhysicsRayQueryParameters3D.new()
		_probe_query.collision_mask = OBSTACLE_MASK
		_probe_query.collide_with_areas = true
		_probe_query.exclude = [_query_body.get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3.UP * PROBE_HEIGHT
	var reach: float = clampf(_car_speed * 0.55, 3.0, 6.0) + 1.5
	var lateral: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	lateral.y = 0.0
	if lateral.is_zero_approx():
		lateral = Vector3.RIGHT
	else:
		lateral = lateral.normalized()
	var half_width: float = _footprint_extent(lateral) + PROBE_MARGIN
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for side: float in [-half_width, -half_width * 0.5, 0.0, half_width * 0.5, half_width]:
		var from: Vector3 = origin + lateral * side
		_probe_query.from = from
		_probe_query.to = from + forward * reach
		var hit: Dictionary = space.intersect_ray(_probe_query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit["position"]
			var distance: float = (hit_position - origin).dot(forward)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = hit
	return nearest

func _footprint_extent(direction: Vector3) -> float:
	return (absf(direction.dot(global_basis.x)) * fitted_size.x + absf(direction.dot(global_basis.z)) * fitted_size.z) * 0.5

func _note_obstacle(hit: Dictionary) -> void:
	var collider: Object = hit.get("collider")
	if collider is Node and (collider as Node).has_meta(&"city_car"):
		var other: Node = (collider as Node).get_meta(&"city_car") as Node
		if is_instance_valid(other) and other != self:
			_yield_left = maxf(_yield_left, 0.35 if _priority < other.get_instance_id() else 0.85)
			return
	_yield_left = maxf(_yield_left, 0.25)

func _sync_query_body() -> void:
	if _query_body != null:
		_query_body.global_transform = global_transform

func _on_car_depleted() -> void:
	_car_speed = 0.0
	_motion = Motion.PARKED
	_car_audio.call(&"set_enabled", false)
	set_physics_process(false)

func _clear_collision() -> void:
	super()
	if is_instance_valid(_query_body):
		_query_body.set_deferred(&"collision_layer", 0)
		var collision: CollisionShape3D = _query_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.set_deferred(&"disabled", true)

func _is_depleted() -> bool:
	return drainable != null and drainable.is_collapsed

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
