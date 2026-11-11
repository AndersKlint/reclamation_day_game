extends Node3D

signal progress_changed(drained: float, initial: float)
signal navigation_became_ready()

const Catalog = preload("res://game/demo/targets/demo_asset_catalog.gd")
const Dressing = preload("res://game/demo/world/region_dressing.gd")
const Forest = preload("res://game/demo/world/forest_assets.gd")
const CoverPatch = preload("res://game/demo/world/cover_patch.gd")
const CityBuilder = preload("res://game/demo/city/city_builder.gd")
const CityLayout = preload("res://game/demo/city/city_layout.gd")
const FARM_OPENING: PackedScene = preload("res://game/demo/farm_opening/farm_opening.tscn")
const RURAL_FIELD: PackedScene = preload("res://game/demo/rural_fields/rural_field.tscn")
const FARM_CENTER: Vector2 = Vector2(0.0, 280.0)
const FIELD_SITES: Array[Dictionary] = [
	{"center": Vector2(-52.0, 124.0), "size": Vector2(60.0, 80.0), "seed": 71041},
	{"center": Vector2(54.0, 100.0), "size": Vector2(56.0, 76.0), "seed": 71042},
]
const COVER_FADE_SHADER: Shader = preload("res://game/demo/world/ground_cover_fade.gdshader")
const GROUND = preload("res://available-assets/retro3d-assets/Buildings/Abandoned House/Textures/groundgrass.png")
const GRASS = preload("res://available-assets/retro3d-assets/Nature/Materials/grass_bush_1.png")
const STEP: float = 4.0
const WORLD_BOUNDS: Rect2 = Rect2(Vector2(-280.0, -780.0), Vector2(560.0, 1160.0))
const CITY_EDGE: float = -190.0
const DOWNTOWN_EDGE: float = -460.0
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
var _buildings: Array[Node3D] = []
var _cover: Dictionary = {}
@export var ground_scorch: Node
var _spawn_points: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _navigation: NavigationRegion3D
var _landscape: Node3D
var _decoration: Node3D
var _target_root: Node3D
var _spawn_root: Node3D
var _fields_root: Node3D
var _fields: Array[Node3D] = []
var _field_footprints: Array[Rect2] = []
var _grass_material: StandardMaterial3D
var _grass_fade_material: ShaderMaterial
var _renew_tween: Tween
var _city_layout: Dictionary = {}
var _city_pedestrian_points: Array[Vector3] = []
var _pedestrian_points: Array[Vector3] = []
var _traffic_routes: Array[PackedVector3Array] = []
var _tank_routes: Array[PackedVector3Array] = []
var _city_parking: Array[Transform3D] = []
var _opening_encounter: Node3D

func _ready() -> void:
	_rng.seed = 30102026
	_landscape = _container("Landscape")
	_decoration = _container("Decoration")
	_target_root = _container("Targets")
	_spawn_root = _container("SpawnPoints")
	_fields_root = _container("Fields")
	_build_terrain()
	_build_roads()
	_build_city()
	_build_settlement()
	_build_fields()
	_build_resources()
	_build_margins()
	_build_farm_opening()
	_build_spawns()
	_build_grass()
	Forest.populate(self, _decoration)
	_finish_cover()
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

func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS

func get_pedestrian_points() -> Array[Vector3]:
	return _pedestrian_points.duplicate()

func get_traffic_routes() -> Array[PackedVector3Array]:
	var routes: Array[PackedVector3Array] = []
	for route: PackedVector3Array in _traffic_routes:
		routes.append(route.duplicate())
	return routes

func get_tank_routes() -> Array[PackedVector3Array]:
	var routes: Array[PackedVector3Array] = []
	for route: PackedVector3Array in _tank_routes:
		routes.append(route.duplicate())
	return routes

func get_city_parking() -> Array[Transform3D]:
	return _city_parking.duplicate()

func get_player_spawn() -> Vector3:
	return to_global(Vector3(FARM_CENTER.x, ground_height(FARM_CENTER.x, FARM_CENTER.y), FARM_CENTER.y))

func get_opening_encounter() -> Node3D:
	return _opening_encounter

