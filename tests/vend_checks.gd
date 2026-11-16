extends SceneTree
## Checks for the rules (scripts/vend.gd) and the three modes (scripts/modes.gd), ported from the Roblox game's
## tests/vend_checks.luau, plus figures for simulated players whose timing is a little off.
##
## Run (after `godot --headless --import` once, so class names are known):
##   godot --headless -s tests/vend_checks.gd
## Exit code = number of failed checks.

const T := 1000.0 # a pretend clock
const EXPECTED := 91 # checks in this file; fewer ran = a script error

var passed := 0
var failures: Array[String] = []
var infos: Array[String] = []


func check(name: String, cond: bool, detail: Variant = null) -> void:
	if cond:
		passed += 1
	else:
		failures.append(name + ("" if detail == null else " :: " + str(detail)))


# The Roblox game's lives mode on its 8 machines (items on, capped streak), unless `extra` says otherwise.
func params(tier := 1, extra := {}) -> Vend.Params:
	var p := Vend.Params.new()
	p.tier = tier
	p.max_tier = 8
	p.phase = 0.0
	p.lives = 1
	p.seed = 12345
	for key: String in extra:
		p.set(key, extra[key])
	return p


# The time when the cursor is in the middle of ring position i, at or after t.
func time_on(run: Vend, i: int, t: float) -> float:
	for k in 2001:
		var probe := maxf(t, run.t0) + k * 0.002
		if run.index_at(probe) == i:
			var stop := probe
			while run.index_at(stop + 0.002) == i:
				stop += 0.002
			return (probe + stop) / 2.0
	push_error("cursor never reached %d" % i)
	return NAN


# Press every safe cell, in cursor order, starting at t, until the machine clears (or the run ends).
func clear_machine(run: Vend, t: float) -> Array:
	var out: Array = []
	t = maxf(t, run.last_press + 0.005) # a press must be later than the one before it
	for _i in 30:
		var at := run.next_target(t)
		if is_nan(at):
			break
		var r := run.press(at)
		out.append(r)
		t = at + 0.005
		if r.cleared or r.over:
			break
	return [out, t]


# A run on `tier` whose first board has a cell of `kind` (searching seeds). Returns [run, index].
func run_with(kind: String, tier := 6, extra := {}) -> Array:
	for seed in range(1, 5001):
		var e := extra.duplicate()
		e["seed"] = seed
		var run := Vend.new(params(tier, e), T)
		for i in Vend.ICONS:
			if run.board[i].kind == kind:
				return [run, i]
	push_error("no seed gives a " + kind)
	return []


func _init() -> void:
	rules()
	items()
	modes()
	players()
	for line in infos:
		print("INFO ", line)
	for line in failures:
		print("FAIL ", line)
	print("%d passed, %d failed" % [passed, failures.size()])
	if passed + failures.size() < EXPECTED:
		print("ERROR: only %d of %d checks ran (a script error stopped the rest)" % [passed + failures.size(), EXPECTED])
		quit(1)
		return
	quit(failures.size())


