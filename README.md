# Vending Game (working title)

A one-button timing game for phones, built in Godot 4. Six fruit sit behind the glass of a vending machine and a
cursor runs round them. Tap to light the fruit under the cursor; light all six without tapping one twice and the
machine vends and the next one starts at once.

It is a standalone port of the vending machine floor from the Roblox game *Plinko Simulator*. The rules are a
line-for-line port of that game's `shared/Vend.luau`, so the cursor speeds, the speed burst on every hit, the points
and the items behave the same.

## Modes

| Mode | Fruit | Lives | Speed |
| --- | --- | --- | --- |
| Traditional | plain | 1 (LIVES button: 3) | 7.4 items/sec on machines 1-4, 8.2 on 5-8, then +0.3 every two machines up to 10 |
| Party | items: multiplier fruit, caged fruit (two hits), bombs, ice, reverse | 3 | same as Traditional |
| Zen | plain | 1 (LIVES button: 3) | Traditional's first machine for ever: 7.4 on every machine, it never gets faster |

Every mode is endless, and losing never stops you: the next run is live the instant one ends. Each machine cleared
without a mistake raises the STREAK (x2, x3, ...), which multiplies what the next machine pays. The stats window keeps totals for each mode: best score, furthest machine, best streak, and how
many streaks of each size there have been.

## Running it

Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET), open this folder as a project and
press Play. On a desktop, click, or press Space, Enter or E.

## Trying it on an iPhone (no Mac needed)

The repository builds an unsigned iPhone app on GitHub; a sideloading tool on your own computer then signs it with
your Apple ID and installs it. With a free Apple ID the app runs for 7 days and then needs installing again the same
way.

1. On GitHub, open the repository's **Actions** tab, choose **iOS build (unsigned)** and press **Run workflow**.
2. When the run finishes, open it and download **vending-game-unsigned-ipa** from its Artifacts. Unzip it to get
   `vending-game-unsigned.ipa`.
3. Install a sideloading tool on your computer (Sideloadly and AltStore both run on Windows and macOS; on Windows they
   need Apple's iTunes and iCloud installed), plug the phone in, and give the tool the `.ipa` and your Apple ID.
4. On the phone: Settings > General > VPN & Device Management, trust your Apple ID; and on iOS 16 or later,
   Settings > Privacy & Security > Developer Mode, on.

The build is checked up to the `.ipa`; installing it has not been tried by the project yet.

For Android, add an Android export preset in the editor (Project > Export). Portrait orientation is already set in
the project settings.

## Tests

```bash
godot --headless --import
```

```bash
godot --headless -s tests/vend_checks.gd
```

```bash
godot --headless -s tests/input_checks.gd -- --nosave --seed=5
```

`vend_checks` covers the rules and the three modes and prints how simulated players of different skill do in each
mode. `input_checks` drives the real scene with touches, clicks and keys.

## Layout

- `scripts/vend.gd`: the rules, pure (no nodes, no clock)
- `scripts/modes.gd`: the three modes, what a machine is worth, machine names and colours
- `scripts/game.gd`: the clock, the run, input, and how everything reacts to a press
- `scripts/cabinet.gd`, `pixel_tex.gd`, `parts.gd`: the retro 3D machine and its pixel textures, built in code
- `scripts/fruit.gd`, `shapes.gd`: the fruit, as meshes made in code
- `scripts/effects.gd`, `sfx.gd`: particles and camera, sound
- `scripts/hud.gd`, `pixel_ui.gd`: the pixel-style buttons, callouts and stats window
- `scripts/fx_config.gd`: one table of look-and-feel numbers
- `scripts/save_data.gd`: what is kept between sessions
- `tools/make_sounds.py`: makes the sound effects in `assets/sfx`

## Sounds

The sounds in `assets/sfx` are synthesised by `tools/make_sounds.py` (soft mallet tones): the Roblox version's sounds
are Roblox Creator Store assets and can't be shipped outside Roblox. Replace any file with a recording of the same
name.

## Credits

The font is Pixelify Sans by The Pixelify Sans Project Authors, under the SIL Open Font License (`assets/fonts/OFL.txt`). All other
art and sound is made by the code in this repository.
