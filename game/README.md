# Echoes of a Sunken World

A silhouette sword duel built with Godot 4.7. Maren, a swordswoman who fights with her legs as much as her blade, against five men with different bodies, swords and styles. Life-size human shadows on two stages: the Hollow Gate (a ribbed cavern with a portal) and the Dune Monolith (a desert under a giant screen).

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

## Modes

- **Story.** Five chapters, one man each. Your progress is saved.
- **Casual Duel.** Pick any of the men, the stage and the difficulty on the title screen.
- **Duel a Friend.** Player two plays the chosen man. Trained ranks don't count here.
- **Train.** Drills against a sparring partner raise Blade, Kick, Footwork, Guard and Vigor up to rank V, for good.

## Kicks

Kicks are Maren's main weapon. They follow the guard line you hold, and each press takes the next karate technique on that line. Every technique runs load, chamber, snap, re-chamber, set down, with her standing foot pivoting and her free hand pulling back to the ribs.

- **Leg kick (hold down): gedan mawashi-geri, kansetsu-geri, ashi-barai.** Slows him, and a second within about four seconds sweeps him down for a long opening. A mark over his head shows the leg is wounded. Only a low guard stops it.
- **Head kick (hold up): jodan mawashi-geri, kakato-otoshi.** Big damage and stun if it reaches the head. Only a high guard stops it.
- **Push kick (no direction): mae-geri, yoko-geri kekomi.** Shoves through any guard and wrecks posture.
- **Flying side kick (hold forward): tobi yoko-geri.** She jumps across the gap, side-on with the lead leg straight out. Hits 50% harder and shoves through any guard, but it's slow and costs the most stamina.

A cut straight after any kick lands 30% harder. The men only have a weak push kick.

## Edit

Open this `game/` folder in the [Godot 4.7 editor](https://godotengine.org/download) and press F5.

| File | What it controls |
| --- | --- |
| `scripts/rig.gd` | Skeleton, IK, foot planting, cloth (hair, skirt, capes), ragdoll, Maren's silhouette clothes (`_outfit`), and the anatomical silhouette (`ANATOMY`, `HAIR_SLEEK`, ...; 1 unit = 1 cm) |
| `scripts/builds.gd` | Every fighter's body, sword, stats and AI; story text; training drills; saved progress |
| `scripts/fighter.gd` | States, move timings (`MOVES`) and every key pose (`GUARD`, `BLOCK`, `ATTACKS`, Maren's techniques in `KICK_ART`, ...) |
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

Add `--headless` and drop `--shots` to get only the combat event counts, which is quick. `--opp=0..4` picks the man, and `--game=story` or `--game=train` runs those modes (tests use a separate save file). `--dump=/some/file.json` writes every fighter's silhouette in several poses.

The font is Cormorant Garamond under the SIL Open Font License (`fonts/OFL.txt`).
