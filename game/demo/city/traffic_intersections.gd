extends RefCounted

const CityLayout = preload("res://game/demo/city/city_layout.gd")
const REQUEST_DISTANCE: float = 12.0
const ADMISSION_DISTANCE: float = 1.5
const STOP_MARGIN: float = 0.6
const STALE_FRAMES: int = 2
const EXIT_CLEARANCE: float = 12.0
const LANE_CLEARANCE: float = 2.8
const GREEN_SECONDS: float = 10.0
const ALL_RED_SECONDS: float = 10.0

enum Phase { NORTH_SOUTH, ALL_RED_TO_EAST_WEST, EAST_WEST, ALL_RED_TO_NORTH_SOUTH }

class TrafficCar:
	var car: WeakRef
	var car_id: int
	var body: WeakRef
	var route: PackedVector3Array
	var position: Vector2
	var extent: Vector2
	var axis: Vector2
	var collidable: bool = false
	var clearing: WeakRef

class Request:
	var car: WeakRef
	var car_id: int
	var frame: int
	var clearance: float
	var extent: Vector2
	var north_south: bool
	var checked_frame: int = -1
	var can_enter: bool = false

class Junction:
	var center: Vector2
	var occupants: Array[TrafficCar] = []
	var owner: WeakRef
	var owner_entered: bool = false
	var owner_extent: Vector2
	var phase: Phase = Phase.NORTH_SOUTH
	var phase_time: float = 0.0
	var queue: Array[Request] = []

var _region: Node3D
var _junctions: Array[Junction] = []
var _cars: Array[TrafficCar] = []
var _car_routes: Dictionary = {}
var _pending: Dictionary = {}
var _inverse: Transform3D
var _extent_scale: Vector2

func configure(region: Node3D) -> void:
	_region = region
	_inverse = region.global_transform.affine_inverse()
	var basis: Basis = _inverse.basis
	_extent_scale = Vector2(
		Vector3(basis.x.x, basis.y.x, basis.z.x).length(),
		Vector3(basis.x.z, basis.y.z, basis.z.z).length()
	)
	_junctions.clear()
	_cars.clear()
	_car_routes.clear()
	_pending.clear()
	for x: float in CityLayout.X_STREETS:
		for z: float in CityLayout.Z_STREETS:
			var junction: Junction = Junction.new()
			junction.center = Vector2(x, z)
			_junctions.append(junction)

func register(car: Node3D, route: PackedVector3Array) -> void:
	var entry: TrafficCar = TrafficCar.new()
	entry.car = weakref(car)
	entry.car_id = car.get_instance_id()
	var body: CollisionObject3D = car.get_node_or_null("Body") as CollisionObject3D
	if body != null:
		entry.body = weakref(body)
	for point: Vector3 in route:
		entry.route.append(_inverse * point)
	_cars.append(entry)
	_car_routes[car.get_instance_id()] = entry

func tick(delta: float) -> void:
	if not is_instance_valid(_region):
		return
	for junction: Junction in _junctions:
		junction.occupants.clear()
	for i: int in range(_cars.size() - 1, -1, -1):
		var entry: TrafficCar = _cars[i]
		var car: Node3D = entry.car.get_ref() as Node3D
		if not is_instance_valid(car):
			_car_routes.erase(entry.car_id)
			_cars.remove_at(i)
		elif bool(car.call(&"_is_depleted")) and not _car_collidable(entry):
			_car_routes.erase(car.get_instance_id())
			_cars.remove_at(i)
		else:
			entry.collidable = _car_collidable(entry)
			if not entry.collidable:
				continue
			var local: Transform3D = _inverse * car.global_transform
			entry.position = Vector2(local.origin.x, local.origin.z)
			entry.axis = Vector2(-local.basis.z.x, -local.basis.z.z).normalized()
			var size: Vector3 = car.get(&"fitted_size")
			entry.extent = Vector2(
				absf(local.basis.x.x) * size.x + absf(local.basis.y.x) * size.y + absf(local.basis.z.x) * size.z,
				absf(local.basis.x.z) * size.x + absf(local.basis.y.z) * size.y + absf(local.basis.z.z) * size.z
			) * 0.5
			for junction: Junction in _junctions:
				if _inside(entry.position - junction.center, Vector2.ONE * CityLayout.ROAD_HALF + entry.extent):
					junction.occupants.append(entry)
	var frame: int = Engine.get_physics_frames()
	for junction: Junction in _junctions:
		_update_owner(junction)
		_prune_queue(junction, frame)
		junction.phase_time += maxf(delta, 0.0)
		match junction.phase:
			Phase.NORTH_SOUTH:
				if junction.phase_time >= GREEN_SECONDS:
					junction.phase = Phase.ALL_RED_TO_EAST_WEST
					junction.phase_time = 0.0
			Phase.EAST_WEST:
				if junction.phase_time >= GREEN_SECONDS:
					junction.phase = Phase.ALL_RED_TO_NORTH_SOUTH
					junction.phase_time = 0.0
			Phase.ALL_RED_TO_EAST_WEST, Phase.ALL_RED_TO_NORTH_SOUTH:
				if junction.phase_time >= ALL_RED_SECONDS and junction.owner == null and _junction_clear(junction, null):
					junction.phase = Phase.EAST_WEST if junction.phase == Phase.ALL_RED_TO_EAST_WEST else Phase.NORTH_SOUTH
					junction.phase_time = 0.0

