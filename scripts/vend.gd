class_name Vend
extends RefCounted
## The vending machine game as pure rules: no nodes, no clock, no global random state. Everything follows from the
## parameters a run starts with and the times it is pressed at, so it can be unit-tested (tests/vend_checks.gd) and a
## replay is exact.
##
## This is a port of the Roblox game's shared/Vend.luau. Ring positions are 0-5 here (1-6 there); everything else,
## including the board generator's integer sequence, is the same, so the same seed rolls the same boards.
##
## Six fruit sit behind the glass. A cursor runs round them in a ring. Its speed is the machine's base speed plus a
## BURST that each correct press adds and that fades away within about a second. Both only change on a press, so where
## the cursor is follows from the time alone: index_at(t).
##
##   * Press on an unlit fruit: it lights, adds points to the machine's POT (the nth fruit lit is worth n) and bursts
##     the cursor forward, so a player who keeps hitting chains presses and clears the board quickly.
##   * Press on a fruit that is already lit: a MISTAKE. It costs a life; with none left the run is over (pot lost).
##   * All fruit lit: the machine pays (pot + bonus) x MULT x any multiplier fruit lit, and the next machine starts at
##     once. Every machine cleared without a mistake raises MULT for the next one.
##   * Items (only in modes that switch them on):
##       mult     a glowing fruit worth x2 to x100 (x100 is rainbow and very rare)
##       strong   a caged fruit that takes two correct hits (the first cracks the cage)
##       bomb     a bomb instead of a fruit: pressing it ends the run on the spot. The machine clears without it.
##       ice      lighting it chills the cursor: it slows right down, then speeds back up over a second or two
##       reverse  lighting it turns the cursor round

const ICONS := 6
## The fruit behind the glass, round the ring in cursor order (clockwise from the top left of a 2 x 3 grid).
const ITEMS: Array[String] = ["apple", "banana", "orange", "cherry", "strawberry", "pear"]
## Grid cell [column, row] of each ring position (column 1-2 from the left, row 1-3 from the top).
const CELLS := [[1, 1], [2, 1], [2, 2], [2, 3], [1, 3], [1, 2]]

const PERFECT_BONUS := 15 ## points added to a machine cleared without a mistake
const MISTAKE_POINTS := 3 ## points a mistake takes out of the pot
## Base cursor speed (items/sec) by machine in the Roblox game. Modes pass their own table (scripts/modes.gd).
const TIER_SPEEDS: Array[float] = [7.4, 7.4, 7.4, 7.4, 8.2, 8.2, 8.2, 8.2]
const BOOST_STEP := 3.2 ## a BURST of speed (items per second) added by every fruit lit...
const BOOST_MAX := 7.0 ## ...stacking up to this much while you chain hits
const BOOST_FADE := 0.42 ## seconds for a burst to fade to 37% (1/e)
const ICE_SLOW := 0.6 ## an ice fruit takes this share off the base speed...
const ICE_FADE := 1.4 ## ...and the cursor gets it back over this (1/e)
const MULT_CHANCE_BASE := 0.04 ## chance of a multiplier fruit on machine 1...
const MULT_CHANCE_TIER := 0.025 ## ...plus this per machine after it (about 21% on machine 8)
const STREAK_STEP := 1.0 ## MULT gained per machine cleared in a row
const MAX_MULT := 8.0 ## the Roblox game's cap (a mode may pass another)
const START_DELAY := 0.4 ## seconds before a new run's cursor moves
const MACHINE_PAUSE := 0.0 ## the next machine starts the moment the last one is cleared
const SPECIALS_FROM := 4 ## the first machine that can roll strong / bomb / ice / reverse cells
## The Roblox run was 8 machines long. Item chances rise up to this machine and hold there in an endless run.
const REF_TIERS := 8

## What a multiplier fruit is worth, and how often. `rare` = how strongly luck boosts it (weight x luck ^ rare).
const FRUIT_MULTS := [
	{"value": 2, "weight": 40.0, "rare": 0.0},
	{"value": 3, "weight": 26.0, "rare": 0.0},
	{"value": 5, "weight": 18.0, "rare": 0.0},
	{"value": 10, "weight": 11.0, "rare": 0.5},
	{"value": 25, "weight": 3.5, "rare": 1.0},
	{"value": 50, "weight": 1.2, "rare": 1.5},
	{"value": 100, "weight": 0.3, "rare": 2.0},
]


