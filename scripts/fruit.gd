class_name Fruit
extends RefCounted
## The six fruit and the bomb (about 1.6 studs across). Each is one smooth mesh made in code (scripts/shapes.gd) and
## kept, so putting a fruit on a shelf is cheap. The Roblox version stacked balls and blocks; these keep its colours
## and sizes but have real silhouettes: a lathed apple, pear and strawberry, curved bananas and stems.

const STEM := Color8(110, 75, 40)
const LEAF := Color8(70, 185, 70)
const LEAF_DARK := Color8(46, 140, 60)
const WHITE := Color(1, 1, 1)

static var _meshes := {}


## A new fruit (or "bomb") standing at the origin of the node returned.
static func build(kind: String) -> Node3D:
	var model := Node3D.new()
	model.name = "Item_" + kind
	var body := MeshInstance3D.new()
	body.mesh = _mesh(kind)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(body)
	if kind == "bomb":
		# The lit end of the fuse is its own part, so it can flicker.
		var spark := Parts.part(model, Vector3.ONE * 0.3, Transform3D(Basis.IDENTITY, Vector3(0.42, 1.08, 0)), Color8(255, 190, 60), Parts.NEON, "ball", 1.0, true)
		spark.name = "Spark"
	return model


static func clear_cache() -> void:
	_meshes.clear()


static func _mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		var b := Shapes.Builder.new()
		match kind:
			"bomb":
				_bomb(b)
			"apple":
				_apple(b)
			"banana":
				_banana(b)
			"orange":
				_orange(b)
			"cherry":
				_cherry(b)
			"strawberry":
				_strawberry(b)
			_:
				_pear(b)
		_meshes[kind] = b.build()
	return _meshes[kind]


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


# A leaf: a flattened ellipsoid, tilted.
static func _leaf(b: Shapes.Builder, at: Vector3, tilt_deg: float, yaw_deg := 0.0, length := 0.6, color := LEAF) -> void:
	b.ball(at, Vector3(length, 0.09, length * 0.48), color, Parts.PLASTIC, Parts.rot(0, deg_to_rad(yaw_deg), deg_to_rad(tilt_deg)))


# The glint every fruit has, up and to the left on the side facing you.
static func _shine(b: Shapes.Builder, at: Vector3, size := 0.24) -> void:
	b.ball(at, Vector3(size, size * 1.35, size * 0.5), WHITE, Parts.NEON, Parts.rot(0, deg_to_rad(-25), deg_to_rad(25)))


static func _apple(b: Shapes.Builder) -> void:
	var red := Color8(225, 35, 45)
	# Wider at the shoulders than the base, with a dimple top and bottom.
	var profile := [Vector2(0.0, -0.5), Vector2(0.18, -0.63), Vector2(0.38, -0.67), Vector2(0.54, -0.57), Vector2(0.67, -0.34),
		Vector2(0.75, -0.02), Vector2(0.77, 0.26), Vector2(0.69, 0.5), Vector2(0.52, 0.67), Vector2(0.32, 0.72), Vector2(0.15, 0.64), Vector2(0.0, 0.5)]
	b.add(Shapes.lathe(Shapes.smooth(profile), 28), _at(0, -0.02, 0), red)
	b.add(Shapes.tube([Vector3(0, 0.5, 0), Vector3(0.02, 0.72, 0), Vector3(0.08, 0.95, 0)], [0.05, 0.045, 0.06]), Transform3D.IDENTITY, STEM)
	_leaf(b, Vector3(0.36, 0.88, 0.02), 24.0)
	_shine(b, Vector3(-0.4, 0.3, 0.6))


static func _orange(b: Shapes.Builder) -> void:
	var orange := Color8(255, 140, 20)
	b.ball(Vector3(0, -0.05, 0), Vector3(1.56, 1.46, 1.56), orange)
	# The star where the stalk was, and a leaf.
	b.add(Parts.mesh_for("cylinder", Vector3(0.06, 0.26, 0.26)), Parts.cf(Vector3(0, 0.67, 0), 0, 0, 90) * Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO), Color8(96, 130, 46))
	_leaf(b, Vector3(0.26, 0.74, 0.05), 18.0, 30.0, 0.56, LEAF_DARK)
	_shine(b, Vector3(-0.4, 0.3, 0.58))


static func _pear(b: Shapes.Builder) -> void:
	var green := Color8(182, 218, 62)
	var profile := [Vector2(0.0, -0.84), Vector2(0.3, -0.86), Vector2(0.56, -0.72), Vector2(0.7, -0.45), Vector2(0.7, -0.15),
		Vector2(0.58, 0.14), Vector2(0.42, 0.38), Vector2(0.34, 0.6), Vector2(0.3, 0.76), Vector2(0.2, 0.9), Vector2(0.0, 0.94)]
	b.add(Shapes.lathe(Shapes.smooth(profile), 28), _at(0, -0.02, 0), green)
	b.add(Shapes.tube([Vector3(0, 0.88, 0), Vector3(0.03, 1.02, 0), Vector3(0.1, 1.16, 0)], [0.05, 0.045, 0.055]), Transform3D.IDENTITY, STEM)
	_leaf(b, Vector3(0.34, 1.02, 0.0), 20.0, 0.0, 0.5)
	_shine(b, Vector3(-0.32, -0.2, 0.6))


