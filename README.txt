Home: Equestria mods by modChad (made for game version 0.3.0-maredev)

.github/README.md   the mod list with download links (shown on GitHub)
release_packs/      ready-to-use .pck files: put them in the game's mods folder and switch each on in Settings -> Mods
<mod folder>/       each mod's source (res://mods/<id>/), with its own README
MOD_IDEAS.md        what's done, what's next, and ideas
BUGS.md             game bugs to report, and local game changes
MODDING_NOTES.md    rules and how-tos for every mod
build_packs.sh      builds packs into release_packs/

Mods:
  grooming 1.0.3            brushes and wing preening, princesses included
  flowing_manes 1.0.0       Celestia's and Luna's manes and tails flow, with mood colours
  idle_life 1.4.2           sixteen new idles, plus princess scroll, quill, tea, shoe, sun and moon idles
  princess_wings 1.0.0      Celestia's and Luna's open wings on their shoulder blades
  princess_teleport 1.1.0   Celestia, Luna and Twilight teleport you both to far places, when you ask
  balloon_boarding 1.0.0    ponies stay aboard the hot-air balloon
  teleport 1.0.0            places and tp debug commands
  pegasus_ride_v2 2.2.1     ride a winged friend (princesses too); someone else's mod, adapted
  fishing 0.4.1             readable pier fishing, rare fish and junk, the Angler's Log, a live-well pail
  kissing 1.2.8             hold K to kiss the pony in front of you (Shift+K toggles rearing)
  horn_glow 1.1.0           a unicorn's magic glows around the horn itself, with a soft hum
  item_spawn 1.0.0          is list / is add debug commands to put any item in your briefcase

To build a pack, from the game project:
  mods/build_packs.sh <id>      (or no id for all)
It writes mods/release_packs/<name>-v<version>.pck.
