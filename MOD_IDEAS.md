# Home: Equestria mod ideas

What's built, what's next, and ideas. Also see:
- **BUGS.md:** game bugs to report, and local changes to the game.
- **MODDING_NOTES.md:** how-tos and rules for every mod (hooks, packs, AI, Blender).
- **Per-mod dev notes** (build history, labs, what's unchecked) are in the claude.ai project under `mods/notes/<id>.md`.

Status key: **Done** · **Next** · **Backburner** · **Idea**

## Done

All made for game 0.3.0-maredev. Packs are in `release_packs/`.

| Mod | Version | What it does |
| --- | --- | --- |
| Grooming | 1.0.3 | Mane & tail brush, coat brush and wing preening; raises friendship and love. |
| Flowing Manes | 1.0.0 | Celestia's and Luna's manes and tails flow and react to their mood; settings page. |
| Balloon Boarding | 1.0.0 | Carried ponies stay aboard the balloon; followers who stop short are helped in. |
| Pegasus Ride | 2.2.1 | Someone else's mod, adapted: ride a winged friend, princesses included. |
| Teleport | 1.0.0 | `places` and `tp` debug commands. |
| Idle Life | 1.4.2 | Sixteen idles, plus princess scroll, quill, tea, shoe, sun and moon idles; remembered by onlookers. |
| Princess Teleport | 1.1.0 | Celestia, Luna and Twilight teleport you both to far places, when you ask (or in danger). |
| Princess Wings | 1.0.0 | Moves the princesses' open wings onto their shoulder blades (fix handed to the dev). |
| Kissing | 1.2.8 | Hold K to kiss; feelings build; rearing into your arms (Shift+K toggles); clipping guards. |
| Fishing | 0.4.1 | Readable pier fishing, five species plus rares and junk, live-well pail, Angler's Log, pony reactions. |
| Horn Glow | 1.1.0 | Horn magic glows around the horn itself, with a soft hum. |
| Item Spawn | 1.0.0 | `is list` / `is add` debug commands to put any item in the briefcase. |
| Fluttershy's Cottage | 1.2.0 | Replaces the cottage with Discopears' full room (CC BY-SA 4.0) and a new exterior; ponies route through it. |
| Briefcase Rescue | 1.0.0 | Repairs briefcases and saves refused because of items from a removed mod. |
| Russian Ponies | 1.0.0 | Ponies understand and always speak Russian (typed chat; voices and speech input unsupported). Untested with a real model. |
| Typing Lock | 1.0.0 | While a text box has focus, all game hotkeys are off and Anon stays put (no more WASD/Q standing you up mid-chat). |

Private/debug: **Idle Life Debug** (`idle_life_debug`, `idle` console command), never in release_packs or the download table.

## Next

### Cuddling
- **Code review (0.3.0):** suspected pony size and Anon height problems, from reading the code only and not yet confirmed in game:
  1. **Grass naps (all sizes):** the pony's spot beside or on Anon is a fixed offset tuned for Canon, and there's no fit check. At larger sizes she spawns overlapping him.
  2. **Bed "shoulder" and "snuggle" positions:** fixed offsets tuned for Canon. Her head lands in the wrong place at larger sizes (past his head, or into the headboard). The fit check only tests her body length.
  3. **Anon's height setting (new in 0.3.0):** the bed layout (head, hips, eye height, his half-width) assumes a 6 ft Anon. Shorter or taller Anons misalign, and "Same height as Anon" grows the mare without growing his half of the gap.
  4. **Cuddle posing at large sizes:** the limb floor check uses fixed ray lengths while the limb radius scales, so big ponies' hooves can sink into the mattress. Several distances also don't scale: drag speed, follow/break distances, the 1 m release, and the 2.5 / 2.8 m start and end range.
  5. **Stallions:** adult stallions (1.2×) are never eligible for the shared bed at any size setting.
  6. **Tall VR players:** the couch refuses a rest when the VR avatar scale is over 1.3.

### Improvements

#### Hooves don't bend when they should (Kissing, all hoof poses)
- The pastern/hoof bend (`pony_finger` −20° in the Blender rear, and the game's own curls) barely shows.
- To check: the hoof mesh's skin weights (`pony_finger` vs `pony_finger_*_end` vs `pony_hand`); the glTF bone axes on the hoof bones (their tails point sideways, so a bend "about X" may become a twist); whether the game's leg IK or terrain modifier overwrites the hoof angle afterwards.

## Backburner

### Mod reloader ("Restart and load")
- **The problem:** mods load at startup. Godot can't unmount a pack, and the game reads data merges, script extensions and replaced files once, so a true live refresh isn't reliable.
- **The idea:** a "Restart and load" button that saves your mod choices, relaunches the game, skips the title screen and opens the chosen save, so every mod loads cleanly in one click.
- **Live loading:** entry-script-only mods already switch on and off live. Newly added packs that only add their own files could also be mounted when a save loads.
- **To check:** the game's launch options for skipping the title (`--skip-title`) and choosing a world (`--world-id`) in the released build.
- **Platforms:** probably desktop only, since a Quest app may not relaunch itself cleanly.
- **Better Mods:** could sit as a button on its mods page, or be its own small mod.

## Idea

### More princess idles (Idle Life)
- **Regal settle:** a mane shake, then draws herself up tall, chin raised, eyes half closed. No props.
- **Tea extras:** steam curling from the cup; tea for any unicorn, not just the princesses.
- **Luna:** a dream-scroll with a starry glow.

### Wedding
- **Marriage today:** in 0.3.0 marriage is a status change agreed in conversation (dating, then engagement after 3 dates, 50+ trust and 3 days, then marriage 1 day later). There's no ceremony.
- **The mod:** could add the wedding itself: a ceremony, rings, guests and a venue.
- **Rules:** adults only.