func speed_limit(car: Node3D, forward: Vector3, front_extent: float, brake: float) -> float:
	if not is_instance_valid(_region) or not is_instance_valid(car):
		return INF
	var direction: Vector3 = forward.normalized()
	if direction.is_zero_approx():
		return INF
	var inverse: Basis = _inverse.basis
	var local_direction: Vector3 = inverse * direction
	var local_position: Vector3 = _inverse * car.global_position
	var position: Vector2 = Vector2(local_position.x, local_position.z)
	var ray: Vector2 = Vector2(local_direction.x, local_direction.z)
	var radius: float = maxf(front_extent, 0.0) * sqrt(2.0)
	var extent: Vector2 = _extent_scale * radius + Vector2.ONE * CityLayout.ROAD_HALF
	var frame: int = Engine.get_physics_frames()
	var nearest: Junction = null
	var nearest_distance: float = INF
	var entry: TrafficCar = _car_routes.get(car.get_instance_id())
	if entry != null and entry.clearing != null:
		var clearing: Junction = entry.clearing.get_ref() as Junction
		# The stop-line envelope extends beyond the physical junction and must clear too.
		if clearing != null and _inside(position - clearing.center, extent):
			_remove_requests(car, null)
			return INF
		entry.clearing = null
	for junction: Junction in _junctions:
		if entry != null and _inside(position - junction.center, Vector2.ONE * CityLayout.ROAD_HALF + entry.extent):
			entry.clearing = weakref(junction)
			_remove_requests(car, null)
			return INF
		if junction.owner != null and junction.owner.get_ref() == car:
			continue
		var distance: float = _entry_distance(position - junction.center, ray, extent)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = junction
	if nearest == null or nearest_distance > REQUEST_DISTANCE + STOP_MARGIN:
		_remove_requests(car, null)
		return INF
	_remove_requests(car, nearest)
	var clearance: float = maxf(0.0, nearest_distance - STOP_MARGIN)
	_prune_queue(nearest, frame)
	var request: Request = null
	for candidate: Request in nearest.queue:
		if candidate.car.get_ref() == car:
			request = candidate
			break
	if request == null:
		request = Request.new()
		request.car = weakref(car)
		request.car_id = car.get_instance_id()
		nearest.queue.append(request)
		_pending[car.get_instance_id()] = nearest
	request.frame = frame
	request.clearance = clearance
	request.extent = extent
	request.north_south = absf(ray.y) >= absf(ray.x)
	if nearest.owner == null and (nearest.phase == Phase.NORTH_SOUTH or nearest.phase == Phase.EAST_WEST):
		for candidate: Request in nearest.queue:
			var waiting: Node3D = candidate.car.get_ref() as Node3D
			var green: bool = candidate.north_south == (nearest.phase == Phase.NORTH_SOUTH)
			if not green or candidate.clearance > ADMISSION_DISTANCE or not is_instance_valid(waiting):
				continue
			if candidate.checked_frame != frame:
				candidate.checked_frame = frame
				candidate.can_enter = _can_enter(nearest, waiting, candidate.extent)
			if candidate.can_enter:
				if candidate == request:
					nearest.owner = weakref(car)
					nearest.owner_extent = extent
					nearest.owner_entered = _inside(position - nearest.center, extent)
					nearest.queue.erase(request)
					_pending.erase(car.get_instance_id())
					return INF
				break
	return sqrt(2.0 * maxf(brake, 0.0) * clearance)

func is_clearing(car: Node3D) -> bool:
	var entry: TrafficCar = _car_routes.get(car.get_instance_id())
	return entry != null and entry.clearing != null

func release(car: Node3D) -> void:
	var entry: TrafficCar = _car_routes.get(car.get_instance_id())
	if entry != null:
		entry.clearing = null
	for junction: Junction in _junctions:
		if junction.owner != null and junction.owner.get_ref() == car:
			junction.owner = null
		_remove_from_queue(junction, car)

func clear() -> void:
	for entry: TrafficCar in _cars:
		entry.clearing = null
	for junction: Junction in _junctions:
		junction.owner = null
		junction.queue.clear()
	_pending.clear()

