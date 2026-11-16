class_name Hud
extends CanvasLayer
## Everything drawn flat on the screen, in a light pixel-art style (scripts/pixel_ui.gd): one slim row along the top
## (mode, lives as hearts, the STREAK badge, stats, sound), the short callouts ("CLEARED!  STREAK x3") in the gap under
## it, the run-over strip and the stats window. The score itself is on the cabinet's marquee.
##
## Nothing here is drawn over the fruit: callouts sit above the cabinet and the strip on its base.

signal mode_pressed
signal lives_pressed
signal sound_pressed
signal stats_toggled(open: bool)

const MARGIN := 24.0
const GAP := 12.0
const ROW_A := 84.0 ## the button row's height
const BAND := 196.0 ## the whole top band's height: the row, then room for a callout
const HEARTS := 3

var _root: Control
var _mode_button: Button
var _lives_button: Button
var _stats_button: Button
var _sound_button: Button
var _sound_icon: TextureRect
var _hearts: Array[TextureRect] = []
var _streak_panel: Panel
var _streak_caption: Label
var _streak_label: Label
var _banner: Label
var _banner_tween: Tween
var _strip: Panel
var _strip_title: Label
var _strip_detail: Label
var _strip_tween: Tween
var _stats: Control
var _cover: ColorRect
var _save: SaveData
var _variant := "traditional"
var _streak := 1.0
var _top := 0.0 ## the notch / status bar inset, in canvas units
var _bottom := 0.0
var _banner_y := 300.0
var _size := Vector2(1080, 1920)


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # hard pixels for the boxes and icons
	var theme := Theme.new()
	theme.default_font = Parts.font()
	_root.theme = theme
	add_child(_root)

	_mode_button = _button("TRADITIONAL", 38, PixelUi.TEAL, PixelUi.CYAN)
	_mode_button.pressed.connect(func() -> void: mode_pressed.emit())
	_lives_button = _button("", 30, PixelUi.CHIP, PixelUi.PANEL_EDGE)
	_lives_button.pressed.connect(func() -> void: lives_pressed.emit())
	for i in HEARTS:
		_hearts.append(_icon(_lives_button, PixelUi.HEART, PixelUi.RED))
	_stats_button = _button("", 30, PixelUi.CHIP, PixelUi.PANEL_EDGE)
	_stats_button.pressed.connect(func() -> void: show_stats(true))
	_icon(_stats_button, PixelUi.BARS, PixelUi.CYAN)
	_sound_button = _button("", 30, PixelUi.CHIP, PixelUi.PANEL_EDGE)
	_sound_button.pressed.connect(func() -> void: sound_pressed.emit())
	_sound_icon = _icon(_sound_button, PixelUi.SPEAKER, PixelUi.TEXT)

	_streak_panel = Panel.new()
	_streak_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_panel.add_theme_stylebox_override("panel", PixelUi.box(PixelUi.PANEL, PixelUi.PANEL_EDGE))
	_root.add_child(_streak_panel)
	_streak_caption = _label("STREAK", 24, PixelUi.SOFT, _streak_panel)
	_streak_label = _label("x1", 52, PixelUi.SOFT, _streak_panel)
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_banner = _label("", 72, PixelUi.GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", PixelUi.INK)
	_banner.modulate.a = 0.0

	_strip = Panel.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	_root.add_child(_strip)
	_strip_title = _label("RUN OVER", 48, PixelUi.RED, _strip)
	_strip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip_detail = _label("", 32, PixelUi.TEXT, _strip)
	_strip_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	get_viewport().size_changed.connect(_layout)
	_layout()


# A pixel button: a coloured block with a dark lip under it that it sinks into when pressed.
func _button(text: String, font_size: int, fill: Color, outline: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, PixelUi.TEXT)
	b.add_theme_stylebox_override("normal", PixelUi.box(fill, outline, 2))
	b.add_theme_stylebox_override("hover", PixelUi.box(fill.lightened(0.1), outline, 2))
	b.add_theme_stylebox_override("disabled", PixelUi.box(fill, outline, 2))
	# Pressed: the lip is gone and the face sits where the lip was.
	var down := PixelUi.box(fill.darkened(0.12), outline, 0).duplicate() as StyleBoxTexture
	down.expand_margin_top = -2.0 * PixelUi.UNIT
	down.content_margin_top = 4.0 * PixelUi.UNIT
	down.content_margin_bottom = 2.0 * PixelUi.UNIT
	b.add_theme_stylebox_override("pressed", down)
	_root.add_child(b)
	return b


# A pixel icon on a button (or anywhere): placed and sized by _layout.
func _icon(parent: Control, rows: Array, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = PixelUi.icon(rows)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = color
	parent.add_child(t)
	return t


# Put an icon in the middle of a `width` x `height` face, `scale` canvas units per pixel, `dx` off centre.
static func _place_icon(icon: TextureRect, width: float, height: float, scale: float, dx := 0.0) -> void:
	var size := Vector2(icon.texture.get_size()) * scale
	icon.size = size
	icon.position = Vector2((width - size.x) / 2.0 + dx, (height - 2.0 * PixelUi.UNIT - size.y) / 2.0)


func _label(text: String, font_size: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(parent if parent else _root).add_child(l)
	return l


## Room to leave at the top and bottom of the screen for a notch or home bar, in canvas units.
func set_insets(top: float, bottom: float) -> void:
	_top = top
	_bottom = bottom
	_layout()


## The screen height (canvas units) the top band takes up, insets included.
func band_height() -> float:
	return _top + BAND


## Where callouts go: between the row of buttons and the top of the cabinet (`cabinet_top` is its screen height).
func set_cabinet_top(cabinet_top: float) -> void:
	var row_bottom := _top + 14.0 + ROW_A
	_banner_y = maxf((row_bottom + cabinet_top) / 2.0, row_bottom + 48.0)
	_layout()


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	var w := _size.x
	var y := _top + 14.0
	# One row: mode, lives and the streak on the left, stats and sound on the right.
	_mode_button.position = Vector2(MARGIN, y)
	_mode_button.size = Vector2(308, ROW_A)
	_lives_button.position = Vector2(MARGIN + 308 + GAP, y)
	_lives_button.size = Vector2(176, ROW_A)
	for i in HEARTS:
		_place_icon(_hearts[i], 176, ROW_A, 5.0, (i - 1) * 50.0)
	_sound_button.size = Vector2(ROW_A + 8, ROW_A)
	_sound_button.position = Vector2(w - MARGIN - _sound_button.size.x, y)
	_place_icon(_sound_icon, _sound_button.size.x, ROW_A, 5.0)
	_stats_button.size = Vector2(ROW_A + 8, ROW_A)
	_stats_button.position = Vector2(_sound_button.position.x - GAP - _stats_button.size.x, y)
	_place_icon(_stats_button.get_child(0) as TextureRect, _stats_button.size.x, ROW_A, 5.0)
	_streak_panel.size = Vector2(maxf(_stats_button.position.x - GAP - _streak_x(), 200.0), ROW_A - 2.0 * PixelUi.UNIT)
	_streak_panel.position = Vector2(_streak_x(), y)
	_streak_panel.pivot_offset = _streak_panel.size / 2.0
	_streak_caption.position = Vector2(20, 0)
	_streak_caption.size = Vector2(130, _streak_panel.size.y)
	_streak_label.position = Vector2(0, 0)
	_streak_label.size = Vector2(_streak_panel.size.x - 20, _streak_panel.size.y)
	_banner.size = Vector2(w, 110)
	_banner.position = Vector2(0, _banner_y - 55)
	_banner.pivot_offset = _banner.size / 2.0
	_strip.size = Vector2(minf(w - 2 * MARGIN, 1030), 148)
	_strip_title.position = Vector2(0, 14)
	_strip_title.size = Vector2(_strip.size.x, 60)
	_strip_detail.position = Vector2(0, 78)
	_strip_detail.size = Vector2(_strip.size.x, 50)
	if not _strip.visible:
		_strip.position = Vector2((w - _strip.size.x) / 2.0, _size.y)
	if _stats:
		show_stats(false)


func _streak_x() -> float:
	return MARGIN + 308 + GAP + 176 + GAP


## True if a touch here belongs to the HUD (a button, or the stats window is open), so it isn't a press on the machine.
func blocks_tap(at: Vector2) -> bool:
	if _stats:
		return true
	for b: Button in [_mode_button, _lives_button, _stats_button, _sound_button]:
		if b.visible and b.get_global_rect().grow(8).has_point(at):
			return true
	return false


func set_mode(mode: String, _lives_on: bool) -> void:
	_mode_button.text = Modes.INFO[mode].title
	_lives_button.disabled = not Modes.has_lives_toggle(mode)


## The hearts on the lives button: one per life the run started with, emptied as they are lost. With one life the
## other two are faint outlines of what the button would give you.
func set_lives(lives: int, max_lives: int) -> void:
	for i in HEARTS:
		var heart := _hearts[i]
		if i < lives:
			heart.modulate = PixelUi.RED
		elif i < max_lives:
			heart.modulate = Color8(84, 40, 56)
		else:
			heart.modulate = Color(PixelUi.SOFT, 0.22)


func set_sound(on: bool) -> void:
	_sound_icon.texture = PixelUi.icon(PixelUi.SPEAKER if on else PixelUi.SPEAKER_OFF)
	_sound_icon.modulate = PixelUi.TEXT if on else PixelUi.SOFT
	_place_icon(_sound_icon, _sound_button.size.x, ROW_A, 5.0)


## The score went up: the amount pops up at `from`, flies to `to` (screen positions) and `on_land` is called when it
## gets there (the cabinet's marquee then rolls up to the new score).
func fly_score(gained: int, from: Vector2, to: Vector2, color: Color, on_land: Callable) -> void:
	var fly := _label("+" + Fx.number(gained), 60, color)
	fly.add_theme_constant_override("outline_size", 10)
	fly.add_theme_color_override("font_outline_color", PixelUi.INK)
	fly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fly.size = Vector2(600, 90)
	fly.pivot_offset = fly.size / 2.0
	fly.position = from - fly.size / 2.0
	fly.scale = Vector2.ONE * 0.5
	var land := func() -> void:
		fly.queue_free()
		on_land.call()
	var tween := create_tween()
	tween.tween_property(fly, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.22)
	tween.tween_property(fly, "position", to - fly.size / 2.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fly, "scale", Vector2.ONE * 0.55, 0.32)
	tween.tween_callback(land)


func _streak_box(on: bool) -> StyleBoxTexture:
	return PixelUi.box(Color8(64, 46, 10), PixelUi.GOLD) if on else PixelUi.box(PixelUi.PANEL, PixelUi.PANEL_EDGE)


## The streak badge. `bump`: it just went up (it pops); a drop back to x1 shakes it red.
func set_streak(mult: float, bump: bool) -> void:
	var lost := mult < _streak and _streak > 1.0
	_streak = mult
	_streak_label.text = Fx.times(mult)
	var on := mult > 1.0
	var color := PixelUi.GOLD if on else PixelUi.SOFT
	_streak_label.add_theme_color_override("font_color", color)
	_streak_caption.add_theme_color_override("font_color", color)
	_streak_panel.add_theme_stylebox_override("panel", _streak_box(on))
	if bump and on:
		_streak_panel.scale = Vector2.ONE * 1.3
		create_tween().tween_property(_streak_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif lost:
		_streak_panel.add_theme_stylebox_override("panel", PixelUi.box(Color8(70, 14, 22), PixelUi.RED))
		var home := Vector2(_streak_x(), _top + 14.0)
		var settle := func() -> void:
			if _streak <= 1.0:
				_streak_panel.add_theme_stylebox_override("panel", _streak_box(false))
		var tween := create_tween()
		for dx: float in [-14.0, 12.0, -8.0, 5.0, 0.0]:
			tween.tween_property(_streak_panel, "position", home + Vector2(dx, 0), 0.04)
		tween.tween_callback(settle)


## A plain dark cover over everything while the game loads; it fades away when play starts.
func cover(on: bool) -> void:
	if on:
		_cover = ColorRect.new()
		_cover.color = PixelUi.INK
		_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_cover)
	elif _cover:
		var old := _cover
		_cover = null
		var tween := create_tween()
		tween.tween_property(old, "modulate:a", 0.0, 0.25)
		tween.tween_callback(old.queue_free)


## A short callout over the cabinet's sign. `big` holds longer and is larger.
func banner(text: String, color: Color, big := false) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.add_theme_font_size_override("font_size", 92 if big else 70)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE * 0.5
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.0 if big else 0.35)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)


## The run ended: a strip slides up over the cabinet's base while the next run is already live.
func run_over(score: int, machine: int, best_streak: float, new_best: bool) -> void:
	if _strip_tween:
		_strip_tween.kill()
	var color := PixelUi.GOLD if new_best else PixelUi.RED
	_strip.add_theme_stylebox_override("panel", PixelUi.box(PixelUi.INK, color))
	_strip_title.text = "NEW BEST!  " + Fx.number(score) if new_best else "RUN OVER  " + Fx.number(score)
	_strip_title.add_theme_color_override("font_color", color)
	_strip_detail.text = "MACHINE %d      BEST STREAK %s" % [machine, Fx.times(best_streak)]
	_strip.visible = true
	var x := (_size.x - _strip.size.x) / 2.0
	_strip.position = Vector2(x, _size.y)
	var shown := Vector2(x, _size.y - _strip.size.y - 20.0 - _bottom)
	var hide := func() -> void: _strip.visible = false
	_strip_tween = create_tween()
	_strip_tween.tween_property(_strip, "position", shown, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strip_tween.tween_interval(2.6)
	_strip_tween.tween_property(_strip, "position", Vector2(x, _size.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_strip_tween.tween_callback(hide)


## What the stats window shows: the save, and which way of playing to list first.
func set_stats_source(save: SaveData, variant: String) -> void:
	_save = save
	_variant = variant


func stats_open() -> bool:
	return _stats != null


## Open (or redraw) the stats window. `announce` tells the game, which pauses the machine while it is open.
func show_stats(announce: bool) -> void:
	if _stats:
		_stats.queue_free()
		_stats = null
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	_stats = shade
	var w := minf(_size.x - 2 * MARGIN, 1000.0)
	var h := _size.y - _top - _bottom - 160.0
	var window := Panel.new()
	window.add_theme_stylebox_override("panel", PixelUi.box(PixelUi.PANEL, PixelUi.CYAN))
	window.position = Vector2((_size.x - w) / 2.0, _top + 80.0)
	window.size = Vector2(w, h)
	shade.add_child(window)
	var title := _label("STATS", 60, PixelUi.CYAN, window)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 22)
	title.size = Vector2(w, 76)
	var close := _button("CLOSE", 38, Color8(170, 44, 64), PixelUi.RED)
	close.reparent(window)
	close.size = Vector2(280, 92)
	close.position = Vector2((w - 280) / 2.0, h - 92 - 30)
	close.pressed.connect(hide_stats)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36, 112)
	scroll.size = Vector2(w - 72, h - 112 - 92 - 54)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(w - 100, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var variants: Array[String] = [_variant]
	for v: String in ["traditional", "traditional_lives", "party", "zen", "zen_lives"]:
		if v != _variant:
			variants.append(v)
	for v in variants:
		var s: Dictionary = _save.stats_for(v) if _save else SaveData.empty_stats()
		var parts := v.split("_")
		var heading := String(Modes.INFO[parts[0]].title) + ("  +  3 LIVES" if parts.size() > 1 else "")
		var head := _label(heading, 40, PixelUi.GOLD if v == _variant else PixelUi.TEXT, list)
		head.custom_minimum_size = Vector2(0, 60)
		_stat_row(list, "Best score", Fx.number(s.best_score))
		_stat_row(list, "Furthest machine", str(int(s.best_machine)) if int(s.best_machine) > 0 else "-")
		_stat_row(list, "Best streak", Fx.times(float(s.best_streak)) if int(s.best_streak) > 1 else "-")
		_stat_row(list, "Runs", Fx.number(s.runs))
		_stat_row(list, "Machines cleared", Fx.number(s.machines))
		# Every streak there has been, by the size it reached.
		var sizes: Array = []
		for key: String in s.streaks:
			sizes.append(int(key))
		sizes.sort()
		var line := ""
		for size: int in sizes:
			line += "x%d: %s     " % [size, Fx.number(s.streaks[str(size)])]
		var streaks := _label("Streaks   " + (line.strip_edges() if line != "" else "none yet"), 30, PixelUi.CYAN, list)
		streaks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		streaks.custom_minimum_size = Vector2(w - 100, 44)
		var rule := ColorRect.new()
		rule.color = PixelUi.PANEL_EDGE
		rule.custom_minimum_size = Vector2(0, PixelUi.UNIT)
		list.add_child(rule)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 14)
		list.add_child(spacer)
	if announce:
		stats_toggled.emit(true)


func _stat_row(list: Control, name: String, value: String) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	var left := _label(name, 32, PixelUi.SOFT, row)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(0, 44)
	var right := _label(value, 34, PixelUi.TEXT, row)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func hide_stats() -> void:
	if _stats:
		_stats.queue_free()
		_stats = null
		stats_toggled.emit(false)
