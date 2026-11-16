class_name Fruit
extends RefCounted
## The six fruit and the bomb, built from simple shapes (about 1.6 studs across), part for part as in the Roblox
## version's VendGame.itemModel.

const STEM := Color8(110, 75, 40)
const LEAF := Color8(70, 185, 70)
const WHITE := Color(1, 1, 1)


## A new fruit (or "bomb") standing at the origin of the node returned.
static func build(kind: String) -> Node3D:
	var model := Node3D.new()
	model.name = "Item_" + kind
	var P := Parts
	var v := func(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z)
	var one := Vector3.ONE
	match kind:
		"bomb":
			P.part(model, one * 1.45, P.cf(v.call(0, -0.1, 0)), Color8(28, 28, 34), P.PLASTIC, "ball")
			P.part(model, v.call(0.3, 0.5, 0.5), P.cf(v.call(0, 0.66, 0), 0, 0, 90), Color8(70, 72, 82), P.METAL, "cylinder")
			P.part(model, v.call(0.08, 0.45, 0.08), P.cf(v.call(0.1, 0.98, 0), 0, 0, -25), Color8(150, 120, 80))
			var spark := P.part(model, one * 0.26, P.cf(v.call(0.2, 1.2, 0)), Color8(255, 170, 40), P.NEON, "ball", 1.0, true)
			spark.name = "Spark"
			P.part(model, one * 0.26, P.cf(v.call(-0.35, 0.25, 0.5)), Color8(120, 120, 140), P.PLASTIC, "ball")
		"apple":
			var red := Color8(225, 35, 45)
			P.part(model, one * 1.5, P.cf(v.call(0, -0.05, 0)), red, P.PLASTIC, "ball")
			P.part(model, v.call(0.12, 0.5, 0.5), P.cf(v.call(0, 0.68, 0), 0, 0, 90), red.lerp(Color.BLACK, 0.3), P.PLASTIC, "cylinder")
			P.part(model, v.call(0.1, 0.5, 0.1), P.cf(v.call(0.04, 0.85, 0), 0, 0, -12), STEM)
			_leaf(model, P.cf(v.call(0.32, 0.88, 0), 0, 0, 25))
			P.part(model, one * 0.3, P.cf(v.call(-0.35, 0.3, 0.55)), WHITE, P.NEON, "ball")
		"banana":
			# A bunch of three, each a curve of short yellow segments, joined at a brown stem.
			var yellow := Color8(255, 215, 50)
			var spreads := [-0.32, 0.0, 0.32]
			for b in 3:
				var spread: float = spreads[b]
				for i in 5:
					var angle := deg_to_rad(-60.0 + i * 30.0)
					var x := sin(angle) * 0.85
					var y := -cos(angle) * 0.85 + 0.35
					P.part(model, v.call(0.52, 0.36, 0.34), Transform3D(P.rot(0, 0, angle), v.call(x, y + (b + 1) * 0.05, spread)), yellow.lerp(Color8(230, 180, 30), b * 0.25))
				P.part(model, v.call(0.12, 0.12, 0.12), P.cf(v.call(0.78, 0.0, spread)), Color8(80, 55, 30))
			P.part(model, v.call(0.3, 0.22, 0.6), P.cf(v.call(-0.84, 0.05, 0)), Color8(120, 140, 50))
		"orange":
			var orange := Color8(255, 140, 20)
			P.part(model, one * 1.5, P.cf(v.call(0, -0.05, 0)), orange, P.PLASTIC, "ball")
			P.part(model, v.call(0.1, 0.22, 0.22), P.cf(v.call(0, 0.7, 0), 0, 0, 90), Color8(120, 140, 50), P.PLASTIC, "cylinder")
			_leaf(model, P.cf(v.call(0.22, 0.75, 0.05), 0, 30, 20))
			P.part(model, one * 0.26, P.cf(v.call(-0.35, 0.3, 0.55)), WHITE, P.NEON, "ball")
		"cherry":
			# Two cherries on stems that meet at the top.
			var red := Color8(200, 20, 45)
			for side: float in [-1.0, 1.0]:
				P.part(model, one * 0.8, P.cf(v.call(side * 0.42, -0.45, side * 0.05)), red, P.PLASTIC, "ball")
				P.part(model, one * 0.16, P.cf(v.call(side * 0.42 - 0.18, -0.3, side * 0.05 + 0.32)), WHITE, P.NEON, "ball")
				P.part(model, v.call(0.08, 1.2, 0.08), P.cf(v.call(side * 0.22, 0.3, 0), 0, 0, side * 20.0), Color8(80, 140, 50))
			_leaf(model, P.cf(v.call(0.2, 0.92, 0), 0, 0, 20))
		"strawberry":
			var red := Color8(235, 40, 60)
			P.part(model, one * 1.3, P.cf(v.call(0, 0.1, 0)), red, P.PLASTIC, "ball")
			P.part(model, one * 0.85, P.cf(v.call(0, -0.45, 0)), red, P.PLASTIC, "ball")
			P.part(model, one * 0.45, P.cf(v.call(0, -0.8, 0)), red, P.PLASTIC, "ball")
			P.part(model, v.call(0.12, 0.9, 0.9), P.cf(v.call(0, 0.72, 0), 0, 0, 90), LEAF, P.PLASTIC, "cylinder")
			P.part(model, v.call(0.1, 0.3, 0.1), P.cf(v.call(0, 0.9, 0)), Color8(80, 140, 50))
			for i in 7:
				var angle := i * 0.9
				var y := -0.5 + (i % 3) * 0.4
				P.part(model, one * 0.1, P.cf(v.call(sin(angle) * 0.45, y, 0.38 + cos(angle) * 0.1)), Color8(255, 230, 120), P.PLASTIC, "ball")
		_: # pear
			var green := Color8(175, 215, 60)
			P.part(model, one * 1.35, P.cf(v.call(0, -0.3, 0)), green, P.PLASTIC, "ball")
			P.part(model, one * 0.95, P.cf(v.call(0, 0.35, 0)), green, P.PLASTIC, "ball")
			P.part(model, v.call(0.1, 0.45, 0.1), P.cf(v.call(0.05, 0.95, 0), 0, 0, -15), STEM)
			_leaf(model, P.cf(v.call(0.3, 0.95, 0), 0, 0, 25))
			P.part(model, one * 0.4, P.cf(v.call(0.3, -0.25, 0.5)), Color8(230, 150, 60), P.PLASTIC, "ball")
	return model


static func _leaf(model: Node3D, xform: Transform3D) -> void:
	Parts.part(model, Vector3(0.55, 0.08, 0.3), xform, LEAF)