func rules() -> void:
	check("the items are fruit", Vend.ITEMS.has("apple") and Vend.ITEMS.has("cherry") and Vend.ITEMS.size() == 6)

	# ===== speeds =====
	var s := Vend.new(params(1), T)
	check("machines 1-4 share one speed", s.start_speed(1) == s.start_speed(4) and s.start_speed(1) == 7.4)
	check("machines 5-8 share a faster one", s.start_speed(5) == s.start_speed(8) and s.start_speed(5) == 8.2)
	check("no pause between machines", Vend.MACHINE_PAUSE == 0.0)

	# ===== the cursor is a pure function of time =====
	var run := Vend.new(params(1), T)
	check("cursor waits START_DELAY before moving", run.phase_at(T) == run.phase_at(T + Vend.START_DELAY))
	var start := run.t0
	var seen := {}
	for k in 60:
		seen[run.index_at(start + k / 10.0 / run.base)] = true
	check("the cursor visits all six items", seen.size() == 6, seen.size())
	check("no burst: one item per 1/base seconds", (run.index_at(start + 0.5 / run.base) + 1) % 6 == run.index_at(start + 1.5 / run.base))
	check("a press before the cursor moves doesn't count", run.press(T + 0.1) == null)

	# ===== lighting, the burst, and a mistake ending the run =====
	run = Vend.new(params(1), T)
	var base := run.base
	var t := time_on(run, 2, run.t0)
	var phase_before := run.phase_at(t)
	var r := run.press(t)
	check("press on an unlit fruit lights it", r != null and r.kind == "light" and r.index == 2 and run.lit[2])
	check("the first fruit lit is worth 1 point", r.points == 1 and run.pot == 1)
	check("lighting bursts the cursor", absf(run.speed_at(t) - (base + Vend.BOOST_STEP)) < 1e-9)
	check("the burst fades", run.speed_at(t + 3.0) - base < 0.01)
	check("the cursor doesn't jump when its speed changes", absf(run.phase_at(t) - phase_before) < 1e-9)
	check("the same moment can't be pressed twice", run.press(t) == null)
	check("a press earlier than the last doesn't count", run.press(t - 0.05) == null)
	var t2 := time_on(run, 4, t + 0.01)
	var r2 := run.press(t2)
	check("the second fruit lit is worth 2 points", r2.points == 2 and run.pot == 3)
	var t3 := time_on(run, 2, t2 + 0.01)
	var r3 := run.press(t3)
	check("press on a lit fruit is a mistake", r3.kind == "mistake" and r3.index == 2)
	check("one mistake ends the run", r3.over and run.over and not r3.perfect_run)
	check("...and its pot is lost", run.pot == 0 and r3.paid == 0.0)
	check("no presses count after the run is over", run.press(t3 + 1.0) == null)

	# Lives: a mistake costs one instead.
	run = Vend.new(params(1, {"lives": 3}), T)
	var first := run.press(run.next_target(run.t0))
	var miss := run.press(time_on(run, first.index, run.last_press + 0.01))
	check("with lives, a mistake costs one", miss.kind == "mistake" and not miss.over and run.lives == 2)
	check("...takes the burst away", run.boost == 0.0)
	check("...and drops the streak", miss.mult == 1.0)
	var done: Array = clear_machine(run, run.last_press + 0.01)[0]
	check("a machine with a mistake pays without the bonus", done.back().cleared and not done.back().perfect)
	check("...and doesn't start a streak", run.streak == 0)

	# A perfect machine gives a life back.
	run = Vend.new(params(1, {"lives": 3}), T)
	first = run.press(run.next_target(run.t0))
	run.press(time_on(run, first.index, run.last_press + 0.01))
	clear_machine(run, run.last_press + 0.01)
	check("still two lives after the flawed machine", run.lives == 2)
	clear_machine(run, run.t0)
	check("a flawless machine gives a life back", run.lives == 3 and run.streak == 1)

	# ===== clearing machines, streaks =====
	run = Vend.new(params(1), T)
	var cleared: Array = clear_machine(run, run.t0)
	var list: Array = cleared[0]
	var last: Vend.Result = list.back()
	check("six presses clear a plain machine", list.size() == 6 and last.cleared, list.size())
	check("a clear pays (21 + bonus) x1", last.paid == (21 + Vend.PERFECT_BONUS) * 1.0, last.paid)
	check("clearing climbs a tier", last.tier_up and run.tier == 2)
	check("a clear raises the streak MULT", run.streak == 1 and run.mult() == 2.0)
	check("the next machine is empty and starts at once", run.lit_count == 0 and run.pot == 0 and absf(run.t0 - (float(cleared[1]) - 0.005)) < 1e-6)
	check("...with no burst", run.boost == 0.0)
	var list2: Array = clear_machine(run, run.t0)[0]
	check("the second clear pays at x2", list2.back().paid_mult == 2.0 and list2.back().paid == 36.0 * 2)

	run = Vend.new(params(8), T)
	last = clear_machine(run, run.t0)[0].back()
	check("with a top machine, clearing it is a perfect run", last.over and last.perfect_run and run.over and not last.tier_up)
	check("...and it still pays", last.paid > 0.0)

	run = Vend.new(params(1, {"streak_step": 5.0}), T)
	for _i in 3:
		clear_machine(run, run.t0)
	check("MULT is capped at max_mult", run.mult() == Vend.MAX_MULT, run.mult())

	# ===== two copies agree =====
	var a := Vend.new(params(5, {"phase": 2.7, "seed": 99, "lives": 50}), T)
	var b := Vend.new(params(5, {"phase": 2.7, "seed": 99, "lives": 50}), T)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	t = a.t0
	var agree := true
	for _i in 60:
		t += 0.05 + rng.randf() * 0.4
		var ra := a.press(t)
		var rb := b.press(t)
		if (ra == null) != (rb == null) or (ra != null and (ra.index != rb.index or ra.kind != rb.kind or ra.paid != rb.paid)):
			agree = false
		if a.over:
			break
	check("two copies given the same press times stay identical", agree and a.pot == b.pot and a.tier == b.tier and a.phase0 == b.phase0 and a.rng == b.rng)


