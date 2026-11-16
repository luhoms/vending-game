# Vending Game (working title)

A standalone mobile port (Godot 4.7, GDScript) of the vending machine floor from the Roblox game Plinko Simulator
(repo `luhoms/plinko-simulator`, `src/shared/Vend.luau` and `src/client/VendGame.luau`). The user found that floor fun
enough to be its own game. Goal for now: **get the gameplay down, feeling the same as the Roblox version.** Coins,
skins and other meta-progression may come later; none of it is built.

## Workflow
- Everything is code: the cabinet, fruit, HUD and effects are built in scripts, and `scenes/main.tscn` is one node.
  Edit scripts, not scenes.
- Godot is not on a fresh machine. Linux build:
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
- After adding or renaming a script with a `class_name`, run `godot --headless --import` before the tests.
- Tests: `godot --headless -s tests/vend_checks.gd` (rules and modes, 89 checks, plus simulated-player figures) and
  `godot --headless -s tests/input_checks.gd -- --nosave --seed=5` (touch/click/key input on the real scene, 15 checks).
  Both exit non-zero on a failure or if a script error stopped checks from running.
- Seeing it: `xvfb-run -a godot --rendering-driver opengl3 --resolution 540x960 --audio-driver Dummy -- --nosave
  --bot=0.01 --seed=3 --shot=/path/out.png --at=2.6`. The `--` arguments are testing aids in `scripts/game.gd`
  (`--mode`, `--lives`, `--seed`, `--tier`, `--bot`, `--shot`/`--at`, `--runfor`, `--stats`, `--nosave`).
- Sounds: edit `tools/make_sounds.py`, run it, re-import.

## Conventions
- GDScript with static types; tabs.
- Rules stay pure in `scripts/vend.gd` (no nodes, no clock, no global random state) and keep matching
  `Vend.luau`: change a rule there only on purpose, and say so. Mode differences go in `scripts/modes.gd` as
  parameters. Look-and-feel numbers go in `scripts/fx_config.gd`.
- Ring positions are 0-5 here (1-6 in the Luau).
- No casino wording (the Roblox project's rule): no "jackpot", "slots", "bet".

## Design rules
- **The cursor is a pure function of time** (`Vend.index_at(t)`): it only changes on a press. A press is judged at the
  moment the input event is handled (`game.gd` `_input`), minus `Fx.PRESS_OFFSET` (0 for now: a knob for phone lag).
- **Always running**: no start button; a cleared machine rolls into the next with no pause; a run that ends is
  followed by a new one `Fx.RESTART_DELAY` (0.35s) later, with the run-over strip showing meanwhile.
- **Modes** (`Modes.params`): traditional (plain fruit, 1 life or 3), party (all items, 3 lives: the Roblox lives
  mode), zen (plain fruit, 7.4 items/sec on every machine, no burst, 1 life or 3). All endless. Machines 1-8 of
  traditional and party use the Roblox speeds; past 8, +0.3 every 2 machines to a cap of 10.
- **Changes from the Roblox rules, all on purpose**: runs don't end at machine 8 (it gets an "ALL 8 CLEARED!"
  callout instead); the streak MULT has no cap (the Roblox cap of x8 could not be reached inside its 8 machines
  without an upgrade); item chances stop rising at machine 8; multiplier fruit count as items, so traditional and zen
  have none (the Roblox no-lives mode had them); no upgrades, luck, Auto Vend or coins.
- **Score**: a machine pays (pot + 15 if flawless) x streak x multiplier fruit, times `Modes.machine_value`: 10 on
  machine 1, x1.55 per machine up to machine 8, then +25% of machine 8's value per machine.
- **Streak trackers**: the badge shows the run's streak MULT; `SaveData` counts every streak that ends by the size it
  reached, per variant (a mode plus its lives setting). The user asked for totals for now, not a log of each streak.
- **Touch input**: a finger arrives as a touch event and as an emulated mouse click. The machine counts touches and
  real mouse clicks only (`device != DEVICE_ID_EMULATION`), so one touch is one press and a second finger still
  counts while the first is down. HUD buttons use the emulated click; `Hud.blocks_tap` keeps their touches off the
  machine.
- **Nothing is drawn over the fruit**: callouts take over the header sign (the machine's name hides while they show);
  the run-over strip sits on the cabinet's base.

## Not checked yet
- On a real phone: touch latency against the timing windows, audio latency, haptics, safe-area insets, frame rate.
- The sounds have not been listened to by anyone; they are synthesised stand-ins.
- The port was not compared against the Luau by running both on the same press times (no Luau runtime was set up);
  the ported checks pass and the board generator's arithmetic is the same.
- No export presets yet (Android/iOS), no app icon beyond a placeholder, no pause when the app goes to the background.

## Open questions for the user
- Zen has no speed burst (their words: "the speed doesn't change"). The burst is one number to switch back on
  (`boost_step` in `Modes.params`).
- Whether the speed cap of 10 past machine 8 is right: the simulated players in `vend_checks` say a +-0.03s player
  never fails at it, a +-0.05s player rarely gets there.
