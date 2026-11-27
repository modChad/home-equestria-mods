# Kiss intensity

- **Author:** devanon (pin update by modChad, see [CHANGES.md](CHANGES.md))
- **Version:** 0.7.3
- **Needs:** [Kissing](../kissing/README.md) 1.2.11 or newer

A returned kiss builds: a slow lip cycle with head tilts, half-lidded eyes, an ear flick and a
deepening blush; later her tongue, and on desktop your view tips down to see it. Now and then
she parts for a breath. A pegasus's wings lift and snap open, and a partner rears up later in the
kiss. Before she answers she holds still for a moment; if she turns you down she turns her face
aside. Her mane fades where it would cover your eyes. Adults only: the forehead kiss for the young
is unchanged. Each part has its own switch in `user://mods/data/kiss_intensity/options.cfg`.

The game bundles devanon's 0.7.1, which only loads with Kissing exactly 1.2.11. This 0.7.3 is the
same mod with only that pin loosened, so it keeps working with newer Kissing. Put it in your mods
folder and it replaces the bundled copy.

## Install

Put `kiss-intensity-v0.7.3.pck` in the game's `mods` folder and restart the game.

## Building

`mods/kiss_intensity/tools/stage.sh`, then `./build_packs.sh kiss_intensity` (packs with
`tools/pack.gd`: the `.glb` models must stay raw, so the normal mod build can't be used).
