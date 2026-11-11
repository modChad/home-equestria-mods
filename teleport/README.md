# Teleport

- **Version:** 1.0.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop and VR

Adds teleporting to the game's debug console.

## Commands

- **`places`** lists every place the game knows by name: houses, landmarks and town buildings nearest first, then the world's regions. Each one has a number.
- **`places <word>`** lists only the places matching that word, e.g. `places bridge`.
- **`tp <number>`** takes you to a place from the last list, e.g. `tp 3`.
- **`tp <place>`** takes you to a place by name, e.g. `tp sugarcube corner` or `tp balloon`.
- **`tp <pony>`** puts you next to a pony who's in the world, e.g. `tp celestia`.
- **`tp <x> <y> <z>`** takes you to a point.

`help` lists these alongside the console's own commands. They also work on the command line in **Settings → Debug**.

## Using the console

The console is part of the game's developer tools. To turn them on, go to **Settings → More** and click **Updates** five times quickly. Then press **`** (backtick) in a world to open the console.

## Install

Put `teleport-v1.0.0.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Things to know

- The place list is the same one ponies use when they're asked to go somewhere, so it grows as more of the world loads in.
- The regions are far-off places on the world map. Teleporting there takes you to where that region starts.