func _build_farm_opening() -> void:
	_opening_encounter = FARM_OPENING.instantiate() as Node3D
	_opening_encounter.position = Vector3(FARM_CENTER.x, 0.0, FARM_CENTER.y)
	_opening_encounter.prepare(_farm_ground_height)
	add_child(_opening_encounter)
	initial_capacity += float(_opening_encounter.initial_wheat_capacity) + float(_opening_encounter.initial_fence_capacity)
	_opening_encounter.wheat.life_absorbed.connect(_on_drained)
	_opening_encounter.fence_life_absorbed.connect(_on_drained)
	for ring: int in 3:
		var half: float = 56.0 + ring * 8.0
		for offset: int in range(-int(half), int(half) + 1, 7):
			for side: float in [-1.0, 1.0]:
				var p: Vector2 = FARM_CENTER + Vector2(offset, side * half)
				if not _on_road(p, 6.0):
					_scenery(StringName("forest_tree%d" % (1 + posmod(offset + ring, 4))), p, Vector3(9.0, 14.0 + ring * 2.0, 9.0))
				p = FARM_CENTER + Vector2(side * half, offset)
				_scenery(StringName("forest_tree%d" % (1 + posmod(offset + ring + 1, 4))), p, Vector3(9.0, 14.0 + ring * 2.0, 9.0))

func _farm_ground_height(x: float, z: float) -> float:
	return ground_height(x + FARM_CENTER.x, z + FARM_CENTER.y)

func get_zone_at(world_position: Vector3) -> StringName:
	var z: float = to_local(world_position).z
	if z < DOWNTOWN_EDGE:
		return &"downtown"
	if z < CITY_EDGE:
		return &"city"
	if z < -20.0:
		return &"village"
	if z < 35.0:
		return &"approach"
	return &"field"

func renew(duration: float) -> void:
	if ground_scorch != null:
		ground_scorch.renew(duration)
	for target: Node3D in _targets:
		target.renew(duration)
	if _renew_tween != null and _renew_tween.is_valid():
		_renew_tween.kill()
	_renew_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renew_tween.tween_property(_grass_fade_material, "shader_parameter/base_color", Color(0.57, 0.78, 0.49), maxf(duration, 0.01))
	_renew_tween.tween_property(_grass_fade_material, "shader_parameter/base_color", Color(0.65, 0.68, 0.47), 3.0)

func _height_sample(x: float, z: float) -> float:
	var rolling: float = 1.5 * sin(x * 0.025) * sin(z * 0.021) + 0.65 * cos(z * 0.035)
	var village_blend: float = smoothstep(-28.0, 45.0, z)
	var height: float = lerpf(0.5, rolling, village_blend)
	for center: Vector3 in BUILDINGS:
		var distance: float = maxf(absf(x - center.x) - 13.0, absf(z - center.z) - 12.0)
		height = lerpf(0.5, height, smoothstep(0.0, 9.0, distance))
	var city_blend: float = 1.0 - smoothstep(-210.0, -150.0, z)
	height = lerpf(height, 0.5, city_blend)
	var farm_distance: float = maxf(absf(x - FARM_CENTER.x) - 52.0, absf(z - FARM_CENTER.y) - 52.0)
	height = lerpf(0.5, height, smoothstep(0.0, 16.0, farm_distance))
	var margin: float = maxf(absf(x) - 245.0, maxf(z - 350.0, -800.0 - z))
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
	for z: int in range(int(WORLD_BOUNDS.position.y), int(WORLD_BOUNDS.end.y), int(STEP)):
		for x: int in range(int(WORLD_BOUNDS.position.x), int(WORLD_BOUNDS.end.x), int(STEP)):
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
	if z > 170.0:
		return lerpf(sin(170.0 * 0.021) * 13.0, 0.0, smoothstep(170.0, 232.0, z))
	return sin(maxf(z, 0.0) * 0.021) * 13.0 * smoothstep(-20.0, 40.0, z)

func _build_roads() -> void:
	var dirt: StandardMaterial3D = _material(Color(0.29, 0.25, 0.19), GROUND)
	var points: Array[Vector2] = []
	for z: int in range(-190, 241, 2):
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

