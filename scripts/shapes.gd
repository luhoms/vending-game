class_name Shapes
extends RefCounted
## Meshes made in code for the fruit: a profile turned round an axis (apple, pear, strawberry), a tube along a curve
## (banana, stems), and a Builder that merges many small pieces into one mesh with one surface per material, so a whole
## fruit is a single node and a few draw calls.


## Round off a list of points (Vector2 or Vector3) by running a smooth curve through them: `steps` points per span.
static func smooth(points: Array, steps := 4) -> Array:
	var out: Array = []
	var last := points.size() - 1
	for i in last:
		var p0: Variant = points[maxi(i - 1, 0)]
		var p1: Variant = points[i]
		var p2: Variant = points[i + 1]
		var p3: Variant = points[mini(i + 2, last)]
		for k in steps:
			var t := float(k) / steps
			# Catmull-Rom
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[last])
	return out


## Turn a profile round the Y axis. `profile` is a list of Vector2(radius, height) from the bottom up.
static func lathe(profile: Array, sides := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for point: Vector2 in profile:
		var r := maxf(point.x, 0.0)
		for j in sides:
			var a := TAU * j / sides
			st.add_vertex(Vector3(cos(a) * r, point.y, sin(a) * r))
	_stitch(st, profile.size(), sides)
	st.generate_normals()
	return st.commit()


## A round tube through `points`, `radii[i]` thick at each (0 at an end closes it to a point).
static func tube(points: Array, radii: Array, sides := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var count := points.size()
	for i in count:
		var p: Vector3 = points[i]
		var ahead: Vector3 = points[mini(i + 1, count - 1)]
		var behind: Vector3 = points[maxi(i - 1, 0)]
		var tangent := (ahead - behind).normalized()
		var reference := Vector3.BACK if absf(tangent.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
		var normal := reference.cross(tangent).normalized()
		var binormal := tangent.cross(normal)
		var r: float = radii[i]
		for j in sides:
			var a := TAU * j / sides
			st.add_vertex(p + (normal * cos(a) + binormal * sin(a)) * r)
	_stitch(st, count, sides)
	st.generate_normals()
	return st.commit()


# Join `rings` rings of `sides` vertices each into a skin.
static func _stitch(st: SurfaceTool, rings: int, sides: int) -> void:
	for i in rings - 1:
		for j in sides:
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c := (i + 1) * sides + j
			var d := (i + 1) * sides + (j + 1) % sides
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)


## Points along a circular arc in the XY plane: centre, radius, from/to angles in degrees (0 = straight down).
static func arc(centre: Vector3, radius: float, from_deg: float, to_deg: float, steps: int) -> Array:
	var out: Array = []
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		out.append(centre + Vector3(sin(a) * radius, -cos(a) * radius, 0))
	return out


## Collects pieces by material and turns them into one mesh.
class Builder:
	var _tools := {}
	var _materials := {}

	## Add a mesh, placed by `xform`, in a colour and finish (Parts.PLASTIC and so on).
	func add(mesh: Mesh, xform: Transform3D, color: Color, kind := Parts.PLASTIC) -> void:
		var key := "%s|%d" % [color.to_html(false), kind]
		if not _tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[key] = st
			_materials[key] = Parts.material(color, kind)
		(_tools[key] as SurfaceTool).append_from(mesh, 0, xform)

	## A ball (or, with a non-uniform `size`, an ellipsoid) at `at`.
	func ball(at: Vector3, size: Vector3, color: Color, kind := Parts.PLASTIC, turn := Basis.IDENTITY) -> void:
		add(Parts.mesh_for("ball", Vector3.ONE), Transform3D(turn * Basis.from_scale(size), at), color, kind)

	func build() -> ArrayMesh:
		var out := ArrayMesh.new()
		for key: String in _tools:
			(_tools[key] as SurfaceTool).commit(out)
			out.surface_set_material(out.get_surface_count() - 1, _materials[key])
		return out
