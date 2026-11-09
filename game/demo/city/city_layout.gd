extends RefCounted

const Assets = preload("res://game/demo/city/city_assets.gd")

const X_STREETS: Array[float] = [-192.0, -96.0, 0.0, 96.0, 192.0]
const Z_STREETS: Array[float] = [-220.0, -340.0, -460.0, -580.0, -700.0]
const ROAD_HALF: float = 6.0
const WALK_WIDTH: float = 4.0
const BUILDING_INSET: float = 12.5
const MAX_FOOTPRINT: float = 34.0
const HOUSE_MAX_FOOTPRINT: float = 10.0
const HOUSE_CLEARANCE: float = 3.0
const CITY_EDGE: float = -190.0
const CITY_BACK: float = -760.0
const DOWNTOWN_EDGE: float = -460.0

const RESERVED: Dictionary = {
	Vector2i(1, 0): &"park_formal",
	Vector2i(2, 1): &"staging",
	Vector2i(1, 2): &"plaza",
	Vector2i(3, 3): &"park_woodland",
}

const RESIDENTIAL_LOTS: Dictionary[Vector2i, Array] = {
	Vector2i(0, 0): [0, 1, 2, 3],
	Vector2i(2, 0): [0, 1, 2, 3],
	Vector2i(3, 0): [0, 1, 2, 3],
	Vector2i(0, 1): [0, 2, 3],
	Vector2i(1, 1): [0, 1, 2, 3],
	Vector2i(3, 1): [0, 1, 3],
	Vector2i(0, 2): [1, 3, 4],
	Vector2i(2, 2): [0, 1, 2],
	Vector2i(3, 2): [0, 3],
	Vector2i(0, 3): [1, 4],
	Vector2i(1, 3): [2, 3],
	Vector2i(2, 3): [0, 1],
}

static func build() -> Dictionary:
	var buildings: Array[Dictionary] = _buildings()
	return {
		"buildings": buildings,
		"reserved": _reserved_spaces(),
		"road_rects": road_rects(),
		"sidewalk_rects": sidewalk_rects(),
		"crosswalk_rects": crosswalk_rects(),
		"pedestrian_points": _pedestrian_points(),
		"spawn_points": _spawn_points(),
		"parking": _parking(),
		"traffic_routes": _traffic_routes(),
		"tank_routes": _tank_routes(),
	}

static func block_center(ix: int, iz: int) -> Vector2:
	return Vector2((X_STREETS[ix] + X_STREETS[ix + 1]) * 0.5, (Z_STREETS[iz] + Z_STREETS[iz + 1]) * 0.5)

static func block_rect(ix: int, iz: int) -> Rect2:
	return _rect(X_STREETS[ix], X_STREETS[ix + 1], Z_STREETS[iz], Z_STREETS[iz + 1])

static func road_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var z_intervals: Array[Vector2] = [
		Vector2(CITY_EDGE, -214.0),
		Vector2(-226.0, -334.0),
		Vector2(-346.0, -454.0),
		Vector2(-466.0, -574.0),
		Vector2(-586.0, -694.0),
		Vector2(-706.0, CITY_BACK),
	]
	var x_intervals: Array[Vector2] = [
		Vector2(-240.0, -198.0),
		Vector2(-186.0, -102.0),
		Vector2(-90.0, -6.0),
		Vector2(6.0, 90.0),
		Vector2(102.0, 186.0),
		Vector2(198.0, 240.0),
	]
	for x: float in X_STREETS:
		for interval: Vector2 in z_intervals:
			rects.append(_rect(x - ROAD_HALF, x + ROAD_HALF, interval.x, interval.y))
	for z: float in Z_STREETS:
		for interval: Vector2 in x_intervals:
			rects.append(_rect(interval.x, interval.y, z - ROAD_HALF, z + ROAD_HALF))
		for x: float in X_STREETS:
			rects.append(_rect(x - ROAD_HALF, x + ROAD_HALF, z - ROAD_HALF, z + ROAD_HALF))
	return rects