func _build_city() -> void:
	_city_layout = CityBuilder.build(self)
	for p: Vector2 in _city_layout["pedestrian_points"]:
		_city_pedestrian_points.append(to_global(Vector3(p.x, ground_height(p.x, p.y), p.y)))
	for route: PackedVector3Array in _city_layout["traffic_routes"]:
		_traffic_routes.append(_route_world(route))
	for route: PackedVector3Array in _city_layout["tank_routes"]:
		_tank_routes.append(_route_world(route))
	for entry: Dictionary in _city_layout["parking"]:
		var parking_position: Vector2 = entry["position"]
		_city_parking.append(_parking_world(parking_position, float(entry["yaw"])))
	for z: float in [72.0, 98.0, 124.0, 150.0]:
		_city_parking.append(_parking_world(Vector2(_lane_x(z) + 4.2, z), 0.0))

func _route_world(route: PackedVector3Array) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in route:
		points.append(ground_position(to_global(Vector3(point.x, 0.0, point.z))))
	return points

func _parking_world(p: Vector2, yaw: float) -> Transform3D:
	var origin: Vector3 = to_global(Vector3(p.x, ground_height(p.x, p.y) + 0.065, p.y))
	return Transform3D(global_basis * Basis(Vector3.UP, yaw), origin)

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

func _place_target(kind: StringName, location: Vector3, dimensions: Vector3, yaw: float = 0.0) -> Node3D:
	var target: Node3D = Catalog.instantiate_target(kind, dimensions)
	target.ground_position = ground_position
	target.position = Vector3(location.x, ground_height(location.x, location.z), location.z)
	target.rotation.y = yaw
	target.set_meta(&"zone", get_zone_at(to_global(target.position)))
	_register_target(target)
	return target

func _register_target(target: Node3D, preserve_parent: bool = false) -> void:
	target.get_node("Drainable").drained.connect(_on_drained)
	_targets.append(target)
	if not preserve_parent:
		_target_root.add_child(target)
	initial_capacity += float(target.get_node("Drainable").get("capacity"))
	var effect: Node = target.get_node_or_null("DepletionEffect")
	if effect != null and effect.has_signal(&"life_absorbed"):
		effect.connect(&"life_absorbed", _on_drained)

func _on_drained(amount: float) -> void:
	drained_capacity = minf(initial_capacity, drained_capacity + amount)
	progress_changed.emit(drained_capacity, initial_capacity)

func _scenery(kind: StringName, position_xz: Vector2, dimensions: Vector3) -> void:
	_place_target(kind, Vector3(position_xz.x, 0, position_xz.y), dimensions, _rng.randf_range(-PI, PI))

func _build_settlement() -> void:
	var wood: Material = _material(Color(0.25, 0.20, 0.14))
	var stone: Material = _material(Color(0.32, 0.33, 0.30))
	for i: int in BUILDINGS.size():
		var center: Vector3 = BUILDINGS[i]
		var farm: bool = i < 2
		var kind: StringName = &"shed" if farm else StringName("house%d" % (1 + (i - 2) % 5))
		var large: bool = i in [7, 12, 15]
		var dimensions: Vector3 = Vector3(22, 13, 20) if large else (Vector3(12, 8, 12) if i >= 16 else Vector3(17, 10, 16))
		_buildings.append(_place_target(kind, center, dimensions, 0.0 if center.x < 0 else PI))
		_box(Vector3(center.x, -0.34, center.z), Vector3(dimensions.x + 0.8, 0.36, dimensions.z + 0.8), stone, true)
		for offset: float in [-11.0, 11.0]:
			if not _on_road(Vector2(center.x + offset, center.z + 9.5), 3.0):
				_fence(Vector2(center.x + offset, center.z + 9.5), Vector3(0.22, 1.5, 5.0), wood)
		for offset: float in [-6.0, 6.0]:
			if not _on_road(Vector2(center.x + offset, center.z + 12.0), 3.0):
				_fence(Vector2(center.x + offset, center.z + 12.0), Vector3(5.0, 1.1, 0.18), wood)
		var rock: Vector2 = Vector2(center.x + 12, center.z - 7)
		if not _on_road(rock, 1.5):
			_scenery(&"rock", rock, Vector3(1.5, 0.9, 1.5))

