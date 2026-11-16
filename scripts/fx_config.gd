class_name Fx
extends RefCounted
## ONE tuning table for how the game looks, sounds and feels. The rules' numbers are in vend.gd and modes.gd.
## Values marked (Roblox) are the Roblox version's FxConfig.Vend numbers, kept so it feels the same.

# The cabinet
const SKIN := Color(0.110, 0.251, 0.275) ## the cabinet's front panels (Roblox)
const CURSOR_WIDTH := 0.32 ## the cursor's white frame, studs (Roblox)
const CURSOR_GLOW := 0.8 ## the glow plate's transparency (Roblox)
const LIT_DARKEN := 0.6 ## how far a lit cell's gold glow is darkened, so the cursor stays the brightest thing (Roblox)
const CHASE_TAIL := 9.0 ## bulbs lit behind the chase's head (Roblox)
const TICK_BELOW_SPEED := 9.0 ## above this speed (items/sec) the cursor stops ticking: it would just buzz (Roblox)
const FX_SCALE := 0.55 ## size of particles and pop text next to the Roblox defaults (Roblox)

# Vending a full machine (Roblox)
const SHOOT_STEP := 0.06 ## seconds between one fruit shooting out of the tray and the next
const SHOOT_OUT := 5.5 ## studs/sec out of the flap...
const SHOOT_UP := 12.0 ## ...upward...
const SHOOT_SPREAD := 4.0 ## ...and sideways (random, either way)
const GRAVITY := 55.0 ## studs/s^2 while a fruit flies
const BOUNCE := 0.42 ## share of its speed a fruit keeps when it bounces on the floor
const FRUIT_REST := 0.75 ## a resting fruit's centre above the floor
const FRUIT_STAY := 3.0 ## seconds the fruit lies on the floor

# Runs
const RESTART_DELAY := 0.35 ## seconds between a run ending and the next one starting (Roblox)
const MISTAKE_SHAKE := 0.6 ## camera shake on a mistake, degrees (Roblox)
const RUN_OVER_SHAKE := 0.6

# Camera (Roblox's CameraFX)
const SHAKE_DECAY := 2.2 ## degrees of shake lost per second
const FOV_RETURN := 5.0 ## how fast punches return to normal (per second, exponential)
const SWAY_DEGREES := 0.12 ## slow idle drift so the view is never perfectly still
const SWAY_SPEED := 0.35
const CAMERA_FOV := 40.0 ## vertical field of view, degrees
const VIEW_WIDTH := 12.4 ## studs of world shown across the screen at the cabinet's front, at least
const TOP_BAND := 0.13 ## share of the screen's height kept clear above the cabinet for the score
const BOTTOM_BAND := 0.04 ## ...and below it for the floor
const SPARE_TOP := 0.6 ## on tall screens, this share of the spare height goes above the cabinet

# Input
const PRESS_OFFSET := 0.0 ## seconds taken off every press time, to make up for a phone's touch and display lag

# Sound (Roblox's SoundManager / FxConfig.Sound.vend)
const HIT_SCALE: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16] ## semitones above the ding for the 1st, 2nd... hit on a machine
const CLEAR_ARPEGGIO: Array[int] = [12, 16, 19, 24] ## the all-lit arpeggio
const ARPEGGIO_STEP := 0.045 ## seconds between its notes
const DING_VOLUME := 0.6
const SPARKLE_VOLUME := 0.28
const SPARKLE_PITCH := 1.15
const COMPLETE_VOLUME := 0.75
const ERROR_VOLUME := 0.9
const TICK_VOLUME := 0.07

# Haptics (milliseconds)
const BUZZ_HIT := 12
const BUZZ_CLEAR := 30
const BUZZ_MISTAKE := 45
const BUZZ_BOMB := 90

# Colours
const CHARCOAL := Color8(24, 25, 32)
const GOLD := Color8(255, 205, 60)
const RED := Color8(255, 70, 80)
const WHITE := Color(1, 1, 1)
const DIM := Color8(28, 28, 36)
const PINK := Color8(255, 95, 200)
const CYAN := Color8(120, 255, 240)
const SOFT := Color8(150, 160, 195)
const BOOM := Color8(255, 120, 40)
const STEEL := Color8(200, 210, 225)

## What marks an item cell: its tag and colour.
const KIND_TAG := {
	"strong": {"text": "2 HITS", "color": Color8(200, 210, 225)},
	"bomb": {"text": "BOMB!", "color": Color8(255, 70, 80)},
	"ice": {"text": "ICE", "color": Color8(140, 220, 255)},
	"reverse": {"text": "REVERSE", "color": Color8(255, 90, 230)},
}


## The colour of a multiplier fruit's glow, by how big it is (x100 is a rainbow, drawn frame by frame).
static func mult_color(mult: int) -> Color:
	if mult >= 50:
		return Color8(190, 90, 255)
	elif mult >= 10:
		return Color8(255, 80, 190)
	elif mult >= 5:
		return Color8(255, 140, 40)
	return GOLD


static func semitones(n: float) -> float:
	return pow(2.0, n / 12.0)


## 12345678 -> "12,345,678"
static func number(value: float) -> String:
	var digits := str(int(roundf(absf(value))))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## 3 -> "x3", 2.5 -> "x2.5"
static func times(value: float) -> String:
	return "x%d" % int(value) if is_equal_approx(value, roundf(value)) else "x%.1f" % value
