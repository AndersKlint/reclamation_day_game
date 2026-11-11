extends RefCounted

const CityLayout = preload("res://game/demo/city/city_layout.gd")

var _graph: AStar3D = AStar3D.new()
var _edges: Array[Vector2i] = []
var _region: Node3D
var aggro_radius: float

func configure(region: Node3D) -> void:
	_region = region
	var roads: Array[Rect2] = CityLayout.road_rects()
	var bounds: Rect2 = roads[0]
	for road: Rect2 in roads:
		bounds = bounds.merge(road)
	aggro_radius = bounds.size.length() / 6.0
	var width: int = CityLayout.X_STREETS.size()
	var depth: int = CityLayout.Z_STREETS.size()
	for iz: int in depth:
		for ix: int in width:
			var id: int = iz * width + ix
			_graph.add_point(id, Vector3(CityLayout.X_STREETS[ix], 0.0, CityLayout.Z_STREETS[iz]))
			if ix > 0:
				_connect(id - 1, id)
			if iz > 0:
				_connect(id - width, id)
	for ix: int in width:
		_add_end(ix, Vector3(CityLayout.X_STREETS[ix], 0.0, bounds.end.y))
		_add_end((depth - 1) * width + ix, Vector3(CityLayout.X_STREETS[ix], 0.0, bounds.position.y))
	for iz: int in depth:
		_add_end(iz * width, Vector3(bounds.position.x, 0.0, CityLayout.Z_STREETS[iz]))
		_add_end(iz * width + width - 1, Vector3(bounds.end.x, 0.0, CityLayout.Z_STREETS[iz]))

func path_to(position: Vector3, target: Vector3, visible: Callable, accessible: Callable) -> PackedVector3Array:
	var local_start: Vector3 = _region.to_local(position)
	local_start.y = 0.0
	var local_target: Vector3 = _region.to_local(target)
	local_target.y = 0.0
	var start_edge: Vector2i = _edges[0]
	var start: Vector3
	var nearest: float = INF
	for edge: Vector2i in _edges:
		var point: Vector3 = _project(local_start, edge)
		var distance: float = local_start.distance_squared_to(point)
		if distance < nearest and (distance <= 4.0 or bool(accessible.call(_world_point(point)))):
			nearest = distance
			start = point
			start_edge = edge
	if not is_finite(nearest):
		return PackedVector3Array()
	var start_id: int = _graph.get_available_point_id()
	_graph.add_point(start_id, start)
	_graph.connect_points(start_id, start_edge.x)
	_graph.connect_points(start_id, start_edge.y)
	var best: PackedVector3Array = PackedVector3Array()
	var best_score: float = INF
	for edge: Vector2i in _edges:
		var goal: Vector3 = _project(local_target, edge)
		var goal_id: int = _graph.get_available_point_id()
		_graph.add_point(goal_id, goal)
		_graph.connect_points(goal_id, edge.x)
		_graph.connect_points(goal_id, edge.y)
		if edge == start_edge:
			_graph.connect_points(start_id, goal_id)
		var path: PackedVector3Array = _graph.get_point_path(start_id, goal_id)
		var travel: float = 0.0
		for index: int in range(1, path.size()):
			travel += path[index - 1].distance_to(path[index])
		var world_goal: Vector3 = _world_point(goal)
		var proximity_weight: float = 1.0 if visible.is_valid() else 1000.0
		var score: float = goal.distance_to(local_target) * proximity_weight + travel * 0.2
		if visible.is_valid() and not bool(visible.call(world_goal, target)):
			score += aggro_radius * 2.0
		if score < best_score:
			best_score = score
			best = path
		_graph.remove_point(goal_id)
	_graph.remove_point(start_id)
	for index: int in best.size():
		best[index] = _world_point(best[index])
	return best

func _world_point(point: Vector3) -> Vector3:
	return _region.call("ground_position", _region.to_global(point)) as Vector3

func _project(point: Vector3, edge: Vector2i) -> Vector3:
	return Geometry3D.get_closest_point_to_segment(point, _graph.get_point_position(edge.x), _graph.get_point_position(edge.y))

func _add_end(neighbor: int, point: Vector3) -> void:
	var id: int = _graph.get_available_point_id()
	_graph.add_point(id, point)
	_connect(neighbor, id)

func _connect(a: int, b: int) -> void:
	_graph.connect_points(a, b)
	_edges.append(Vector2i(a, b))
