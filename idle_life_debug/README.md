# Idle Life Debug

- **Version:** 1.0.0
- **By:** modChad
- **Made for:** Home: Equestria 0.3.0-maredev
- **Needs:** Idle Life
- **Private:** a debug tool, left out of the public download table.

Adds an `idle` command to the game's debug console (the `` ` `` console, and Settings → Debug's command line):

| Command | What it does |
| --- | --- |
| `idle list` | Lists every idle's name. |
| `idle <name>` | Plays that idle on the pony you're looking at. |
| `idle <name> <pony>` | Plays it on a named pony, e.g. `idle shoe celestia`. |
| `idle run_all [pony]` | Plays every idle on her in turn, with a 2 s pause after each. Idles she can't do are skipped and listed at the end. |
| `idle stop [pony]` | Stops the idle she's doing, and a `run_all` if one is going. |

Idles started this way play to their end; nothing interrupts them. An idle still needs what it needs (wings, a horn, a princess, room to take off), and says so if it can't play.

Works alongside Teleport's `tp` and `places`, whichever loads first.
