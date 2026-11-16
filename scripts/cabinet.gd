class_name Cabinet
extends Node3D
## The vending machine: six fruit behind the glass, the cursor, the display panel, life lamps, the tray flap and a ring
## of chasing bulbs. Built in code, part for part from the Roblox version's VendGame.buildCabinet, with the same sizes
## (studs). It stands on the origin and faces +Z.
##
## Feel, as in the Roblox version: a thick white cursor that snaps from cell to cell (no easing, so its timing reads
## exactly) and shows over lit fruit too; bulbs that chase in step with the cursor and heat toward white with each
## speed burst; a full machine VENDS, its fruit shooting out of the tray flap onto the floor while the next machine is
## already running.

const BODY_W := 11.0
const BODY_H := 17.4
const BODY_D := 3.0
const BASE_H := 0.6
const FRONT_Z := 2.6 ## the cabinet's front face
const GLASS_Z := FRONT_Z + 0.06
const ITEM_Z := 1.7
const WIN_LEFT := -5.05 ## the glass window: two columns of items
const WIN_RIGHT := 1.55
const WIN_TOP := 15.9 ## three rows
const WIN_BOTTOM := 4.6
const CELL_W := (WIN_RIGHT - WIN_LEFT) / 2.0
const CELL_H := (WIN_TOP - WIN_BOTTOM) / 3.0
const PANEL_X := 3.4 ## middle of the right-hand panel
const TRAY_Y := 2.55
const TOP_Y := BASE_H + BODY_H
const BULB_TOP := TOP_Y + 0.45 + 0.12 ## the highest thing on the cabinet


class Cell:
	var index := 0
	var centre := Vector3.ZERO ## the item's resting place
	var back: MeshInstance3D ## glows when lit
	var frame: Array[MeshInstance3D] = [] ## four thin neon bars round the cell: gold when lit
	var item: Node3D ## the fruit (or bomb); it sways and spins
	var decor: Node3D ## what marks an item cell: halo, cage, ice, tag (stays still)
	var shown := "" ## the board cell this was dressed for, so it is only rebuilt when it changes
	var kind := "fruit"
	var mult := 1
	var spin := 0.0


var fx: Effects
var cells: Array[Cell] = []
var tier_color := Fx.WHITE
var power_down := false

