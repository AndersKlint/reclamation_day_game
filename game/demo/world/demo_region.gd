extends Node3D

signal progress_changed(drained: float, initial: float)
signal navigation_became_ready()

const Catalog = preload("res://game/demo/targets/demo_asset_catalog.gd")
const Dressing = preload("res://game/demo/world/region_dressing.gd")
const Forest = preload("res://game/demo/world/forest_assets.gd")
const GROUND = preload("res://available-assets/retro3d-assets/Buildings/Abandoned House/Textures/groundgrass.png")
const GRASS = preload("res://available-assets/retro3d-assets/Nature/Materials/grass_bush_1.png")
const STEP: float = 2.0
const BUILDINGS: Array[Vector3] = [
	Vector3(-43, 0, 16), Vector3(42, 0, 4),
	Vector3(-27, 0, -32), Vector3(28, 0, -35),
	Vector3(-65, 0, -42), Vector3(66, 0, -44),
	Vector3(-29, 0, -73), Vector3(30, 0, -74),
	Vector3(-72, 0, -86), Vector3(73, 0, -86),
	Vector3(-28, 0, -116), Vector3(30, 0, -114),
	Vector3(-68, 0, -130), Vector3(69, 0, -133),
	Vector3(-27, 0, -140), Vector3(29, 0, -140),
	Vector3(-65, 0, -3), Vector3(68, 0, -5),
	Vector3(-61, 0, -72), Vector3(66, 0, -72),
	Vector3(-112, 0, -38), Vector3(113, 0, -38),
	Vector3(-112, 0, -125), Vector3(113, 0, -125),
]

var initial_capacity: float = 0.0
var drained_capacity: float = 0.0
var navigation_ready: bool = false
var _targets: Array[Node3D] = []
var _spawn_points: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _navigation: NavigationRegion3D
var _landscape: Node3D
var _decoration: Node3D
var _target_root: Node3D
var _spawn_root: Node3D
var _grass_material: StandardMaterial3D
var _renew_tween: Tween

func _ready() -> void:
	_rng.seed = 30102026
	_landscape = _container("Landscape")
	_decoration = _container("Decoration")
	_target_root = _container("Targets")
	_spawn_root = _container("SpawnPoints")
	_build_terrain()
	_build_roads()
	_build_settlement()
	_build_resources()
	_build_margins()
	_build_spawns()
	_build_grass()
	Forest.populate(self, _decoration)
	Dressing.populate(self, _decoration)
	_build_perimeter()
	_begin_navigation.call_deferred()

