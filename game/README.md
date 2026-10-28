# Echoes of a Sunken World

A silhouette sword duel built with Godot 4.7. Two robed fighters, two stages: the Hollow Gate (a ribbed cavern with a portal) and the Dune Monolith (a desert under a giant screen).

## Play

Run `build/windows/EchoesOfASunkenWorld.exe`. It's a single file with nothing to install.

| Action | Player 1 | Player 2 | Gamepad |
| --- | --- | --- | --- |
| Move | A / D | ← / → | left stick, d-pad |
| Guard high / low | hold W / S | hold ↑ / ↓ | stick up / down |
| Light cut | J or F | numpad 1 | X / □ |
| Heavy cut (hold to charge) | K or G | numpad 2 | Y / △ |
| Guard, tap to parry | L or H | numpad 3 | RB / R1 |
| Thrust | I or T | numpad 5 | B / ○ |
| Kick (breaks a guard) | U or R | numpad 4 | LB / L1 |
| Dash | Space | numpad 0 | A / ✕ |
| Pause | Esc | | Start |

How the fight works:

- **Guard lines.** Your guard blocks only the height you hold. Read where the opponent's blade is raised and match it.
- **Parry.** Raise your guard in the last moment before impact to deflect. The attacker is thrown open. Mashing the guard does not parry.
- **Posture.** Blocking costs posture (the bar above a fighter's head). When it fills, the guard breaks and hits land 50% harder.
- **Stamina.** Attacks and dashes cost stamina. When exhausted you move, swing and recover slower.
- **Wounds.** Hits are detected on the actual blade. Head cuts deal the most damage and arm cuts the least, and a cut leg makes you limp.
- **Feints and charges.** Press guard during a heavy's wind-up to feint it. Hold heavy to charge it.

## Edit

Open this `game/` folder in the [Godot 4.7 editor](https://godotengine.org/download) and press F5.

| File | What it controls |
| --- | --- |
| `scripts/rig.gd` | Skeleton, IK, foot planting, cloth (robe, hood, sash, sleeves), ragdoll |
| `scripts/fighter.gd` | States, move timings (`MOVES`) and every key pose (`GUARD`, `BLOCK`, `ATTACKS`, ...) |
| `scripts/combat.gd` | Blade hit detection, parry, block, posture, clashes |
| `scripts/ai.gd` | Opponent behaviour |
| `scripts/stage_hollow.gd`, `scripts/stage_dune.gd` | Stage art, light position, shadow settings |
| `shaders/` | Cavern walls, light shafts, soft shadows, final colour grade |
| `scripts/sfx.gd` | All sounds, synthesized at startup |

To make the game snappier or slower, edit `MOVES` in `fighter.gd`. Its values are in frames at 60 fps.

## Rebuild the .exe

In the editor: **Project → Export → Windows Desktop → Export Project**. From a terminal:

```
godot --headless --path game --export-release "Windows Desktop" ../build/windows/EchoesOfASunkenWorld.exe
```

## Test mode

This runs an AI-vs-AI duel and saves screenshots:

```
godot --path game -- --autotest --stage=0 --frames=1200 --every=120 --shots=/some/folder
```

Add `--headless` and drop `--shots` to get only the combat event counts, which is quick.

The font is Cormorant Garamond under the SIL Open Font License (`fonts/OFL.txt`).