var _body: MeshInstance3D
var _body_home := Transform3D.IDENTITY
var _title: Label3D
var _display := {}
var _lives_label: Label3D
var _life_lamps: Array[MeshInstance3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _trims: Array[MeshInstance3D] = []
var _button: MeshInstance3D
var _button_home := Transform3D.IDENTITY
var _flap: Node3D
var _flap_home := Transform3D.IDENTITY
var _flap_size_y := 1.3
var _cursor_bars: Array[MeshInstance3D] = []
var _cursor_offsets: Array[Vector3] = []
var _cursor_glow: MeshInstance3D
var _flying: Array = [] ## fruit shooting out of the tray: dictionaries (see _shoot)
var _pending: Array = [] ## fruit waiting their turn to shoot: {at, kind, slot}
var _clock := 0.0 ## seconds this cabinet has been updated for (drives the decoration, not the rules)
var _title_hidden_until := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build()


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _build() -> void:
	var P := Parts
	var mid_y := BASE_H + BODY_H / 2.0
	var dark := Color8(16, 16, 22)
	var black := Color8(8, 8, 13)
	var chrome := Color8(214, 218, 228)

	P.part(self, Vector3(BODY_W + 0.6, BASE_H, BODY_D + 0.6), _at(0, BASE_H / 2.0, 1.1), dark, P.METAL)
	# The body is a back wall plus a front frame round the window, so the items behind the glass can be seen.
	var back_z := FRONT_Z - BODY_D
	_body = P.part(self, Vector3(BODY_W, BODY_H, 1), _at(0, mid_y, back_z + 0.5), Fx.CHARCOAL)
	_body_home = _body.transform
	var front_d := FRONT_Z - (back_z + 1.0)
	var front_z := back_z + 1.0 + front_d / 2.0
	var shell := func(x0: float, x1: float, y0: float, y1: float) -> void:
		P.part(_body, Vector3(x1 - x0, y1 - y0, front_d), _body_home.affine_inverse() * _at((x0 + x1) / 2.0, (y0 + y1) / 2.0, front_z), Fx.CHARCOAL)
	shell.call(-BODY_W / 2.0, WIN_LEFT, BASE_H, TOP_Y)
	shell.call(WIN_RIGHT, BODY_W / 2.0, BASE_H, TOP_Y)
	shell.call(WIN_LEFT, WIN_RIGHT, WIN_TOP, TOP_Y)
	# Below the window: a recess for the tray (behind the flap), solid above and below it.
	shell.call(WIN_LEFT, WIN_RIGHT, BASE_H, TRAY_Y - 0.8)
	shell.call(WIN_LEFT, WIN_RIGHT, TRAY_Y + 0.8, WIN_BOTTOM)
	P.part(self, Vector3(BODY_W + 0.4, 0.35, BODY_D + 0.3), _at(0, TOP_Y + 0.17, FRONT_Z - BODY_D / 2.0), dark, P.METAL)
	# Glossy front panels round the window.
	P.part(self, Vector3(0.35, BODY_H - 0.6, 0.06), _at(-BODY_W / 2.0 + 0.18, mid_y, FRONT_Z + 0.03), Fx.SKIN)
	P.part(self, Vector3(3.4, BODY_H - 0.6, 0.06), _at(PANEL_X, mid_y, FRONT_Z + 0.03), Fx.SKIN)

	# The header sign.
	P.part(self, Vector3(BODY_W - 0.6, 1.1, 0.08), _at(0, TOP_Y - 0.75, FRONT_Z + 0.06), black)
	_title = P.label(self, Vector3(0, TOP_Y - 0.75, FRONT_Z + 0.12), BODY_W - 1.0, 0.9, "", Fx.WHITE)

	# The window: dark back wall, glass, chrome frame.
	var win_w := WIN_RIGHT - WIN_LEFT
	var win_h := WIN_TOP - WIN_BOTTOM
	var win_x := (WIN_LEFT + WIN_RIGHT) / 2.0
	var win_y := (WIN_TOP + WIN_BOTTOM) / 2.0
	P.part(self, Vector3(win_w, win_h, 0.1), _at(win_x, win_y, 0.6), Color8(10, 11, 20))
	P.part(self, Vector3(win_w, win_h, 0.06), _at(win_x, win_y, GLASS_Z), Color8(175, 210, 228), P.GLASS, "block", 0.1)
	P.part(self, Vector3(win_w + 0.3, 0.14, 0.14), _at(win_x, WIN_TOP + 0.07, GLASS_Z), chrome, P.METAL)
	P.part(self, Vector3(win_w + 0.3, 0.14, 0.14), _at(win_x, WIN_BOTTOM - 0.07, GLASS_Z), chrome, P.METAL)
	for x: float in [WIN_LEFT - 0.07, WIN_RIGHT + 0.07]:
		P.part(self, Vector3(0.14, win_h, 0.14), _at(x, win_y, GLASS_Z), chrome, P.METAL)

	# The cells: a glowing back, a shelf with its spiral, the item, and four neon bars.
	for index in Vend.ICONS:
		var spot: Array = Vend.CELLS[index]
		var cx: float = WIN_LEFT + (spot[0] - 0.5) * CELL_W
		var cy: float = WIN_TOP - (spot[1] - 0.5) * CELL_H
		var cell := Cell.new()
		cell.index = index
		cell.back = P.part(self, Vector3(CELL_W - 0.3, CELL_H - 0.3, 0.06), _at(cx, cy, 0.7), Fx.DIM, P.NEON, "block", 0.75, true)
		P.part(self, Vector3(CELL_W - 0.2, 0.12, 1.8), _at(cx, cy - CELL_H / 2.0 + 0.25, 1.6), chrome, P.METAL)
		var coil_at := P.cf(Vector3(cx, cy - CELL_H / 2.0 + 0.48, 1.6), 0, 90, 0)
		P.part(self, Vector3(1.6, 0.3, 0.3), coil_at, Color8(170, 175, 190), P.METAL, "cylinder")
		for k in 4: # the spiral's turns
			P.part(self, Vector3(0.08, 0.62, 0.62), coil_at * _at(-0.6 + k * 0.4, 0, 0), Color8(200, 205, 215), P.METAL, "cylinder")
		var w := CELL_W - 0.12
		var h := CELL_H - 0.12
		var z := GLASS_Z - 0.12
		cell.frame.append(P.part(self, Vector3(w, 0.12, 0.08), _at(cx, cy + h / 2.0, z), Fx.DIM, P.NEON, "block", 1.0, true))
		cell.frame.append(P.part(self, Vector3(w, 0.12, 0.08), _at(cx, cy - h / 2.0, z), Fx.DIM, P.NEON, "block", 1.0, true))
		cell.frame.append(P.part(self, Vector3(0.12, h, 0.08), _at(cx - w / 2.0, cy, z), Fx.DIM, P.NEON, "block", 1.0, true))
		cell.frame.append(P.part(self, Vector3(0.12, h, 0.08), _at(cx + w / 2.0, cy, z), Fx.DIM, P.NEON, "block", 1.0, true))
		cell.centre = Vector3(cx, cy + 0.15, ITEM_Z)
		cell.spin = (index + 1) * 1.3
		cells.append(cell)

	# The cursor: one thick white frame and a soft glow plate in front of the glass, snapped to the cell under the
	# cursor. It sits on top of everything, so you can see it over lit fruit as well as unlit.
	var cw := CELL_W - 0.05
	var ch := CELL_H - 0.05
	var cz := GLASS_Z + 0.08
	for bar: Array in [[cw, Fx.CURSOR_WIDTH, 0.0, ch / 2.0], [cw, Fx.CURSOR_WIDTH, 0.0, -ch / 2.0], [Fx.CURSOR_WIDTH, ch, -cw / 2.0, 0.0], [Fx.CURSOR_WIDTH, ch, cw / 2.0, 0.0]]:
		var part := P.part(self, Vector3(bar[0], bar[1], 0.1), _at(0, 0, cz), Fx.WHITE, P.NEON, "block", 1.0, true)
		_cursor_bars.append(part)
		_cursor_offsets.append(Vector3(bar[2], bar[3], 0))
	_cursor_glow = P.part(self, Vector3(cw - 0.2, ch - 0.2, 0.04), _at(0, 0, cz - 0.04), Fx.WHITE, P.NEON, "block", 1.0 - Fx.CURSOR_GLOW, true)

	# The right-hand panel: the display, the life lamps, the big button and a coin slot.
	var screen_top := 14.15 + 1.6
	P.part(self, Vector3(2.7, 3.2, 0.06), _at(PANEL_X, 14.15, FRONT_Z + 0.08), Color8(6, 8, 14))
	var line := func(name: String, y: float, h: float, color: Color) -> void:
		_display[name] = P.label(self, Vector3(PANEL_X, screen_top - (y + h / 2.0) / 100.0, FRONT_Z + 0.13), 2.5, h / 100.0, "", color)
	line.call("caption", 8.0, 40.0, Fx.SOFT)
	line.call("pot", 50.0, 90.0, Fx.GOLD)
	line.call("mult", 150.0, 80.0, Fx.PINK)
	line.call("speed", 240.0, 60.0, Fx.CYAN)

	for i in 5:
		_life_lamps.append(P.part(self, Vector3.ONE * 0.48, _at(PANEL_X - 1.2 + i * 0.6, 11.35, FRONT_Z + 0.12), Fx.DIM, P.NEON, "ball", 1.0, true))
	P.part(self, Vector3(2.7, 0.45, 0.04), _at(PANEL_X, 12.0, FRONT_Z + 0.08), black)
	_lives_label = P.label(self, Vector3(PANEL_X, 12.0, FRONT_Z + 0.12), 2.6, 0.42, "ONE SHOT", Fx.SOFT)

	P.part(self, Vector3(0.2, 2.5, 2.5), P.cf(Vector3(PANEL_X, 8.9, FRONT_Z + 0.1), 0, 90, 0), dark, P.METAL, "cylinder")
	_button = P.part(self, Vector3(0.4, 2.0, 2.0), P.cf(Vector3(PANEL_X, 8.9, FRONT_Z + 0.25), 0, 90, 0), Fx.RED, P.NEON, "cylinder")
	_button_home = _button.transform
	P.part(self, Vector3(2.6, 0.5, 0.04), _at(PANEL_X, 7.25, FRONT_Z + 0.08), black)
	P.label(self, Vector3(PANEL_X, 7.25, FRONT_Z + 0.12), 2.5, 0.46, "TAP!", Fx.WHITE)
	P.part(self, Vector3(0.18, 0.9, 0.08), _at(PANEL_X - 0.6, 5.6, FRONT_Z + 0.08), Color8(200, 205, 215), P.METAL)
	P.part(self, Vector3(1.2, 1.4, 0.06), _at(PANEL_X + 0.6, 5.6, FRONT_Z + 0.08), Color8(40, 42, 52), P.METAL)

	# The tray the items fall into, behind a flap that swings open.
	P.part(self, Vector3(win_w, 1.6, 0.12), _at(win_x, TRAY_Y, FRONT_Z - BODY_D + 1.08), Color8(6, 6, 10))
	_flap = Node3D.new()
	_flap_home = _at(win_x, TRAY_Y, FRONT_Z + 0.12)
	_flap.transform = _flap_home
	add_child(_flap)
	P.part(_flap, Vector3(win_w - 0.3, _flap_size_y, 0.06), Transform3D.IDENTITY, Color8(60, 62, 75), P.GLASS, "block", 0.55)
	P.label(_flap, Vector3(0, 0, 0.05), 3.0, 0.7, "PUSH", Fx.SOFT)

	# Neon edges and a ring of bulbs round the front that chase in step with the cursor.
	for side: float in [-1.0, 1.0]:
		_trims.append(P.part(self, Vector3(0.12, BODY_H, 0.12), _at(side * BODY_W / 2.0, mid_y, FRONT_Z + 0.02), Fx.WHITE, P.NEON, "block", 1.0, true))
	_trims.append(P.part(self, Vector3(BODY_W + 0.9, 0.05, 0.06), _at(0, 0.06, FRONT_Z + 0.5), Fx.WHITE, P.NEON, "block", 1.0, true))
	var edge := BODY_W / 2.0 - 0.15
	var bulb := func(x: float, y: float) -> void:
		_bulbs.append(P.part(self, Vector3.ONE * 0.24, _at(x, y, FRONT_Z + 0.16), Fx.DIM, P.NEON, "ball", 1.0, true))
	for i in 23:
		bulb.call(-edge, 1.2 + i * 0.68)
	for i in range(1, 15):
		bulb.call(-edge + i * (2.0 * edge) / 15.0, TOP_Y + 0.45)
	for i in range(22, -1, -1):
		bulb.call(edge, 1.2 + i * 0.68)


# ===== what is behind the glass =====

func _clear_cell(cell: Cell) -> void:
	if cell.item:
		cell.item.queue_free()
		cell.item = null
	if cell.decor:
		cell.decor.queue_free()
		cell.decor = null
	cell.shown = ""


# Build what a cell shows for its board entry: the fruit (or a bomb) plus the marks of an item.
func _dress_cell(cell: Cell, spec: Dictionary, hit_count: int) -> void:
	_clear_cell(cell)
	cell.kind = spec.kind
	cell.mult = spec.mult
	cell.shown = "%s:%s:%d" % [Vend.ITEMS[cell.index], spec.kind, spec.mult]
	cell.item = Fruit.build("bomb" if spec.kind == "bomb" else Vend.ITEMS[cell.index])
	cell.item.position = cell.centre
	add_child(cell.item)
	if spec.kind == "fruit":
		return
	var P := Parts
	var decor := Node3D.new()
	decor.name = "Item_" + spec.kind
	decor.position = cell.centre
	add_child(decor)
	cell.decor = decor
	var tag_text := ""
	var tag_color := Fx.WHITE
	match spec.kind:
		"mult":
			var color := Fx.mult_color(spec.mult)
			var halo := P.part(decor, Vector3(0.06, 2.3, 2.3), P.cf(Vector3(0, 0, -0.75), 0, 90, 0), color, P.NEON, "cylinder", 0.75, true)
			halo.name = "Halo"
			tag_text = "x%d" % spec.mult
			tag_color = color
		"strong":
			# A cage of bars in front of the fruit; the first hit knocks two of them away.
			var steel := Color8(150, 158, 175)
			for i in range(-2, 3):
				var bar := P.part(decor, Vector3(0.12, 2.2, 0.12), _at(i * 0.42, 0, 0.85), steel, P.METAL, "block", 1.0, true)
				if absi(i) == 1:
					bar.add_to_group("breaks")
			for dy: float in [-1.1, 1.1]:
				P.part(decor, Vector3(2, 0.14, 0.14), _at(0, dy, 0.85), steel, P.METAL)
			tag_text = Fx.KIND_TAG.strong.text
			tag_color = Fx.KIND_TAG.strong.color
		"ice":
			P.part(decor, Vector3(2, 2, 1.7), P.cf(Vector3.ZERO, 0, 0, 4), Color8(170, 225, 255), P.GLASS, "block", 0.45)
			tag_text = Fx.KIND_TAG.ice.text
			tag_color = Fx.KIND_TAG.ice.color
		_:
			tag_text = Fx.KIND_TAG[spec.kind].text
			tag_color = Fx.KIND_TAG[spec.kind].color
	# The tag under the fruit says what the cell is.
	P.part(decor, Vector3(CELL_W - 0.6, 0.55, 0.04), _at(0, -CELL_H / 2.0 + 0.6, 0.95), Color8(8, 8, 13))
	var tag := P.label(decor, Vector3(0, -CELL_H / 2.0 + 0.6, 0.99), CELL_W - 0.8, 0.5, tag_text, tag_color)
	tag.name = "TagText"
	if hit_count >= 1 and spec.kind == "strong":
		for bar in decor.get_children():
			if bar.is_in_group("breaks"):
				bar.queue_free()


## Dress every cell for the run's board (only the cells that changed are rebuilt). `pop` = a new machine: they pop in.
func show_board(run: Vend, pop: bool) -> void:
	for cell in cells:
		var spec: Dictionary = run.board[cell.index]
		var key := "%s:%s:%d" % [Vend.ITEMS[cell.index], spec.kind, spec.mult]
		if cell.shown != key or cell.item == null:
			_dress_cell(cell, spec, run.hits[cell.index])
			if pop:
				cell.item.scale = Vector3.ONE * 0.4
				create_tween().tween_property(cell.item, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A plain set of fruit (before the first run, or after one ends).
func show_plain() -> void:
	for cell in cells:
		if cell.kind != "fruit" or cell.item == null:
			_dress_cell(cell, {"kind": "fruit", "mult": 1}, 0)


## Where effects for a cell go: just in front of its fruit.
func cell_front(index: int) -> Vector3:
	return to_global(cells[index].centre + Vector3(0, 0, 0.9))


func tray_position() -> Vector3:
	return to_global(Vector3((WIN_LEFT + WIN_RIGHT) / 2.0, TRAY_Y, FRONT_Z + 0.5))


func sign_position() -> Vector3:
	return to_global(Vector3(0, TOP_Y - 0.75, FRONT_Z + 0.2))


# ===== reactions to a press =====

func flash_cell(index: int, color: Color) -> void:
	var cell := cells[index]
	for bar in cell.frame:
		Parts.set_color(bar, color)
	Parts.set_color(cell.back, color)
	Parts.set_alpha(cell.back, 1.0)


func flash_all(color: Color) -> void:
	for cell in cells:
		flash_cell(cell.index, color)


## A lit fruit jumps (1.3x for a moment).
func pop_item(index: int) -> void:
	var item := cells[index].item
	if item:
		item.scale = Vector3.ONE * 1.3
		var settle := func() -> void:
			if is_instance_valid(item):
				item.scale = Vector3.ONE
		var tween := create_tween()
		tween.tween_interval(0.12)
		tween.tween_callback(settle)


## The first hit on a caged fruit: two bars fall away.
func crack(index: int) -> void:
	var decor := cells[index].decor
	if decor == null:
		return
	for bar in decor.get_children():
		if bar.is_in_group("breaks"):
			var mesh := bar as MeshInstance3D
			var target: Transform3D = mesh.transform * Transform3D(Parts.rot(deg_to_rad(70), 0, 0), Vector3(0, -1.5, 0.8))
			(mesh.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var fade := func(a: float) -> void:
				if is_instance_valid(mesh):
					Parts.set_alpha(mesh, a)
			var tween := create_tween().set_parallel(true)
			tween.tween_property(mesh, "transform", target, 0.3)
			tween.tween_method(fade, 1.0, 0.0, 0.3)
			tween.chain().tween_callback(mesh.queue_free)


func remove_decor(index: int) -> void:
	var cell := cells[index]
	if cell.decor:
		cell.decor.queue_free()
		cell.decor = null


## The bomb went off: it is gone from its shelf.
func remove_item(index: int) -> void:
	var cell := cells[index]
	if cell.item:
		cell.item.queue_free()
		cell.item = null


## The big button kicks.
func press_button() -> void:
	_button.transform = _button_home * _at(-0.15, 0, 0)
	create_tween().tween_property(_button, "transform", _button_home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A mistake shudders the whole machine.
func shudder() -> void:
	_body.transform = _body_home * _at(0.15, 0, 0)
	create_tween().tween_property(_body, "transform", _body_home, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_tier(tier: int) -> void:
	tier_color = Modes.tier_color(tier)
	Parts.set_text(_title, Modes.tier_title(tier))
	_title.modulate = Color(tier_color, _title.modulate.a)
	if not power_down:
		set_trims(tier_color)


## A callout is showing on the header sign: the machine's name steps aside for `seconds`.
func hide_title(seconds: float) -> void:
	_title_hidden_until = _clock + seconds


func set_trims(color: Color) -> void:
	for trim in _trims:
		Parts.set_color(trim, color)


## The panel: the pot (in score), the streak MULT and any multiplier fruit, the speed, the lives.
func update_display(run: Vend, t: float) -> void:
	if run == null:
		return
	if run.over:
		Parts.set_text(_display.caption, "JAMMED")
		Parts.set_text(_display.pot, "--")
		Parts.set_text(_display.mult, "")
		Parts.set_text(_display.speed, "")
	else:
		Parts.set_text(_display.caption, "POT")
		Parts.set_text(_display.pot, Fx.number(floorf(run.pot * run.fruit_mult * Modes.machine_value(run.tier))))
		Parts.set_text(_display.mult, Fx.times(run.mult()) + ("  x%d" % run.fruit_mult if run.fruit_mult > 1 else ""))
		_show_speed(run, t)
	Parts.set_text(_lives_label, "LIVES" if run.max_lives > 1 else "ONE SHOT")
	for i in _life_lamps.size():
		var lamp := _life_lamps[i]
		lamp.visible = i < run.max_lives and run.max_lives > 1
		Parts.set_color(lamp, Fx.DIM if power_down else (Color8(80, 255, 140) if i < run.lives else Color8(60, 20, 24)))


func _show_speed(run: Vend, t: float) -> void:
	var boost := run.boost_at(t)
	Parts.set_text(_display.speed, "BURST +%.1f" % boost if boost > 0.3 else "SPEED %.1f" % run.base)


# ===== vending =====

# Swing the tray's flap open (outward, about its top edge) and let it fall shut again.
func _swing_flap() -> void:
	var set_swing := func(k: float) -> void:
		var hinge := _flap_home * _at(0, _flap_size_y / 2.0, 0)
		_flap.transform = hinge * Transform3D(Parts.rot(-deg_to_rad(70) * k, 0, 0), Vector3.ZERO) * _at(0, -_flap_size_y / 2.0, 0)
	var tween := create_tween()
	tween.tween_method(set_swing, 0.0, 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_swing, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## A full machine vends: the fruit in the window pops away and the same six shoot out of the tray at the bottom, one
## right after another, while the next machine restocks. The fruit on the floor clears away a few seconds later.
func vend_all() -> void:
	for old: Dictionary in _flying:
		if is_instance_valid(old.item):
			old.item.queue_free()
	_flying.clear()
	_pending.clear()
	_swing_flap()
	var order := 0
	for cell in cells:
		var item := cell.item
		var was_bomb := cell.kind == "bomb"
		cell.item = null
		if cell.decor:
			cell.decor.queue_free()
			cell.decor = null
		cell.shown = ""
		if item == null:
			continue
		if was_bomb:
			item.queue_free() # the bomb isn't vended
			continue
		# Gone from the shelf at once (a quick shrink and a sparkle)...
		if fx:
			fx.burst(to_global(item.position), Fx.GOLD, 5, "sparkle", Fx.FX_SCALE)
		item.scale = Vector3.ONE * 0.5
		get_tree().create_timer(0.06).timeout.connect(item.queue_free)
		# ...and out of the tray.
		order += 1
		_pending.append({"at": _clock + (order - 1) * Fx.SHOOT_STEP, "kind": Vend.ITEMS[cell.index], "slot": order})


# Shoot one fruit out of the tray: it leaves the flap fast, arcs onto the floor in front of the machine, bounces and
# rolls to a stop. Pure decoration: the next machine is already running.
func _shoot(kind: String, slot: int) -> void:
	var fruit := Fruit.build(kind)
	fruit.position = Vector3((WIN_LEFT + WIN_RIGHT) / 2.0 + (slot - 3.5) * 0.7, TRAY_Y - 0.2, FRONT_Z - 0.2)
	add_child(fruit)
	_flying.append({
		"item": fruit,
		"axis": Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(),
		"angle": 0.0,
		"v": Vector3(_rng.randf_range(-1.0, 1.0) * Fx.SHOOT_SPREAD, Fx.SHOOT_UP * _rng.randf_range(0.8, 1.2), Fx.SHOOT_OUT * _rng.randf_range(0.8, 1.2)),
		"bounces": 0,
		"rolling": false,
		"gone_at": _clock + Fx.FRUIT_STAY + slot * 0.08,
	})


func _update_flying(dt: float) -> void:
	while not _pending.is_empty() and _pending[0].at <= _clock:
		var next: Dictionary = _pending.pop_front()
		_shoot(next.kind, next.slot)
	dt = minf(dt, 1.0 / 20.0)
	for i in range(_flying.size() - 1, -1, -1):
		var f: Dictionary = _flying[i]
		var item: Node3D = f.item
		if not is_instance_valid(item) or _clock >= f.gone_at + 0.12:
			if is_instance_valid(item):
				item.queue_free()
			_flying.remove_at(i)
			continue
		if _clock >= f.gone_at:
			item.scale = Vector3.ONE * 0.6
		var p := item.position
		var v: Vector3 = f.v
		if not f.rolling:
			v.y -= Fx.GRAVITY * dt
			p += v * dt
			f.angle += dt * 12.0
			if p.y <= Fx.FRUIT_REST and v.y < 0.0:
				p.y = Fx.FRUIT_REST
				f.bounces += 1
				if f.bounces == 1 and fx:
					fx.burst(to_global(p), Fx.GOLD, 6, "sparkle", Fx.FX_SCALE)
				v.y = -v.y * Fx.BOUNCE
				v.x *= 0.6
				v.z *= 0.45
				if absf(v.y) < 1.5:
					f.rolling = true
		else:
			var keep := 1.0 - minf(dt * 4.0, 1.0)
			v.x *= keep
			v.z *= keep
			p += Vector3(v.x * dt, 0, v.z * dt)
			f.angle += (absf(v.x) + absf(v.z)) * dt * 2.0
		f.v = v
		item.transform = Transform3D(Basis(f.axis, f.angle).scaled(item.scale), p)


# ===== every frame =====

## Draw the machine for time `t` of `run` (null or over = idle). `dt` is the frame's length.
func update(run: Vend, t: float, dt: float) -> int:
	_clock += dt
	_update_flying(dt)
	_title.modulate.a = move_toward(_title.modulate.a, 0.0 if _clock < _title_hidden_until else 1.0, dt * 8.0)
	var live := run != null and not run.over
	var cursor := run.index_at(t) if live and not power_down else -1
	var color := tier_color

	for cell in cells:
		var lit := live and run.lit[cell.index]
		var frame_color := Fx.DIM if power_down else (Fx.GOLD if lit else color.lerp(Fx.DIM, 0.6))
		for bar in cell.frame:
			Parts.set_color(bar, Parts.get_color(bar).lerp(frame_color, minf(dt * 30.0, 1.0)))
		# Lit fruit sit on a warm gold glow, kept fairly dark so the white cursor stands out over it.
		var unlit := Fx.DIM
		if cell.kind == "bomb":
			unlit = Fx.RED.lerp(Fx.DIM, 0.55 + 0.25 * sin(_clock * 8.0))
		elif cell.kind == "mult":
			unlit = (Color.from_hsv(fposmod(_clock * 0.5, 1.0), 0.8, 1.0) if cell.mult >= 100 else Fx.mult_color(cell.mult)).lerp(Fx.DIM, 0.5)
		elif Fx.KIND_TAG.has(cell.kind):
			unlit = (Fx.KIND_TAG[cell.kind].color as Color).lerp(Fx.DIM, 0.7)
		var back_color := Fx.DIM if power_down else (Fx.GOLD.lerp(Fx.DIM, Fx.LIT_DARKEN) if lit else unlit)
		var now_color := Parts.get_color(cell.back).lerp(back_color, minf(dt * 18.0, 1.0))
		now_color.a = 0.9 if lit else 0.7
		(cell.back.material_override as StandardMaterial3D).albedo_color = now_color
		# A x100 fruit's halo and tag cycle through the rainbow; a bomb's fuse sparks.
		if cell.decor and cell.kind == "mult" and cell.mult >= 100:
			var hue := Color.from_hsv(fposmod(_clock * 0.5, 1.0), 0.85, 1.0)
			var halo := cell.decor.get_node_or_null("Halo") as MeshInstance3D
			if halo:
				Parts.set_color(halo, hue)
			var tag := cell.decor.get_node_or_null("TagText") as Label3D
			if tag:
				tag.modulate = hue
		if cell.kind == "bomb" and cell.item:
			var spark := cell.item.get_node_or_null("Spark") as MeshInstance3D
			if spark:
				Parts.set_alpha(spark, 0.4 if _rng.randf() < 0.3 else 1.0)
		# Items sway on their shelves; lit ones turn to show off.
		if cell.item:
			cell.spin += dt * (2.4 if lit else 0.9)
			cell.item.rotation.y = cell.spin if lit else sin(cell.spin) * 0.35

	if live:
		_show_speed(run, t)

	# The cursor snaps to its cell and pulses a little.
	var target: Cell = cells[cursor] if cursor >= 0 else null
	for i in _cursor_bars.size():
		var bar := _cursor_bars[i]
		bar.visible = target != null
		if target:
			bar.position = Vector3(target.back.position.x, target.back.position.y, GLASS_Z + 0.08) + _cursor_offsets[i]
			Parts.set_color(bar, Fx.WHITE.lerp(Fx.GOLD, 0.25) if run.lit[cursor] else Fx.WHITE)
	_cursor_glow.visible = target != null
	if target:
		Parts.set_alpha(_cursor_glow, 1.0 - (Fx.CURSOR_GLOW + sin(_clock * 14.0) * 0.04))
		_cursor_glow.position = Vector3(target.back.position.x, target.back.position.y, GLASS_Z + 0.04)

	# The bulbs chase round the cabinet in step with the cursor, faster as it speeds up; a burst heats them to white.
	var count := _bulbs.size()
	var phase := run.phase_at(t) if live else _clock * 0.6
	var head := phase / Vend.ICONS * count
	var hot := color.lerp(Fx.WHITE, clampf(run.boost_at(t) / Vend.BOOST_MAX, 0.0, 0.8) if run != null else 0.0)
	for i in count:
		var distance := fposmod(head - (i + 1), float(count))
		var glow := 0.0 if power_down else maxf(0.0, 1.0 - distance / Fx.CHASE_TAIL)
		Parts.set_color(_bulbs[i], Fx.DIM.lerp(hot, 0.18 + 0.82 * glow))
	return cursor
