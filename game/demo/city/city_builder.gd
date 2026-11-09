extends RefCounted

const Assets = preload("res://game/demo/city/city_assets.gd")
const Layout = preload("res://game/demo/city/city_layout.gd")
const Catalog = preload("res://game/demo/targets/demo_asset_catalog.gd")
const Drainable = preload("res://game/draining/drainable.gd")

const FOREST_TREES: Array[StringName] = [&"forest_tree1", &"forest_tree2", &"forest_tree3", &"forest_tree4"]

static func build(region: Node3D) -> Dictionary:
	var layout: Dictionary = Layout.build()
	var root: Node3D = Node3D.new()
	root.name = "City"
	region.add_child(root)
	_build_ground(region, root, layout)
	_build_buildings(region, layout["buildings"])
	var reserved: Dictionary = layout["reserved"]
	_build_formal_park(region, reserved["park_formal"])
	_build_woodland_park(region, reserved["park_woodland"])
	_build_plaza(region, reserved["plaza"])
	_build_staging(region, reserved["staging"])
	_build_street_details(region, root)
	_build_street_lamps(region, reserved)
	return layout

static func _build_ground(region: Node3D, root: Node3D, layout: Dictionary) -> void:
	var asphalt: StandardMaterial3D = _material(Assets.ROAD_TEXTURE, Color.WHITE, 1.0)
	var concrete: StandardMaterial3D = _material(Assets.SIDEWALK_TEXTURE, Color(0.86, 0.85, 0.81), 1.0)
	var lines: StandardMaterial3D = _material(null, Color(0.87, 0.86, 0.78), 0.9)
	var asphalt_surface: SurfaceTool = SurfaceTool.new()
	asphalt_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect: Rect2 in layout["road_rects"]:
		_add_rect(asphalt_surface, rect, region, 0.061)
	var sidewalk_surface: SurfaceTool = SurfaceTool.new()
	sidewalk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect: Rect2 in layout["sidewalk_rects"]:
		_add_rect(sidewalk_surface, rect, region, 0.112)
	var reserved: Dictionary = layout["reserved"]
	_add_formal_paths(region, sidewalk_surface, reserved["park_formal"])
	_add_woodland_path(region, sidewalk_surface, reserved["park_woodland"])
	_add_plaza_pavement(region, sidewalk_surface, reserved["plaza"])
	_add_staging_yard(region, sidewalk_surface, reserved["staging"])
	_commit(asphalt_surface, "CityAsphalt", asphalt, root)
	_commit(sidewalk_surface, "CitySidewalks", concrete, root)
	var crosswalk_surface: SurfaceTool = SurfaceTool.new()
	crosswalk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rect: Rect2 in layout["crosswalk_rects"]:
		_add_rect(crosswalk_surface, rect, region, 0.134)
	_commit(crosswalk_surface, "CityCrossings", lines, root)

static func _build_buildings(region: Node3D, buildings: Array) -> void:
	for entry: Dictionary in buildings:
		var position: Vector2 = entry["position"]
		var dimensions: Vector3 = entry["dimensions"]
		var target: Node3D = region._place_target(
			StringName(entry["kind"]),
			Vector3(position.x, 0.0, position.y),
			dimensions,
			float(entry["capacity"]),
			float(entry["gate"]),
			float(entry["yaw"])
		)
		target.set_meta(&"city_district", entry["district"])
		target.set_meta(&"city_tall", bool(entry["tall"]))

static func _build_formal_park(region: Node3D, center: Vector2) -> void:
	_place_model(region, &"city_fountain", Assets.FOUNTAIN_ROUND, null, center, Vector3(5.6, 2.6, 5.6), 250.0, 4.0, 0.0, false)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 10.0
		_place_model(region, &"city_bench", Assets.BENCH, Assets.BENCH_TEXTURE, p, Vector3(2.4, 0.8, 0.9), 45.0, 2.0, _face(center, p), true)
	for i: int in 4:
		var angle: float = TAU * (float(i) + 0.5) / 4.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 15.0
		_place_model(region, &"city_flowerbed", Assets.FLOWERBED, null, p, Vector3(2.4, 1.0, 2.4), 40.0, 2.0, angle, true)
	for i: int in 4:
		var angle: float = TAU * float(i) / 4.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 24.0
		_place_model(region, &"city_hedge", Assets.HEDGE_LONG, null, p, Vector3(4.3, 1.2, 1.2), 70.0, 2.5, angle + PI * 0.5, true, true)
	for i: int in 8:
		var angle: float = TAU * (float(i) + 0.5) / 8.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 29.0
		_place_tree(region, p, 9.0, 12.0)
	for p: Vector2 in [center + Vector2(-26, -26), center + Vector2(26, -26), center + Vector2(-26, 26), center + Vector2(26, 26)]:
		_place_lamp(region, p)

