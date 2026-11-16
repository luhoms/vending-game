class_name Effects
extends Node3D
## Effects in the 3D world: particle bursts, floating pop text, and the camera's shake, punch and idle sway.
## Ported from the Roblox version's FxPool.burst, Board.popText and CameraFX.

const ROBLOX_FOV := 70.0 ## the Roblox camera's field of view: punches are scaled from it to ours

var camera: Camera3D
var base_transform := Transform3D.IDENTITY ## where the camera rests (set by the game whenever the screen changes)
var base_fov := Fx.CAMERA_FOV

var _shake := 0.0
var _punch := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _quad: QuadMesh
var _fade: Gradient
var _sparkle_size: Curve
var _burst_size: Curve


func _ready() -> void:
	_rng.randomize()
	# A soft round dot for every particle.
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 32
	dot.height = 32
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.35, Color(1, 1, 1, 0.9))
	dot.gradient = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.no_depth_test = true
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_quad.material = m
	_fade = Gradient.new()
	_fade.set_color(0, Color(1, 1, 1, 1))
	_fade.set_color(1, Color(1, 1, 1, 0))
	_fade.add_point(0.5, Color(1, 1, 1, 0.7))
	_sparkle_size = Curve.new()
	_sparkle_size.add_point(Vector2(0, 0))
	_sparkle_size.add_point(Vector2(0.2, 1))
	_sparkle_size.add_point(Vector2(1, 0))
	_burst_size = Curve.new()
	_burst_size.add_point(Vector2(0, 1))
	_burst_size.add_point(Vector2(1, 0))


## A puff of particles. "sparkle" drifts up and twinkles; "burst" flies out in every direction and falls.
func burst(at: Vector3, color: Color, count: int, style := "sparkle", scale := 0.4) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(count, 1)
	p.color = Color(color.lerp(Color.WHITE, 0.15), 0.36)
	p.color_ramp = _fade
	p.direction = Vector3.UP
	if style == "sparkle":
		p.lifetime = 1.2
		p.lifetime_randomness = 0.5
		p.initial_velocity_min = 3.0 * scale
		p.initial_velocity_max = 9.0 * scale
		p.spread = 70.0
		p.gravity = Vector3(0, 4.0 * scale, 0)
		p.damping_min = 3.3
		p.damping_max = 3.3
		p.scale_amount_min = 0.7 * scale * 0.5
		p.scale_amount_max = 0.7 * scale * 0.9
		p.scale_amount_curve = _sparkle_size
	else:
		p.lifetime = 0.9
		p.lifetime_randomness = 0.44
		p.initial_velocity_min = 14.0 * scale
		p.initial_velocity_max = 26.0 * scale
		p.spread = 180.0
		p.gravity = Vector3(0, -20.0 * scale, 0)
		p.damping_min = 16.0
		p.damping_max = 16.0
		p.scale_amount_min = 0.9 * scale * 0.5
		p.scale_amount_max = 0.9 * scale * 0.9
		p.scale_amount_curve = _burst_size
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Floating text that pops in, rises and fades ("+3", "CRACK!").
func pop_text(at: Vector3, text: String, color: Color, size: float) -> void:
	var label := Label3D.new()
	label.font = Parts.font_medium()
	label.font_size = 96
	label.outline_size = 7 # thin: a thick outline closes up the pixel letters
	label.outline_modulate = Color(0.05, 0.03, 0.1, 1)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 5
	label.outline_render_priority = 4
	label.text = text
	var height := size * Fx.FX_SCALE
	var measured := label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 96)
	label.pixel_size = minf(height / maxf(measured.y, 1.0), height * 2.4 / maxf(measured.x, 1.0)) * 1.25
	# Keep wide words on the screen: slide them in from the edges.
	var reach := maxf(Fx.VIEW_WIDTH / 2.0 - 0.3 - measured.x * label.pixel_size / 2.0, 0.0)
	at.x = clampf(at.x, -reach, reach)
	label.position = at
	label.scale = Vector3.ONE * 0.4
	add_child(label)
	var fade := func(a: float) -> void:
		label.modulate.a = a
		label.outline_modulate.a = a
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", at + Vector3(0, 2.0 * Fx.FX_SCALE + 1.0, 0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(fade, 1.0, 0.0, 0.5).set_delay(0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Shake the camera by up to this many degrees; it dies away.
func shake(degrees: float) -> void:
	_shake = maxf(_shake, degrees)


## Kick the field of view (negative = a quick zoom in); it springs back. Given in the Roblox camera's degrees.
func punch(fov: float) -> void:
	fov *= base_fov / ROBLOX_FOV
	if fov < _punch:
		_punch = fov


func _process(dt: float) -> void:
	if camera == null:
		return
	_clock += dt
	var turn := Basis.IDENTITY
	if _shake > 0.01:
		var a := _shake
		turn = Parts.rot(deg_to_rad((_rng.randf() - 0.5) * a), deg_to_rad((_rng.randf() - 0.5) * a), deg_to_rad((_rng.randf() - 0.5) * a * 0.5))
		_shake = maxf(0.0, _shake - dt * Fx.SHAKE_DECAY)
	# Idle sway: two slow sine waves, so it never visibly repeats.
	var s := _clock * Fx.SWAY_SPEED
	turn = turn * Parts.rot(deg_to_rad(sin(s * 1.37 + 1.0) * Fx.SWAY_DEGREES * 0.7), deg_to_rad(sin(s) * Fx.SWAY_DEGREES), 0)
	camera.transform = base_transform * Transform3D(turn, Vector3.ZERO)
	_punch += (0.0 - _punch) * minf(1.0, dt * Fx.FOV_RETURN)
	if absf(_punch) < 0.02:
		_punch = 0.0
	camera.fov = base_fov + _punch