func _update_owner(junction: Junction) -> void:
	if junction.owner == null:
		return
	var car: Node3D = junction.owner.get_ref() as Node3D
	if not is_instance_valid(car) or car.is_queued_for_deletion() or not car.is_inside_tree():
		junction.owner = null
		return
	var entry: TrafficCar = _car_routes.get(car.get_instance_id())
	if entry != null and not _car_collidable(entry):
		junction.owner = null
		return
	var inside_control: bool = entry != null and _inside(entry.position - junction.center, junction.owner_extent)
	if inside_control:
		junction.owner_entered = true
	elif junction.owner_entered and (entry == null or not junction.occupants.has(entry)):
		junction.owner = null

func _prune_queue(junction: Junction, frame: int) -> void:
	for i: int in range(junction.queue.size() - 1, -1, -1):
		var request: Request = junction.queue[i]
		var car: Node3D = request.car.get_ref() as Node3D
		if not is_instance_valid(car) or car.is_queued_for_deletion() or not car.is_inside_tree() or frame - request.frame > STALE_FRAMES:
			_pending.erase(request.car_id)
			junction.queue.remove_at(i)

func _remove_requests(car: Node3D, except: Junction) -> void:
	var junction: Junction = _pending.get(car.get_instance_id())
	if junction != null and junction != except:
		_remove_from_queue(junction, car)

func _remove_from_queue(junction: Junction, car: Node3D) -> void:
	for i: int in range(junction.queue.size() - 1, -1, -1):
		if junction.queue[i].car.get_ref() == car:
			junction.queue.remove_at(i)
			_pending.erase(car.get_instance_id())

func _can_enter(junction: Junction, car: Node3D, extent: Vector2) -> bool:
	if not _junction_clear(junction, car):
		return false
	var exit: Vector2 = Vector2.ZERO
	var axis: Vector2 = Vector2.ZERO
	var entry: TrafficCar = _car_routes.get(car.get_instance_id())
	if entry == null or entry.route.size() < 2:
		return false
	var current: Vector2 = entry.position
	var index: int = int(car.get(&"_route_index"))
	for step: int in entry.route.size() + 1:
		var target_local: Vector3 = entry.route[posmod(index + step, entry.route.size())]
		var target: Vector2 = Vector2(target_local.x, target_local.z)
		var segment: Vector2 = target - current
		var length: float = segment.length()
		if length > 0.001:
			var segment_axis: Vector2 = segment / length
			var bounds_entry: float = _entry_distance(current - junction.center, segment_axis, extent)
			var bounds_exit: float = _exit_distance(current - junction.center, segment_axis, extent)
			if bounds_entry <= length and bounds_exit >= bounds_entry and bounds_exit <= length:
				exit = current + segment_axis * bounds_exit
				axis = segment_axis
				break
		current = target
	if axis.is_zero_approx():
		return false
	for registered: TrafficCar in _cars:
		var other: Node3D = registered.car.get_ref() as Node3D
		if not registered.collidable or not is_instance_valid(other) or other == car:
			continue
		var from_exit: Vector2 = registered.position - exit
		var along: float = from_exit.dot(axis)
		var across: float = absf(from_exit.cross(axis))
		if along >= 0.0 and along < EXIT_CLEARANCE and across < LANE_CLEARANCE and registered.axis.dot(axis) > 0.5:
			return false
	return true

func _car_collidable(entry: TrafficCar) -> bool:
	var car: Node3D = entry.car.get_ref() as Node3D
	if not is_instance_valid(car) or not car.is_inside_tree() or car.is_queued_for_deletion():
		return false
	if entry.body != null:
		var body: CollisionObject3D = entry.body.get_ref() as CollisionObject3D
		if not is_instance_valid(body) or body.collision_layer == 0:
			return false
	return true

func _junction_clear(junction: Junction, except: Node3D) -> bool:
	for entry: TrafficCar in junction.occupants:
		var car: Node3D = entry.car.get_ref() as Node3D
		if is_instance_valid(car) and car != except:
			return false
	return true

func _inside(offset: Vector2, extent: Vector2) -> bool:
	return absf(offset.x) <= extent.x and absf(offset.y) <= extent.y

func _entry_distance(offset: Vector2, direction: Vector2, extent: Vector2) -> float:
	var entry: float = 0.0
	var exit: float = INF
	for axis: int in 2:
		if absf(direction[axis]) < 0.00001:
			if absf(offset[axis]) > extent[axis]:
				return INF
			continue
		var first: float = (-extent[axis] - offset[axis]) / direction[axis]
		var last: float = (extent[axis] - offset[axis]) / direction[axis]
		entry = maxf(entry, minf(first, last))
		exit = minf(exit, maxf(first, last))
	if exit < entry:
		return INF
	return entry

func _exit_distance(offset: Vector2, direction: Vector2, extent: Vector2) -> float:
	var distance: float = INF
	for axis: int in 2:
		if absf(direction[axis]) >= 0.00001:
			var first: float = (-extent[axis] - offset[axis]) / direction[axis]
			var last: float = (extent[axis] - offset[axis]) / direction[axis]
			distance = minf(distance, maxf(first, last))
	return distance
