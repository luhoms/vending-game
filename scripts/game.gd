extends Node3D
## The game: one vending machine, played forever. This script owns the clock and the run (scripts/vend.gd), turns
## touches into presses, and makes the cabinet, effects, sounds and HUD react.
##
## There is no start button: the cursor is always running, a cleared machine rolls straight into the next, and when a
## run ends the next one starts RESTART_DELAY later (as in the Roblox game).
##
## Testing aids (after `--` on the command line; none of this is reachable in a normal launch):
##   --mode=party  --lives      start in this mode / with lives on (not saved)
##   --seed=N                   roll the same boards every time
##   --tier=N                   start on machine N
##   --bot=0.03                 play by itself, pressing within this many seconds of each cell's middle
##   --shot=PATH --at=SECONDS   save a screenshot after this long and quit
##   --runfor=SECONDS           print the totals after this long and quit
##   --stats                    open the stats window at the start
##   --nosave                   don't read or write the save file

var save := SaveData.new()
var mode := "traditional"
var run: Vend
var score := 0
var machines := 0 ## cleared this run
var best_streak := 1.0 ## the highest streak MULT this run
var cabinet: Cabinet
var fx: Effects
var sfx: Sfx
var hud: Hud
var camera: Camera3D

var _rng := RandomNumberGenerator.new()
var _restart_at := 0.0 ## (real seconds) when the next run starts
var _clock_offset := 0.0 ## real seconds the game clock has been stopped for
var _paused_at := -1.0 ## the game clock's reading while it is stopped (-1 = running)
var _last_cursor := -1
var _args := {}
var _bot_at := NAN
var _elapsed := 0.0
var _shot_done := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		_args[pair[0]] = pair[1] if pair.size() > 1 else "1"
	_rng.randomize()
	if not _args.has("nosave"):
		save.load_file()
	mode = save.mode
	if _args.has("mode") and Modes.LIST.has(_args.mode):
		mode = _args.mode
	if _args.has("lives"):
		save.lives_on[mode] = true

	_build_room()
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = Fx.CAMERA_FOV
	camera.near = 0.5
	camera.far = 200.0
	add_child(camera)
	fx = Effects.new()
	fx.camera = camera
	add_child(fx)
	cabinet = Cabinet.new()
	cabinet.fx = fx
	add_child(cabinet)
	sfx = Sfx.new()
	sfx.muted = not save.sound
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	hud.mode_pressed.connect(_next_mode)
	hud.lives_pressed.connect(_toggle_lives)
	hud.sound_pressed.connect(_toggle_sound)
	hud.stats_toggled.connect(_on_stats)
	hud.set_sound(save.sound)

	get_viewport().size_changed.connect(_layout)
	_layout()
	cabinet.show_plain()
	_start_run()
	if _args.has("stats"):
		hud.show_stats(true)


# The room: a dark teal wall behind the machine and a floor for the fruit to land on.
func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(8, 9, 14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.9
	add_child(sun)
	var P := Parts
	P.part(self, Vector3(80, 60, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, 28, -0.7)), Color8(16, 44, 50))
	P.part(self, Vector3(80, 0.4, 40), Transform3D(Basis.IDENTITY, Vector3(0, -0.2, 8)), Color8(30, 28, 38))
	for x: float in [-8.2, 8.2]: # gold pilasters either side
		P.part(self, Vector3(0.5, 60, 0.3), Transform3D(Basis.IDENTITY, Vector3(x, 28, -0.45)), Color8(170, 130, 50), P.METAL)
	P.part(self, Vector3(80, 0.5, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, 0.25, -0.45)), Color8(170, 130, 50), P.METAL)