## What a run starts with.
class Params:
	var tier := 1
	var max_tier := 0 ## clearing this machine ends the run as a perfect run; 0 = endless
	var phase := 0.0 ## where the cursor starts on the ring (0 to 6)
	var slow := 0.0 ## share taken off every speed, 0 to 0.9
	var lives := 1
	var streak_step := Vend.STREAK_STEP
	var max_mult := Vend.MAX_MULT
	var seed := 1 ## rolls the items
	var luck := 1.0 ## 1 = normal; bigger makes big multiplier fruit likelier
	var mult_chance := 0.0 ## extra chance of a multiplier fruit on a board
	var mults := true ## multiplier fruit can appear
	var specials := true ## strong, bomb, ice and reverse cells can appear
	var speeds: Array[float] = Vend.TIER_SPEEDS ## base speed by machine
	var late_step := 0.0 ## past the end of `speeds`: this much faster...
	var late_every := 1 ## ...every this many machines...
	var speed_cap := 0.0 ## ...up to this (0 = no cap)
	var boost_step := Vend.BOOST_STEP


## What one press did.
class Result:
	var index := 0 ## ring position the press landed on (0-5)
	var kind := "light" ## light | crack | mistake | bomb
	var cell := "fruit" ## what that cell was
	var points := 0 ## what this press added to (or took from) the pot
	var pot := 0 ## the pot after the press (0 once paid or lost)
	var mult := 1.0 ## streak MULT after the press
	var fruit_mult := 1 ## multiplier fruit lit on this machine so far (or that it was paid with)
	var cleared := false ## all fruit lit: the machine paid
	var perfect := false ## ...without a mistake
	var paid := 0.0 ## points paid by the machine: (pot + bonus) x MULT x fruit_mult, 0 unless cleared
	var paid_mult := 1.0 ## the streak MULT it was paid at
	var tier_up := false ## the next machine started
	var tier := 1 ## the run's tier after the press
	var lives := 1
	var streak := 0
	var over := false ## the run ended (a mistake, a bomb, or a perfect run)
	var perfect_run := false


var tier := 1
var max_tier := 0
var slow := 0.0
var streak_step := STREAK_STEP
var max_mult := MAX_MULT
var luck := 1.0
var mult_chance := 0.0
var mults := true
var specials := true
var speeds: Array[float] = TIER_SPEEDS
var late_step := 0.0
var late_every := 1
var speed_cap := 0.0
var boost_step := BOOST_STEP
var rng := 1
var board: Array = [] ## six cells: {"kind": String, "mult": int}
var need := ICONS ## fruit to light to clear this machine (6 minus bombs)
# The cursor, from t0 on (it holds still before t0): speed(t) = base + boost * e^(-dt / fade), where dt = t - t0, so it
# has gone dir * (base * dt + boost * fade * (1 - e^(-dt / fade))) round the ring from phase0. It only changes on a press.
var t0 := 0.0
var phase0 := 0.0
var base := 0.0
var boost := 0.0 ## a burst (positive) or an ice chill (negative)
var fade := BOOST_FADE
var dir := 1 ## 1 = clockwise, -1 = turned round by a reverse fruit
var lit: Array[bool] = []
var hits: Array[int] = [] ## correct hits on each cell (a strong cell lights on its second)
var lit_count := 0
var fruit_mult := 1 ## product of the multiplier fruit lit on this machine
var mistakes := 0 ## on this machine
var pot := 0
var lives := 1
var max_lives := 1
var streak := 0 ## machines cleared in a row without a mistake
var last_press := -INF
var presses := 0
var over := false


func _init(params: Params, now: float) -> void:
	tier = params.tier
	max_tier = params.max_tier
	slow = clampf(params.slow, 0.0, 0.9)
	streak_step = params.streak_step
	max_mult = params.max_mult
	luck = maxf(params.luck, 1.0)
	mult_chance = clampf(params.mult_chance, 0.0, 0.5)
	mults = params.mults
	specials = params.specials
	speeds = params.speeds
	late_step = params.late_step
	late_every = maxi(params.late_every, 1)
	speed_cap = params.speed_cap
	boost_step = params.boost_step
	rng = posmod(params.seed, 2147483646) + 1
	t0 = now + START_DELAY
	phase0 = fposmod(params.phase, float(ICONS))
	base = start_speed(tier)
	lives = maxi(1, params.lives)
	max_lives = lives
	lit.resize(ICONS)
	hits.resize(ICONS)
	_next_random()
	_clear_machine()


