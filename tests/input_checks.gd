extends SceneTree
## Checks that touches, clicks and keys reach the machine as exactly one press each, and that the HUD's buttons take
## their own touches. Runs the real main scene.
##
##   godot --headless -s tests/input_checks.gd -- --nosave --seed=5
## Exit code = number of failed checks.

const EXPECTED := 19

var passed := 0
var failures: Array[String] = []
var game: Node


func check(name: String, cond: bool, detail: Variant = null) -> void:
	if cond:
		passed += 1
	else:
		failures.append(name + ("" if detail == null else " :: " + str(detail)))


func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_run.call_deferred()


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# Events are given to the engine in window pixels; the checks work in the HUD's canvas units.
func to_window(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func centre_of(button: Button) -> Vector2:
	return button.get_global_rect().get_center()


func touch(at: Vector2, index := 0, down := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(at)
	e.pressed = down
	Input.parse_input_event(e)


func tap(at: Vector2, index := 0) -> void:
	touch(at, index, true)
	await process_frame
	await process_frame
	touch(at, index, false)
	await process_frame
	await process_frame


func click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = to_window(at)
		e.global_position = to_window(at)
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
		await process_frame


func key(code: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
		await process_frame


func _run() -> void:
	await wait(0.2)
	var size := root.get_visible_rect().size
	var middle := size / 2.0
	var run: Vend = game.run
	check("a run is live at once (no start button)", run != null and not run.over)
	await tap(middle)
	check("a touch before the cursor moves doesn't count", game.run.presses == 0, game.run.presses)
	await wait(0.5)

	await tap(middle)
	check("one touch = one press (not a second from the made-up mouse click)", game.presses_total == 1, game.presses_total)
	await wait(0.3)

	# Two thumbs: the second lands while the first is still down.
	touch(middle + Vector2(-200, 300), 0, true)
	await process_frame
	await process_frame
	touch(middle + Vector2(200, 300), 1, true)
	await process_frame
	await process_frame
	touch(middle + Vector2(-200, 300), 0, false)
	touch(middle + Vector2(200, 300), 1, false)
	await process_frame
	check("a second finger while the first is down is its own press", game.presses_total == 3, game.presses_total)
	await wait(0.3)

	var before: int = game.presses_total
	await click(middle)
	check("a mouse click presses", game.presses_total == before + 1, [before, game.presses_total])
	await wait(0.3)
	before = game.presses_total
	await key(KEY_SPACE)
	check("the space bar presses", game.presses_total == before + 1, [before, game.presses_total])
	await wait(0.3)

	# The HUD's buttons take their own touches.
	var hud: Hud = game.hud
	before = game.presses_total
	var mode_before: String = game.mode
	await tap(centre_of(hud._mode_button))
	check("touching MODE switches mode", game.mode != mode_before, game.mode)
	check("...and is not a press on the machine", game.presses_total == before, [before, game.presses_total])
	check("the mode goes traditional -> party", mode_before == "traditional" and game.mode == "party")
	check("party starts with three lives", game.run.lives == 3 and game.run.specials)
	await tap(centre_of(hud._mode_button))
	check("party -> zen: plain fruit at one speed", game.mode == "zen" and not game.run.specials and not game.run.mults and game.run.start_speed(30) == game.run.start_speed(1))
	await tap(centre_of(hud._lives_button))
	check("LIVES gives zen three lives", game.run.lives == 3, game.run.lives)
	await tap(centre_of(hud._lives_button))

	# The stats window stops the clock.
	await wait(0.6)
	await tap(centre_of(hud._stats_button))
	check("touching STATS opens the stats window", hud.stats_open())
	var frozen: float = game.now()
	var before_stats: int = game.presses_total
	await tap(middle)
	await wait(0.3)
	check("...the clock stops and touches don't press while it is open", game.now() == frozen and game.presses_total == before_stats, [frozen, game.now(), game.presses_total])
	hud.hide_stats()
	await wait(0.1)
	check("closing it starts the clock again", game.now() > frozen and not hud.stats_open())

	# Losing never stops play: the next run is live in the same instant (zen, one life, at this point).
	await wait(0.3)
	var run_before: Vend = game.run
	var first: float = run_before.next_target(game.now() + 0.01)
	game.press(first)
	var lit_index: int = run_before.index_at(first)
	var again := first + 0.02
	while run_before.index_at(again) == lit_index:
		again += 0.002
	while run_before.index_at(again) != lit_index:
		again += 0.002
	game.press(again) # the same fruit twice: a mistake, and with one life the run is over
	check("a mistake on the last life ends the run", run_before.over)
	check("...and a new run is already live, with no wait before its cursor moves", game.run != run_before and not game.run.over and game.run.presses == 0 and game.run.t0 <= game.now())
	check("...its cursor carrying on from where the old one was", game.run.index_at(game.run.t0) == run_before.index_at(game.run.t0))
	await tap(middle)
	check("...so the very next touch counts", game.run.presses == 1, game.run.presses)

	for line in failures:
		print("FAIL ", line)
	print("%d passed, %d failed" % [passed, failures.size()])
	var code := failures.size()
	if passed + failures.size() < EXPECTED:
		print("ERROR: only %d of %d checks ran" % [passed + failures.size(), EXPECTED])
		code = 1
	quit(code)