static func _build_woodland_park(region: Node3D, center: Vector2) -> void:
	_place_model(region, &"city_gazebo", Assets.GAZEBO, null, center, Vector3(6.2, 5.8, 6.2), 300.0, 4.5, 0.0, false)
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0 + 0.4
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 13.0
		_place_model(region, &"city_bench", Assets.BENCH, Assets.BENCH_TEXTURE, p, Vector3(2.4, 0.8, 0.9), 45.0, 2.0, _face(center, p), true)
	for i: int in 4:
		var angle: float = TAU * (float(i) + 0.5) / 4.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 19.0
		_place_model(region, &"city_flowerbed", Assets.FLOWERBED, null, p, Vector3(2.4, 1.0, 2.4), 40.0, 2.0, angle, true)
	for i: int in 2:
		var p: Vector2 = center + Vector2(-18.0 + i * 36.0, 31.0)
		_place_model(region, &"city_hedge_square", Assets.HEDGE_SQUARE, null, p, Vector3(2.3, 1.2, 2.3), 55.0, 2.4, 0.0, true, true)
	for i: int in 18:
		var angle: float = TAU * float(i) / 18.0 + 0.17
		var radius: float = 19.0 + float((i * 7) % 14)
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		_place_tree(region, p, 8.0 + float(i % 3), 11.0 + float((i * 2) % 4))
	for p: Vector2 in [center + Vector2(-28, 26), center + Vector2(28, 26), center + Vector2(0, 32)]:
		_place_lamp(region, p)

static func _build_plaza(region: Node3D, center: Vector2) -> void:
	_place_model(region, &"city_fountain", Assets.FOUNTAIN_SQUARE, null, center, Vector3(6.0, 3.9, 6.0), 350.0, 4.0, 0.0, false)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 11.0
		_place_model(region, &"city_bench", Assets.BENCH, Assets.BENCH_TEXTURE, p, Vector3(2.4, 0.8, 0.9), 45.0, 2.0, _face(center, p), true)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0 + PI * 0.125
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 17.0
		_place_model(region, &"city_flowerbed", Assets.FLOWERBED, null, p, Vector3(2.4, 1.0, 2.4), 40.0, 2.0, angle, true)
	for i: int in 4:
		var angle: float = TAU * float(i) / 4.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 24.0
		_place_model(region, &"city_hedge", Assets.HEDGE_LONG, null, p, Vector3(4.3, 1.2, 1.2), 70.0, 2.5, angle + PI * 0.5, true, true)
	for i: int in 4:
		var angle: float = TAU * (float(i) + 0.5) / 4.0
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * 29.0
		_place_tree(region, p, 8.0, 11.0)
	for p: Vector2 in [center + Vector2(-28, -28), center + Vector2(28, -28), center + Vector2(-28, 28), center + Vector2(28, 28), center + Vector2(0, -28), center + Vector2(0, 28)]:
		_place_lamp(region, p)

static func _build_staging(region: Node3D, center: Vector2) -> void:
	for row: int in 2:
		for i: int in 5:
			var p: Vector2 = center + Vector2(-10.0 + i * 5.0, -14.0 + row * 28.0)
			_place_model(region, &"city_barrier", Assets.BARRIER_STRONG, null, p, Vector3(1.1, 1.1, 0.35), 20.0, 1.5, 0.0, false, true)
	for side: float in [-1.0, 1.0]:
		for i: int in 4:
			var p: Vector2 = center + Vector2(side * 24.0, -12.0 + i * 8.0)
			_place_model(region, &"city_barrier", Assets.BARRIER_A, null, p, Vector3(1.1, 1.0, 0.34), 20.0, 1.5, PI * 0.5, false, true)
	for i: int in 3:
		var p: Vector2 = center + Vector2(-12.0 + i * 12.0, 4.0)
		var scene: PackedScene = Assets.TRUCK_GREEN if i % 2 == 0 else Assets.TRUCK_GREY
		_place_model(region, &"city_truck", scene, null, p, Vector3(2.0, 2.4, 4.0), 180.0, 3.0, PI * 0.5, false, true)
	for p: Vector2 in [center + Vector2(-26, -26), center + Vector2(-20, -29), center + Vector2(24, 27), center + Vector2(29, 22)]:
		_place_model(region, &"city_dumpster", Assets.DUMPSTER, null, p, Vector3(1.4, 1.6, 1.2), 50.0, 2.0, 0.0, false, true)
	for p: Vector2 in [center + Vector2(-28, 0), center + Vector2(28, 0)]:
		_place_lamp(region, p)