func _build_fields() -> void:
	for site: Dictionary in FIELD_SITES:
		var field: Node3D = RURAL_FIELD.instantiate() as Node3D
		field.set(&"footprint_size", site["size"])
		field.set(&"generation_seed", site["seed"])
		var center: Vector2 = site["center"]
		field.position = Vector3(center.x, 0.0, center.y)
		field.call(&"prepare", self)
		_fields_root.add_child(field)
		_field_footprints.append(_field_footprint(field))
		initial_capacity += float(field.get(&"initial_wheat_capacity"))
		var wheat: Node3D = field.get(&"wheat") as Node3D
		if wheat != null:
			wheat.connect(&"life_absorbed", _on_drained)
		var fences: Array = field.get(&"fence_targets")
		for fence: Node3D in fences:
			_register_target(fence, true)
		_fields.append(field)

func _field_footprint(field: Node3D) -> Rect2:
	var local: Rect2 = field.call(&"footprint") as Rect2
	return Rect2(local.position + Vector2(field.position.x, field.position.z), local.size)

func start_field_encounters(player: CharacterBody3D) -> void:
	for field: Node3D in _fields:
		if is_instance_valid(field):
			field.call(&"start", player)

func stop_field_encounters() -> void:
	for field: Node3D in _fields:
		if is_instance_valid(field):
			field.call(&"stop")

func _fence(p: Vector2, dimensions: Vector3, material: Material) -> void:
	var root: Node3D = Node3D.new()
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = material
	part.position.y = dimensions.y * 0.5 + 0.5
	root.add_child(part)
	part.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	var target: Node3D = Catalog.instantiate_model(&"fence", scene, null, dimensions + Vector3(0, 0.5, 0), true)
	target.position = Vector3(p.x, ground_height(p.x, p.y), p.y)
	target.ground_position = ground_position
	_register_target(target)

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
			p = _field_margin(p)
			_place_target(&"bush" if i % 2 == 0 else &"bush_alt", Vector3(p.x, 0, p.y), Vector3(3.2, 2.1, 3.2), angle)
	for i: int in 12:
		var p: Vector2 = Vector2(-80 if i % 2 == 0 else 80, 45 + (i / 2) * 20)
		p = _field_margin(p)
		_place_target(StringName("forest_tree%d" % (1 + i % 4)), Vector3(p.x, 0, p.y), Vector3(8, 11, 8))
	for row: int in 4:
		for column: int in 4:
			var p: Vector2 = Vector2(-72 + column * 14, 27 - row * 13)
			if _clear_route(p):
				p = Vector2(-121 - column * 3, 40 + row * 13)
			p = _field_margin(p)
			_place_target(StringName("forest_tree%d" % (1 + (row + column) % 4)), Vector3(p.x, 0, p.y), Vector3(7, 9, 7))
	for i: int in 10:
		_place_target(&"bush", Vector3(53 + (i % 5) * 9, 0, 15 + (i / 5) * 12), Vector3(3, 2, 3))
	for i: int in 12:
		var x: float = -108.0 if i % 2 == 0 else 108.0
		var z: float = -28.0 - (i / 2) * 23.0
		var p: Vector2 = Vector2(x, z)
		if _clear_route(p):
			p.x = signf(x) * 130
		_place_target(StringName("forest_tree%d" % (1 + i % 4)), Vector3(p.x, 0, p.y), Vector3(8, 12, 8))
		var bush: Vector2 = Vector2(x * 0.77, z + 6)
		if _clear_route(bush):
			bush.x = signf(x) * 124
		_place_target(&"bush_alt", Vector3(bush.x, 0, bush.y), Vector3(3, 2, 3))
	var field_edge: Array[Vector2] = [Vector2(98, 54), Vector2(99, 76), Vector2(98, 98), Vector2(98, 120), Vector2(99, 138), Vector2(98, 164)]
	for side: int in [-1, 1]:
		for i: int in field_edge.size():
			var p: Vector2 = field_edge[i] * Vector2(side, 1)
			_place_target(StringName("forest_tree%d" % (1 + (i + (2 if side > 0 else 0)) % 4)), Vector3(p.x, 0, p.y), Vector3(8, 11, 8))