func _container(label: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = label
	add_child(node)
	return node

func get_spawn_points() -> Array[Node3D]:
	return _spawn_points.duplicate()

func get_player_spawn() -> Vector3:
	return to_global(Vector3(0.0, ground_height(0.0, 130.0), 130.0))

func get_zone_at(world_position: Vector3) -> StringName:
	var z: float = to_local(world_position).z
	if z < -20.0:
		return &"village"
	if z < 35.0:
		return &"approach"
	return &"field"

func renew(duration: float) -> void:
	for target: Node3D in _targets:
		target.renew(duration)
	if _renew_tween != null and _renew_tween.is_valid():
		_renew_tween.kill()
	_renew_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renew_tween.tween_property(_grass_material, "albedo_color", Color(0.57, 0.78, 0.49), maxf(duration, 0.01))
	_renew_tween.tween_property(_grass_material, "albedo_color", Color(0.65, 0.68, 0.47), 3.0)

func _height_sample(x: float, z: float) -> float:
	var rolling: float = 1.5 * sin(x * 0.025) * sin(z * 0.021) + 0.65 * cos(z * 0.035)
	var village_blend: float = smoothstep(-28.0, 45.0, z)
	var height: float = lerpf(0.5, rolling, village_blend)
	for center: Vector3 in BUILDINGS:
		var distance: float = maxf(absf(x - center.x) - 13.0, absf(z - center.z) - 12.0)
		height = lerpf(0.5, height, smoothstep(0.0, 9.0, distance))
	var margin: float = maxf(absf(x) - 120.0, absf(z) - 170.0)
	return height + smoothstep(0.0, 65.0, margin) * (14.0 + 5.0 * sin(x * 0.031 + z * 0.019))

func ground_height(x: float, z: float) -> float:
	var x0: float = floorf(x / STEP) * STEP
	var z0: float = floorf(z / STEP) * STEP
	var u: float = (x - x0) / STEP
	var v: float = (z - z0) / STEP
	var a: float = _height_sample(x0, z0)
	var b: float = _height_sample(x0 + STEP, z0)
	var c: float = _height_sample(x0, z0 + STEP)
	var d: float = _height_sample(x0 + STEP, z0 + STEP)
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

func ground_position(world_point: Vector3) -> Vector3:
	var local_point: Vector3 = to_local(world_point)
	local_point.y = ground_height(local_point.x, local_point.z)
	if _on_road(Vector2(local_point.x, local_point.z), 0.0):
		local_point.y += 0.065
	return to_global(local_point)

func _material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = texture
	material.roughness = 0.95
	return material

func _build_terrain() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(-250, 250, 2):
		for x: int in range(-200, 200, 2):
			var a: Vector3 = Vector3(x, _height_sample(x, z), z)
			var b: Vector3 = Vector3(x + STEP, _height_sample(x + STEP, z), z)
			var c: Vector3 = Vector3(x, _height_sample(x, z + STEP), z + STEP)
			var d: Vector3 = Vector3(x + STEP, _height_sample(x + STEP, z + STEP), z + STEP)
			for vertex: Vector3 in [a, b, c, b, d, c]:
				surface.set_uv(Vector2(vertex.x, vertex.z) / 7.0)
				surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "RollingTerrain"
	terrain.mesh = mesh
	terrain.material_override = _material(Color(0.57, 0.63, 0.48), GROUND)
	_landscape.add_child(terrain)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	_landscape.add_child(body)

func _lane_x(z: float) -> float:
	return sin(maxf(z, 0.0) * 0.021) * 13.0 * smoothstep(-20.0, 40.0, z)

func _build_roads() -> void:
	var dirt: StandardMaterial3D = _material(Color(0.29, 0.25, 0.19), GROUND)
	var points: Array[Vector2] = []
	for z: int in range(-166, 171, 2):
		points.append(Vector2(_lane_x(z), z))
	_ribbon(points, 7.0, dirt, "MainLane")
	for z: float in [-18.0, -58.0, -100.0, -156.0]:
		points.clear()
		for x: int in range(-98, 99, 2):
			points.append(Vector2(x, z))
		_ribbon(points, 5.0, dirt, "CrossLane")
	for x: float in [-94.0, 95.0]:
		points.clear()
		for z: int in range(-156, 31, 2):
			points.append(Vector2(x, z))
		_ribbon(points, 4.0, dirt, "BackLane")

func _ribbon(points: Array[Vector2], half_width: float, material: Material, label: String) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(points.size() - 1):
		var direction: Vector2 = (points[i + 1] - points[i]).normalized()
		var side: Vector2 = Vector2(direction.y, -direction.x)
		for width_step: int in range(-int(half_width), int(half_width)):
			var a: Vector2 = points[i] + side * width_step
			var b: Vector2 = points[i] + side * (width_step + 1)
			var c: Vector2 = points[i + 1] + side * width_step
			var d: Vector2 = points[i + 1] + side * (width_step + 1)
			for p: Vector2 in [a, b, c, b, d, c]:
				surface.set_uv(p / 6.0)
				surface.add_vertex(Vector3(p.x, ground_height(p.x, p.y) + 0.065, p.y))
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	_landscape.add_child(instance)

func _place_target(kind: StringName, location: Vector3, dimensions: Vector3, capacity: float, gate: float, yaw: float = 0.0) -> Node3D:
	var target: Node3D = Catalog.instantiate_target(kind, dimensions, capacity, gate)
	target.ground_position = ground_position
	target.position = Vector3(location.x, ground_height(location.x, location.z), location.z)
	target.rotation.y = yaw
	target.set_meta(&"zone", get_zone_at(to_global(target.position)))
	target.get_node("Drainable").drained.connect(_on_drained)
	initial_capacity += capacity
	_targets.append(target)
	_target_root.add_child(target)
	return target

func _on_drained(amount: float) -> void:
	drained_capacity = minf(initial_capacity, drained_capacity + amount)
	progress_changed.emit(drained_capacity, initial_capacity)

func _scenery(kind: StringName, position_xz: Vector2, dimensions: Vector3) -> void:
	var item: Node3D = Catalog.instantiate_scenery(kind, dimensions)
	item.position = Vector3(position_xz.x, ground_height(position_xz.x, position_xz.y), position_xz.y)
	item.rotation.y = _rng.randf_range(-PI, PI)
	_decoration.add_child(item)

func _build_settlement() -> void:
	var wood: Material = _material(Color(0.25, 0.20, 0.14))
	var stone: Material = _material(Color(0.32, 0.33, 0.30))
	for i: int in BUILDINGS.size():
		var center: Vector3 = BUILDINGS[i]
		var farm: bool = i < 2
		var kind: StringName = &"shed" if farm else StringName("house%d" % (1 + (i - 2) % 5))
		var large: bool = i in [7, 12, 15]
		var dimensions: Vector3 = Vector3(22, 13, 20) if large else (Vector3(12, 8, 12) if i >= 16 else Vector3(17, 10, 16))
		var gate: float = 2.5 if i < 6 else (3.0 if i < 10 else (3.5 if i < 14 else 4.0))
		_place_target(kind, center, dimensions, 90.0 if farm else (100.0 if i < 16 else 43.75), gate, 0.0 if center.x < 0 else PI)
		_box(Vector3(center.x, -0.34, center.z), Vector3(dimensions.x + 0.8, 0.36, dimensions.z + 0.8), stone, true)
		for offset: float in [-11.0, 11.0]:
			if not _on_road(Vector2(center.x + offset, center.z + 9.5), 3.0):
				_box(Vector3(center.x + offset, 0.5, center.z + 9.5), Vector3(0.22, 1.5, 5.0), wood, false)
		for offset: float in [-6.0, 6.0]:
			if not _on_road(Vector2(center.x + offset, center.z + 12.0), 3.0):
				_box(Vector3(center.x + offset, 0.5, center.z + 12.0), Vector3(5.0, 1.1, 0.18), wood, false)
		var rock: Vector2 = Vector2(center.x + 12, center.z - 7)
		if not _on_road(rock, 1.5):
			_scenery(&"rock", rock, Vector3(1.5, 0.9, 1.5))

func _box(location: Vector3, dimensions: Vector3, material: Material, blocking: bool) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = Vector3(location.x, location.y + ground_height(location.x, location.z) + dimensions.y * 0.5, location.z)
	_decoration.add_child(instance)
	if blocking:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 6
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
		body.position = instance.position
		_decoration.add_child(body)

func _build_resources() -> void:
	var clusters: Array[Vector2] = [Vector2(0, 130), Vector2(-22, 88), Vector2(25, 60), Vector2(-57, 83), Vector2(-32, 49), Vector2(65, 151)]
	for cluster_index: int in clusters.size():
		var center: Vector2 = clusters[cluster_index]
		for i: int in 10:
			var starter: bool = cluster_index == 0
			var angle: float = PI + PI * (i + 0.5) / 10.0 if starter else TAU * i / 10.0
			var radius: float = _rng.randf_range(12, 17) if starter else _rng.randf_range(6, 16)
			var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			p.y = maxf(p.y, 36.0)
			_place_target(&"bush" if i % 2 == 0 else &"bush_alt", Vector3(p.x, 0, p.y), Vector3(3.2, 2.1, 3.2), 10, 1.0, angle)
	for i: int in 12:
		var p: Vector3 = Vector3(-80 if i % 2 == 0 else 80, 0, 45 + (i / 2) * 20)
		_place_target(StringName("forest_tree%d" % (1 + i % 4)), p, Vector3(8, 11, 8), 15, 1.8)
	for row: int in 4:
		for column: int in 4:
			var p: Vector2 = Vector2(-72 + column * 14, 27 - row * 13)
			if _clear_route(p):
				p = Vector2(-121 - column * 3, 40 + row * 13)
			_place_target(StringName("forest_tree%d" % (1 + (row + column) % 4)), Vector3(p.x, 0, p.y), Vector3(7, 9, 7), 25, 1.8)
	for i: int in 10:
		_place_target(&"bush", Vector3(53 + (i % 5) * 9, 0, 15 + (i / 5) * 12), Vector3(3, 2, 3), 12, 1)
	for i: int in 12:
		var x: float = -108.0 if i % 2 == 0 else 108.0
		var z: float = -28.0 - (i / 2) * 23.0
		var p: Vector2 = Vector2(x, z)
		if _clear_route(p):
			p.x = signf(x) * 130
		_place_target(StringName("forest_tree%d" % (1 + i % 4)), Vector3(p.x, 0, p.y), Vector3(8, 12, 8), 15, 1.8)
		var bush: Vector2 = Vector2(x * 0.77, z + 6)
		if _clear_route(bush):
			bush.x = signf(x) * 124
		_place_target(&"bush_alt", Vector3(bush.x, 0, bush.y), Vector3(3, 2, 3), 10, 1)
	var field_edge: Array[Vector2] = [Vector2(98, 54), Vector2(99, 76), Vector2(98, 98), Vector2(98, 120), Vector2(99, 138), Vector2(98, 164)]
	for side: int in [-1, 1]:
		for i: int in field_edge.size():
			var p: Vector2 = field_edge[i] * Vector2(side, 1)
			_place_target(StringName("forest_tree%d" % (1 + (i + (2 if side > 0 else 0)) % 4)), Vector3(p.x, 0, p.y), Vector3(8, 11, 8), 10, 1.8)

func _build_margins() -> void:
	for i: int in 18:
		var p: Vector2 = Vector2((-1.0 if i % 2 == 0 else 1.0) * (105 + i % 3 * 8), 42 + (i / 2) * 14)
		if not _clear_route(p):
			_scenery(&"forest_trunk" if i % 3 == 0 else &"forest_rock", p, Vector3(2.8, 1.4, 2.8))
	for side: int in [-1, 1]:
		for i: int in 48:
			var z: float = -205 + i * 8.5 + _rng.randf_range(-5, 5)
			var x: float = side * _rng.randf_range(133, 180)
			_scenery(&"pine" if i % 3 == 0 else StringName("forest_tree%d" % (1 + i % 4)), Vector2(x, z), Vector3(12, _rng.randf_range(14, 23), 12))
		for i: int in 34:
			_scenery(&"pine", Vector2(-175 + i * 10.5, side * _rng.randf_range(185, 228)), Vector3(13, _rng.randf_range(16, 25), 13))
	for i: int in 55:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_scenery(&"rock", Vector2(side * _rng.randf_range(112, 144), _rng.randf_range(-166, 167)), Vector3(3, 2, 3))

func _on_road(p: Vector2, clearance: float = 3.0) -> bool:
	if absf(p.x - _lane_x(p.y)) < 7.0 + clearance:
		return true
	if p.y < 35:
		if absf(p.x + 94.0) < 4.0 + clearance or absf(p.x - 95.0) < 4.0 + clearance:
			return true
		for z: float in [-18.0, -58.0, -100.0, -156.0]:
			if absf(p.y - z) < 5.0 + clearance:
				return true
	return false

func _clear_route(p: Vector2) -> bool:
	if _on_road(p):
		return true
	for marker: Node3D in _spawn_points:
		if p.distance_squared_to(Vector2(marker.position.x, marker.position.z)) < 16.0:
			return true
	for center: Vector3 in BUILDINGS:
		if absf(p.x - center.x) < 14 and absf(p.y - center.z) < 14:
			return true
	return false

func _build_grass() -> void:
	var material: StandardMaterial3D = _material(Color(0.65, 0.68, 0.47), GRASS)
	_grass_material = material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.45
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(1.1, 0.85)
	mesh.material = material
	for chunk_z: int in range(-170, 170, 34):
		for chunk_x: int in range(-120, 120, 30):
			var transforms: Array[Transform3D] = []
			for i: int in 110:
				var p: Vector2 = Vector2(chunk_x + _rng.randf_range(0, 30), chunk_z + _rng.randf_range(0, 34))
				if _clear_route(p):
					continue
				var scale_factor: float = _rng.randf_range(0.65, 1.5)
				var basis: Basis = Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale_factor)
				transforms.append(Transform3D(basis, Vector3(p.x, ground_height(p.x, p.y) + 0.4 * scale_factor, p.y)))
			var multimesh: MultiMesh = MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = transforms.size()
			for i: int in transforms.size():
				multimesh.set_instance_transform(i, transforms[i])
			var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = 95
			instance.visibility_range_end_margin = 15
			_decoration.add_child(instance)

