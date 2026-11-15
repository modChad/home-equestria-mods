# Fishing

- **Version:** 0.7.1
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
- **Rare fish:** a **golden carp** (canal or lake, by day, about 1 carp in 60) and a **moonlit catfish** (only on nights with the moon at least 80% full). A "Rare!" card and their own jingle.
- **Junk:** about 1 bite in 12 isn't a fish. An old sun hat, a tin can or a lost horseshoe can be kept (they land on the pier beside the bucket); pond weed and sticks go straight back.
- **The Angler's Log:** a book lying on the pier by the rod rack. **E** takes it; hold it and **left click** to read: a page per fish with its picture, your best size, how many, and the first one's day, time and water. Fish you haven't caught show as a silhouette with a hint. A/D or the mouse wheel turns pages (you stay put while it's open). VR (untested): the trigger on the hand holding the log shows a floating page and turns to the next.
- **Ponies notice:** firsts, bests, rare fish and junk are remembered by ponies nearby (so they can bring them up), and a pony fishing with you says a quick line over her head. Big Mac, Spike and Fluttershy (for her animals) like fish now, so they may ask you for one. Ponies can now see the pier, the rod rack and the catch pail, and know they can join you: a pony following you, or one idling within about 24 m, takes a rod when you start fishing.
- **Unicorns and princesses** fishing with you hold the rod in their magic: it floats in front of them, wrapped in their aura, with their horn lit. Earth ponies and pegasi hold it in their mouth.
- **The bucket** is a hollow wooden pail (made for the mod) in place of the game's.
- **VR (untested):** controller pulses and a floating "!" on a bite; the catch hangs from the rod tip with a floating card. Rod hand's trigger keeps, the other hand's trigger releases.

- **Sounds (made in code):** a whoosh and the reel paying out on the cast, ratchet clicks as you reel (deeper when a fish pulls), a plop and a little rod bell on a bite, wet flaps while a catch hangs, and a jingle for a first catch or a new best.

Your best size and count per species are saved with the world.

## Changes

- **0.7.1:** the Angler's Log shows how to read it while held (desktop: click, left or right; VR: trigger for each page, closes after the last).
- **0.7.0:** a fish thrown into the water swims away (junk sinks) instead of reappearing on the pier; ponies wait 30–60 s for a bite; ponies speak their catch comments in their own voice (your Ponese or TTS setting).
- **0.6.1:** talking to a pony who's fishing no longer makes her put her rod back; she turns to you while you chat, then goes back to fishing.
- **0.6.0:** ponies fish on their own: up to two idle ponies near the pier take rods whether or not you're fishing, and keep them when you put yours away. Pier markers fixed so ponies can actually look at the rack, pier and pail.
- **0.5.3:** ponies can look at and refer to the pier, rod rack and pail (their AI names now match the game's).
- **0.5.2:** ponies fishing with you no longer give up on the pier when the game briefly loses their footing; more debug lines (`[fishing] footing:`).
- **0.5.1:** typing to a pony no longer puts your rod back (and sends fishing companions away); temporary debug lines in the log (`[fishing] magic:`, `[fishing] typing:`, `[fishing-route]`).
- **0.5.0:** unicorns and princesses hold the rod in their magic.
- **0.4.1:** you no longer walk while turning the Angler's Log's pages; ponies can see the pier, rod rack and pail, and know about fishing (an AI lore note).
- **0.4.0:** rare fish, junk, the Angler's Log, pony reactions and memories, fish fans (Big Mac, Spike, Fluttershy), a new hollow pail for the live well.
- **0.3.1:** put a fish in the bucket with E, or drop/throw it in; the catch list no longer flickers; the bucket logs why E didn't work (lines starting `[fishing]`).
- **0.3.0:** the bucket is a live well (fish swim in it, catch list, take one out); ponies' catches are the mod's species and go in the bucket.
- **0.2.0:** sounds; putting the rod back (E/Q) with a fish on now keeps it and clears the card; clicks on the card always reach the mod first.
- **0.1.0:** first release.

## Install

Put `fishing-v0.7.1.pck` in the game's `mods` folder and switch it on in **Settings → Mods**. If you have `fishing-debug-v0.1.0.pck`, remove it.

## Things to know

- Kept fish are separate items from the game's "River fish".
- The fish models are made in code by the mod (no outside art).
