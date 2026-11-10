extends RefCounted


static func build() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_taper(surface, Vector3.ZERO, Vector3(0.0, 0.86, 0.0), 0.018, 0.006, Color(0.68, 0.72, 0.40))
	for level: int in 3:
		var height: float = 0.23 + level * 0.19
		var direction := Vector3(cos(level * 2.4), 0.0, sin(level * 2.4))
		var root := Vector3(0.0, height, 0.0)
		var middle: Vector3 = root + direction * 0.17 + Vector3.UP * 0.09
		var side: Vector3 = direction.cross(Vector3.UP) * 0.022
		_add_triangle(surface, root, middle + side, middle + direction * 0.16 - Vector3.UP * 0.04, Color(0.58, 0.66, 0.31))
		_add_triangle(surface, root, middle + direction * 0.16 - Vector3.UP * 0.04, middle - side, Color(0.58, 0.66, 0.31))
	for level: int in 5:
		var height: float = 0.84 + level * 0.043
		var width: float = 0.035 * (1.0 - level * 0.10)
		for side: int in 2:
			var direction := Vector3(-1.0 if side == 0 else 1.0, 0.0, 0.0)
			var root := Vector3(0.0, height, 0.0)
			_add_taper(surface, root, root + direction * width + Vector3.UP * 0.075, 0.023, 0.002, Color(1.0, 0.90, 0.59))
	surface.generate_normals()
	return surface.commit()


static func _add_taper(surface: SurfaceTool, start: Vector3, end: Vector3, base_radius: float, tip_radius: float, color: Color) -> void:
	var axis: Vector3 = (end - start).normalized()
	var tangent: Vector3 = axis.cross(Vector3.FORWARD).normalized()
	var bitangent: Vector3 = axis.cross(tangent).normalized()
	for side: int in 4:
		var angle: float = side * TAU / 4.0
		var next_angle: float = (side + 1) * TAU / 4.0
		var radial: Vector3 = tangent * cos(angle) + bitangent * sin(angle)
		var next_radial: Vector3 = tangent * cos(next_angle) + bitangent * sin(next_angle)
		var a: Vector3 = start + radial * base_radius
		var b: Vector3 = start + next_radial * base_radius
		var c: Vector3 = end + next_radial * tip_radius
		var d: Vector3 = end + radial * tip_radius
		_add_triangle(surface, a, b, c, color)
		_add_triangle(surface, a, c, d, color)


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