# Fit the camera to the screen: the cabinet fills the width (or the height, on wide screens), with a band kept clear
# above it for the score and a little floor below it.
func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.has_feature("mobile"):
		# Keep clear of a notch or home bar. The safe area is in screen pixels; the HUD works in canvas units.
		var screen := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0.0 and safe.size.y > 0:
			var k := size.y / screen.y
			top_inset = maxf(safe.position.y, 0.0) * k
			bottom_inset = maxf(screen.y - float(safe.end.y), 0.0) * k
	hud.set_insets(top_inset, bottom_inset)

	var aspect := size.x / maxf(size.y, 1.0)
	var top_share := maxf(Fx.TOP_BAND, hud.band_height() / size.y)
	var cabinet_height := Cabinet.BULB_TOP
	var height := maxf(Fx.VIEW_WIDTH / aspect, cabinet_height / (1.0 - top_share - Fx.BOTTOM_BAND))
	var spare := height - cabinet_height
	var above := clampf(Fx.SPARE_TOP * spare, top_share * height, spare)
	var centre_y := cabinet_height + above - height / 2.0
	var distance := height / (2.0 * tan(deg_to_rad(Fx.CAMERA_FOV) / 2.0))
	fx.base_fov = Fx.CAMERA_FOV
	fx.base_transform = Transform3D(Basis.IDENTITY, Vector3(0, centre_y, Cabinet.FRONT_Z + distance))
	camera.transform = fx.base_transform
	camera.fov = Fx.CAMERA_FOV
	hud.set_banner_y(camera.unproject_position(cabinet.sign_position()).y)


## The game clock, in seconds. It stops while the stats window is open, so the cursor waits where it was.
func now() -> float:
	if _paused_at >= 0.0:
		return _paused_at
	return _real() - _clock_offset


func _real() -> float:
	return Time.get_ticks_usec() / 1000000.0 + 10.0


func variant() -> String:
	return Modes.variant(mode, save.lives_for(mode))


func _start_run() -> void:
	var seed := int(_args.seed) if _args.has("seed") else _rng.randi_range(1, 2147483646)
	var params := Modes.params(mode, save.lives_for(mode), _rng.randf() * Vend.ICONS, seed)
	if _args.has("tier"):
		params.tier = maxi(int(_args.tier), 1)
	run = Vend.new(params, now())
	score = 0
	machines = 0
	best_streak = 1.0
	_bot_at = NAN
	cabinet.power_down = false
	cabinet.set_tier(run.tier)
	cabinet.show_board(run, true)
	cabinet.update_display(run, now())
	hud.set_mode(mode, save.lives_for(mode))
	hud.reset_score(0)
	hud.set_best(int(save.stats_for(variant()).best_score))
	hud.set_streak(1.0, false)
	hud.set_stats_source(save, variant())


func _process(dt: float) -> void:
	_elapsed += dt
	var t := now()
	if (run == null or run.over) and _real() >= _restart_at and _paused_at < 0.0:
		_start_run()

	if _args.has("bot") and run != null and not run.over and _paused_at < 0.0:
		if is_nan(_bot_at):
			var target := run.next_target(t + 0.12)
			if not is_nan(target):
				_bot_at = target + _rng.randf_range(-1.0, 1.0) * float(_args.bot)
		if not is_nan(_bot_at) and t >= _bot_at:
			_bot_at = NAN
			press(t)

	var cursor := cabinet.update(run, t, dt)
	if cursor != _last_cursor:
		_last_cursor = cursor
		if cursor >= 0 and t >= run.t0 and run.speed_at(t) < Fx.TICK_BELOW_SPEED:
			sfx.tick()

	if _args.has("runfor") and _elapsed >= float(_args.runfor):
		var s: Dictionary = save.stats_for(variant())
		print("%s: %d runs, %d machines, best score %d, furthest machine %d, best streak x%d, streaks %s" % [variant(), s.runs, s.machines, s.best_score, s.best_machine, s.best_streak, s.streaks])
		get_tree().quit()
		return

	if _args.has("shot") and not _shot_done and _elapsed >= float(_args.get("at", "2")):
		_shot_done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_args.shot)
		get_tree().quit()


func _input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
		at = event.position
	elif event is InputEventMouseButton:
		# A finger also arrives as a made-up mouse click (so the buttons work); only real mice count here.
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
		at = event.position
	elif event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			if not hud.stats_open():
				press(now())
		return
	if pressed and not hud.blocks_tap(at):
		press(now())


## Press: light whatever the cursor is on at game time `t`.
func press(t: float) -> void:
	if run == null or run.over or _paused_at >= 0.0:
		return # the next run starts by itself
	t = maxf(t - Fx.PRESS_OFFSET, run.last_press + 0.000001)
	cabinet.press_button()
	var streak_before := run.streak
	var result := run.press(t)
	if result:
		_on_result(result, streak_before)


# A callout on the cabinet's header sign; the machine's name steps aside while it shows.
func _banner(text: String, color: Color, big := false) -> void:
	hud.banner(text, color, big)
	cabinet.hide_title(1.45 if big else 0.8)


