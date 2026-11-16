class_name Cabinet
extends Node3D
## The vending machine, in the style of an early-2000s console game: a black cabinet with flat, hard-pixel art
## (scripts/pixel_tex.gd). A pale marquee across the top shows the score; under it a white-framed window holds six
## fruit on coloured tiles; the panel beside it carries a screen, heart lamps and the big button over side art in the
## machine's colour; a hatch at the bottom throws the fruit out when a machine is cleared.
##
## It keeps the Roblox cabinet's overall size and the cells' places (studs), stands on the origin and faces +Z.
##
## Feel, as in the Roblox version: a thick white cursor that snaps from cell to cell (no easing, so its timing reads
## exactly) and shows over lit fruit too; lamps that chase round the cabinet in step with the cursor and heat toward
## white with each speed burst. A fruit's tile is dark until it is lit, then glows in the fruit's colour.

const BODY_W := 11.0
const BODY_H := 17.4
const BODY_D := 3.0
const BASE_H := 0.6
const FRONT_Z := 2.6 ## the cabinet's front face
const ITEM_Z := 1.7
const WIN_LEFT := -5.05 ## the window: two columns of items
const WIN_RIGHT := 1.55
const WIN_TOP := 15.9 ## three rows
const WIN_BOTTOM := 4.6
const CELL_W := (WIN_RIGHT - WIN_LEFT) / 2.0
const CELL_H := (WIN_TOP - WIN_BOTTOM) / 3.0
const CURSOR_Z := FRONT_Z + 0.14
const PANEL_X := 3.4 ## middle of the right-hand panel
const TRAY_Y := 2.55
const TOP_Y := BASE_H + BODY_H
const BULB_TOP := TOP_Y + 0.45 + 0.13 ## the highest thing on the cabinet
const MARQUEE_Y := TOP_Y - 0.9
const MARQUEE_H := 1.35

const BLACK := Color8(14, 14, 20)
const INK := Color8(26, 16, 44) ## the marquee's lettering
const PAPER := Color8(238, 234, 222) ## the marquee and the window frame
const MARQUEE_RED := Color8(214, 36, 60)
const TILE_OFF := Color8(40, 44, 70) ## an unlit fruit's tile
## The colour each fruit's tile glows when it is lit, in ring order (apple, banana, orange, cherry, strawberry, pear).
const TILE_LIT: Array[Color] = [Color8(255, 150, 150), Color8(255, 236, 130), Color8(255, 190, 110), Color8(255, 150, 200), Color8(255, 170, 170), Color8(196, 240, 130)]


class Cell:
	var index := 0
	var centre := Vector3.ZERO ## the item's resting place
	var back: MeshInstance3D ## the tile behind it: dark, or glowing when lit
	var item: Node3D ## the fruit (or bomb); it sways and spins
	var decor: Node3D ## what marks an item cell: halo, cage, ice, tag (stays still)
	var shown := "" ## the board cell this was dressed for, so it is only rebuilt when it changes
	var kind := "fruit"
	var mult := 1
	var spin := 0.0


var fx: Effects
var cells: Array[Cell] = []
var tier_color := Fx.WHITE

