# Home: Equestria mods by modChad

Mods for [Home: Equestria](https://github.com/homedevanon/home-equestria), made for game version **0.3.0-maredev**.

Each mod is one `.pck` file. Download it from the table below (or all of them from the [latest release](https://github.com/modChad/home-equestria-mods/releases/latest)). Players only need the `.pck`; the rest of each folder is its source.

## Mods

| Mod | Version | Download | What it does |
| --- | --- | --- | --- |
| [Grooming](grooming/README.md) | 1.0.2 | [grooming.pck](https://github.com/modChad/home-equestria-mods/raw/main/grooming/grooming.pck) | A mane & tail brush, a coat brush and wing preening, each with its own animation and sounds. Grooming raises friendship, and love with adult ponies already fond of you. Works on Celestia and Luna too. |
| [Flowing Manes](flowing_manes/) | 1.0.0 | [flowing_manes.pck](https://github.com/modChad/home-equestria-mods/raw/main/flowing_manes/flowing_manes.pck) | Celestia's and Luna's manes and tails flow and ripple, with sparkles and drifting stars, and react to how they feel. Settings under Settings → More → Flowing Manes. |
| [Idle Life](idle_life/README.md) | 1.0.0 | [idle_life.pck](https://github.com/modChad/home-equestria-mods/raw/main/idle_life/idle_life.pck) | Ten new idles for ponies standing about: stretches, pawing the ground, looking round, wing stretches and preens, magic fringe brushes and sparkles, and at night dozing and stargazing. |
| [Princess Teleport](princess_teleport/README.md) | 1.0.0 | [princess_teleport.pck](https://github.com/modChad/home-equestria-mods/raw/main/princess_teleport/princess_teleport.pck) | Celestia, Luna and Twilight can teleport you both to far places when you ask while standing beside them. |
| [Balloon Boarding](balloon_boarding/README.md) | 1.0.0 | [balloon_boarding.pck](https://github.com/modChad/home-equestria-mods/raw/main/balloon_boarding/balloon_boarding.pck) | A pony you carry into the hot-air balloon stays aboard, and a follower who stops short of the ramp is helped in. |
| [Teleport](teleport/README.md) | 1.0.0 | [teleport.pck](https://github.com/modChad/home-equestria-mods/raw/main/teleport/teleport.pck) | Adds `places` and `tp` to the debug console: jump to a place, a pony or coordinates. |
| [Pegasus Ride](pegasus_ride_v2/Readme.txt) | 2.2.1 | [pegasus_ride_v2.pck](https://github.com/modChad/home-equestria-mods/raw/main/pegasus_ride_v2/pegasus_ride_v2.pck) | Ride on the back of a winged friend, Celestia and Luna included. Someone else's mod, adapted for 0.3.0 (see its [CHANGES.md](pegasus_ride_v2/CHANGES.md)). |

## Installing

1. Download the `.pck` files you want from the table above.
2. Put them in the game's mods folder. **Settings → Mods → Open mods folder** opens it for you.

   | System | Mods folder |
   | --- | --- |
   | Windows | `%APPDATA%\home-equestria-public\mods\` |
   | Linux | `~/.local/share/home-equestria-public/mods/` |
   | Quest | `Android/data/org.homeequestria.game/files/mods/` (USB file transfer; create the `mods` folder if it is missing) |

3. Restart the game. Each mod can be switched on and off in **Settings → Mods**.

**Mods are programs**: they run with the same rights as the game. Only install mods from people you trust.

## Building from source

Clone this repo as the `mods/` folder of the game's source project (with the game's source data for the same version), then run `./build_packs.sh` to rebuild every mod's `.pck` in its folder, or `./build_packs.sh <id>` for one. It moves the old `.pck` aside while building, so it isn't packed into the new one.

To build by hand instead, move the old `.pck` out of the mod's folder first, then run:

```
godot --headless --xr-mode off --path <project> --script res://tools/modding/build_mod.gd -- <id>
```

See the game's own `mods/README.md` for the mod format.
