extends SceneTree
## Checks that touches, clicks and keys reach the machine as exactly one press each, and that the HUD's buttons take
## their own touches. Runs the real main scene.
##
##   godot --headless -s tests/input_checks.gd -- --nosave --seed=5
## Exit code = number of failed checks.

const EXPECTED := 15

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
	check("one touch = one press (not a second from the made-up mouse click)", game.run.presses == 1, game.run.presses)
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
	check("a second finger while the first is down is its own press", game.run.presses == 3 or game.run.over, game.run.presses)
	await wait(0.8) # whatever those hit, let a fresh run start if one ended

	var before: int = game.run.presses
	await click(middle)
	check("a mouse click presses", game.run.presses == before + 1 or game.run.presses == 0 or game.run.over, [before, game.run.presses])
	await wait(0.8)
	before = game.run.presses
	await key(KEY_SPACE)
	check("the space bar presses", game.run.presses == before + 1 or game.run.presses == 0 or game.run.over, [before, game.run.presses])
	await wait(0.8)

	# The HUD's buttons take their own touches.
	var hud: Hud = game.hud
	before = game.run.presses
	var mode_before: String = game.mode
	await tap(centre_of(hud._mode_button))
	check("touching MODE switches mode", game.mode != mode_before, game.mode)
	check("...and is not a press on the machine", game.run.presses == 0)
	check("the mode goes traditional -> party", mode_before == "traditional" and game.mode == "party")
	check("party starts with three lives", game.run.lives == 3 and game.run.specials)
	await tap(centre_of(hud._mode_button))
	check("party -> zen: no burst, no items", game.mode == "zen" and game.run.boost_step == 0.0 and not game.run.specials)
	await tap(centre_of(hud._lives_button))
	check("LIVES gives zen three lives", game.run.lives == 3, game.run.lives)
	await tap(centre_of(hud._lives_button))

	# The stats window stops the clock.
	await wait(0.6)
	await tap(centre_of(hud._stats_button))
	check("touching STATS opens the stats window", hud.stats_open())
	var frozen: float = game.now()
	await tap(middle)
	await wait(0.3)
	check("...the clock stops and touches don't press while it is open", game.now() == frozen and game.run.presses == 0, [frozen, game.now(), game.run.presses])
	hud.hide_stats()
	await wait(0.1)
	check("closing it starts the clock again", game.now() > frozen and not hud.stats_open())

	for line in failures:
		print("FAIL ", line)
	print("%d passed, %d failed" % [passed, failures.size()])
	var code := failures.size()
	if passed + failures.size() < EXPECTED:
		print("ERROR: only %d of %d checks ran" % [passed + failures.size(), EXPECTED])
		code = 1
	quit(code)
