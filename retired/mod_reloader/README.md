# Mod Reloader

> **Retired (2026-11-26):** merged into **modChads modManager**: its Reload game button restarts to the main menu or straight into your last save or a chosen one. Switch Mod Reloader off and delete `mod-reloader-v1.0.0.pck`.


- **Version:** 1.0.0
- **By:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev

Most mods switch on and off at once, but some (ones that change game data, extend scripts or
replace game files) only apply after a restart. Mod Reloader turns that into one click.

## What it does

- When a mod change needs a restart, a **Reload from last save** button appears under
  "Open mods folder" in Settings → Mods. It stays hidden otherwise.
- The dropdown beside it picks which save to load: **Last save** (default) or any recent one.
- Pressing it saves your game, restarts it and takes you straight back into that save, with
  every mod loaded. You still see the title screen briefly while the game gets ready.
- If anything goes wrong you land on the normal title screen with **"modChad fucked it. Sorry."**

## Install

Put `mod-reloader-v1.0.0.pck` in your mods folder and restart the game. It can stay installed.

Desktop, Linux and Windows. VR should work (it restarts in the same mode) but isn't tested.