static func _build_street_details(region: Node3D, root: Node3D) -> void:
	for ix: int in 4:
		for iz: int in 4:
			if Layout.RESERVED.has(Vector2i(ix, iz)):
				continue
			var x0: float = Layout.X_STREETS[ix]
			var x1: float = Layout.X_STREETS[ix + 1]
			var z0: float = Layout.Z_STREETS[iz]
			var z1: float = Layout.Z_STREETS[iz + 1]
			var p: Vector2 = Vector2(x0 + 10.8, (z0 + z1) * 0.5)
			_place_tree(region, p, 8.0, 11.0)
			if ix % 2 == 0:
				_place_model(region, &"city_bench", Assets.BENCH, Assets.BENCH_TEXTURE, Vector2(x1 - 10.8, (z0 + z1) * 0.5), Vector3(2.4, 0.8, 0.9), 45.0, 2.0, -PI * 0.5, true)
	for x: float in [-96.0, 0.0, 96.0]:
		for z: float in [-340.0, -460.0, -580.0]:
			_traffic_signal(root, Vector2(x + 8.8, z + 8.8), -PI * 0.5)

static func _build_street_lamps(region: Node3D, reserved: Dictionary) -> void:
	for street_x: float in Layout.X_STREETS:
		for interval_index: int in 4:
			var z: float = (Layout.Z_STREETS[interval_index] + Layout.Z_STREETS[interval_index + 1]) * 0.5
			for side: float in [-1.0, 1.0]:
				var p: Vector2 = Vector2(street_x + side * 8.5, z)
				var near_reserved_space: bool = false
				for center: Vector2 in reserved.values():
					if p.distance_to(center) < 40.0:
						near_reserved_space = true
						break
				if not near_reserved_space:
					_place_lamp(region, p)

static func _place_tree(region: Node3D, p: Vector2, width: float, height: float) -> void:
	var kind: StringName = FOREST_TREES[absi(int(p.x + p.y)) % FOREST_TREES.size()]
	region._place_target(kind, Vector3(p.x, 0.0, p.y), Vector3(width, height, width), 30.0, 1.8, float((int(p.x) + int(p.y)) % 6) * 0.8)

static func _place_model(
	region: Node3D,
	kind: StringName,
	scene: PackedScene,
	texture: Texture2D,
	p: Vector2,
	dimensions: Vector3,
	capacity: float,
	gate: float,
	yaw: float,
	wooden: bool,
	blocking: bool = false
) -> Node3D:
	var target: Node3D = Catalog.instantiate_model(kind, scene, texture, dimensions, capacity, wooden)
	var drainable: Node = target.get_node("Drainable")
	drainable.set("required_size", Drainable.gate_to_size(maxf(gate, 0.1)))
	target.set("blocking", blocking)
	target.position = Vector3(p.x, float(region.ground_height(p.x, p.y)), p.y)
	target.rotation.y = yaw
	target.ground_position = Callable(region, "ground_position")
	target.set_meta(&"zone", region.get_zone_at(region.to_global(target.position)))
	region._register_target(target, capacity)
	return target

static func _place_lamp(region: Node3D, p: Vector2) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.name = "CityLamp"
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.08, 0.10, 0.09)
	metal.roughness = 0.75
	_part(lamp, Vector3(0, 2.65, 0), Vector3(0.16, 5.3, 0.16), metal)
	_part(lamp, Vector3(0.35, 5.3, 0), Vector3(0.8, 0.12, 0.14), metal)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.76, 0.47)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.43, 0.13)
	glow.emission_energy_multiplier = 5.0
	_part(lamp, Vector3(0.68, 5.12, 0), Vector3(0.5, 0.28, 0.42), glow)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.68, 5.0, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.0
	light.omni_range = 14
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 2.5
	light.distance_fade_enabled = true
	light.distance_fade_begin = 90
	light.distance_fade_length = 30
	lamp.add_child(light)
	for child: Node in lamp.get_children():
		child.owner = lamp
	var scene: PackedScene = PackedScene.new()
	scene.pack(lamp)
	lamp.free()
	var target: Node3D = Catalog.instantiate_model(&"city_lamp", scene, null, Vector3(0.8, 5.4, 0.8), 4.0, false)
	target.preserve_model_lights = true
	target.position = Vector3(p.x, float(region.ground_height(p.x, p.y)), p.y)
	target.rotation.y = 0.0
	target.ground_position = Callable(region, "ground_position")
	target.set_meta(&"zone", region.get_zone_at(region.to_global(target.position)))
	region._register_target(target, 4.0)

