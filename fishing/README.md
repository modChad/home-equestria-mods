# Fishing

- **Version:** 0.3.1
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop (VR controls included but untested)

The river pier's fishing, made readable, with five fish species.

## What it changes

- **Casting:** look up to cast far (about 13 m), down to drop it close (about 3 m). A bigger float (white, red top, yellow antenna), a line you can actually see, a splash and ripples where it lands, and a soft ring every couple of seconds so you can find it again.
- **Bites:** a fish may nibble first (a small dip). On a real bite the float plunges and jerks, ripples burst out, the rod tip jerks and **Bite! Click to hook** appears. You have 3.5 s (was 2.6).
- **Hooked:** the fish thrashes at the surface, the rod stays bent and a tension bar shows how hard it's pulling. A pulling fish gives line back more slowly.
- **The catch:** reel it in and it hangs from your line in front of you with a card: species, size, and "First trout!" or "New personal best!". **Left click: keep** (it goes into the pier's bucket) · **Right click: release** (it flips back with a splash). Putting the rod back with a fish on keeps it.
- **The bucket (live well):** kept fish swim in water inside the pier's bucket, up to 12, saved with the world, each with its own size. Look at it to see the catch list; **E** takes the newest fish out into your free hand as an item (to gift, sell or store); **E** with a fish in hand puts it back, and a fish dropped or thrown in swims too. When it's full, extra fish land beside it. Ponies fishing with you put their catches in it too. VR (untested): grip inside the bucket to take one.
- **Species:** Trout, Perch, Carp, Catfish and Sunfish, each its own item (tagged fish, giftable). Which one bites depends on the water (canal, river or lake), its depth and the time of day: catfish mostly at night, trout at dawn and dusk. The pier is on the canal, so carp, perch and sunfish are the usual catches there.
- **VR (untested):** controller pulses and a floating "!" on a bite; the catch hangs from the rod tip with a floating card. Rod hand's trigger keeps, the other hand's trigger releases.

- **Sounds (made in code):** a whoosh and the reel paying out on the cast, ratchet clicks as you reel (deeper when a fish pulls), a plop and a little rod bell on a bite, wet flaps while a catch hangs, and a jingle for a first catch or a new best.

Your best size and count per species are saved with the world.

## Changes

- **0.3.1:** put a fish in the bucket with E, or drop/throw it in; the catch list no longer flickers; the bucket logs why E didn't work (lines starting `[fishing]`).
- **0.3.0:** the bucket is a live well (fish swim in it, catch list, take one out); ponies' catches are the mod's species and go in the bucket.
- **0.2.0:** sounds; putting the rod back (E/Q) with a fish on now keeps it and clears the card; clicks on the card always reach the mod first.
- **0.1.0:** first release.

## Install

Put `fishing-v0.3.1.pck` in the game's `mods` folder and switch it on in **Settings → Mods**. If you have `fishing-debug-v0.1.0.pck`, remove it.

## Things to know

- Kept fish are separate items from the game's "River fish".
- The fish models are made in code by the mod (no outside art).