static func sidewalk_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var outer: float = ROAD_HALF
	var inner: float = ROAD_HALF + WALK_WIDTH
	for ix: int in 4:
		for iz: int in 4:
			var x0: float = X_STREETS[ix]
			var x1: float = X_STREETS[ix + 1]
			var z0: float = Z_STREETS[iz]
			var z1: float = Z_STREETS[iz + 1]
			rects.append(_rect(x0 + outer, x1 - outer, z0 + inner, z0 + outer))
			rects.append(_rect(x0 + outer, x1 - outer, z1 - outer, z1 - inner))
			rects.append(_rect(x0 + inner, x0 + outer, z0 + inner, z1 - inner))
			rects.append(_rect(x1 - outer, x1 - inner, z0 + inner, z1 - inner))
	return rects

static func crosswalk_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for x: float in X_STREETS:
		for z: float in Z_STREETS:
			for side: float in [-1.0, 1.0]:
				var stripe_z: float = z + side * 7.6
				for i: int in 6:
					var stripe_x: float = x - 4.15 + i * 1.66
					rects.append(_rect(stripe_x, stripe_x + 0.72, stripe_z - 1.0, stripe_z + 1.0))
				var stripe_x2: float = x + side * 7.6
				for i: int in 6:
					var stripe_z2: float = z - 4.15 + i * 1.66
					rects.append(_rect(stripe_x2 - 1.0, stripe_x2 + 1.0, stripe_z2, stripe_z2 + 0.72))
	return rects

static func _buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: int = 0
	for iz: int in 4:
		for ix: int in 4:
			if RESERVED.has(Vector2i(ix, iz)):
				continue
			var center: Vector2 = block_center(ix, iz)
			var corners: Array[Vector2] = [
				Vector2(-1.0, -1.0),
				Vector2(1.0, -1.0),
				Vector2(-1.0, 1.0),
				Vector2(1.0, 1.0),
			]
			for corner: int in corners.size():
				var tall: bool = _is_tall(ix, iz, corner)
				var height: float = _height_for(iz, ix, corner, tall, index)
				var kind: StringName = _kind_for(iz, tall, index + corner * 3 + ix * 5 + iz * 7)
				var dims: Vector3 = _fit_dimensions(kind, height)
				if maxf(dims.x, dims.z) > MAX_FOOTPRINT + 0.01:
					continue
				var direction: Vector2 = corners[corner]
				var x: float = center.x + direction.x * ((X_STREETS[ix + 1] - X_STREETS[ix]) * 0.5 - BUILDING_INSET - dims.x * 0.5)
				var z: float = center.y + direction.y * ((Z_STREETS[iz] - Z_STREETS[iz + 1]) * 0.5 - BUILDING_INSET - dims.z * 0.5)
				out.append({
					"kind": kind,
					"position": Vector2(x, z),
					"dimensions": dims,
					"yaw": _street_yaw(x, z, X_STREETS[ix], X_STREETS[ix + 1], Z_STREETS[iz], Z_STREETS[iz + 1]),
					"district": _district_for(iz),
					"index": index,
					"tall": tall,
				})
				index += 1
	var house_index: int = 0
	for iz: int in 4:
		for ix: int in 4:
			if RESERVED.has(Vector2i(ix, iz)):
				continue
			house_index = _append_infill_houses(out, ix, iz, index, house_index)
	var police: Dictionary = _police_station()
	out.append(police)
	return out

static func _append_infill_houses(buildings: Array[Dictionary], ix: int, iz: int, index: int, house_index: int) -> int:
	var kinds: Array[StringName] = [&"city_house_1", &"city_house_2", &"city_house_3"]
	var dims_by_kind: Dictionary = {}
	for kind: StringName in kinds:
		var dims: Vector3 = _fit_dimensions(kind, 9.0)
		var footprint_scale: float = minf(1.0, HOUSE_MAX_FOOTPRINT / maxf(dims.x, dims.z))
		dims *= footprint_scale
		dims_by_kind[kind] = dims
	var center: Vector2 = block_center(ix, iz)
	var candidates: Array[Vector2] = [
		center + Vector2(-10.0, -10.0), center + Vector2(10.0, -10.0),
		center + Vector2(-10.0, 10.0), center + Vector2(10.0, 10.0),
		center + Vector2(-10.0, 0.0), center + Vector2(10.0, 0.0),
		center + Vector2(0.0, -10.0), center + Vector2(0.0, 10.0),
	]
	for candidate_index: int in RESIDENTIAL_LOTS[Vector2i(ix, iz)]:
		var kind: StringName = kinds[(ix * 3 + iz + candidate_index) % kinds.size()]
		var dims: Vector3 = dims_by_kind[kind]
		var position: Vector2 = candidates[candidate_index]
		var yaw: float = _street_yaw(position.x, position.y, X_STREETS[ix], X_STREETS[ix + 1], Z_STREETS[iz], Z_STREETS[iz + 1])
		if not _infill_candidate_clear(position, dims, yaw, buildings, ix, iz):
			continue
		var entry: Dictionary = {
			"kind": kind,
			"position": position,
			"dimensions": dims,
			"yaw": yaw,
			"district": _district_for(iz),
			"index": index + house_index,
			"tall": false,
		}
		buildings.append(entry)
		house_index += 1
	return house_index