func _build_margins() -> void:
	for i: int in 18:
		var p: Vector2 = Vector2((-1.0 if i % 2 == 0 else 1.0) * (105 + i % 3 * 8), 42 + (i / 2) * 14)
		if not _clear_route(p):
			_scenery(&"forest_trunk" if i % 3 == 0 else &"forest_rock", p, Vector3(2.8, 1.4, 2.8))
	for side: int in [-1, 1]:
		for i: int in 48:
			var z: float = -178.0 + i * 7.8 + _rng.randf_range(-2.0, 2.0)
			var x: float = side * _rng.randf_range(133, 180)
			_scenery(&"pine" if i % 3 == 0 else StringName("forest_tree%d" % (1 + i % 4)), Vector2(x, z), Vector3(12, _rng.randf_range(14, 23), 12))
	for i: int in 30:
		var p: Vector2 = Vector2(-175 + i * 11.5, 185 + _rng.randf_range(0, 30))
		if not _on_road(p, 7.0):
			_scenery(&"pine", p, Vector3(13, _rng.randf_range(16, 25), 13))
	for i: int in 60:
		var p: Vector2 = Vector2(-178 + i * 6.0, -769.0 + _rng.randf_range(-2.0, 2.0))
		if not _on_road(p, 4.0):
			_scenery(&"pine", p, Vector3(13, _rng.randf_range(16, 25), 13))
	for i: int in 55:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_scenery(&"rock", Vector2(side * _rng.randf_range(112, 144), _rng.randf_range(-166, 167)), Vector3(3, 2, 3))

func _on_road(p: Vector2, clearance: float = 3.0) -> bool:
	if p.y <= 240.0 and absf(p.x - _lane_x(p.y)) < 7.0 + clearance:
		return true
	if p.y < 35:
		if absf(p.x + 94.0) < 4.0 + clearance or absf(p.x - 95.0) < 4.0 + clearance:
			return true
		for z: float in [-18.0, -58.0, -100.0, -156.0]:
			if absf(p.y - z) < 5.0 + clearance:
				return true
	if p.y < CITY_EDGE + 12.0:
		for x: float in CityLayout.X_STREETS:
			if absf(p.x - x) < CityLayout.ROAD_HALF + clearance:
				return true
		for z: float in CityLayout.Z_STREETS:
			if absf(p.y - z) < CityLayout.ROAD_HALF + clearance:
				return true
	return false

func _in_field(p: Vector2, inset: float = 0.0) -> bool:
	for footprint: Rect2 in _field_footprints:
		if footprint.grow(-inset).has_point(p):
			return true
	return false

func _field_margin(p: Vector2) -> Vector2:
	var margin: float = 5.0
	for footprint: Rect2 in _field_footprints:
		if not footprint.has_point(p):
			continue
		var left: float = p.x - footprint.position.x
		var right: float = footprint.end.x - p.x
		var top: float = p.y - footprint.position.y
		var bottom: float = footprint.end.y - p.y
		var nearest: float = minf(minf(left, right), minf(top, bottom))
		# Field gates face the central lane, so nearest-side relocation skips the gate edge.
		var gate_left: bool = footprint.get_center().x > 0.0
		if nearest == left and not gate_left:
			p.x = footprint.position.x - margin
		elif nearest == right and gate_left:
			p.x = footprint.end.x + margin
		elif nearest == left or nearest == right:
			p.y = footprint.position.y - margin if top <= bottom else footprint.end.y + margin
		elif top <= bottom:
			p.y = footprint.position.y - margin
		else:
			p.y = footprint.end.y + margin
	return p

func _clear_route(p: Vector2) -> bool:
	if _in_field(p, 4.0):
		return true
	if Rect2(FARM_CENTER - Vector2(48.0, 48.0), Vector2(96.0, 96.0)).has_point(p):
		return true
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
			for i: int in 110:
				var p: Vector2 = Vector2(chunk_x + _rng.randf_range(0, 30), chunk_z + _rng.randf_range(0, 34))
				if _clear_route(p):
					continue
				var scale_factor: float = _rng.randf_range(0.65, 1.5)
				var basis: Basis = Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale_factor)
				_add_cover(mesh, Transform3D(basis, Vector3(p.x, ground_height(p.x, p.y) + 0.4 * scale_factor, p.y)))

func _add_cover(mesh: Mesh, transform: Transform3D) -> void:
	var key: Vector2i = Vector2i(floori(transform.origin.x / 8.0), floori(transform.origin.z / 8.0))
	if not _cover.has(key):
		_cover[key] = {}
	var batches: Dictionary = _cover[key]
	if not batches.has(mesh):
		batches[mesh] = []
	batches[mesh].append(transform)

