# Lighter Hair

- **Version:** 1.0.0
- **Author:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev
- **Works on:** desktop and VR

Every pony's mane and tail with far fewer triangles, for better framerates (made with the Quest 3 in mind). Same look, rig, colours and tail physics.

| | Before | After (full detail) |
|---|---|---|
| Pinkie Pie | 106,464 | 21,248 |
| Applejack | 78,208 | 24,704 |
| Rainbow Dash | 72,240 | 17,224 |
| Fluttershy | 69,600 | 14,656 |
| Twilight Sparkle | 62,736 | 13,016 |
| Rarity | 43,536 | 9,904 |
| Anon (pony, mare/filly) | 25,760 | 8,576 |
| Anon (pony, stallion) | 14,737 | 4,711 |
| Background ponies | any mane or tail over 6,000 halved (58 of 129) | |

The Mane 6's far-away hair (past 12 m) is halved too.

## Install

Put `hair-lite-v1.0.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**, then restart the game.

## Things to know

- It replaces the game's own hair files, so after a game update the game switches it off until a version for the new game is out.
- Anonfilly (NPC) has her own copy of the hair: use the Anonfilly lighter hair patch for her.

## Building

1. From the project root: `godot --headless --xr-mode off --path . --script res://mods/hair_lite/tools/reduce_hair.gd -- <absolute path to mods/hair_lite/tools/hair_list.txt>` (writes `build/hair_lite/stage/`).
2. `mods/build_packs.sh hair_lite` (packs with `tools/pack.gd`).
