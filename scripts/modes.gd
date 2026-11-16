class_name Modes
extends RefCounted
## The three ways to play, as parameters for the rules in vend.gd, plus what a machine is worth and what it is called.
##
##   traditional  plain fruit, one life (or three with LIVES on), the machines get faster
##   party        items (multiplier, caged, bomb, ice, reverse) and three lives: the Roblox game's lives mode
##   zen          plain fruit, traditional's first machine for ever: the speed never goes up. One life (or three)
##
## Every mode is endless. Machines 1-8 of traditional and party run at the Roblox game's speeds.

const LIST: Array[String] = ["traditional", "party", "zen"]

const INFO := {
	"traditional": {"title": "TRADITIONAL", "blurb": "Plain fruit. It gets faster.", "lives_toggle": true},
	"party": {"title": "PARTY", "blurb": "Items and three lives.", "lives_toggle": false},
	"zen": {"title": "ZEN", "blurb": "It never gets faster.", "lives_toggle": true},
}

const LIVES := 3 ## lives with LIVES on (and always in party)

# Speed past machine 8 (traditional and party): +LATE_STEP items/sec every LATE_EVERY machines, up to SPEED_CAP.
const LATE_STEP := 0.3
const LATE_EVERY := 2
const SPEED_CAP := 10.0
const ZEN_SPEED: Array[float] = [7.4]

# What one point is worth on a machine: x VALUE_GROWTH per machine up to machine 8 (as in the Roblox game), then
# +LATE_VALUE of machine 8's value per machine, so an endless run's score stays a readable number.
const BASE_VALUE := 10.0
const VALUE_GROWTH := 1.55
const LATE_VALUE := 0.25

## The machines' names and colours (the Roblox floor's tiers). Past the eighth they come round again: "SNACK STOP II".
const TIERS := [
	{"name": "Snack Stop", "color": Color8(70, 225, 210)},
	{"name": "Soda Fountain", "color": Color8(255, 95, 170)},
	{"name": "Candy Counter", "color": Color8(255, 160, 60)},
	{"name": "Toy Corner", "color": Color8(160, 240, 80)},
	{"name": "Night Market", "color": Color8(170, 110, 255)},
	{"name": "Sky Bar", "color": Color8(80, 190, 255)},
	{"name": "Gold Reserve", "color": Color8(255, 205, 60)},
	{"name": "Grand Vend", "color": Color8(255, 245, 235)},
]


static func has_lives_toggle(mode: String) -> bool:
	return INFO[mode].lives_toggle


## Lives a run starts with.
static func lives_for(mode: String, lives_on: bool) -> int:
	return LIVES if mode == "party" or lives_on else 1


## The key a mode's records are saved under: three lives is a different game from one, so it keeps its own.
static func variant(mode: String, lives_on: bool) -> String:
	return mode + "_lives" if has_lives_toggle(mode) and lives_on else mode


static func params(mode: String, lives_on: bool, phase: float, seed: int) -> Vend.Params:
	var p := Vend.Params.new()
	p.tier = 1
	p.max_tier = 0
	p.phase = phase
	p.seed = seed
	p.lives = lives_for(mode, lives_on)
	p.max_mult = INF # the streak has no cap here (it never reached the Roblox game's x8 cap inside its 8 machines)
	p.mults = mode == "party"
	p.specials = mode == "party"
	if mode == "zen":
		p.speeds = ZEN_SPEED # machine 1's speed on every machine; hits still burst the cursor
	else:
		p.late_step = LATE_STEP
		p.late_every = LATE_EVERY
		p.speed_cap = SPEED_CAP
	return p


## Score for one point paid by machine `tier`.
static func machine_value(tier: int) -> float:
	var top := BASE_VALUE * pow(VALUE_GROWTH, mini(tier, Vend.REF_TIERS) - 1)
	if tier > Vend.REF_TIERS:
		top *= 1.0 + LATE_VALUE * (tier - Vend.REF_TIERS)
	return roundf(top)


static func tier_color(tier: int) -> Color:
	return TIERS[posmod(tier - 1, TIERS.size())].color


## "MACHINE 9  -  SNACK STOP II"
static func tier_title(tier: int) -> String:
	var def: Dictionary = TIERS[posmod(tier - 1, TIERS.size())]
	var lap := (tier - 1) / TIERS.size() + 1
	var text := "MACHINE %d  -  %s" % [tier, String(def.name).to_upper()]
	if lap > 1:
		text += " " + _roman(lap)
	return text


static func _roman(n: int) -> String:
	var out := ""
	var values := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var marks := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	for i in values.size():
		while n >= values[i]:
			out += marks[i]
			n -= values[i]
	return out