static func _strawberry(b: Shapes.Builder) -> void:
	var red := Color8(235, 40, 60)
	var profile := [Vector2(0.0, -0.86), Vector2(0.16, -0.76), Vector2(0.38, -0.46), Vector2(0.56, -0.1), Vector2(0.66, 0.22),
		Vector2(0.64, 0.46), Vector2(0.5, 0.62), Vector2(0.26, 0.7), Vector2(0.0, 0.7)]
	b.add(Shapes.lathe(Shapes.smooth(profile), 28), Transform3D.IDENTITY, red)
	# Seeds, in rows round the body, each sitting on the skin.
	var rows := [[-0.5, 4, 0.36], [-0.2, 6, 0.52], [0.1, 7, 0.63], [0.38, 7, 0.66]]
	for k in rows.size():
		var row: Array = rows[k]
		for i in int(row[1]):
			var a := TAU * (i + 0.5 * (k % 2)) / int(row[1])
			b.ball(Vector3(cos(a) * row[2], row[0], sin(a) * row[2]), Vector3(0.09, 0.12, 0.09), Color8(255, 226, 120))
	# A crown of leaves and a stalk.
	for i in 6:
		var yaw := 60.0 * i
		var out := Parts.rot(0, deg_to_rad(yaw), 0) * Vector3(0.3, 0, 0)
		b.ball(Vector3(out.x, 0.7, out.z), Vector3(0.56, 0.1, 0.26), LEAF, Parts.PLASTIC, Parts.rot(0, deg_to_rad(yaw), deg_to_rad(-16)))
	b.add(Shapes.tube([Vector3(0, 0.68, 0), Vector3(0.02, 0.84, 0), Vector3(0.08, 0.98, 0)], [0.05, 0.045, 0.05]), Transform3D.IDENTITY, LEAF_DARK)
	_shine(b, Vector3(-0.3, 0.26, 0.56), 0.2)


static func _banana(b: Shapes.Builder) -> void:
	# A hand of three: each a curved tube, fat in the middle and tapering to its ends, joined at the stalk.
	var yellow := Color8(255, 215, 50)
	var centre := Vector3(0, 0.42, 0)
	var steps := 10
	var path := Shapes.arc(centre, 0.86, -62.0, 62.0, steps)
	var radii: Array = []
	for i in steps + 1:
		var k := float(i) / steps
		radii.append(0.08 + 0.15 * sin(PI * clampf(k * 0.92 + 0.06, 0.0, 1.0)))
	var one := Shapes.tube(path, radii, 9)
	var stalk: Vector3 = path[0]
	for i in 3:
		var fan := (i - 1) * 20.0
		# Swing each banana about the stalk, so they splay like a hand.
		var swing := Transform3D(Basis.IDENTITY, stalk) * Transform3D(Parts.rot(0, deg_to_rad(fan), 0), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -stalk)
		b.add(one, swing, yellow.lerp(Color8(232, 182, 30), i * 0.22))
		b.ball(swing * (path[steps] as Vector3), Vector3.ONE * 0.17, Color8(84, 58, 32))
	b.add(Shapes.tube([stalk + Vector3(0.05, -0.02, 0), stalk + Vector3(-0.08, 0.1, 0), stalk + Vector3(-0.16, 0.28, 0)], [0.13, 0.1, 0.09]), Transform3D.IDENTITY, Color8(124, 140, 48))


static func _cherry(b: Shapes.Builder) -> void:
	# Two cherries on stems that meet at the top.
	var red := Color8(200, 20, 45)
	var top := Vector3(0.12, 0.92, 0)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.44, -0.42, side * 0.06)
		b.ball(at, Vector3(0.86, 0.82, 0.86), red)
		_shine(b, at + Vector3(-0.2, 0.14, 0.34), 0.13)
		var from := at + Vector3(0, 0.36, 0)
		var bend := from.lerp(top, 0.5) + Vector3(side * 0.12, 0.08, 0)
		var stem := Shapes.smooth([from, bend, top], 5)
		var thick: Array = []
		thick.resize(stem.size())
		thick.fill(0.04)
		b.add(Shapes.tube(stem, thick, 8), Transform3D.IDENTITY, Color8(80, 140, 50))
	_leaf(b, top + Vector3(0.28, 0.06, 0), 16.0, 0.0, 0.58)


static func _bomb(b: Shapes.Builder) -> void:
	b.ball(Vector3(0, -0.1, 0), Vector3.ONE * 1.5, Color8(28, 28, 34))
	b.add(Parts.mesh_for("cylinder", Vector3(0.26, 0.5, 0.5)), Parts.cf(Vector3(0, 0.66, 0), 0, 0, 90) * Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO), Color8(70, 72, 82), Parts.METAL)
	b.add(Shapes.tube([Vector3(0, 0.76, 0), Vector3(0.1, 0.96, 0), Vector3(0.28, 1.06, 0), Vector3(0.42, 1.08, 0)], [0.045, 0.045, 0.045, 0.045], 8), Transform3D.IDENTITY, Color8(160, 130, 86))
	b.ball(Vector3(-0.38, 0.22, 0.52), Vector3(0.3, 0.38, 0.16), Color8(120, 120, 140), Parts.PLASTIC, Parts.rot(0, deg_to_rad(-25), deg_to_rad(25)))
