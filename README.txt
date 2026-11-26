Home: Equestria mods by modChad (made for game version 0.3.1-maredev)

.github/README.md   the mod list with download links (shown on GitHub)
release_packs/      ready-to-use .pck files: put them in the game's mods folder and switch each on in Settings -> Mods
<mod folder>/       each mod's source (res://mods/<id>/), with its own README
retired/            mods merged into another mod or no longer released (source and last pack, not built)
MOD_IDEAS.md        what's done, what's next, and ideas
BUGS.md             game bugs to report, and local game changes
MODDING_NOTES.md    rules and how-tos for every mod
build_packs.sh      builds packs into release_packs/

Mods:
  anonfilly_patch 1.0.0     Anonfilly's mane and tail with far fewer triangles (needs Anonfilly 1.0.0)
  better_balloon 1.0.0      the hot-air balloon made for ponies: WASD flying, a lower basket, passengers who look out and chat (replaces balloon_boarding)
  briefcase_rescue 1.0.0    repairs briefcases and saves refused because of items from a removed mod
  fishing 0.7.1             readable pier fishing, rare fish and junk, the Angler's Log, a live-well pail
  flowing_manes 1.0.1       Celestia's and Luna's manes and tails flow, with mood colours
  grab_perf 1.0.0           stops the VR frame drop while your hands are clenched
  grooming 1.0.4            brushes and wing preening, princesses included
  dance_mod_patch 1.0.0     a typed "y" no longer starts or stops a dance (patch for the bundled Dance Mod 2.1.1)
  hair_lite 1.0.1           every pony's mane and tail with far fewer triangles, for Quest 3 framerates
  horn_glow 1.1.1           a unicorn's magic glows around the horn itself, with a soft hum
  idle_life 1.5.0           twenty-one idles, princess scroll, quill, tea, shoe, sun and moon, and mood reactions
  item_spawn 1.0.0          is list / is add debug commands to put any item in your briefcase
  kissing 1.2.12            hold K to kiss the pony in front of you (Shift+K toggles rearing)
  mod_reloader 1.0.0        "Reload from last save" in Settings -> Mods when a mod change needs a restart
  optimare 1.0.0            performance tweaks for the game's own models, for Quest 3 framerates
  pathfinding_fix 1.1.0     ponies pick better routes: roads, detours, doorways
  pegasus_ride_v2 2.2.1     ride a winged friend (princesses too); someone else's mod, adapted
  pin_the_tail 0.4.2        Pin the Tail on the Pony party game at Sugarcube Corner
  princess_teleport 1.2.0   Celestia, Luna and Twilight teleport you both to far places, when you ask (English or Russian)
  princess_wings 1.0.0      Celestia's and Luna's open wings on their shoulder blades
  russian_ponies 1.0.0      ponies understand Russian and always answer in Russian
  teleport 1.0.0            places and tp debug commands

To build a pack, from the game project:
  mods/build_packs.sh <id>      (or no id for all)
It writes mods/release_packs/<name>-v<version>.pck.