static func _traffic_signal(root: Node3D, p: Vector2, yaw: float) -> void:
	var post: Node3D = Node3D.new()
	post.name = "TrafficSignal"
	post.position = Vector3(p.x, 0.5, p.y)
	post.rotation.y = yaw
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.08, 0.09, 0.08)
	metal.roughness = 0.8
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.95, 0.16, 0.08)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.08, 0.02)
	red.emission_energy_multiplier = 4.0
	_part(post, Vector3(0, 2.4, 0), Vector3(0.14, 4.8, 0.14), metal)
	_part(post, Vector3(0, 4.65, 0.28), Vector3(0.42, 0.9, 0.24), metal)
	_part(post, Vector3(0, 4.92, 0.41), Vector3(0.2, 0.2, 0.06), red)
	root.add_child(post)

static func _part(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

static func _add_formal_paths(region: Node3D, surface: SurfaceTool, center: Vector2) -> void:
	_add_rect(surface, Rect2(center - Vector2(36.0, 2.0), Vector2(72.0, 4.0)), region, 0.112)
	_add_rect(surface, Rect2(center - Vector2(2.0, 36.0), Vector2(4.0, 72.0)), region, 0.112)

static func _add_woodland_path(region: Node3D, surface: SurfaceTool, center: Vector2) -> void:
	var points: Array[Vector2] = [
		center + Vector2(0.0, 36.0),
		center + Vector2(-3.0, 22.0),
		center + Vector2(4.0, 10.0),
		center + Vector2(0.0, 0.0),
		center + Vector2(-8.0, -12.0),
		center + Vector2(-16.0, -24.0),
		center + Vector2(-28.0, -33.0),
	]
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var direction: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-direction.y, direction.x) * 2.0
		_add_quad(surface, a - side, a + side, b - side, b + side, region, 0.112)

static func _add_plaza_pavement(region: Node3D, surface: SurfaceTool, center: Vector2) -> void:
	_add_rect(surface, Rect2(center - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), region, 0.113)

static func _add_staging_yard(region: Node3D, surface: SurfaceTool, center: Vector2) -> void:
	_add_rect(surface, Rect2(center - Vector2(28.0, 32.0), Vector2(56.0, 64.0)), region, 0.113)

static func _add_rect(surface: SurfaceTool, rect: Rect2, region: Node3D, offset: float) -> void:
	var min_x: float = rect.position.x
	var min_z: float = rect.position.y
	var max_x: float = rect.end.x
	var max_z: float = rect.end.y
	_add_quad(surface, Vector2(min_x, min_z), Vector2(max_x, min_z), Vector2(min_x, max_z), Vector2(max_x, max_z), region, offset)

static func _add_quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, region: Node3D, offset: float) -> void:
	var ya: float = float(region.ground_height(a.x, a.y)) + offset
	var yb: float = float(region.ground_height(b.x, b.y)) + offset
	var yc: float = float(region.ground_height(c.x, c.y)) + offset
	var yd: float = float(region.ground_height(d.x, d.y)) + offset
	for vertex: Vector3 in [Vector3(a.x, ya, a.y), Vector3(b.x, yb, b.y), Vector3(c.x, yc, c.y), Vector3(b.x, yb, b.y), Vector3(d.x, yd, d.y), Vector3(c.x, yc, c.y)]:
		surface.set_uv(Vector2(vertex.x, vertex.z) / 8.0)
		surface.add_vertex(vertex)

static func _commit(surface: SurfaceTool, name: String, material: Material, parent: Node3D) -> void:
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

static func _material(texture: Texture2D, color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = color
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func _face(center: Vector2, p: Vector2) -> float:
	var direction: Vector2 = center - p
	return atan2(-direction.x, -direction.y)