func _finish_cover() -> void:
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	for key: Vector2i in _cover:
		var p: Vector2 = Vector2(key.x * 8.0 + 4.0, key.y * 8.0 + 4.0)
		var patch: Node3D = CoverPatch.new()
		patch.position = Vector3(p.x, ground_height(p.x, p.y), p.y)
		patch.ground_position = ground_position
		var batches: Dictionary = _cover[key]
		patch.configure()
		for mesh: Mesh in batches:
			if not meshes.has(mesh):
				var fade_mesh: Mesh = mesh.duplicate() as Mesh
				for surface: int in fade_mesh.get_surface_count():
					var source: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
					if not materials.has(source):
						var material: ShaderMaterial = ShaderMaterial.new()
						material.shader = COVER_FADE_SHADER
						material.set_shader_parameter("base_color", source.albedo_color)
						material.set_shader_parameter("albedo_texture", source.albedo_texture)
						material.set_shader_parameter("albedo_texture_nearest", source.albedo_texture)
						material.set_shader_parameter("nearest_filter", source.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS)
						material.set_shader_parameter("vertex_color", source.vertex_color_use_as_albedo)
						material.set_shader_parameter("uv_scale", source.uv1_scale)
						material.set_shader_parameter("uv_offset", source.uv1_offset)
						material.set_shader_parameter("roughness", source.roughness)
						material.set_shader_parameter("metallic", source.metallic)
						if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
							material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold)
						materials[source] = material
						if source == _grass_material:
							_grass_fade_material = material
					fade_mesh.surface_set_material(surface, materials[source])
				meshes[mesh] = fade_mesh
			var transforms: Array = batches[mesh]
			var multimesh: MultiMesh = MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = meshes[mesh]
			multimesh.instance_count = transforms.size()
			for i: int in transforms.size():
				var transform: Transform3D = transforms[i]
				transform.origin -= patch.position
				multimesh.set_instance_transform(i, transform)
			var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = 90
			instance.visibility_range_end_margin = 15
			patch.visual.add_child(instance)
		_decoration.add_child(patch)
	_cover.clear()

func _build_spawns() -> void:
	var player: Marker3D = Marker3D.new()
	player.name = "PlayerSpawn"
	player.position = Vector3(FARM_CENTER.x, ground_height(FARM_CENTER.x, FARM_CENTER.y), FARM_CENTER.y)
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
	for p: Vector2 in _city_layout["spawn_points"]:
		_add_spawn(p)
	_finish_pedestrian_points()

func _finish_pedestrian_points() -> void:
	_pedestrian_points = _city_pedestrian_points.duplicate()
	for marker: Node3D in _spawn_points:
		_pedestrian_points.append(marker.global_position)

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
	var center: Vector2 = WORLD_BOUNDS.get_center()
	var half_x: float = WORLD_BOUNDS.size.x * 0.5 - 4.0
	var half_z: float = WORLD_BOUNDS.size.y * 0.5 - 4.0
	for side: float in [-1.0, 1.0]:
		var collision_x: CollisionShape3D = CollisionShape3D.new()
		var shape_x: BoxShape3D = BoxShape3D.new()
		shape_x.size = Vector3(2, 90, WORLD_BOUNDS.size.y - 8.0)
		collision_x.shape = shape_x
		collision_x.position = Vector3(center.x + side * half_x, 30, center.y)
		body.add_child(collision_x)
		var collision_z: CollisionShape3D = CollisionShape3D.new()
		var shape_z: BoxShape3D = BoxShape3D.new()
		shape_z.size = Vector3(WORLD_BOUNDS.size.x - 8.0, 90, 2)
		collision_z.shape = shape_z
		collision_z.position = Vector3(center.x, 30, center.y + side * half_z)
		body.add_child(collision_z)
	_landscape.add_child(body)

func _begin_navigation() -> void:
	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.6
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.6
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 35
	mesh.filter_baking_aabb = AABB(
		Vector3(WORLD_BOUNDS.position.x + 2.0, -8.0, WORLD_BOUNDS.position.y + 2.0),
		Vector3(WORLD_BOUNDS.size.x - 4.0, 50.0, WORLD_BOUNDS.size.y - 4.0)
	)
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
