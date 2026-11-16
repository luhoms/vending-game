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
| Zen | plain | 1 (LIVES button: 3) | 7.4 on every machine, and no speed burst on hits |

Every mode is endless. Each machine cleared without a mistake raises the STREAK (x2, x3, ...), which multiplies what
the next machine pays. The stats window keeps totals for each mode: best score, furthest machine, best streak, and how
many streaks of each size there have been.

## Running it

Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET), open this folder as a project and
press Play. On a desktop, click, or press Space, Enter or E.

To put it on a phone, add an Android or iOS export preset in the editor (Project > Export). Portrait orientation is
already set in the project settings.

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
- `scripts/cabinet.gd`, `fruit.gd`, `parts.gd`: the 3D machine and fruit, built in code
- `scripts/effects.gd`, `sfx.gd`, `hud.gd`: particles and camera, sound, the flat UI
- `scripts/fx_config.gd`: one table of look-and-feel numbers
- `scripts/save_data.gd`: what is kept between sessions
- `tools/make_sounds.py`: makes the sound effects in `assets/sfx`

## Sounds

The sounds in `assets/sfx` are synthesised by `tools/make_sounds.py` as stand-ins: the Roblox version's sounds are
Roblox Creator Store assets and can't be shipped outside Roblox. Replace any file with a recording of the same name.
