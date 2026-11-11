# Idle Life

- **Version:** 1.4.2
- **By:** modChad
- **Made for:** Home: Equestria 0.3.0-maredev
- **Works on:** desktop and VR (nothing to press)

Ponies standing about now and then do one of sixteen new idles, alongside the game's own stretches, yawns and hoof lifts.

## The idles

| Idle | Who | What she does |
| --- | --- | --- |
| **Stretch** | Everypony | Tips forward into a long stretch, rump up, forehooves sliding out. Half the time a light stretch inside her joint limits, half the time a deeper one. Pegasi spread their wings out at about 45° with a little flutter. |
| **Pawing the ground** | Everypony | Lifts a forehoof and scrapes it back three times, head low watching it. |
| **Look round** | Everypony | Ears prick up, then she turns to look at something, a curious tilt, a second glance and back. |
| **Wing stretch** | Pegasi | Opens her wings and reaches one up and back with a quiver, then the other, head turned away to give each room. |
| **Wing preen** | Pegasi | Lies down or sits, brings one wing round to her muzzle and licks along the feathers. |
| **Magic brush** | Unicorns and alicorns | A brush floats up in her magic (the same aura colour as her horn) and brushes her fringe, eyes half closed. Celestia and Luna brush the big swoop of mane beside their face. |
| **Magic sparkle** | Unicorns and alicorns | Her horn lights and little bursts of sparkles drift up from it while she watches with a smile. |
| **Dozing** | Everypony, at night | Head slowly sinks, eyes close, a hind hoof cocked to rest. She catches herself with a little start, then settles back up. |
| **Stargazing** | Everypony, at night | Sits down, tips her head back to the sky and lets her gaze drift from star to star, blinking slowly. |
| **Reading a scroll** | Celestia and Luna | Her horn lights and a scroll appears in a flash of her magic: chunky rollers (gold for Celestia, silver and navy for Luna) and plain parchment with looping lines of writing. It unrolls and she reads it, eyes following the lines, then gives a little smile and nod, rolls it up and makes it vanish. |
| **Writing a scroll** | Celestia and Luna | A blank scroll, a quill and an inkwell appear in her magic (Celestia: red quill, gold inkwell; Luna: blue quill, silver inkwell). The quill dips into the ink before each line, writes three lines and a signature with a flourish, the ink appearing behind the nib; she nods and makes them vanish. |
| **Tea** | Celestia and Luna | Her own tea set appears (Celestia: white and gold with a sun; Luna: night blue and silver with a crescent). The cup comes up to her lips for two sips, eyes closed, then she smiles, sets it back on the saucer and both vanish. |
| **Shoe check** | Celestia and Luna | Lifts her left forehoof, slides the shoe off in her magic, swings it out and up beside her muzzle, turns it over and shakes out a pebble, then puts it back on. |
| **Tending the sun** | Celestia, at sunrise and sunset | Flies up about 1.5 m, turns to face the sun and lights her horn with sparkles rising toward it, then lands. |
| **Checking the moon** | Luna, at moonrise and moonset | The same for Luna and the moon, on nights with at least a quarter of the moon lit. |

Each one plays on either side at random (the magic brush goes to whichever side her fringe sweeps).

## When they happen

- **Who:** every pony. The game's own test for its fidgets decides when one may play: standing settled, going about her own day, not being talked to, touched, held or led, awake, and drawn in full detail.
- **How often:** roughly every 18–45 seconds per pony, never the same idle twice in a row and never on top of one of the game's own fidgets.
- **Night:** dozing and stargazing only happen from a little before sunset to a little after sunrise.
- **Interrupting:** talk to her, touch her or call her away and the idle fades out within half a second (one that sat or lay her down stands her back up).

## Install

Put `idle-life-v1.4.2.pck` in the game's `mods` folder and switch it on in **Settings → Mods**.

## Things to know

- Every movement stays inside the game's own joint limits, except the deep stretch's forelegs, which reach a little further so the hooves stay on the ground.
- The magic brush skips ponies without a fringe or who wouldn't brush one: King Sombra, Tempest Shadow, Shining Armor, Prince Blueblood, Jackpot, Night Light, Silver Spanner, Comet Tail and Pokey Pierce.
- The wing preen and wing stretch skip Celestia and Luna for now: the game's open wings don't fit their bodies yet.
- The tea sets, scroll rollers, quills and inkwells are small models (about 440 triangles a tea set, under 750 a scroll set). The parchment and its writing are drawn by the mod: looping lines, not real text.
- The shoe check takes off the princess's own shoe: her body mesh is swapped for a copy without that shoe while it's off, and her own is put back after.
- The sun and moon checks use the game's own flight to take off, hover and land. While she's up, only being spoken to or held cuts it short.
- Tea finds her lips from her face rig: the princesses' body `MOUNT_MOUTH` is in the wrong place (a game bug).
- Everything scales with the pony's size.
- **Remembered:** the scroll, writing, tea, shoe check, sun, moon and dozing off are written to the game's memory of witnessed events about halfway through (one line, e.g. "Princess Celestia conjured a scroll with her magic, read it through and made it vanish again."), for the pony herself and AI ponies within 10 m. At most one per pony every 3 minutes. Ponies can then mention it in conversation.
- Switching the mod off hands back anything it was holding (eyes, ears, mouth, wings, magic, gaze).

## Changes

- **1.4.2:** With the Horn Glow mod, the sparks leaving her horn (magic sparkle, sun and moon) are quiet puffs of sparkles, with no round disc or cast sound. Her horn itself glows the Horn Glow way.

- **1.4.1 (2026-11-11):** the scroll floats further out (45 cm ahead, a little higher and 10 cm to her left) and the inkwell further out from her, clear of Flowing Manes' fuller manes.
- **1.4.0 (2026-11-10):** modelled tea sets, scroll rollers, quills and inkwells, one set for Celestia and one for Luna; the quill now dips into an inkwell before each line (writing takes 13.6 s); show-style parchment and writing.
- **1.3.0 (2026-11-08):** nearby ponies (and the pony herself) remember the notable idles, so they can talk about them.
- **1.2.0 (2026-11-08):** new idles for Celestia and Luna: writing a scroll, tea, the shoe check; tending the sun (Celestia) and checking the moon (Luna). The scroll's head sway is gentler.
- **1.1.0 (2026-11-08):** new idle: reading a scroll (Celestia and Luna). The stretch's neck no longer lifts, so her head sits lower.
- **1.0.0 (2026-11-06):** ten idles.
