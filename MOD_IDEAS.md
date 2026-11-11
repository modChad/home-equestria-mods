# Home: Equestria mod ideas

Status key: **Done** · **Next** · **Backburner** · **Idea**

## Done

### Grooming (`grooming-v1.0.3.pck`, v1.0.3, game 0.3.0)
- **What it does:** a mane & tail brush, a coat brush and wing preening, each with its own animation and sounds.
- **Bond:** raises friendship, and love with adult ponies already fond of you.
- **1.0.2:** brushing and preening work on Celestia and Luna (their hair and wings are built into their body model).
- **1.0.3:** new brush models, made in Blender (`renders/grooming_brushes_v1.0.3.blend`) and generated into `models/` by `tools/make_models.gd`.

### Flowing Manes (`flowing-manes-v1.0.0.pck`, v1.0.0, game 0.3.0)
- **What it does:** Celestia's and Luna's manes and tails flow like in the show, with sparkles (Celestia) and drifting stars and a see-through glowing edge (Luna).
- **Feelings:** the hair reacts to emotions (brighter when happy, dim and drooping when sad), with a Daybreaker flame for an angry Celestia and Nightmare Moon night for an angry Luna.
- **Movement:** the hair streams back as they walk and turn, and is kept from clipping through their faces.
- **Settings:** its own page under Settings → More → Flowing Manes, with an on/off per princess, a look preset, wave size and speed, sparkles, Luna's glow, emotions and mood colours, and a separate Daybreaker flame switch.

### Balloon Boarding (`balloon-boarding-v1.0.0.pck`, v1.0.0, game 0.3.0)
- **What it does:** a pony you carry into the hot-air balloon stays aboard as a passenger, and a follower who stops short of the ramp (e.g. Celestia) is helped in.

### Pegasus Ride (`pegasus-ride-v2-v2.2.1.pck`, v2.2.1, game 0.3.0) — someone else's mod, adapted
- **What it does:** ride on a winged friend's back and fly to named places, cruise or explore (N / V / P, or say where).
- **Our changes (2.2.0):** Celestia and Luna can carry you; the seat is measured from each pony's own back (was a fixed height that put you inside Celestia); the friendship gate now works (Friend or closer); flight diagnostics off.
- **Untested:** a full ride on a princess in game, VR.

### Teleport (`teleport-v1.0.0.pck`, v1.0.0, game 0.3.0)
- **What it does:** adds `places` (a numbered list of houses, landmarks and regions) and `tp` (to a place, a list number, a pony or coordinates) to the debug console and Settings → Debug.