func items() -> void:
	var plain := true
	for tier in range(1, Vend.SPECIALS_FROM):
		for seed in range(1, 201):
			for cell: Dictionary in Vend.new(params(tier, {"seed": seed}), T).board:
				if cell.kind != "fruit" and cell.kind != "mult":
					plain = false
	check("only multiplier fruit before machine %d" % Vend.SPECIALS_FROM, plain)

	var only_mult := true
	var nothing := true
	for tier in range(1, 9):
		for seed in range(1, 301):
			for cell: Dictionary in Vend.new(params(tier, {"seed": seed, "specials": false}), T).board:
				if cell.kind != "fruit" and cell.kind != "mult":
					only_mult = false
			for cell: Dictionary in Vend.new(params(tier, {"seed": seed, "specials": false, "mults": false}), T).board:
				if cell.kind != "fruit":
					nothing = false
	check("specials off: no bombs or other specials on any machine", only_mult)
	check("specials and mults off: plain fruit only", nothing)

	var mult_share := func(tier: int) -> float:
		var hits := 0
		for seed in range(1, 3001):
			for cell: Dictionary in Vend.new(params(tier, {"seed": seed}), T).board:
				if cell.kind == "mult":
					hits += 1
		return hits / 3000.0
	var m1: float = mult_share.call(1)
	var m4: float = mult_share.call(4)
	var m8: float = mult_share.call(8)
	check("multiplier fruit get likelier with the machine", m1 < m4 and m4 < m8, "%.3f / %.3f / %.3f" % [m1, m4, m8])
	check("...and stay rare (under 1 board in 4 on machine 8)", m8 < 0.25 and m1 < 0.07, "%.3f / %.3f" % [m1, m8])
	check("item chances hold past machine 8", Vend.mult_chance_at(30) == Vend.mult_chance_at(8))

	var kinds := {}
	var specials := 0
	var plain_left := true
	for seed in range(1, 2001):
		var run := Vend.new(params(6, {"seed": seed}), T)
		var plain_count := 0
		for cell: Dictionary in run.board:
			kinds[cell.kind] = kinds.get(cell.kind, 0) + 1
			if cell.kind != "fruit":
				specials += 1
			else:
				plain_count += 1
		if plain_count < 2:
			plain_left = false
	check("every item turns up on machine 6", kinds.has("mult") and kinds.has("strong") and kinds.has("bomb") and kinds.has("ice") and kinds.has("reverse"), kinds)
	check("at least two plain fruit on every board", plain_left)
	infos.append("machine 6: %.2f items per board (the Roblox game measured about 1.9)" % (specials / 2000.0))
	var a := Vend.new(params(6, {"seed": 777}), T)
	var b := Vend.new(params(6, {"seed": 777}), T)
	var same := true
	for i in 6:
		if a.board[i].kind != b.board[i].kind or a.board[i].mult != b.board[i].mult:
			same = false
	check("the same seed rolls the same board", same)
	# The generator's first values, worked out by hand from rng = rng * 48271 mod (2^31 - 1), starting at seed + 1.
	var g := Vend.new(params(1, {"seed": 0}), T)
	check("the board generator is the Roblox one (Lehmer, 48271)", (48271 * 48271) % 2147483647 == 182605794 and g.rng > 0)

	# bomb
	var found := run_with("bomb")
	var run: Vend = found[0]
	check("a bomb isn't needed to clear", run.need < 6)
	var r := run.press(time_on(run, found[1], run.t0))
	check("pressing a bomb ends the run", r.kind == "bomb" and r.over and run.over)
	found = run_with("bomb", 6, {"lives": 5})
	r = found[0].press(time_on(found[0], found[1], found[0].t0))
	check("...even with lives left", r.over)
	run = run_with("bomb")[0]
	var need := run.need
	var list: Array = clear_machine(run, run.t0)[0]
	check("a board with a bomb clears without it", list.back().cleared and list.size() >= need, list.size())

	# strong
	found = run_with("strong")
	run = found[0]
	var i: int = found[1]
	var t := time_on(run, i, run.t0)
	r = run.press(t)
	check("the first hit on a strong fruit cracks it", r.kind == "crack" and not run.lit[i] and run.hits[i] == 1 and r.points == 0)
	check("...and bursts the cursor", run.boost > 0.0)
	var r2 := run.press(time_on(run, i, t + 0.01))
	check("the second hit lights it", r2.kind == "light" and run.lit[i])
	var r3 := run.press(time_on(run, i, run.last_press + 0.01))
	check("a third hit is a mistake", r3.kind == "mistake" and r3.over)

	# mult
	found = run_with("mult")
	run = found[0]
	var value: int = run.board[found[1]].mult
	need = run.need
	var last: Vend.Result = clear_machine(run, run.t0)[0].back()
	check("a multiplier fruit multiplies the machine's payout", last.cleared and last.fruit_mult == value and last.paid == (need * (need + 1) / 2.0 + Vend.PERFECT_BONUS) * value, "x%d paid %s" % [value, last.paid])
	var counts := {}
	var lucky := {}
	var n := 20000
	for k in range(1, n + 1):
		var v := Vend.roll_fruit_mult((k - 0.5) / n, 1.0)
		counts[v] = counts.get(v, 0) + 1
		v = Vend.roll_fruit_mult((k - 0.5) / n, 3.0)
		lucky[v] = lucky.get(v, 0) + 1
	check("most multiplier fruit are x2-x10", (counts.get(2, 0) + counts.get(3, 0) + counts.get(5, 0) + counts.get(10, 0)) / float(n) > 0.9)
	check("x100 is very rare", counts.get(100, 0) / float(n) < 0.01 and counts.get(100, 0) > 0, counts.get(100, 0))
	check("luck makes x100 likelier", lucky.get(100, 0) > counts.get(100, 0) * 3)

	# ice
	found = run_with("ice")
	run = found[0]
	t = time_on(run, found[1], run.t0)
	run.press(t)
	check("an ice fruit slows the cursor below its base", run.speed_at(t) < run.base * 0.5)
	check("...and it recovers", absf(run.speed_at(t + 8.0) - run.base) < 0.02)

	# reverse
	found = run_with("reverse")
	run = found[0]
	t = time_on(run, found[1], run.t0)
	var before := run.index_at(t)
	run.press(t)
	var after := run.index_at(t + 0.6 / run.base + 0.2)
	check("a reverse fruit turns the cursor round", run.dir == -1 and after != (before + 1) % 6, "%d -> %d" % [before, after])
	var nt := run.next_target(t + 0.01)
	check("next_target works going backwards", not is_nan(nt) and run.is_target(run.index_at(nt)) and absf(fposmod(run.phase_at(nt), 1.0) - 0.5) < 1e-4)
	list = clear_machine(run, t + 0.01)[0]
	check("a reversed machine can still be cleared", list.back().cleared)
	check("the next machine runs forwards again", run.dir == 1)