func _build_spawns() -> void:
	var player: Marker3D = Marker3D.new()
	player.name = "PlayerSpawn"
	player.position = Vector3(0, ground_height(0, 130), 130)
	add_child(player)
	for p: Vector2 in [Vector2(-95, 145), Vector2(95, 125), Vector2(-95, 65), Vector2(95, 48), Vector2(-94, 26), Vector2(94, 22), Vector2(-94, -16), Vector2(94, -16), Vector2(-94, -58), Vector2(94, -58), Vector2(-94, -100), Vector2(94, -100), Vector2(-94, -156), Vector2(94, -156), Vector2(0, -158)]:
		_add_spawn(p)
	for z: float in [55.0, 85.0, 115.0, 155.0]:
		for x: float in [-52.0, -30.0, 30.0, 52.0]:
			_add_spawn(Vector2(x, z))
	for p: Vector2 in [Vector2(-30, 28), Vector2(30, 28), Vector2(-55, 10), Vector2(55, 10), Vector2(-12, -12), Vector2(12, -12)]:
		_add_spawn(p)
	for z: float in [-58.0, -100.0, -156.0]:
		for x: float in [-52.0, -8.0, 8.0, 52.0]:
			_add_spawn(Vector2(x, z))

func _add_spawn(p: Vector2) -> void:
	var marker: Marker3D = Marker3D.new()
	marker.name = "HumanSpawn%02d" % _spawn_points.size()
	marker.position = Vector3(p.x, ground_height(p.x, p.y), p.y)
	marker.set_meta(&"zone", get_zone_at(to_global(marker.position)))
	_spawn_root.add_child(marker)
	_spawn_points.append(marker)

