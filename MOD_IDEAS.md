# Home: Equestria mod ideas

Status key: **Done** · **Next** · **Backburner** · **Idea**

## Done

### Grooming (`grooming.pck`, v1.0.2, game 0.3.0)
- **What it does:** a mane & tail brush, a coat brush and wing preening, each with its own animation and sounds.
- **Bond:** raises friendship, and love with adult ponies already fond of you.
- **1.0.2:** brushing and preening work on Celestia and Luna (their hair and wings are built into their body model).

### Flowing Manes (`flowing_manes.pck`, v1.0.0, game 0.3.0)
- **What it does:** Celestia's and Luna's manes and tails flow like in the show, with sparkles (Celestia) and drifting stars and a see-through glowing edge (Luna).
- **Feelings:** the hair reacts to emotions (brighter when happy, dim and drooping when sad), with a Daybreaker flame for an angry Celestia and Nightmare Moon night for an angry Luna.
- **Movement:** the hair streams back as they walk and turn, and is kept from clipping through their faces.
- **Settings:** its own page under Settings → More → Flowing Manes, with an on/off per princess, a look preset, wave size and speed, sparkles, Luna's glow, emotions and mood colours, and a separate Daybreaker flame switch.

### Balloon Boarding (`balloon_boarding.pck`, v1.0.0, game 0.3.0)
- **What it does:** a pony you carry into the hot-air balloon stays aboard as a passenger, and a follower who stops short of the ramp (e.g. Celestia) is helped in.

### Pegasus Ride (`pegasus_ride_v2.pck`, v2.2.1, game 0.3.0) — someone else's mod, adapted
- **What it does:** ride on a winged friend's back and fly to named places, cruise or explore (N / V / P, or say where).
- **Our changes (2.2.0):** Celestia and Luna can carry you; the seat is measured from each pony's own back (was a fixed height that put you inside Celestia); the friendship gate now works (Friend or closer); flight diagnostics off.
- **Untested:** a full ride on a princess in game, VR.

### Teleport (`teleport.pck`, v1.0.0, game 0.3.0)
- **What it does:** adds `places` (a numbered list of houses, landmarks and regions) and `tp` (to a place, a list number, a pony or coordinates) to the debug console and Settings → Debug.

### Idle Life (`idle_life.pck`, v1.0.0, game 0.3.0)
- **What it does:** ten new idles for ponies standing about: a light or deep stretch (pegasi spread their wings), pawing the ground, looking round, a wing stretch and wing preen (pegasi), a magic fringe brush and magic sparkles (unicorns and alicorns), and at night dozing off and stargazing.
- **When:** the game's own fidget rules decide, roughly every 18–45 s per pony; anything that disturbs her fades it out.
- **Unchecked:** the full town (tested in a cut-down world).
- **Later: tail mechanics.** The stretch's tail arch is only a few kicks to the tail's spring physics, so it flicks up and sags rather than holding a pose. Look into how the tail physics (hybrid_tail_motion.gd, hybrid_tail_physics.gd) could hold a raised tail, e.g. a lift goal like the existing sideways `aside_goal`. Also wanted: a tail swat idle (a fly on her flank, tail flicking at it). Tried with the tail spring's kicks; dropped because it read weakly. Revisit once the tail can be driven to poses.
- **Shelved: princess preen.** The wing preen is off for Celestia and Luna. Their open wings don't sit right on their bodies, a known game bug, and it shows when the wing is brought forward to her muzzle. Revisit once the game fixes the princess wing fit, then remove `"preen"` from `NOT_PRINCESSES` in idles.gd. The preen already reaches a princess's muzzle: about 10 cm from the nearest wing bone.
- **Built v1.0.0 (2026-11-06):** ten idles: light/deep stretch (pegasus wings at ~45°), paw, look round, wing stretch, wing preen, magic fringe brush (princesses: swoop), magic sparkle, doze and stargaze (night only). Tail swat dropped (see tail mechanics). Still to do: a hoof mane-brush.

