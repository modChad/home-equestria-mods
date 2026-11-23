# Flowing Manes

- **Version:** 1.0.1
- **By:** modChad
- **Made for:** Home: Equestria 0.3.1-maredev
- **Works on:** desktop and VR (nothing to press)

Princess Celestia's and Princess Luna's manes and tails flow and ripple, with twinkling sparkles (Celestia) and slowly drifting stars and a soft glowing edge (Luna).

## What it changes

- **Flow:** a gentle wave travels from root to tip of each mane and tail, and the tail sways.
- **Feelings:** the hair reacts to how she feels: brighter when happy, dim and drooping when sad. An angry Celestia's mane can flare like flame; an angry Luna's turns to deep night (each with its own switch).
- **Movement:** the hair streams back as they walk and turn, and is kept from clipping through their faces.

## Settings

**Settings → More → Flowing Manes:** on/off per princess, a look preset, wave size and speed, sparkles, Luna's glow, emotions and mood colours, and a separate angry-flame switch.

## Install

Put `flowing-manes-v1.0.1.pck` in the game's `mods` folder and switch it on in **Settings → Mods**. It switches on and off straight away; switched off, the hair goes back to the game's own look. 1.0.1 replaces the bundled 1.0.0 and its devanon warm-up patch (now built in).

## Build from source

Copy this folder into `res://mods/flowing_manes/` in the game project, then run `mods/build_packs.sh flowing_manes`.

## Things to know

- Only Celestia and Luna are changed. No game file is replaced.

## Changes

### 1.0.1
- In VR the effect fades out when a princess is more than 12 m from you, and back in as you approach.
- A princess whose effect has fully faded out (far away, or out of range in VR) no longer costs anything each frame.
- Folds in devanon's warm-up patch 1.0.0: the hair shaders are compiled behind the loading screen, so the first sight of Celestia or Luna doesn't stutter.