### Idle Life (`idle-life-v1.4.2.pck`, v1.4.2, game 0.3.0)
- **What it does:** sixteen new idles for ponies standing about: a light or deep stretch (pegasi spread their wings), pawing the ground, looking round, a wing stretch and wing preen (pegasi), a magic fringe brush and magic sparkles (unicorns and alicorns), and at night dozing off and stargazing. For Celestia and Luna: reading a scroll, writing one with a quill, tea and a shoe check. Celestia tends the sun at sunrise and sunset; Luna checks the moon at moonrise and moonset.
- **Remembered:** nearby ponies (and the pony herself) remember the notable idles, so they can bring them up in conversation.
- **When:** the game's own fidget rules decide, roughly every 18–45 s per pony; anything that disturbs her fades it out.
- **Unchecked:** the full town (tested in a cut-down world); the sun and moon checks with the game's native flight library and at a real sunrise/moonrise (the lab forced them, and native flight doesn't load in the lab here); whether ponies actually mention the remembered idles with the real AI.
- **Later: the shoe check.** The user still sees the shoe clip through her in game, though in the lab (and a Blender trace of baked poses, `renders/idle_life/shoe_path_v1.blend`) the path stays 15 cm+ clear of her body and mane. Cause unknown (possibly Flowing Manes' hair). Revisit at the next round of new animations.
- **Later: tail mechanics.** The stretch's tail arch is only a few kicks to the tail's spring physics, so it flicks up and sags rather than holding a pose. Look into how the tail physics (hybrid_tail_motion.gd, hybrid_tail_physics.gd) could hold a raised tail, e.g. a lift goal like the existing sideways `aside_goal`. Also wanted: a tail swat idle (a fly on her flank, tail flicking at it). Tried with the tail spring's kicks; dropped because it read weakly. Revisit once the tail can be driven to poses.
- **Shelved: princess preen.** The wing preen is off for Celestia and Luna. Their open wings don't sit right on their bodies, a known game bug, and it shows when the wing is brought forward to her muzzle. Princess Wings (below) may fix this: retest the preen with it, then remove `"preen"` from `NOT_PRINCESSES` in idles.gd. The preen already reaches a princess's muzzle: about 10 cm from the nearest wing bone.
- **Built v1.0.0 (2026-11-06):** ten idles: light/deep stretch (pegasus wings at ~45°), paw, look round, wing stretch, wing preen, magic fringe brush (princesses: swoop), magic sparkle, doze and stargaze (night only). Tail swat dropped (see tail mechanics). Still to do: a hoof mane-brush.
- **Built v1.1.0 (2026-11-08):** reading a scroll (princesses only, 9.5 s): appears in a flash, unrolls, she reads four lines, smiles and nods, rolls it up and it vanishes. The scroll is made in code (scroll.gd: no real text, a sun seal). Her gaze follows the lines through the game's action gaze (`set_action_gaze`); the busy check ignores that gaze (`_still_free`). Gaze sweep kept to 30% (`SCROLL_SWAY`) so the head sway stays gentle. Scales with pony size. Also: the stretch's neck lift removed so her head sits lower. Signed modChad.
- **Built v1.2.0 (2026-11-08):** five more princess idles.
  - **Writing (10.8 s):** a blank scroll and a quill (both made in code) appear; three lines and a signature with a flourish, the ink revealed row by row by a shader as the nib moves; a nod, then both vanish.
  - **Tea (9.4 s):** a white-and-gold cup and saucer (tea.gd); two sips at her lips, eyes closed, then a smile. Her gaze eases from the cup to straight ahead for each sip so her head stays steady. Lips from the face rig (`mFaceLipUpperCenter`/`LowerCenter`), not `MOUNT_MOUTH` (see bugs).
  - **Shoe check (8.4 s):** always her left foreleg (on the right the shoe went through her mane). Her body mesh is swapped for a copy without that shoe while it's off (shoe.gd) and a loose copy floats in her magic. The shoe drops 10 cm, swings 40 cm out past the mane (`SHOE_DROP`, `SHOE_SWING`), rises beside her muzzle, is turned over and shaken (a pebble falls), and goes back on.
  - **Sun (Celestia) / moon (Luna):** the game's own flight (`flight.request` hover, 1.5 m, 5 s); she turns to face the sun or moon, horn glow and sparkles rising toward it, then lands. Only when the sun or moon is between about −2° and 15° (sunrise/sunset, moonrise/moonset); the moon check skips nights under a quarter lit. While she's up, only being spoken to or held cuts it short.
  - **Packs:** now built to `mods/release_packs/` as `idle-life-vX.Y.Z.pck` (the builder packs every file in `mods/<id>/`, so packs must not sit there). The 1.1.0 pack had the 1.0.0 pack inside it by mistake (harmless, just bigger).
- **Built v1.3.0 (2026-11-08):** notable idles (scroll, write, tea, shoe, sun, moon, doze) are written to the game's witnessed-events memory with `world_context.record("idle_life", ...)` at 45% through, one line about her by name (e.g. "Princess Celestia conjured a scroll with her magic, read it through and made it vanish again."). Witnesses: the pony and AI ponies within 10 m (ids from `game.director.characters`). At most one per pony per 3 minutes (`RECORD_GAP`).
- **Built v1.4.0 (2026-11-10): show-style props**, modelled in Blender (original designs in the show's style, not copies), exported as glb to `mods/idle_life/models/`, one set per princess (Luna's in her colours); the code-made versions remain as a fallback.
  - **Tea sets:** a cup and saucer each, under 500 tris per set (`tea_<princess>_cup/saucer.glb`; Blender file `renders/idle_life/tea_sets_v2.blend`).
  - **Scroll kit:** scroll rollers, a quill and a floating inkwell each (`roller_/quill_/inkwell_<princess>.glb`; `renders/idle_life/scroll_kit_v1.blend`). Paper and ink tinted per princess.
  - **Writing now 13.6 s:** the inkwell floats at her left (on her right it sat in Celestia's mane) and the quill dips before each of the four lines.
- **Built v1.4.1 (2026-11-11):** the scroll floats further out (45 cm ahead, a little higher and 10 cm to her left) and the inkwell further out from her, clear of Flowing Manes' fuller manes.
- **Built v1.4.2 (2026-11-11):** with Horn Glow on, the sparks leaving her horn (magic sparkle, sun and moon) are quiet puffs of sparkles, with no round disc or cast sound; her horn glows the Horn Glow way.
- **Debug mod: Idle Life Debug** (`mods/idle_life_debug/`, private, `"private": true` in mod.json so it stays out of the GitHub README). Its pack is not kept in release_packs; build it with `--out` somewhere else (e.g. `tools/_il_lab/`). Debug console commands: `idle list`, `idle <name> [pony]`, `idle run_all [pony]`, `idle stop [pony]` (no pony = the one you're looking at, within 12° of screen centre and 25 m). It forces the idle through Idle Life's `play()`, and chains onto the console after other mods (e.g. Teleport) so their commands still work.
- **Lab:** `tools/_il_lab/` (moved under tools/). Switches: `--look-ahead` (she looks ahead, not at the camera), `--scale N`, `--over` (over her shoulder), `--hoof` (close on her front hooves), `--fake-ai` (a stand-in AI memory that prints what's recorded), `--console-test` (types debug-console commands into the real console), `--snapshot t1,t2` (bakes posed meshes to .obj plus the shoe path as .json, for Blender); a second `--mod-src princess_wings` loads Princess Wings too. Renders in `renders/idle_life/`. Renders only run ~3 min per call, so long idles go at 15 fps.

### Princess Teleport (`princess-teleport-v1.1.0.pck`, v1.1.0, game 0.3.0)
- **What it does:** Celestia, Luna and Twilight teleport you both to far places (150 m or more) when you're beside them, with a horn glow and a flash.
- **AI:** each gets a lore note saying she can teleport; she uses her usual go_to or lead tag.
- **Built v1.1.0 (2026-11-08): consent.** A far trip is only teleported if Anon agreed: his last line to her (heard within 90 s, via the director's `transcript` signal, matched to her `history`) asks for a teleport ("teleport", "zap", "poof", "blink", "beam", "warp", "magic us", "with your magic"), or says yes ("yes", "sure", "please", "do it"…) right after her line offered one. "Don't teleport", "no magic", "let's walk" etc. always walk; "why don't you / can't you teleport us" counts as asking. Otherwise the trip is walked and logged. **Danger** skips the ask: a timberwolf within 45 m of Anon or her (`Timberwolves.wolves`), or Anon in the Everfree (habitat > 0.5) when it's dark there. Lore now tells her to offer and wait for his answer, and to teleport unasked only in danger. Wording checks: `tools/_pt_lab/_pt_check.tscn` (14 cases, all pass).
- **Unchecked:** how reliably the AI offers and waits; her landing spot in the full world; the danger case in game.

### Princess Wings (`princess-wings-v1.0.0.pck`, v1.0.0, game 0.3.0)
- **What it does:** moves Celestia's and Luna's open wings onto their shoulder blades, just behind the withers. As shipped, the roots sat about 12 cm too far back (Celestia) and perched on top of the back.
- **How:** entry script with `Mods.on_node`; offsets each open-wing mesh's skin bind poses. Body, folded wings and skeleton untouched; flight, tuck, half-open and preen poses still apply.
- **Placement rule (from Rainbow Dash):** root just behind the top of the foreleg, sunk 8.4% of barrel height into the back, 67% of the way out from the spine. Celestia (0, −5, −10) cm, Luna (±1.1, −1.8, −4.8) cm.
- **Lab:** `tools/_wing_lab/` (lab.gd renders, measure.gd measurements), renders in `renders/wing_fit/`.
- **Unchecked:** full game, VR, preen reach, unfold from folded.
- **Game bugs found:** the princess fits leave the open-wing bones unfitted (`pony_WingBase_*` keep the mare's offsets scaled from the spine); Celestia's folded-wing bones are ~1 cm asymmetric.
- **Status:** given to the game's developer; expected in the next release.

### Kissing (`kissing-v1.2.8.pck`, v1.2.8, game 0.3.0)
- **What it does:** hold K to kiss the pony you're facing (within 1.5 m, times her size above Canon), no carrying needed. She walks up, Anon bends down to her (his standing eye height eases to just above her lips, like Ctrl's crouch), and the game's own kiss starts (`PonyAffection.begin`). VR (attempted, untested): lean in within 8 cm of her lips for 0.4 s.
- **Game rules kept:** kissing back or turning away (`affection_allowed`; only ponies who'd welcome it, per `bonds.welcomes`, walk over), deep after 0.6 s held with lips together (K again ends it), forehead kiss for fillies/colts or a young player, buck if pressed again after a refusal.
- **How:** entry script driving the game's `pony_kisser.gd`. Its kisses are hidden from the kisser for its tick (priority −25) and handed back afterwards (−19), so the kisser's unscaled checks don't end them; the mod does the per-tick work itself (target, eye, face, near plane, `kiss_hold`) with limits scaled to her size.
- **Hoers size (×2.0+):** `reach.gd` after AffectionPose: her back tips down from the hips (up to 14°), forelegs fold knee-forward under her shoulders, neck CCD finishes the reach. After lips meet she stops stepping in.
- **Remembered:** onlookers within 10 m get a line ("Anon kissed …", "… shared a long, deep kiss", forehead, refused), at most once per pony per 3 min. Her own memory of it is the game's (director_contacts).
- **v1.1.0 (2026-11-10): feelings build up** instead of the game's loud horn flare every ~0.9 s (`excitement.gd`). `feelings.gd`: `level` 0..1 rises while she's excited (kiss 0.05/s, deep 0.09/s, petting/AI 0.06/s) up to a peak by bond (acquaintance .35 … married 1.0), holds 1.5 s, fades over 4 s; applies to all excitement. Horn: a quiet aura, sparkles and light that grow and pulse, a hum (peak 0.10). `wings.gd`: spread wings shiver past 0.45 (roots 0.5°, feathers 1.4°, tips 2°, a ripple now and then). `fidgets.gd` (earth ponies): weight shifting, tail swish, ear flicks, hoof taps. After a kiss she backs out of his face; he stays bent until there's room.
- **v1.2.0 (2026-11-10): rising into his arms.** In a deep kiss with a partner (dating or closer), below Hoers size, she rears up on her hind legs and rests her forehooves over his shoulders, kneading gently (`rear.gd` plays `rear_anim.json`). A procedural first try read as "front legs raised", so the motion was keyframed in Blender on the game's rig: `renders/kissing/blender_rear/rear_v2.blend`. 5 s: a small gathering dip, rise to 55° about her hips with the chest curling forward and forelegs tucked, then forelegs reach over his shoulders and knead slowly; neck keeps lips on his. Canon Celestia can't reach a standing 6 ft Anon's shoulders, so he stays bent to ~1.41 m eye. At Hoers size she bows instead.
- **v1.2.1–1.2.7 (2026-11-11): clipping fixes and options.**
  - **1.2.1:** her face stays a few cm off Anon's eyes (her neck turns her head back if her skull or nose gets too close); if her neck or chest comes too close she backs up instead of walking in (`guard.gd`).
  - **1.2.2:** at Canon size her head keeps further off his eyes (forehead and mane went through the camera).
  - **1.2.3:** at Canon size she rests her forehooves on his chest instead of his shoulders, so he no longer bends down into her neck.
  - **1.2.4:** **Shift+K** toggles rearing kisses on/off, with a message; the choice is remembered.
  - **1.2.5:** her muzzle bridge is kept off his eyes too (Canon and JRHNBR clipping); he straightens up within 2.5 s after a kiss regardless.
  - **1.2.6:** his body crouches with his view when he bends to her, so the camera doesn't sink into his own chest.
  - **1.2.7:** she tilts her head to a random side as she kisses, so her forehead passes beside his eyes.
- **v1.2.8 (2026-11-11):** with Horn Glow on, a unicorn's build-up lights the glow around her horn (and its hum) instead of the round disc of light.
- **Lab:** `tools/_kiss_lab/lab.tscn -- --mod-src kissing --who celestia --cases light,deep,refused` (`--scale N`, `--stage <bond>`, `--deep-hold N`, `--after N`, `--fp`, `--as-earth`, `--wingcam`, `--legcam --legdist N`, `--flip`, `--probe`..`--probe4`). Fake relationship runtime; Anon is a capsule with a fake desktop eye height on the real player's layers. Movies record audio. Renders in `renders/kissing/`. Leftover scratch file `tools/_kiss_lab/_hier.gd` (couldn't delete).
- **Unchecked:** full game, VR, Anon height settings, the mane 6 earth ponies' tails, the onlooker memory with the real AI.

### Fishing (`fishing-v0.4.1.pck`, v0.4.1, game 0.3.0)
- **What it does:** the river pier's fishing made readable: aimable cast (look up for far, about 13 m; down for close, about 3 m), a bigger float, a visible line, splashes and ripples, a nibble then a clear bite (float plunges, rod tip jerks, **Bite! Click to hook**, 3.5 s window, was 2.6), a tension bar while hooked, and the catch hanging on the line with a card (species, size, first catch / personal best). Left click keep, right click release.
- **Species:** trout, perch, carp, catfish, sunfish, each its own giftable item (tagged fish), picked by water type, depth and time of day. Best size, count and first catch (day, time, water) per species saved with the world (`Mods.state("fishing")`: `best`, `count`, `first`, `junk`, `bucket`).
- **Habitat:** the water's name says its type — `PonyvilleCanals` canal, `River_<id>_n` river, `Lake_<id>` lake, `Sea` (no fish). Chance = habitat × depth (water surface − ground) × time of day; weights in `species.json`. Canal/river/lake: trout .1/1/.3, perch .6/.6/1, carp 1/.4/.8, catfish .5/1/.6, sunfish 1/.2/.8. Catfish mostly at night, trout at dawn/dusk.
- **Fish models:** made in code, no outside art (`fish_model.gd`): smooth lofted bodies, soft colour bands, rounded fins, big cartoon eyes. Trout 40 cm, perch 30 cm, carp 55 cm, catfish 60 cm, sunfish 20 cm. Baked to `models/<id>.scn` for the items by `tools/_fish_lab/bake.gd`.
- **0.2.0:** sounds made in code (cast whoosh, reel clicks, plop and rod bell on a bite, wet flaps, a jingle for a first catch or best); putting the rod back with a fish on keeps it.
- **0.3.0:** the pier's bucket is a live well: up to 12 kept fish swim in it, saved with the world; look at it for the catch list; E takes the newest out into your free hand. Ponies' catches are the mod's species and go in it too.
- **0.3.1:** E with a fish in hand puts it back, and a fish dropped or thrown in swims too; the catch list no longer flickers; `[fishing]` log lines say why E didn't work. (The user's E problem was the wrong key; it works.)
- **0.4.0 (2026-11-11):**
  - **New pail:** the game's closed bucket model is hidden and replaced by a hollow wooden pail made in Blender (`tools/_fish_lab/pail.blend` → `pail.glb` → `models/pail.scn`): 38 cm tall, 30/36 cm across, 14 two-tone staves, two iron bands, a wire handle. Water at 25 cm inside (radius 14.8 cm); the pier's collision ring is unchanged; switched off, the game's bucket comes back. User: "a perfect pail".
  - **Rare fish:** golden carp (canal or lake, dawn to dusk, 1 in 60 carp) and moonlit catfish (night, `TimeOfDay.moon_lit_fraction()` ≥ 0.8, 1 in 5 catfish), from the same generator with a metallic sheen and a glow (`shine` in their specs). "Rare!" card, the longer jingle, items worth 40 and 35.
  - **Junk (1 bite in 12):** old sun hat (straw, ear holes; replaced a boot — no human boots in a pony world), tin can, lost horseshoe (kept: they land on the pier beside the bucket as items, `food:junk-<id>`); pond weed and stick (tossed back). Modelled in Blender: `tools/_fish_lab/junk.blend` → `junk_<id>.glb` → `models/<id>.scn` via `tools/_fish_lab/bake_pail.gd`.
  - **Angler's Log** (`angler_log.gd`, item `food:fishing-log`, tagged tool): a book on the deck by the rod rack while you don't own one; E takes it; held, left click opens a two-page book (turning picture via its own SubViewport world, best, count, first catch; silhouette and hint if uncaught, "???" for uncaught rares; a last page of odds and ends). A/D or wheel turns, click/E/Esc closes.
  - **Ponies** (`reactions.gd`): firsts, bests, rare, big (top 30% size) and junk catches are recorded to ponies within 10 m (`world_context.record("fishing", ...)`, at most every 45 s unless rare/best). A pony fishing with you (or one within 6 m, half the time, for notable catches) says a short no-AI line over her head via `world/ai/overhead_dialogue.gd` (as the mail courier does); companions announce their own catches. Fish fans: Big Mac, Spike and Fluttershy (for her animals) get "fish" added to their likes and Fluttershy's dislike lifted at runtime in `gifts.gd`'s `tastes()` table (a data merge can only append to lists), undone when the mod is switched off; the game's favour system can then have them ask for fish.
- **0.4.1 (2026-11-11):**
  - **Log:** the player's controls are locked (`player_body.controls_locked`) while the book is open, since walking polls the keys and A/D moved Anon as well as turning pages; unlocked on close, if the log leaves the hand, or when the mod stops.
  - **Ponies couldn't see the pier:** the game registers only the deck's centre (out over the canal) as an `ai_observable` landmark, so the line of sight from a pony on the bank is often blocked by the bank, and the rack and bucket aren't registered at all. The mod adds raised markers: "River fishing pier", "Rack of fishing rods", "Catch pail".
  - **AI lore** (`merge/world/ai/context_seeds.json`, id `fishing_pier`): the pier, rods anyone may borrow, the pail, the species and rare-fish rumours, and that a pony nearby or following Anon can join him fishing.
  - **Companions (game rules):** the game only invites a resident who is idle within 24 m of the pier's approach, or one following Anon, once he holds a rod; it skips ponies who are talking, in a social group, travelling or otherwise busy. Up to two at a time.
- **VR (untested):** the Angler's Log turns pages with the trigger on the hand holding it (a floating page appears above the book on the first pull). No other way to turn pages in VR yet; revisit if VR testing ever happens.
- **How:** entry script + `Mods.on_node` on the dock's rods; swaps `rod.line` (a plain RefCounted) for the mod's own line and reconnects its `caught`/`changed` signals. No script extensions. An input watcher node is kept last in the root so it hears clicks and keys before the game (the game scene is added after mods load).
- **Labs:** `tools/_fish_lab/lab.tscn -- --species <id>` (model renders to `renders/fishing/`); `tools/_fish_lab/cast.tscn` (real pier + canal water, no terrain — it needs the git-ignored `tools/gaea_study/`); `tools/_fish_lab/clip.tscn -- --mode bite|catch|drop|bucket|v04` (movie clips with the mod loaded; record with `--fixed-fps 30 --write-movie`, audio included).
- **Debug mod:** retired; its pack is in `mods/_to_delete/`. Old fishing packs 0.1.0–0.4.0 are there too.
- **Later:** fighting fish, hold-to-charge cast, portable rod, more piers (river, lake), weather. Models: carp scale texture; sunfish ear flap reads like a mouth; fin shading differs per side.
- **Unchecked:** VR; pony reactions, companions joining, and the fish fans asking for fish in the full game.
- **Seen in the user's log:** Sit Anywhere's `desktop_player.gd` extension doesn't compile over the game script (falls back to a full take-over).

### Horn Glow (`horn-glow-v1.1.0.pck`, v1.1.0, game 0.3.0)
- **What it does:** a unicorn's horn magic glows around the horn itself instead of as a round disc of light in front of it: the pony's magic colour, see-through in the middle and brightest at the edges, soft ripples and a rounded, flickering tip. Celestia and Luna glow along their own long horns.
- **Sound:** a gentle hum rises and fades with the glow, in place of the loud cast sparkle sound. The sparkles stay; things lifted with magic keep the game's usual aura.
- **1.1.0:** Kissing's build-up (1.2.8) and Idle Life's magic sparks (1.4.2) use the horn glow when it's on.

### Item Spawn (`item-spawn-v1.0.0.pck`, v1.0.0, game 0.3.0)
- **What it does:** adds `is` to the debug console and Settings → Debug: `is list [word]` lists items with ids and names; `is add <item> [count]` (id or name, up to 999) puts them straight into the briefcase. No match lists the 5 closest. Works alongside Teleport.
- **Limits:** stops when the briefcase is full (items on the ground still need a slot); books, letters and paintings are made per save, so only addable by exact id (e.g. `book:3`).

## Improvements

### Hooves don't bend when they should (Kissing, all hoof poses)
- The pastern/hoof bend (`pony_finger` −20° in the Blender rear, and the game's own curls) barely shows.
- To check: the hoof mesh's skin weights (`pony_finger` vs `pony_finger_*_end` vs `pony_hand`); the glTF bone axes on the hoof bones (their tails point sideways, so a bend "about X" may become a twist); whether the game's leg IK or terrain modifier overwrites the hoof angle afterwards.

### Blender on the game's rig (notes for any keyframed animation)
- Setting `pose_bone.matrix` on this rig adds scale (non-orthogonal rest matrices): reset `scale` and `location` after each set.
- glTF bone tails point sideways, so IK `use_tail` aims the wrong point: target the `*_end` bones' heads with `use_tail=False`.
- In renders, hide the mane (stiff rest pose); the horn and crown don't follow the head (the game drives them from the face rig).
- The second Blender (port 9877) is reached from the MCP-connected one (9876) by its addon's protocol: null-terminated JSON `{"type": "execute", "code": ..., "strict_json": true}`.
- **Props (Idle Life 1.4.0):** run `obj_import` inside `temp_override(window=...)`; on shared meshes scale the mesh data rather than `transform_apply`; render with the Standard view transform (AgX/Filmic wash out colours); export glb Y-up, then `godot --headless --import` to make the .import files.
- **Props (Fishing 0.4.0):** alternatively read the glb at bake time with `GLTFDocument.append_from_file` + `generate_scene` and save a `.scn` (no editor import needed); convert curve objects to meshes before export; `render_viewport_to_path` writes to /tmp, so render with `bpy.ops.render.render(write_still=True)` to a project path instead.

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

## Idea

### More princess idles (Idle Life)
- **Regal settle:** a mane shake, then draws herself up tall, chin raised, eyes half closed. No props.
- **Tea extras:** steam curling from the cup; tea for any unicorn, not just the princesses.
- **Luna:** a dream-scroll with a starry glow.

### Wedding
- **Marriage today:** in 0.3.0 marriage is a status change agreed in conversation (dating, then engagement after 3 dates, 50+ trust and 3 days, then marriage 1 day later). There's no ceremony.
- **The mod:** could add the wedding itself: a ceremony, rings, guests and a venue.
- **Rules:** adults only.

## Bugs to report

### Balloon: Celestia stops short of the ramp
- A following Celestia stopped outside the balloon's entrance in game. In a cut-down test she boarded fine, so the real cause is unconfirmed. A guess: her taller navigation clearance keeps her route away from the ramp. Balloon Boarding works around it.

### Princess open wings unfitted
- Celestia's and Luna's open-wing bones (`pony_WingBase_*`) weren't fitted with the rest of their bodies, so the open wings sit behind the shoulders and above the back. Princess Wings works around it.

### Princess mouth mount unfitted
- On Celestia, the body skeleton's `MOUNT_MOUTH` sits about 34 cm below her head (in her chest), so anything the game places at a princess's mouth will be wrong. The face rig's lip bones are right. Idle Life's tea uses those.

### Fishing gives almost no feedback
- The pier's fishing works, but the bite (6 cm dip, 2.6 s window) and the catch are nearly invisible, and the cast ignores aim: `cast()` uses only the camera's horizontal heading at a fixed speed, so every cast lands ~6–7 m out. Fishing mod works around it.

### Fishing pier hard for ponies to see
- `fishing_dock.gd` makes the dock itself the `ai_observable` landmark, so its point is the deck centre out over the canal; the awareness ray from a pony on the bank is often blocked by the bank. The rod rack and bucket aren't named for the AI, and no lore tells ponies about the pier. Fishing mod works around it (raised markers and a lore note).

### Kissing: the kisser's 1.8 m limit doesn't scale
- `player/pony_kisser.gd` ends any kiss once the pony's root is 1.8 m from Anon's eyes. At JRHNBR size and up her nose alone is further out than that, so the game's own kiss can end the moment it starts. Its 0.2 m pull-back check doesn't scale either. Kissing works around both.
- The game's supported rear in a kiss (affection_pose.gd `_rear_pose`) can stall: with Anon standing she keeps turning/stepping (`rear_step_ahead` stays above 0.025) and never rises.

## Local game changes (not in any mod)
- **`world/modding/mod_loader.gd` (2026-11-08):** `_mod_folders()` skips folders in `NOT_MODS` (`release_packs`), so `mods/release_packs/` isn't reported as a broken mod at every launch. A game update will overwrite it; worth suggesting to the developer. Original in `~/bak/game/` on the workspace.

## Notes for every mod
- **Safest hooks first:** prefer an entry script with `Mods` hooks, then JSON merges, then script extensions. Script extensions don't compile over the released game's compiled scripts.
- **Items via data:** items added through the food data need an `item_tags.json` merge (e.g. `"tool"`) so they don't count as food or gifts.
- **Data merges append to lists:** `deep_merge` adds a patch's arrays to the game's, so a merge can't remove anything (e.g. a pony's dislike). Patch the loaded table at runtime instead and undo it on exit.
- **Desktop first:** mods are made and tested for desktop; VR controls are attempted but not tested.
- **Foals:** no romance with foals, or when the player is one.
- **Sign-off:** every mod's `mod.json` author is modChad.
- **Packs:** named `<mod-name>-vX.Y.Z.pck` (e.g. `idle-life-v1.4.2.pck`), built by `mods/build_packs.sh` into `mods/release_packs/` (with a `.gdignore`), never left in the mod's own folder. Only the current version of each public mod stays in release_packs: move the old one out after a build. Debug and private packs never go there.
- **GitHub README:** `build_packs.sh` runs `mods/update_readme.py`, which sets the Version and Download cells in `mods/.github/README.md` (adding rows for new mods). Mods with `"private": true` in mod.json (e.g. Idle Life Debug) are left out. Each mod's README install line names the versioned pack too.
- **AI memory:** to let ponies know something happened, record it with `game.world_context.record(kind, text, witnesses, subjects)`; witness ids come from `game.director.characters`.
- **AI lore:** to teach ponies about something, add an entry to `merge/world/ai/context_seeds.json` under `lore` (`id`, `scope: "authored"`, `triggers`, `viewers` — empty for everyone — `priority`, `provenance`, `text`).
- **AI landmarks:** ponies see and can walk to Node3Ds in the `ai_observable` group with `ai_id` and `ai_label` metas (`pony_awareness.gd`, `place_directory.gd`); the point must have a clear line of sight from where ponies stand.
- **Ponies speaking without the AI:** `world/ai/overhead_dialogue.gd` — `new()`, `set_fallback_labels(null, null, name)`, set `text` and `caption_full`, add it to the tree, `show_for(pony, camera)`; free it after a few seconds (see `world/letters/courier/courier_swoop.gd` `say`).
- **AI consent:** to know what Anon just said to a pony, connect to `game.director.transcript(text)` and match it against the end of her last `"user"` entry in `director.characters[id].history` (the game prefixes notes to it).
- **Input order:** `_input` reaches later nodes first. The game scene is added after mods load, so a mod that must hear a key before the game keeps its input node last in the root (move it back each frame if needed).
- **Movement keys are polled:** consuming a WASD event doesn't stop Anon walking; lock `player_body.controls_locked` (and unlock afterwards) while a mod's own UI uses those keys.
- **Testing new animations:** the dev has given the user permission to bypass his rules (e.g. joint limits) when testing new animations.
- **Git:** pull only, never push, no commits.