var _body: Node3D
var _score_label: Label3D
var _best_label: Label3D
var _score := 0.0 ## where the marquee's counter is heading
var _shown_score := 0.0
var _display := {}
var _lives_label: Label3D
var _life_lamps: Array[MeshInstance3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _trims: Array[MeshInstance3D] = []
var _art: Array[MeshInstance3D] = []
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
var _trims_until := -1.0 ## while the clock is short of this, the trims hold a flash colour
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build()


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _build() -> void:
	var P := Parts
	var T := PixelTex
	var mid_y := BASE_H + BODY_H / 2.0
	var win_w := WIN_RIGHT - WIN_LEFT
	var win_h := WIN_TOP - WIN_BOTTOM
	var win_x := (WIN_LEFT + WIN_RIGHT) / 2.0
	var win_y := (WIN_TOP + WIN_BOTTOM) / 2.0
	var face_z := FRONT_Z + 0.04 # flat art sits just proud of the body

	P.part(self, Vector3(BODY_W + 0.6, BASE_H, BODY_D + 0.6), _at(0, BASE_H / 2.0, 1.1), Color8(8, 8, 12))
	# The body: a back wall plus a front frame round the window, so the items sit inside it. It shudders as one.
	_body = Node3D.new()
	add_child(_body)
	var back_z := FRONT_Z - BODY_D
	P.part(_body, Vector3(BODY_W, BODY_H, 1), _at(0, mid_y, back_z + 0.5), BLACK)
	var front_d := FRONT_Z - (back_z + 1.0)
	var front_z := back_z + 1.0 + front_d / 2.0
	var shell := func(x0: float, x1: float, y0: float, y1: float) -> void:
		P.part(_body, Vector3(x1 - x0, y1 - y0, front_d), _at((x0 + x1) / 2.0, (y0 + y1) / 2.0, front_z), BLACK)
	shell.call(-BODY_W / 2.0, WIN_LEFT, BASE_H, TOP_Y)
	shell.call(WIN_RIGHT, BODY_W / 2.0, BASE_H, TOP_Y)
	shell.call(WIN_LEFT, WIN_RIGHT, WIN_TOP, TOP_Y)
	# Below the window: a recess for the tray (behind the flap), solid above and below it.
	shell.call(WIN_LEFT, WIN_RIGHT, BASE_H, TRAY_Y - 0.8)
	shell.call(WIN_LEFT, WIN_RIGHT, TRAY_Y + 0.8, WIN_BOTTOM)
	P.part(self, Vector3(BODY_W + 0.4, 0.35, BODY_D + 0.3), _at(0, TOP_Y + 0.17, FRONT_Z - BODY_D / 2.0), Color8(8, 8, 12))

	# Side art in the machine's colour: a thin strip down the left and the whole right-hand panel.
	_art.append(P.plate(self, Vector2(0.36, BODY_H - 0.6), _at(-BODY_W / 2.0 + 0.2, mid_y, face_z), T.art(), Fx.WHITE, false, false, Vector2(0.1, 1)))
	_art.append(P.plate(self, Vector2(3.4, BODY_H - 0.6), _at(PANEL_X, mid_y, face_z), T.art()))

	# The marquee: the score, in ink on a pale plate with a red rim.
	P.plate(self, Vector2(BODY_W - 0.6, MARQUEE_H), _at(0, MARQUEE_Y, face_z + 0.02), T.marquee(PAPER, MARQUEE_RED))
	var text_z := face_z + 0.05
	P.label(self, Vector3(-4.2, MARQUEE_Y, text_z), 1.7, 0.46, "SCORE", MARQUEE_RED)
	_score_label = P.label(self, Vector3(-0.45, MARQUEE_Y - 0.03, text_z), 5.6, 1.5, "0", INK)
	P.label(self, Vector3(3.8, MARQUEE_Y + 0.28, text_z), 2.2, 0.4, "BEST", MARQUEE_RED)
	_best_label = P.label(self, Vector3(3.8, MARQUEE_Y - 0.2, text_z), 2.4, 0.5, "0", INK)

	# The window: a pale frame, its inside walls, and a pale back that shows between the tiles as a grid.
	P.part(self, Vector3(win_w, win_h, 0.06), _at(win_x, win_y, 0.63), PAPER.darkened(0.2), P.NEON)
	var frame := 0.24
	P.part(self, Vector3(win_w + 2 * frame, frame, 0.2), _at(win_x, WIN_TOP + frame / 2.0, FRONT_Z + 0.06), PAPER, P.NEON)
	P.part(self, Vector3(win_w + 2 * frame, frame, 0.2), _at(win_x, WIN_BOTTOM - frame / 2.0, FRONT_Z + 0.06), PAPER, P.NEON)
	for x: float in [WIN_LEFT - frame / 2.0, WIN_RIGHT + frame / 2.0]:
		P.part(self, Vector3(frame, win_h, 0.2), _at(x, win_y, FRONT_Z + 0.06), PAPER, P.NEON)

	# The cells: a tile and the item in front of it.
	for index in Vend.ICONS:
		var spot: Array = Vend.CELLS[index]
		var cx: float = WIN_LEFT + (spot[0] - 0.5) * CELL_W
		var cy: float = WIN_TOP - (spot[1] - 0.5) * CELL_H
		var cell := Cell.new()
		cell.index = index
		cell.back = P.plate(self, Vector2(CELL_W - 0.3, CELL_H - 0.3), _at(cx, cy, 0.7), T.tile(), TILE_OFF)
		cell.centre = Vector3(cx, cy + 0.15, ITEM_Z)
		cell.spin = (index + 1) * 1.3
		cells.append(cell)

	# The cursor: one thick white frame and a soft glow plate in front of the window, snapped to the cell under the
	# cursor. It sits on top of everything, so you can see it over lit fruit as well as unlit.
	var cw := CELL_W - 0.05
	var ch := CELL_H - 0.05
	for bar: Array in [[cw, Fx.CURSOR_WIDTH, 0.0, ch / 2.0], [cw, Fx.CURSOR_WIDTH, 0.0, -ch / 2.0], [Fx.CURSOR_WIDTH, ch, -cw / 2.0, 0.0], [Fx.CURSOR_WIDTH, ch, cw / 2.0, 0.0]]:
		var part := P.part(self, Vector3(bar[0], bar[1], 0.1), _at(0, 0, CURSOR_Z), Fx.WHITE, P.NEON, "block", 1.0, true)
		_cursor_bars.append(part)
		_cursor_offsets.append(Vector3(bar[2], bar[3], 0))
	_cursor_glow = P.part(self, Vector3(cw - 0.2, ch - 0.2, 0.04), _at(0, 0, CURSOR_Z - 0.04), Fx.WHITE, P.NEON, "block", 1.0 - Fx.CURSOR_GLOW, true)

	# The right-hand panel: a screen with scan lines, heart lamps, the big button, a coin slot and a keypad.
	var screen_top := 14.15 + 1.6
	P.part(self, Vector3(2.9, 3.4, 0.08), _at(PANEL_X, 14.15, face_z + 0.03), Color8(8, 8, 12))
	P.plate(self, Vector2(2.7, 3.2), _at(PANEL_X, 14.15, face_z + 0.08), T.scanlines(), Color8(22, 40, 44), false, false, Vector2(1, 30))
	var line := func(name: String, y: float, h: float, color: Color) -> void:
		_display[name] = P.label(self, Vector3(PANEL_X, screen_top - (y + h / 2.0) / 100.0, face_z + 0.11), 2.5, h / 100.0, "", color)
	line.call("caption", 8.0, 40.0, Fx.SOFT)
	line.call("pot", 50.0, 90.0, Fx.GOLD)
	line.call("mult", 150.0, 80.0, Fx.PINK)
	line.call("speed", 240.0, 60.0, Fx.CYAN)

	P.part(self, Vector3(2.9, 1.35, 0.08), _at(PANEL_X, 11.55, face_z + 0.03), Color8(8, 8, 12))
	_lives_label = P.label(self, Vector3(PANEL_X, 11.98, face_z + 0.09), 2.6, 0.36, "ONE SHOT", Fx.SOFT)
	for i in 3:
		_life_lamps.append(P.plate(self, Vector2(0.72, 0.64), _at(PANEL_X + (i - 1) * 0.86, 11.3, face_z + 0.09), T.heart(), Fx.RED, false, true))

	P.part(self, Vector3(0.2, 2.6, 2.6), P.cf(Vector3(PANEL_X, 8.9, FRONT_Z + 0.1), 0, 90, 0), Color8(8, 8, 12), P.PLASTIC, "cylinder")
	P.part(self, Vector3(0.24, 2.3, 2.3), P.cf(Vector3(PANEL_X, 8.9, FRONT_Z + 0.13), 0, 90, 0), PAPER, P.NEON, "cylinder")
	_button = P.part(self, Vector3(0.4, 2.0, 2.0), P.cf(Vector3(PANEL_X, 8.9, FRONT_Z + 0.25), 0, 90, 0), Fx.RED, P.NEON, "cylinder")
	_button_home = _button.transform
	P.part(self, Vector3(2.6, 0.56, 0.06), _at(PANEL_X, 7.2, face_z + 0.03), Color8(8, 8, 12))
	P.label(self, Vector3(PANEL_X, 7.2, face_z + 0.08), 2.4, 0.5, "TAP!", PAPER)
	P.part(self, Vector3(0.9, 1.5, 0.06), _at(PANEL_X - 0.8, 5.5, face_z + 0.03), Color8(8, 8, 12))
	P.part(self, Vector3(0.16, 0.8, 0.08), _at(PANEL_X - 0.8, 5.5, face_z + 0.06), Color8(190, 194, 208), P.NEON)
	P.plate(self, Vector2(1.3, 1.7), _at(PANEL_X + 0.6, 5.5, face_z + 0.05), T.keypad())

	# The tray the items fall into, behind a hatch that swings open.
	P.part(self, Vector3(win_w, 1.6, 0.12), _at(win_x, TRAY_Y, FRONT_Z - BODY_D + 1.08), Color8(4, 4, 8))
	_flap = Node3D.new()
	_flap_home = _at(win_x, TRAY_Y, FRONT_Z + 0.1)
	_flap.transform = _flap_home
	add_child(_flap)
	P.plate(_flap, Vector2(win_w - 0.3, _flap_size_y), Transform3D.IDENTITY, T.hatch())

	# Edges in the machine's colour and a ring of square lamps round the front that chase in step with the cursor.
	for side: float in [-1.0, 1.0]:
		_trims.append(P.part(self, Vector3(0.14, BODY_H, 0.14), _at(side * BODY_W / 2.0, mid_y, FRONT_Z + 0.02), Fx.WHITE, P.NEON, "block", 1.0, true))
	_trims.append(P.part(self, Vector3(BODY_W + 0.9, 0.06, 0.08), _at(0, 0.06, FRONT_Z + 0.5), Fx.WHITE, P.NEON, "block", 1.0, true))
	var edge := BODY_W / 2.0 - 0.15
	var bulb := func(x: float, y: float) -> void:
		_bulbs.append(P.part(self, Vector3(0.24, 0.24, 0.12), _at(x, y, FRONT_Z + 0.14), Fx.DIM, P.NEON, "block", 1.0, true))
	for i in 23:
		bulb.call(-edge, 1.2 + i * 0.68)
	for i in range(1, 15):
		bulb.call(-edge + i * (2.0 * edge) / 15.0, TOP_Y + 0.45)
	for i in range(22, -1, -1):
		bulb.call(edge, 1.2 + i * 0.68)
	_tint_art()


# ===== what is behind the window =====

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
	var tag := P.label(decor, Vector3(0, -CELL_H / 2.0 + 0.6, 0.99), CELL_W - 0.7, 0.66, tag_text, tag_color)
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


## Put one of every kind of item behind the window for a few frames while the game loads, so the first one met in
## play doesn't cost a stutter while its graphics are built.
func warm_up() -> void:
	var kinds := [["mult", 5], ["strong", 1], ["bomb", 1], ["ice", 1], ["reverse", 1], ["mult", 100]]
	for i in cells.size():
		_dress_cell(cells[i], {"kind": kinds[i][0], "mult": kinds[i][1]}, 0)


## A plain set of fruit (before the first run).
func show_plain() -> void:
	for cell in cells:
		if cell.kind != "fruit" or cell.item == null:
			_dress_cell(cell, {"kind": "fruit", "mult": 1}, 0)


## Where effects for a cell go: just in front of its fruit.
func cell_front(index: int) -> Vector3:
	return to_global(cells[index].centre + Vector3(0, 0, 0.9))


func tray_position() -> Vector3:
	return to_global(Vector3((WIN_LEFT + WIN_RIGHT) / 2.0, TRAY_Y, FRONT_Z + 0.5))


## The middle of the score on the marquee.
func score_position() -> Vector3:
	return to_global(Vector3(-0.45, MARQUEE_Y, FRONT_Z + 0.2))


## The top of the cabinet, in the middle.
func top_position() -> Vector3:
	return to_global(Vector3(0, BULB_TOP, FRONT_Z))


# ===== the marquee =====

## The score to show. `at_once` sets it (a new run); otherwise the counter rolls up to it and the digits kick.
func set_score(score: int, at_once := false) -> void:
	_score = score
	if at_once:
		_shown_score = score
		Parts.set_text(_score_label, Fx.number(score))
	else:
		_score_label.scale = Vector3.ONE * 1.2
		create_tween().tween_property(_score_label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_best(best: int) -> void:
	Parts.set_text(_best_label, Fx.number(best))


# ===== reactions to a press =====

func flash_cell(index: int, color: Color) -> void:
	Parts.set_color(cells[index].back, color)


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


## The bomb went off: it is gone from its tile.
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
	_body.position = Vector3(0.15, 0, 0)
	create_tween().tween_property(_body, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The machine the run is on: only its colour shows (the edges, the lamps and the side art).
func set_tier(tier: int) -> void:
	tier_color = Modes.tier_color(tier)
	_tint_art()
	if _trims_until < 0.0:
		set_trims(tier_color)


func _tint_art() -> void:
	for plate in _art:
		Parts.set_color(plate, tier_color.lerp(Color8(40, 30, 90), 0.35))


## Flash the edges a colour for a moment (red when a run ends), then back to the machine's colour.
func flash_trims(color: Color, seconds: float) -> void:
	set_trims(color)
	_trims_until = _clock + seconds


func set_trims(color: Color) -> void:
	for trim in _trims:
		Parts.set_color(trim, color)


## The screen: the pot (in score), the streak MULT and any multiplier fruit, the speed, the lives.
func update_display(run: Vend, t: float) -> void:
	if run == null:
		return
	Parts.set_text(_display.caption, "POT")
	Parts.set_text(_display.pot, Fx.number(floorf(run.pot * run.fruit_mult * Modes.machine_value(run.tier))))
	Parts.set_text(_display.mult, Fx.times(run.mult()) + ("  x%d" % run.fruit_mult if run.fruit_mult > 1 else ""))
	_show_speed(run, t)
	Parts.set_text(_lives_label, "LIVES" if run.max_lives > 1 else "ONE SHOT")
	for i in _life_lamps.size():
		var lamp := _life_lamps[i]
		lamp.visible = i < run.max_lives
		Parts.set_color(lamp, Fx.RED if i < run.lives else Color8(70, 30, 44))


func _show_speed(run: Vend, t: float) -> void:
	var boost := run.boost_at(t)
	Parts.set_text(_display.speed, "BURST +%.1f" % boost if boost > 0.3 else "SPEED %.1f" % run.base)


# ===== vending =====

# Swing the hatch open (outward, about its top edge) and let it fall shut again.
func _swing_flap() -> void:
	var set_swing := func(k: float) -> void:
		var hinge := _flap_home * _at(0, _flap_size_y / 2.0, 0)
		_flap.transform = hinge * Transform3D(Parts.rot(-deg_to_rad(70) * k, 0, 0), Vector3.ZERO) * _at(0, -_flap_size_y / 2.0, 0)
	var tween := create_tween()
	tween.tween_method(set_swing, 0.0, 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_swing, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## A full machine vends: the fruit in the window pops away and the same six shoot out of the hatch at the bottom, one
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
		# Gone from its tile at once (a quick shrink and a sparkle)...
		if fx:
			fx.burst(to_global(item.position), Fx.GOLD, 5, "sparkle", Fx.FX_SCALE)
		item.scale = Vector3.ONE * 0.5
		get_tree().create_timer(0.06).timeout.connect(item.queue_free)
		# ...and out of the hatch.
		order += 1
		_pending.append({"at": _clock + (order - 1) * Fx.SHOOT_STEP, "kind": Vend.ITEMS[cell.index], "slot": order})


# Shoot one fruit out of the hatch: it leaves fast, arcs onto the floor in front of the machine, bounces and rolls to a
# stop. Pure decoration: the next machine is already running.
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

## Draw the machine for time `t` of `run` (null or over = idle). `dt` is the frame's length. Returns the cell the cursor
## is on (-1 for none).
func update(run: Vend, t: float, dt: float) -> int:
	_clock += dt
	_update_flying(dt)
	if _trims_until >= 0.0 and _clock >= _trims_until:
		_trims_until = -1.0
		set_trims(tier_color)
	# The marquee's counter rolls up to the score.
	if _shown_score != _score:
		_shown_score = move_toward(_shown_score, _score, maxf(absf(_score - _shown_score) * minf(dt * 9.0, 1.0), 1.0))
		Parts.set_text(_score_label, Fx.number(_shown_score))

	var live := run != null and not run.over
	var cursor := run.index_at(t) if live else -1
	var color := tier_color

	for cell in cells:
		var lit := live and run.lit[cell.index]
		# A tile is dark until its fruit is lit, then glows in the fruit's colour. An item's tile hints at what it is.
		var unlit := TILE_OFF
		if cell.kind == "bomb":
			unlit = Fx.RED.lerp(TILE_OFF, 0.45 + 0.25 * sin(_clock * 8.0))
		elif cell.kind == "mult":
			unlit = (Color.from_hsv(fposmod(_clock * 0.5, 1.0), 0.8, 1.0) if cell.mult >= 100 else Fx.mult_color(cell.mult)).lerp(TILE_OFF, 0.5)
		elif Fx.KIND_TAG.has(cell.kind):
			unlit = (Fx.KIND_TAG[cell.kind].color as Color).lerp(TILE_OFF, 0.65)
		var target_color := TILE_LIT[cell.index] if lit else unlit
		Parts.set_color(cell.back, Parts.get_color(cell.back).lerp(target_color, minf(dt * 18.0, 1.0)))
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
		# Items sway on their tiles; lit ones turn to show off.
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
			bar.position = Vector3(target.back.position.x, target.back.position.y, CURSOR_Z) + _cursor_offsets[i]
	_cursor_glow.visible = target != null
	if target:
		Parts.set_alpha(_cursor_glow, 1.0 - (Fx.CURSOR_GLOW + sin(_clock * 14.0) * 0.04))
		_cursor_glow.position = Vector3(target.back.position.x, target.back.position.y, CURSOR_Z - 0.04)

	# The lamps chase round the cabinet in step with the cursor, faster as it speeds up; a burst heats them to white.
	var count := _bulbs.size()
	var phase := run.phase_at(t) if live else _clock * 0.6
	var head := phase / Vend.ICONS * count
	var hot := color.lerp(Fx.WHITE, clampf(run.boost_at(t) / Vend.BOOST_MAX, 0.0, 0.8) if run != null else 0.0)
	for i in count:
		var distance := fposmod(head - (i + 1), float(count))
		var glow := maxf(0.0, 1.0 - distance / Fx.CHASE_TAIL)
		Parts.set_color(_bulbs[i], Fx.DIM.lerp(hot, 0.18 + 0.82 * glow))
	return cursor