static func _infill_candidate_clear(position: Vector2, dims: Vector3, yaw: float, buildings: Array[Dictionary], ix: int, iz: int) -> bool:
	var half: Vector2 = _footprint_half_extents(dims, yaw)
	var block: Rect2 = block_rect(ix, iz)
	if position.x - half.x < block.position.x + ROAD_HALF + WALK_WIDTH + HOUSE_CLEARANCE:
		return false
	if position.x + half.x > block.end.x - ROAD_HALF - WALK_WIDTH - HOUSE_CLEARANCE:
		return false
	if position.y - half.y < block.position.y + ROAD_HALF + WALK_WIDTH + HOUSE_CLEARANCE:
		return false
	if position.y + half.y > block.end.y - ROAD_HALF - WALK_WIDTH - HOUSE_CLEARANCE:
		return false
	for existing: Dictionary in buildings:
		if not _footprints_separated(position, half, existing["position"], _footprint_half_extents(existing["dimensions"], float(existing["yaw"])), HOUSE_CLEARANCE):
			return false
	var midpoint: Vector2 = Vector2((X_STREETS[ix] + X_STREETS[ix + 1]) * 0.5, (Z_STREETS[iz] + Z_STREETS[iz + 1]) * 0.5)
	var frontage_props: Array[Vector2] = [
		Vector2(X_STREETS[ix] + 10.8, midpoint.y),
		Vector2(X_STREETS[ix + 1] - 10.8, midpoint.y),
	]
	for prop: Vector2 in frontage_props:
		if _footprints_overlap_circle(position, half, prop, 6.0):
			return false
	for side_x: float in [-1.0, 1.0]:
		var lamp: Vector2 = Vector2(X_STREETS[ix] + side_x * 8.5, midpoint.y)
		if _footprints_overlap_circle(position, half, lamp, 5.0):
			return false
	for signal_position: Vector2 in [Vector2(-96.0, -340.0), Vector2(0.0, -340.0), Vector2(96.0, -340.0), Vector2(-96.0, -460.0), Vector2(0.0, -460.0), Vector2(96.0, -460.0), Vector2(-96.0, -580.0), Vector2(0.0, -580.0), Vector2(96.0, -580.0)]:
		if _footprints_overlap_circle(position, half, signal_position + Vector2(8.8, 8.8), 5.0):
			return false
	return true

static func _footprint_half_extents(dims: Vector3, yaw: float) -> Vector2:
	var swaps_axes: bool = absf(cos(yaw)) < 0.5
	var width: float = dims.z if swaps_axes else dims.x
	var depth: float = dims.x if swaps_axes else dims.z
	return Vector2(width * 0.5, depth * 0.5)

static func _footprints_separated(a: Vector2, a_half: Vector2, b: Vector2, b_half: Vector2, clearance: float) -> bool:
	return absf(a.x - b.x) >= a_half.x + b_half.x + clearance or absf(a.y - b.y) >= a_half.y + b_half.y + clearance

static func _footprints_overlap_circle(position: Vector2, half: Vector2, circle: Vector2, radius: float) -> bool:
	var closest: Vector2 = Vector2(clampf(circle.x, position.x - half.x, position.x + half.x), clampf(circle.y, position.y - half.y, position.y + half.y))
	return closest.distance_squared_to(circle) < radius * radius

static func _reserved_spaces() -> Dictionary:
	return {
		"park_formal": block_center(1, 0),
		"staging": block_center(2, 1),
		"plaza": block_center(1, 2),
		"park_woodland": block_center(3, 3),
	}