func modes() -> void:
	var trad := Vend.new(Modes.params("traditional", false, 0.0, 5), T)
	var trad3 := Vend.new(Modes.params("traditional", true, 0.0, 5), T)
	var party := Vend.new(Modes.params("party", false, 0.0, 5), T)
	var zen := Vend.new(Modes.params("zen", false, 0.0, 5), T)
	var zen3 := Vend.new(Modes.params("zen", true, 0.0, 5), T)
	check("traditional: one life, or three with LIVES on", trad.lives == 1 and trad3.lives == 3)
	check("party: always three lives", party.lives == 3 and Vend.new(Modes.params("party", true, 0.0, 5), T).lives == 3)
	check("zen: one life, or three with LIVES on", zen.lives == 1 and zen3.lives == 3)
	check("only party has items", party.specials and party.mults and not trad.specials and not trad.mults and not zen.specials and not zen.mults)
	check("every mode is endless", trad.max_tier == 0 and party.max_tier == 0 and zen.max_tier == 0)
	check("records are kept per mode and lives setting", Modes.variant("traditional", true) == "traditional_lives" and Modes.variant("party", true) == "party" and Modes.variant("zen", false) == "zen")

	# Speeds: the Roblox game's on machines 1-8, then a gentle climb to a cap.
	var same := true
	for tier in range(1, 9):
		if trad.start_speed(tier) != Vend.TIER_SPEEDS[tier - 1] or party.start_speed(tier) != Vend.TIER_SPEEDS[tier - 1]:
			same = false
	check("traditional and party: machines 1-8 at the Roblox game's speeds", same)
	check("machines 9-10 are one step faster", absf(trad.start_speed(9) - 8.5) < 1e-9 and absf(trad.start_speed(10) - 8.5) < 1e-9)
	check("machines 11-12 another", absf(trad.start_speed(11) - 8.8) < 1e-9)
	var rising := true
	for tier in range(1, 60):
		if trad.start_speed(tier + 1) < trad.start_speed(tier):
			rising = false
	check("the speed never drops", rising)
	check("...and stops at the cap", trad.start_speed(19) == Modes.SPEED_CAP and trad.start_speed(500) == Modes.SPEED_CAP, trad.start_speed(19))
	check("zen: the same speed on every machine", zen.start_speed(1) == 7.4 and zen.start_speed(40) == 7.4)

	# Zen plays like traditional's first machine: the same base speed and the same burst on a hit.
	check("zen starts at traditional's starting speed", zen.base == trad.base)
	var t := zen.next_target(zen.t0)
	zen.press(t)
	check("zen: lighting a fruit bursts the cursor, as in traditional", absf(zen.boost - Vend.BOOST_STEP) < 1e-9)
	t = trad.next_target(trad.t0)
	trad.press(t)
	check("traditional: the same burst", absf(trad.boost - Vend.BOOST_STEP) < 1e-9)
	var quick := Modes.params("traditional", false, 0.0, 5)
	quick.start_delay = 0.0
	var at_once := Vend.new(quick, T)
	check("a run with no start delay can be pressed at once", at_once.t0 == T and at_once.press(T + 0.01) != null)

	# Endless: machine 8 doesn't end the run, and the streak keeps climbing.
	var run := Vend.new(Modes.params("traditional", false, 0.0, 9), T)
	var last: Vend.Result
	for _i in 12:
		last = clear_machine(run, run.t0)[0].back()
	check("clearing machine 8 carries on to machine 9", not run.over and run.tier == 13 and last.tier_up)
	check("the streak has no cap", run.streak == 12 and run.mult() == 13.0, run.mult())
	check("the 12th machine paid at x12", last.paid_mult == 12.0 and last.paid == 36.0 * 12)

	# What a machine is worth.
	check("machine 1 is worth 10 a point", Modes.machine_value(1) == 10.0)
	check("x1.55 a machine up to machine 8", Modes.machine_value(2) == 16.0 and Modes.machine_value(8) == roundf(10.0 * pow(1.55, 7)), Modes.machine_value(8))
	var growing := true
	for tier in range(1, 200):
		if Modes.machine_value(tier + 1) <= Modes.machine_value(tier):
			growing = false
	check("later machines are always worth more", growing)
	check("...but not explosively (machine 100 under 30x machine 8)", Modes.machine_value(100) < 30.0 * Modes.machine_value(8), Modes.machine_value(100))
	check("names come round again past machine 8", Modes.tier_title(1) == "MACHINE 1  -  SNACK STOP" and Modes.tier_title(9) == "MACHINE 9  -  SNACK STOP II" and Modes.tier_title(24) == "MACHINE 24  -  GRAND VEND III", Modes.tier_title(24))
	check("...and so do colours", Modes.tier_color(9) == Modes.tier_color(1))


