# Vending Game (working title)

A standalone mobile port (Godot 4.7, GDScript) of the vending machine floor from the Roblox game Plinko Simulator
(repo `luhoms/plinko-simulator`, `src/shared/Vend.luau` and `src/client/VendGame.luau`). The user found that floor fun
enough to be its own game. Goal for now: **get the gameplay down, feeling as good as the Roblox version.** Coins,
skins and other meta-progression may come later; none of it is built.

## Workflow
- Everything is code: the cabinet, fruit, textures, HUD and effects are built in scripts, and `scenes/main.tscn` is
  one node. Edit scripts, not scenes.
- Godot is not on a fresh machine. Linux build:
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
- After adding or renaming a script with a `class_name`, run `godot --headless --import` before the tests.
- Tests: `godot --headless -s tests/vend_checks.gd` (rules and modes, 91 checks, plus simulated-player figures) and
  `godot --headless -s tests/input_checks.gd -- --nosave --seed=5` (touch/click/key input and instant restarts on the
  real scene, 19 checks). Both exit non-zero on a failure or if a script error stopped checks from running.
- Seeing it: `xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 --audio-driver Dummy -- --nosave
  --bot=0.01 --seed=3 --shot=/path/out.png --at=2.6`. The `--` arguments are testing aids in `scripts/game.gd`
  (`--mode`, `--lives`, `--seed`, `--tier`, `--bot`, `--shot`/`--at`, `--runfor`, `--stats`, `--nosave`).
  `tools/fruit_sheet.gd` draws every fruit side by side.
- Sounds: edit `tools/make_sounds.py`, run it, re-import.

## Conventions
- GDScript with static types; tabs.
- Rules stay pure in `scripts/vend.gd` (no nodes, no clock, no global random state) and keep matching
  `Vend.luau`: change a rule there only on purpose, and say so. Mode differences go in `scripts/modes.gd` as
  parameters. Look-and-feel numbers go in `scripts/fx_config.gd`.
- Ring positions are 0-5 here (1-6 in the Luau).
- No casino wording (the Roblox project's rule): no "jackpot", "slots", "bet".
- **Original art only.** The look is inspired by early-2000s console minigames (the user's reference was a
  vending-machine minigame from a Pac-Man party game); use no copyrighted assets, characters, names or logos.

## Design rules
- **The cursor is a pure function of time** (`Vend.index_at(t)`): it only changes on a press. A press is judged at the
  moment the input event is handled (`game.gd` `_input`), minus `Fx.PRESS_OFFSET` (0: a knob for phone lag). The cursor
  is DRAWN `Fx.DRAW_AHEAD_FRAMES` (1) screen frames ahead, because a frame drawn now is seen about a frame later; 0
  draws it as the Roblox version does. The user found the first build "clunkier" than Roblox; this, the load-time
  warm-up and instant restarts were the answer. Not yet confirmed by the user.
- **Always running, never waiting**: no start button; a cleared machine rolls into the next with no pause; when a run
  ends the next is live in the same instant (`params.start_delay = 0`), its cursor carrying on from where it was. Only
  the first run after launch waits `Vend.START_DELAY`. The user asked for this ("immediately startable after a loss").
  A lost run flashes the edges red and slides the run-over strip up; nothing goes dark.
- **Modes** (`Modes.params`): traditional (plain fruit, 1 life or 3), party (all items, 3 lives: the Roblox lives
  mode), zen (traditional's first machine for ever: 7.4 items/sec with the normal burst on hits, never faster; 1 life
  or 3). All endless. Machines 1-8 of traditional and party use the Roblox speeds; past 8, +0.3 every 2 machines to a
  cap of 10.
- **Changes from the Roblox rules, all on purpose**: runs don't end at machine 8 (it gets an "ALL 8 CLEARED!"
  callout instead); the streak MULT has no cap (the Roblox cap of x8 could not be reached inside its 8 machines
  without an upgrade); item chances stop rising at machine 8; multiplier fruit count as items, so traditional and zen
  have none (the Roblox no-lives mode had them); no start or restart delay after the first run; no upgrades, luck,
  Auto Vend or coins.
- **Score**: a machine pays (pot + 15 if flawless) x streak x multiplier fruit, times `Modes.machine_value`: 10 on
  machine 1, x1.55 per machine up to machine 8, then +25% of machine 8's value per machine.
- **Streak trackers**: the badge shows the run's streak MULT; `SaveData` counts every streak that ends by the size it
  reached, per variant (a mode plus its lives setting). The user asked for totals for now, not a log of each streak.
- **Touch input**: a finger arrives as a touch event and as an emulated mouse click. The machine counts touches and
  real mouse clicks only (`device != DEVICE_ID_EMULATION`), so one touch is one press and a second finger still
  counts while the first is down. HUD buttons use the emulated click; `Hud.blocks_tap` keeps their touches off the
  machine.
- **The cabinet** (`scripts/cabinet.gd`, textures in `scripts/pixel_tex.gd`): retro, hard-pixel, early-2000s. Black
  body; a pale marquee with a red rim showing SCORE and BEST (the user asked for the score there instead of the
  machine's name and number, which no longer show anywhere); a white-framed window of six tiles, dark until a fruit is
  lit and then glowing in that fruit's colour; side art, edges and lamps in the machine's colour (the only sign of
  which machine you are on); a scan-line screen (POT, MULT, SPEED/BURST), heart lamps, the button, a keypad, a hatch.
  It keeps the Roblox cabinet's size and cell positions. One texel is about 0.21 studs.
- **Fruit** (`scripts/fruit.gd`, `scripts/shapes.gd`): smooth meshes made in code, one node each (lathed apple, pear,
  strawberry; tube bananas and stems). The user asked for better models than the Roblox stacked balls.
- **HUD** (`scripts/hud.gd`, `scripts/pixel_ui.gd`): pixel style, Pixelify Sans (OFL, `assets/fonts`). One row: mode,
  lives as hearts (the button toggles 1/3; hearts empty as lives go), STREAK, stats, sound. Callouts show in the gap
  between that row and the cabinet. **Nothing is drawn over the fruit**; the run-over strip sits on the base.
- **Sounds** (`tools/make_sounds.py`): soft mallet tones, slow attacks, everything low-passed at 4.2 kHz. The user
  found the first set (hard attacks, bright partials) "too sharp". Same roles and pitches as the Roblox sounds: a note
  one pentatonic step up per hit, an arpeggio and chime on a clear, a low bonk on a mistake.
- **Load**: one of every item and effect is drawn behind a cover for three frames (`game._boot`) so the first hit
  doesn't stutter. The save file is written a second after a run ends, not during the press.

## Not checked yet
- On a real phone: touch latency against the timing windows, audio latency, haptics, safe-area insets, frame rate.
- Nobody has listened to the sounds; "softer" is measured (centre frequency, energy above 2.5 kHz), not heard.
- Whether draw-ahead and the warm-up actually cure the "clunky" feel on the user's PC: the cause was not measured
  there. Script time per press is under 1 ms on the build machine.
- The port was not compared against the Luau by running both on the same press times (no Luau runtime was set up);
  the ported checks pass and the board generator's arithmetic is the same.
- No export presets yet (Android/iOS/web), no app icon beyond a placeholder, no pause when the app goes to the
  background. At the 540 x 960 desktop window small pixel text is hard to read (a phone has twice the pixels).

## Open questions for the user
- Whether the speed cap of 10 past machine 8 is right: the simulated players in `vend_checks` say a +-0.03s player
  never fails at it, a +-0.05s player rarely gets there.
- Pop text from the top row of fruit rises over the marquee's score for a moment.