### Princess Teleport (`princess_teleport.pck`, v1.0.0, game 0.3.0)
- **What it does:** Celestia, Luna and Twilight teleport you both to far places (150 m or more) when you're beside them and ask, with a horn glow and a flash.
- **AI:** each gets a lore note saying she can teleport; she uses her usual go_to or lead tag.
- **Unchecked:** how reliably the AI agrees, and her landing spot in the full world.

## Next

### Cuddling
- **Code review (0.3.0):** suspected pony size and Anon height problems, from reading the code only and not yet confirmed in game:
  1. **Grass naps (all sizes):** the pony's spot beside or on Anon is a fixed offset tuned for Canon, and there's no fit check. At larger sizes she spawns overlapping him.
  2. **Bed "shoulder" and "snuggle" positions:** fixed offsets tuned for Canon. Her head lands in the wrong place at larger sizes (past his head, or into the headboard). The fit check only tests her body length.
  3. **Anon's height setting (new in 0.3.0):** the bed layout (head, hips, eye height, his half-width) assumes a 6 ft Anon. Shorter or taller Anons misalign, and "Same height as Anon" grows the mare without growing his half of the gap.
  4. **Cuddle posing at large sizes:** the limb floor check uses fixed ray lengths while the limb radius scales, so big ponies' hooves can sink into the mattress. Several distances also don't scale: drag speed, follow/break distances, the 1 m release, and the 2.5 / 2.8 m start and end range.
  5. **Stallions:** adult stallions (1.2×) are never eligible for the shared bed at any size setting.
  6. **Tall VR players:** the couch refuses a rest when the VR avatar scale is over 1.3.

## Backburner

### Mod reloader ("Restart and load")
- **The problem:** mods load at startup. Godot can't unmount a pack, and the game reads data merges, script extensions and replaced files once, so a true live refresh isn't reliable.
- **The idea:** a "Restart and load" button that saves your mod choices, relaunches the game, skips the title screen and opens the chosen save, so every mod loads cleanly in one click.
- **Live loading:** entry-script-only mods already switch on and off live. Newly added packs that only add their own files could also be mounted when a save loads.
- **To check:** the game's launch options for skipping the title (`--skip-title`) and choosing a world (`--world-id`) in the released build.
- **Platforms:** probably desktop only, since a Quest app may not relaunch itself cleanly.
- **Better Mods:** could sit as a button on its mods page, or be its own small mod.

### Fishing
The game already has a river pier with physical cast, bite, hook and reel, and up to two pony companions. The catch is a single "River fish" that has no use yet.

Possible additions:
- **Species:** several species with sizes and rarity, depending on time of day, weather and season, plus some junk catches.
- **Bigger fish:** they fight back, with line tension (the game's line code already tracks tension).
- **What to do with a catch:** release (fits ponies being mostly herbivores), sell, gift to fish-liking characters, or keep in a catch journal with personal bests.
- **Social:** companions react to your catches and remember big ones.
- **Later:** a carry-anywhere rod for any river, lake or canal. This is the riskiest part, since it needs its own desktop and VR controls.

Open questions:
- **Rod:** pier only, portable, or both?
- **The catch:** what happens to it?
- **Pacing:** cosy or challenging?
- **Assets:** fish models and sounds?

## Idea

### Wedding
- **Marriage today:** in 0.3.0 marriage is a status change agreed in conversation (dating, then engagement after 3 dates, 50+ trust and 3 days, then marriage 1 day later). There's no ceremony.
- **The mod:** could add the wedding itself: a ceremony, rings, guests and a venue.
- **Rules:** adults only.

## Bugs to report

### Balloon: Celestia stops short of the ramp
- A following Celestia stopped outside the balloon's entrance in game. In a cut-down test she boarded fine, so the real cause is unconfirmed. A guess: her taller navigation clearance keeps her route away from the ramp. Balloon Boarding works around it.

## Notes for every mod
- **Safest hooks first:** prefer an entry script with `Mods` hooks, then JSON merges, then script extensions. Script extensions don't compile over the released game's compiled scripts.
- **Items via data:** items added through the food data need an `item_tags.json` merge (e.g. `"tool"`) so they don't count as food or gifts.
- **Desktop and VR:** every action needs both a desktop and a VR control.
- **Foals:** no romance with foals, or when the player is one.
- **Git:** pull only, never push, no commits.
