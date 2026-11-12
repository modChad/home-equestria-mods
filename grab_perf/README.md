# Grab Perf

- **Version:** 1.0.0
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** VR (Quest standalone and PC VR); does nothing on desktop

Stops the frame-rate drop while your hands are clenched into fists in VR.

## Why

With a full fist (grip + trigger) the game checks every pony in town for a leg near each hand,
60 times a second, and works out each pony's whole skeleton to do it, however far away she is.
On a Quest 3 that takes the game from about 25 FPS to 17-19 whenever you make a fist.

## What it changes

During the grabber's own physics tick, it only looks at ponies within 2.5 m of a hand (scaled
with the pony's size), plus any pony you're holding or that it's already targeting. Grabbing
works exactly as before: legs and chest grips are only ever taken within centimetres of a hand.
Everything else in the game still sees every pony.

## Install

Put `grab-perf-v1.0.0.pck` in the game's `mods` folder (Quest:
`Android/data/org.homeequestria.game/files/mods/`) and switch it on in **Settings → Mods**.
It switches on and off straight away.

## Things to know

- Tested with stand-in ponies only, not in the real game or on a headset.
- Reported to the developer as a game bug; once the game fixes it, this mod can go.