func _next_random() -> float:
	rng = (rng * 48271) % 2147483647
	return rng / 2147483647.0


## Base cursor speed (items/sec) on a machine.
func start_speed(for_tier: int) -> float:
	var count := speeds.size()
	var speed := speeds[clampi(for_tier, 1, count) - 1]
	if for_tier > count and late_step != 0.0:
		speed += late_step * ceili(float(for_tier - count) / late_every)
		if speed_cap > 0.0:
			speed = minf(speed, speed_cap)
	return speed * (1.0 - slow)


## A multiplier fruit's value, from a 0-1 roll. Luck raises the weight of the big ones.
static func roll_fruit_mult(roll: float, with_luck: float) -> int:
	var total := 0.0
	for entry: Dictionary in FRUIT_MULTS:
		total += entry.weight * pow(with_luck, entry.rare)
	var r := roll * total
	for entry: Dictionary in FRUIT_MULTS:
		r -= entry.weight * pow(with_luck, entry.rare)
		if r <= 0.0:
			return entry.value
	return FRUIT_MULTS[FRUIT_MULTS.size() - 1].value


## The chance of a multiplier fruit on a board on `for_tier`: rare, rising with the machine (up to REF_TIERS).
static func mult_chance_at(for_tier: int) -> float:
	return MULT_CHANCE_BASE + MULT_CHANCE_TIER * (mini(for_tier, REF_TIERS) - 1)


# Roll a board for the run's current tier: maybe a multiplier fruit, and from SPECIALS_FROM on a few other items,
# likelier the deeper you are. With both kinds switched on the random numbers are drawn in the Luau version's order.
func _roll_board() -> void:
	board = []
	for i in ICONS:
		board.append({"kind": "fruit", "mult": 1})
	# The cells, in a random order; items take them from the end, and at least two stay plain.
	var free: Array[int] = [0, 1, 2, 3, 4, 5]
	for i in range(ICONS - 1, 0, -1):
		var j := int(floorf(_next_random() * (i + 1)))
		var swap := free[i]
		free[i] = free[j]
		free[j] = swap
	var place := func(kind: String, mult: int) -> void:
		if free.size() > 2:
			board[free.pop_back()] = {"kind": kind, "mult": mult}
	if mults and _next_random() < mult_chance_at(tier) + mult_chance:
		place.call("mult", roll_fruit_mult(_next_random(), luck))
	if specials and tier >= SPECIALS_FROM:
		var depth := clampf(float(tier - SPECIALS_FROM) / float(REF_TIERS - SPECIALS_FROM), 0.0, 1.0)
		if _next_random() < 0.3 + 0.4 * depth:
			place.call("bomb", 1)
		if _next_random() < 0.45 + 0.3 * depth:
			place.call("strong", 1)
			if _next_random() < 0.3 * depth:
				place.call("strong", 1)
		if _next_random() < 0.25:
			place.call("ice", 1)
		if _next_random() < 0.2 + 0.25 * depth:
			place.call("reverse", 1)
	need = 0
	for cell: Dictionary in board:
		if cell.kind != "bomb":
			need += 1


func _clear_machine() -> void:
	for i in ICONS:
		lit[i] = false
		hits[i] = 0
	lit_count = 0
	fruit_mult = 1
	mistakes = 0
	pot = 0
	_roll_board()


## The streak multiplier the next clear pays at.
func mult() -> float:
	return minf(1.0 + streak * streak_step, max_mult)


# How far the cursor has gone round the ring by time t (signed, not wrapped).
func _travelled(t: float) -> float:
	var dt := maxf(0.0, t - t0)
	return phase0 + dir * (base * dt + boost * fade * (1.0 - exp(-dt / fade)))


## Where the cursor is on the ring at time t (0 up to 6, wrapping).
func phase_at(t: float) -> float:
	return fposmod(_travelled(t), float(ICONS))


## The burst (or ice chill, negative) left at time t.
func boost_at(t: float) -> float:
	return boost * exp(-maxf(0.0, t - t0) / fade)


## Items per second at time t (0 before the cursor starts).
func speed_at(t: float) -> float:
	if t < t0:
		return 0.0
	return base + boost_at(t)


## The ring position (0-5) the cursor is on at time t.
func index_at(t: float) -> int:
	return int(floorf(phase_at(t))) % ICONS


