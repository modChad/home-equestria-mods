# Briefcase Rescue

**Version:** 1.0.0 · **Author:** modChad · **Game:** 0.3.0-maredev

Fixes briefcases and saves the game refuses after a mod that added items is removed incorrectly
(for example Watch Party's TVs and remote). Without it the game sets the briefcase aside, gives
you an empty one, and rejects saves made while you carried those items.

## What it does

On every launch, before the title screen:

- Deletes items the game doesn't recognise from your briefcase and world saves. Everything else
  (items, bits, placed furniture) is kept.
- If your briefcase or a save was set aside (`*.corrupt-*`), restores the newest copy once it is
  valid. Bits earned since are added back on top.
- Shows **"Corrupted items removed."** when it changed anything. Otherwise it does nothing.

Every changed file is backed up first as `<file>.rescue-backup-<time>`. A restored set-aside copy
is renamed to `.rescued-` and never deleted.

## Install

Put `briefcase-rescue-v1.0.0.pck` in your mods folder and restart the game. It can stay installed.

Desktop. VR should work, but the notice is a desktop window and is not tested in a headset.
