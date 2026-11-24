# Optimare

- **Version:** 1.0.0
- **By:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev
- **Works on:** desktop and VR

General performance tweaks for the game's own models, made with the Quest 3 in mind. Each version takes on a little more; the look stays the same.

## 1.0.0: Celestia and Luna

| Triangles | Celestia | Luna |
|---|---|---|
| Shoes | 14,336 → 3,840 | unchanged (2,304) |
| Folded wings (both) | 13,888 → 8,448 | 10,944 → 4,736 |
| Open wings (both) | 13,568 → 8,192 | 10,624 → 5,120 |
| Crown | 3,440 → 1,792 | 3,392 → 1,536 |
| Collar | 3,120 → 1,664 | 3,072 → 1,536 |
| **Total** | 48,352 → 23,936 | 28,032 → 12,928 |

Bodies, manes, tails and horns are untouched. Every vertex is kept, so mods that work from the meshes (Idle Life's shoe check, Princess Wings, Grooming) still line up.

## Install

Put `optimare-v1.0.0.pck` in the game's `mods` folder, switch it on in **Settings → Mods** and restart the game.

## Things to know

- It replaces the game's own model files, so after a game update the game switches it off until a version for the new game is out.

## Building

1. From the project root: `godot --headless --xr-mode off --path . --script res://mods/optimare/tools/reduce.gd` (writes `build/optimare/stage/`; the targets are in `TARGETS` at the top of the script).
2. `mods/build_packs.sh optimare` (packs with `tools/pack.gd`).