func _exit_tree() -> void:
	Parts.clear_cache()


func _buzz(ms: int) -> void:
	if save.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# What a press did: the feel.
func _on_result(result: Vend.Result, streak_before: int) -> void:
	var at := cabinet.cell_front(result.index)
	var cell := cabinet.cells[result.index]
	match result.kind:
		"crack":
			# The first hit on a caged fruit: still a correct hit, so it dings one step up, with a metal clank.
			sfx.vend_hit(run.lit_count + 1)
			sfx.play("clank", 1.0, 0.5)
			fx.burst(at, Fx.STEEL, 14, "burst", Fx.FX_SCALE)
			fx.pop_text(at + Vector3(0, 1, 0), "CRACK!", Fx.STEEL, 1.8)
			fx.shake(0.2)
			cabinet.flash_cell(result.index, Fx.WHITE)
			cabinet.crack(result.index)
			_buzz(Fx.BUZZ_HIT)
		"bomb":
			sfx.play("whoosh", 0.5, 0.6)
			sfx.play("boom", 1.0, 0.9)
			sfx.vend_error()
			fx.burst(at, Fx.BOOM, 50, "burst", Fx.FX_SCALE * 1.4)
			fx.burst(at, Color8(255, 220, 120), 30, "sparkle", Fx.FX_SCALE * 1.4)
			fx.pop_text(at + Vector3(0, 1.2, 0), "BOOM!", Fx.BOOM, 3.6)
			fx.shake(1.4)
			fx.punch(-4.0)
			cabinet.flash_cell(result.index, Fx.BOOM)
			cabinet.remove_item(result.index)
			_buzz(Fx.BUZZ_BOMB)
		"light":
			var count := Vend.ICONS if result.cleared else run.lit_count
			sfx.vend_hit(result.points) # the nth fruit lit dings n steps up the scale
			fx.burst(at, Fx.GOLD, 10 + count * 2, "sparkle", Fx.FX_SCALE)
			fx.pop_text(at + Vector3(0, 1, 0), "+%d" % result.points, Fx.GOLD, 1.6 + count * 0.12)
			fx.punch(-0.4 - count * 0.08)
			cabinet.flash_cell(result.index, Fx.WHITE)
			_buzz(Fx.BUZZ_HIT)
			match result.cell:
				"mult":
					var value := cell.mult
					var color := Fx.mult_color(value)
					_banner("x%d FRUIT!" % value, color, value >= 25)
					fx.burst(at, color, 24 + mini(value, 60), "sparkle", Fx.FX_SCALE * 1.2)
					sfx.play("powerup", 1.0 + minf(value, 100.0) / 200.0, 0.7)
					fx.punch(-3.0 if value >= 25 else -1.2)
				"ice":
					_banner("CHILL!", Fx.KIND_TAG.ice.color)
					fx.burst(at, Fx.KIND_TAG.ice.color, 24, "sparkle", Fx.FX_SCALE)
					sfx.play("whoosh", 1.6, 0.5)
					cabinet.remove_decor(result.index)
				"reverse":
					_banner("REVERSE!", Fx.KIND_TAG.reverse.color)
					fx.burst(at, Fx.KIND_TAG.reverse.color, 20, "burst", Fx.FX_SCALE)
					sfx.play("whoosh", 1.3, 0.5)
				"strong":
					cabinet.remove_decor(result.index) # the cage is gone
			if not result.cleared:
				cabinet.pop_item(result.index)
		_: # a mistake
			sfx.vend_error()
			fx.shake(Fx.MISTAKE_SHAKE)
			cabinet.flash_cell(result.index, Fx.RED)
			cabinet.shudder()
			_buzz(Fx.BUZZ_MISTAKE)
			if result.points < 0:
				fx.pop_text(at + Vector3(0, 1, 0), str(result.points), Fx.RED, 2.0)
			if not result.over:
				_banner("LAST LIFE!" if run.lives == 1 else "MISTAKE!", Fx.RED)
			else:
				fx.pop_text(at + Vector3(0, 1, 0), "ALREADY LIT!", Fx.RED, 2.4)

	if result.cleared:
		var paid_tier := result.tier - 1 if result.tier_up else result.tier
		var gained := int(floorf(result.paid * Modes.machine_value(paid_tier)))
		score += gained
		machines += 1
		best_streak = maxf(best_streak, result.mult)
		sfx.vend_complete()
		hud.add_score(score, gained, camera.unproject_position(cabinet.tray_position()), Fx.GOLD if result.perfect else Fx.WHITE)
		cabinet.flash_all(Fx.GOLD if result.perfect else Fx.WHITE)
		cabinet.vend_all()
		_buzz(Fx.BUZZ_CLEAR)
		if result.perfect and not result.over:
			_banner("CLEARED!  STREAK %s" % Fx.times(result.mult), Fx.GOLD)
			fx.punch(-2.0)
		else:
			_banner("EMPTIED!", Fx.WHITE)
		if result.tier_up:
			# The next machine is live straight away.
			cabinet.set_tier(run.tier)
			cabinet.show_board(run, true)
			if paid_tier % Vend.REF_TIERS == 0:
				# Every eighth machine is the top of the Roblox game's run: mark it.
				var lap := paid_tier / Vend.REF_TIERS
				_banner("ALL 8 CLEARED!" if lap == 1 else "LAP %d CLEARED!" % lap, Fx.GOLD, true)
				fx.burst(cabinet.sign_position(), Fx.GOLD, 60, "burst", Fx.FX_SCALE * 1.6)
				fx.punch(-4.0)

	# The streak tracker: every streak that ends is counted, by the size it reached.
	var ended := 0
	if result.over:
		ended = maxi(streak_before, run.streak)
	elif run.streak < streak_before:
		ended = streak_before
	if ended > 0:
		save.record_streak(variant(), 1 + ended)
	hud.set_streak(run.mult(), run.streak > streak_before)

	if result.over:
		_end_run(true)
	cabinet.update_display(run, now())