# Start the cursor again from where it is now, with a new burst (or chill).
func _rebase(t: float, new_boost: float, new_fade: float) -> void:
	phase0 = phase_at(t)
	t0 = t
	boost = new_boost
	fade = new_fade


func _finish(result: Result) -> void:
	over = true
	pot = 0 # an unfinished machine's pot is lost
	result.over = true


## A press at time t. null when it doesn't count: the run is over, the cursor isn't moving yet, or it isn't later
## than the last press.
func press(t: float) -> Result:
	if over or t < t0 or t <= last_press:
		return null
	last_press = t
	presses += 1
	var index := index_at(t)
	var cell: Dictionary = board[index]
	var result := Result.new()
	result.index = index
	result.cell = cell.kind
	result.fruit_mult = fruit_mult
	result.tier = tier
	result.lives = lives
	result.streak = streak

	if cell.kind == "bomb":
		result.kind = "bomb"
		_rebase(t, 0.0, BOOST_FADE)
		_finish(result)
	elif lit[index]:
		result.kind = "mistake"
		mistakes += 1
		lives -= 1
		var lost := mini(pot, MISTAKE_POINTS)
		pot -= lost
		result.points = -lost
		streak = 0
		_rebase(t, 0.0, BOOST_FADE) # the burst is lost
		if lives <= 0:
			_finish(result)
	elif cell.kind == "strong" and hits[index] == 0:
		# The first hit on a strong cell cracks its cage: a correct press (it bursts), but the fruit isn't lit yet.
		result.kind = "crack"
		hits[index] = 1
		_rebase(t, minf(boost_at(t) + boost_step, BOOST_MAX), BOOST_FADE)
	else:
		lit[index] = true
		hits[index] += 1
		lit_count += 1
		result.points = lit_count
		pot += lit_count
		if cell.kind == "mult":
			fruit_mult *= int(cell.mult)
		if cell.kind == "ice":
			_rebase(t, -ICE_SLOW * base, ICE_FADE)
		else:
			_rebase(t, minf(boost_at(t) + boost_step, BOOST_MAX), BOOST_FADE)
		if cell.kind == "reverse":
			dir = -dir
		if lit_count >= need:
			var perfect := mistakes == 0
			result.cleared = true
			result.perfect = perfect
			result.paid_mult = mult()
			result.fruit_mult = fruit_mult
			result.paid = (pot + (PERFECT_BONUS if perfect else 0)) * result.paid_mult * fruit_mult
			if perfect:
				lives = mini(lives + 1, max_lives)
			streak = streak + 1 if perfect else 0
			if max_tier > 0 and tier >= max_tier:
				_finish(result)
				result.perfect_run = true
			else:
				tier += 1
				result.tier_up = true
				_clear_machine()
				phase0 = phase_at(t)
				t0 = t + MACHINE_PAUSE
				base = start_speed(tier)
				boost = 0.0
				fade = BOOST_FADE
				dir = 1

	result.pot = pot
	result.mult = mult()
	if not result.cleared:
		result.fruit_mult = fruit_mult
	result.tier = tier
	result.lives = lives
	result.streak = streak
	return result


## May the cursor be pressed on this cell right now without losing? (Unlit, not a bomb; a cracked strong cell counts.)
func is_target(index: int) -> bool:
	return not lit[index] and board[index].kind != "bomb"


## The next time from t on when the cursor is in the middle of a cell it is safe to press (NAN if there is none).
## The simulated players in the tests aim for it.
func next_target(t: float) -> float:
	if over:
		return NAN
	var from := maxf(t, t0)
	var phase := _travelled(from)
	var slowest := maxf(base + minf(boost_at(from), 0.0), 0.05)
	for k in range(0, ICONS + 1):
		# The middles of the cells ahead of the cursor, nearest first, in whichever way it is going.
		var centre: float = (floorf(phase) + k + 0.5) if dir > 0 else (ceilf(phase) - k - 0.5)
		var ahead := (centre - phase) * dir
		if ahead >= 0.0 and is_target(posmod(int(floorf(centre)), ICONS)):
			# The cursor never goes slower than `slowest` from here, so it gets there by `late` at the latest.
			var early := from
			var late := from + ahead / slowest
			for _i in 50:
				var mid := (early + late) / 2.0
				if (_travelled(mid) - phase) * dir < ahead:
					early = mid
				else:
					late = mid
			return (early + late) / 2.0
	return NAN