static func _police_station() -> Dictionary:
	var center: Vector2 = block_center(2, 1)
	var kind: StringName = &"city_police"
	var dims: Vector3 = _fit_dimensions(kind, 16.0)
	return {
		"kind": kind,
		"position": Vector2(center.x - 22.0, center.y + 22.0),
		"dimensions": dims,
		"yaw": PI,
		"district": &"midrise",
		"index": 999,
		"tall": false,
	}

static func _is_tall(ix: int, iz: int, corner: int) -> bool:
	if iz < 2:
		return false
	if corner == 0:
		return true
	return corner == 2 and ((ix == 2 and iz == 2) or (ix == 1 and iz == 3))

static func _height_for(iz: int, ix: int, corner: int, tall: bool, index: int) -> float:
	if iz == 0:
		return 14.0 + float((index * 5 + corner * 3) % 15)
	if iz == 1:
		return 27.0 + float((index * 7 + corner * 5 + ix) % 34)
	if tall:
		return 92.0 + float((index * 11 + corner * 7) % 34)
	return 56.0 + float((index * 9 + corner * 4 + ix) % 31)

static func _kind_for(iz: int, tall: bool, index: int) -> StringName:
	if tall:
		var towers: Array[StringName] = [&"city_tower_1", &"city_tower_2", &"city_tower_3", &"city_tower_4"]
		return towers[index % towers.size()]
	if iz >= 2:
		var downtown: Array[StringName] = [&"city_highrise_1", &"city_highrise_2", &"city_highrise_3", &"city_office", &"city_apartment", &"city_loft"]
		return downtown[index % downtown.size()]
	if iz == 1:
		var midrise: Array[StringName] = [&"city_highrise_1", &"city_highrise_2", &"city_office", &"city_apartment", &"city_clinic", &"city_loft"]
		return midrise[index % midrise.size()]
	var outskirts: Array[StringName] = [&"city_storefront_1", &"city_loft", &"city_workshop", &"city_clinic", &"city_shop"]
	return outskirts[index % outskirts.size()]

static func _fit_dimensions(kind: StringName, height: float) -> Vector3:
	var base: Vector3 = Assets.building_base(kind)
	var scale: float = height / base.y
	var dims: Vector3 = base * scale
	var widest: float = maxf(dims.x, dims.z)
	if widest > MAX_FOOTPRINT:
		scale *= MAX_FOOTPRINT / widest
		dims = base * scale
		dims.x = minf(dims.x, MAX_FOOTPRINT)
		dims.z = minf(dims.z, MAX_FOOTPRINT)
	return dims

static func _district_for(iz: int) -> StringName:
	if iz >= 2:
		return &"downtown"
	if iz == 1:
		return &"midrise"
	return &"outskirts"

static func _street_yaw(x: float, z: float, x0: float, x1: float, z0: float, z1: float) -> float:
	var west: float = absf(x - x0)
	var east: float = absf(x1 - x)
	var south: float = absf(z - z0)
	var north: float = absf(z1 - z)
	var nearest: float = minf(west, minf(east, minf(south, north)))
	var direction: Vector2 = Vector2.ZERO
	if is_equal_approx(nearest, west):
		direction = Vector2.LEFT
	elif is_equal_approx(nearest, east):
		direction = Vector2.RIGHT
	elif is_equal_approx(nearest, south):
		direction = Vector2.DOWN
	else:
		direction = Vector2.UP
	return atan2(-direction.x, -direction.y)

static func _pedestrian_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var offset: float = ROAD_HALF + 2.4
	for street: float in X_STREETS:
		for i: int in 26:
			var z: float = -206.0 - i * 19.0
			if _near_z_intersection(z):
				continue
			points.append(Vector2(street - offset, z))
			points.append(Vector2(street + offset, z))
	for street: float in Z_STREETS:
		for i: int in 20:
			var x: float = -206.0 + i * 19.0
			if _near_x_intersection(x):
				continue
			points.append(Vector2(x, street - offset))
			points.append(Vector2(x, street + offset))
	for x: float in X_STREETS:
		for z: float in Z_STREETS:
			for dx: float in [-8.5, 8.5]:
				for dz: float in [-8.5, 8.5]:
					points.append(Vector2(x + dx, z + dz))
	for center: Vector2 in [block_center(1, 0), block_center(3, 3), block_center(1, 2), block_center(2, 1)]:
		for dx: float in [-18.0, -8.0, 8.0, 18.0]:
			for dz: float in [-18.0, -8.0, 8.0, 18.0]:
				points.append(center + Vector2(dx, dz))
	return points

