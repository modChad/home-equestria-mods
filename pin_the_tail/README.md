# Pin the Tail on the Pony

- **Version:** 0.4.2
- **Author:** modChad
- **Works on:** desktop and VR

A party game poster on the west wall of Sugarcube Corner. Put the blindfold on, get spun around, and pin the tail. Your best shot is chalked up beside it. Ponies know the game, call out warmer or colder, tease bad pins, and can have a go themselves.

## Install

Put `pin-the-tail-v0.4.2.pck` in the game's `mods` folder and switch it on in **Settings → Mods**. It replaces the bundled 0.4.1 and its devanon patch (the patch's fix is now built in).

## Changes

### 0.4.2
- Tails are much lighter to draw: 144 triangles and one draw call each, down from about 21,500 triangles and six draw calls. With the most tails out (25), that is about 3,600 triangles instead of about 540,000. Same size, colours and layout.
- Everything (poster, frame, text, basket, score card and tails) stops drawing past 6 m: it is inside Sugarcube Corner, so nothing needs drawing from outside. Before, the poster drew to 60 m and pinned or saved tails were never culled.
- Folds in devanon's patch 1.0.0: with the AI off, the mod no longer searches for the AI client every physics tick.