func _build_perimeter() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "WoodlandPerimeter"
	body.collision_layer = 1
	body.collision_mask = 6
	for side: float in [-1.0, 1.0]:
		for axis: int in 2:
			var collision: CollisionShape3D = CollisionShape3D.new()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(2, 90, 472) if axis == 0 else Vector3(372, 90, 2)
			collision.shape = shape
			collision.position = Vector3(side * 185, 30, 0) if axis == 0 else Vector3(0, 30, side * 235)
			body.add_child(collision)
	_landscape.add_child(body)

func _begin_navigation() -> void:
	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.5
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 35
	mesh.filter_baking_aabb = AABB(Vector3(-120, -8, -170), Vector3(240, 50, 340))
	_navigation.navigation_mesh = mesh
	add_child(_navigation)
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_navigation_baked)

func _on_navigation_baked() -> void:
	if _navigation.navigation_mesh.get_polygon_count() == 0:
		push_error("Demo region navigation bake produced no walkable polygons")
		return
	_navigation.navigation_mesh = _navigation.navigation_mesh
	var map: RID = get_world_3d().navigation_map
	var iteration: int = NavigationServer3D.map_get_iteration_id(map)
	while NavigationServer3D.map_get_iteration_id(map) == iteration:
		await get_tree().physics_frame
	navigation_ready = true
	navigation_became_ready.emit()
