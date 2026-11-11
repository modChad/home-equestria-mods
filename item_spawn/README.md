# Item Spawn

- **Version:** 1.0.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop (VR should work but is untested)

Adds item spawning to the game's debug console.

## Commands

- **`is list`** lists every item in the game, with its id and name.
- **`is list <word>`** lists only the items matching that word, e.g. `is list hat`.
- **`is add <item>`** puts one of that item straight into your briefcase. Use its id or its name, e.g. `is add apple` or `is add river fish`.
- **`is add <item> <count>`** adds several, e.g. `is add apple 5` (up to 999).

If no item matches, the console lists the 5 closest matches.

`help` lists these alongside the console's own commands. They also work on the command line in **Settings → Debug**, and alongside the Teleport mod.

## Using the console

The console is part of the game's developer tools. To turn them on, go to **Settings → More** and click **Updates** five times quickly. Then press **`** (backtick) in a world to open the console.

## Install

Put `item-spawn-v1.0.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Things to know

- If the briefcase fills up, the spawn stops and says how many fitted. Items on the ground still need a briefcase slot in this game, so extras can't be dropped instead.
- Books, letters and paintings are made per save, so they aren't in the list. You can still add one by its exact id (e.g. `book:3`) if you know it.