# The run is over (a mistake, a bomb, or given up by switching mode): count it, flash red, and the next one follows.
func _end_run(show: bool) -> void:
	run.over = true
	var new_best := save.record_run(variant(), score, machines, run.tier)
	if not _args.has("nosave"):
		save.save_file()
	if show:
		hud.run_over(score, run.tier, best_streak, new_best)
		cabinet.power_down = true
		cabinet.set_trims(Fx.RED)
		fx.shake(Fx.RUN_OVER_SHAKE)
		var recover := func() -> void:
			cabinet.power_down = false
			cabinet.set_trims(cabinet.tier_color)
			if run == null or run.over:
				cabinet.show_plain()
		get_tree().create_timer(Fx.RESTART_DELAY).timeout.connect(recover)
	_restart_at = _real() + Fx.RESTART_DELAY


# Give up the run in progress (it still counts, with its streak) and start again at once.
func _abandon_run() -> void:
	if run != null and not run.over:
		if run.streak > 0:
			save.record_streak(variant(), 1 + run.streak)
		if run.presses > 0:
			_end_run(false)
		else:
			run.over = true
	_restart_at = 0.0


func _next_mode() -> void:
	_abandon_run()
	mode = Modes.LIST[(Modes.LIST.find(mode) + 1) % Modes.LIST.size()]
	save.mode = mode
	if not _args.has("nosave"):
		save.save_file()
	_banner(String(Modes.INFO[mode].title), Fx.CYAN, true)
	sfx.play("coin", 1.2, 0.4)
	_start_run()


func _toggle_lives() -> void:
	if not Modes.has_lives_toggle(mode):
		return
	_abandon_run()
	save.lives_on[mode] = not save.lives_for(mode)
	if not _args.has("nosave"):
		save.save_file()
	_banner("THREE LIVES" if save.lives_for(mode) else "ONE LIFE", Fx.CYAN)
	sfx.play("coin", 1.2, 0.4)
	_start_run()


func _toggle_sound() -> void:
	save.sound = not save.sound
	sfx.muted = not save.sound
	hud.set_sound(save.sound)
	if not _args.has("nosave"):
		save.save_file()
	sfx.play("coin", 1.2, 0.4)


# The stats window stops the clock, so the cursor is where you left it when you close it.
func _on_stats(open: bool) -> void:
	if open and _paused_at < 0.0:
		_paused_at = now()
	elif not open and _paused_at >= 0.0:
		_clock_offset = _real() - _paused_at
		_paused_at = -1.0
		_restart_at = maxf(_restart_at, _real())
