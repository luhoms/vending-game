class_name Parts
extends RefCounted
## Builds the cabinet and fruit out of simple shapes, the way the Roblox version builds them out of Parts, so its
## sizes and positions carry over one for one. The world uses the same axes: +X right, +Y up, the cabinet faces +Z.

const PLASTIC := 0 ## lit, matte
const METAL := 1 ## lit, shiny
const NEON := 2 ## glows: unshaded, the brightest thing on screen
const GLASS := 3 ## see-through

static var _meshes := {}
static var _materials := {}
static var _font: FontVariation
static var _font_medium: Font


## A rotation the way Roblox's CFrame.Angles(rx, ry, rz) makes one (X, then Y, then Z), in radians.
static func rot(rx: float, ry: float, rz: float) -> Basis:
	return Basis(Vector3.RIGHT, rx) * Basis(Vector3.UP, ry) * Basis(Vector3.BACK, rz)


## A position plus a CFrame.Angles rotation in degrees.
static func cf(position: Vector3, rx := 0.0, ry := 0.0, rz := 0.0) -> Transform3D:
	return Transform3D(rot(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)), position)


static func material(color: Color, kind := PLASTIC, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match kind:
		NEON:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		METAL:
			m.metallic = 0.35
			m.roughness = 0.35
			m.metallic_specular = 0.8
		GLASS:
			m.roughness = 0.1
			m.metallic_specular = 0.9
		_:
			m.roughness = 0.55
			m.metallic_specular = 0.4
	return m


static func _shared_material(color: Color, kind: int, alpha: float) -> StandardMaterial3D:
	var key := "%s|%d|%.2f" % [color.to_html(false), kind, alpha]
	if not _materials.has(key):
		_materials[key] = material(color, kind, alpha)
	return _materials[key]


static func _mesh(shape: String, size: Vector3) -> Mesh:
	var key := "%s|%.3f|%.3f|%.3f" % [shape, size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match shape:
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius = size.x / 2.0
			sphere.height = size.x
			sphere.radial_segments = 20
			sphere.rings = 10
			mesh = sphere
		"cylinder":
			# A Roblox cylinder lies along X: size = (length, diameter, diameter).
			var cylinder := CylinderMesh.new()
			cylinder.height = size.x
			cylinder.top_radius = size.y / 2.0
			cylinder.bottom_radius = size.y / 2.0
			cylinder.radial_segments = 20
			cylinder.rings = 1
			mesh = cylinder
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	_meshes[key] = mesh
	return mesh


## The shared mesh for a shape: "block", "ball" (size.x across) or "cylinder" (lying along X, as in Roblox).
static func mesh_for(shape: String, size: Vector3) -> Mesh:
	return _mesh(shape, size)


## One part. `own` gives it a material of its own, for parts whose colour changes while the game runs.
static func part(parent: Node, size: Vector3, xform: Transform3D, color: Color, kind := PLASTIC, shape := "block", alpha := 1.0, own := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh(shape, size)
	instance.material_override = material(color, kind, alpha) if own else _shared_material(color, kind, alpha)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shape == "cylinder":
		xform = xform * Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO) # stand Godot's Y cylinder along X
	instance.transform = xform
	parent.add_child(instance)
	return instance


## A flat picture facing +Z, `size` studs, drawn with hard pixel edges. `color` tints it; `lit` lets the room's light
## shade it (most of the cabinet's art is unlit, like a lit-up sign); `cutout` drops the picture's clear pixels;
## `repeat` tiles the picture that many times across and down.
static func plate(parent: Node, size: Vector2, xform: Transform3D, texture: Texture2D, color := Color.WHITE, lit := false, cutout := false, repeat := Vector2.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	instance.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = color
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(repeat.x, repeat.y, 1.0)
	if not lit:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 0.8
		m.metallic_specular = 0.1
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	instance.material_override = m
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.transform = xform
	parent.add_child(instance)
	return instance


static func set_color(instance: MeshInstance3D, color: Color) -> void:
	var m: StandardMaterial3D = instance.material_override
	m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)


static func get_color(instance: MeshInstance3D) -> Color:
	return (instance.material_override as StandardMaterial3D).albedo_color


static func set_alpha(instance: MeshInstance3D, alpha: float) -> void:
	var m: StandardMaterial3D = instance.material_override
	m.albedo_color.a = alpha


## The display font (Pixelify Sans, bold), shared by every label on the cabinet and the HUD.
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		var path := "res://assets/fonts/pixelify-sans-700.woff2"
		_font.base_font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _font


## The same font a weight lighter, for text with an edge round it (callouts, pop text): its letters keep their gaps.
static func font_medium() -> Font:
	if _font_medium == null:
		var path := "res://assets/fonts/pixelify-sans-500.woff2"
		_font_medium = load(path) if ResourceLoader.exists(path) else font()
	return _font_medium


## Text printed on a plate `width` x `height` studs, facing +Z, scaled to fill it like a TextScaled label.
static func label(parent: Node, position: Vector3, width: float, height: float, text: String, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = font()
	l.font_size = 96
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.modulate = color
	l.position = position
	l.set_meta("plate", Vector2(width, height))
	parent.add_child(l)
	set_text(l, text)
	return l


## Change a label's text, keeping it inside its plate.
static func set_text(l: Label3D, text: String) -> void:
	if l.text == text and l.has_meta("fitted"):
		return
	l.text = text
	l.set_meta("fitted", true)
	if text == "":
		return
	var plate: Vector2 = l.get_meta("plate")
	var size := l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size)
	l.pixel_size = minf(plate.y * 0.82 / maxf(size.y, 1.0), plate.x * 0.94 / maxf(size.x, 1.0))


## Drop the shared meshes, materials and font (when the game closes, so nothing is left behind).
static func clear_cache() -> void:
	_meshes.clear()
	_materials.clear()
	_font = null
	_font_medium = null