static func _spawn_points() -> Array[Vector2]:
	return [
		Vector2(-87.5, -206.0), Vector2(87.5, -242.0), Vector2(-104.5, -312.0), Vector2(104.5, -305.0),
		Vector2(-87.5, -365.0), Vector2(87.5, -430.0), Vector2(-104.5, -455.0), Vector2(104.5, -482.0),
		Vector2(-87.5, -545.0), Vector2(87.5, -615.0), Vector2(-104.5, -645.0), Vector2(104.5, -675.0),
		Vector2(-48.0, -300.0), Vector2(130.0, -610.0), Vector2(-70.0, -520.0), Vector2(20.0, -390.0),
	]

static func _parking() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vertical_intervals: Array[Vector2] = [
		Vector2(-220.0, -340.0), Vector2(-340.0, -460.0),
		Vector2(-460.0, -580.0), Vector2(-580.0, -700.0),
	]
	for street_index: int in X_STREETS.size():
		var x: float = X_STREETS[street_index]
		for interval_index: int in vertical_intervals.size():
			var interval: Vector2 = vertical_intervals[interval_index]
			var side: float = -1.0 if (street_index + interval_index) % 2 == 0 else 1.0
			out.append({"position": Vector2(x + side * 4.7, (interval.x + interval.y) * 0.5), "yaw": 0.0 if side > 0.0 else PI})
	var cross_intervals: Array[Vector2] = [
		Vector2(-192.0, -96.0), Vector2(-96.0, 0.0), Vector2(0.0, 96.0), Vector2(96.0, 192.0),
	]
	for street_index: int in Z_STREETS.size():
		var z: float = Z_STREETS[street_index]
		for interval_index: int in cross_intervals.size():
			var interval: Vector2 = cross_intervals[interval_index]
			var side: float = -1.0 if (street_index + interval_index) % 2 == 0 else 1.0
			out.append({"position": Vector2((interval.x + interval.y) * 0.5, z + side * 4.7), "yaw": PI * 0.5 if side > 0.0 else -PI * 0.5})
	for extra: Vector2 in [Vector2(-187.3, -515.0), Vector2(196.7, -515.0), Vector2(-187.3, -625.0), Vector2(196.7, -625.0)]:
		out.append({"position": extra, "yaw": 0.0})
	return out

static func _traffic_routes() -> Array[PackedVector3Array]:
	return [
		_loop(-192.0, 192.0, -700.0, -220.0, 2.8),
		_loop(-96.0, 96.0, -580.0, -340.0, 2.8),
		_loop(-96.0, 96.0, -700.0, -460.0, 2.8),
		_loop(-192.0, 0.0, -460.0, -220.0, 2.8),
	]

static func _tank_routes() -> Array[PackedVector3Array]:
	return [
		_loop(-192.0, 192.0, -700.0, -220.0, 1.8),
		_loop(-192.0, 96.0, -460.0, -220.0, 1.8),
		_loop(-96.0, 192.0, -700.0, -460.0, 1.8),
		_loop(-96.0, 96.0, -580.0, -340.0, 1.8),
	]

static func _loop(x0: float, x1: float, z0: float, z1: float, offset: float) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var west: float = x0 - offset
	var east: float = x1 + offset
	var south: float = z1 + offset
	var north: float = z0 - offset
	for point: Vector2 in [
		Vector2(west, south), Vector2((west + east) * 0.5, south),
		Vector2(east, south), Vector2(east, (south + north) * 0.5),
		Vector2(east, north), Vector2((west + east) * 0.5, north),
		Vector2(west, north), Vector2(west, (south + north) * 0.5),
	]:
		points.append(Vector3(point.x, 0.0, point.y))
	return points

static func _near_z_intersection(z: float) -> bool:
	for street: float in Z_STREETS:
		if absf(z - street) < 10.0:
			return true
	return false

static func _near_x_intersection(x: float) -> bool:
	for street: float in X_STREETS:
		if absf(x - street) < 10.0:
			return true
	return false

static func _rect(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	var min_x: float = minf(x0, x1)
	var min_z: float = minf(z0, z1)
	return Rect2(Vector2(min_x, min_z), Vector2(absf(x1 - x0), absf(z1 - z0)))