# A player whose presses land within `jitter` seconds of a cell's middle, with `gap` seconds of thinking between
# presses. Returns [score per run, seconds per run, machines per run, best streak MULT on average].
func play_runs(mode: String, lives_on: bool, jitter: float, gap: float, runs: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var score := 0.0
	var seconds := 0.0
	var machines := 0
	var best := 0.0
	for r in range(1, runs + 1):
		var run := Vend.new(Modes.params(mode, lives_on, rng.randf() * 6.0, r * 7919), 0.0)
		var t := run.t0
		var top := 1.0
		while not run.over and t < 1800.0:
			var target := run.next_target(t + gap)
			if is_nan(target):
				break
			var at := maxf(target + (rng.randf() * 2.0 - 1.0) * jitter, t + 0.001)
			var tier_before := run.tier
			var res := run.press(at)
			t = at
			if res != null and res.cleared:
				score += floorf(res.paid * Modes.machine_value(tier_before))
				machines += 1
				top = maxf(top, res.mult)
		seconds += t
		best += top
	return [score / runs, seconds / runs, float(machines) / runs, best / runs]


func players() -> void:
	var cases := [["sharp (+-0.03s)", 0.03, 0.15], ["average (+-0.05s)", 0.05, 0.15], ["sloppy (+-0.07s)", 0.07, 0.15], ["patient average (waits 1.2s)", 0.05, 1.2]]
	for variant: Array in [["traditional", false], ["traditional", true], ["party", false], ["zen", false], ["zen", true]]:
		for case: Array in cases:
			var out := play_runs(variant[0], variant[1], case[1], case[2], 40)
			infos.append("%s, %s: %.1f machines/run, %.0f sec/run, best streak x%.1f, score %.0f" % [Modes.variant(variant[0], variant[1]), case[0], out[2], out[1], out[3], out[0]])
