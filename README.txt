Home: Equestria mods by modChad (made for game version 0.3.0-maredev)

.github/README.md   the mod list with download links (shown on GitHub)
release_packs/      ready-to-use .pck files: put them in the game's mods folder and switch each on in Settings -> Mods
<mod folder>/       each mod's source (res://mods/<id>/), with its own README
MOD_IDEAS.md        what's done, known bugs, and ideas for later
build_packs.sh      builds packs into release_packs/

Mods:
  grooming 1.0.3            brushes and wing preening, princesses included
  flowing_manes 1.0.0       Celestia's and Luna's manes and tails flow, with mood colours
  idle_life 1.4.0           sixteen new idles, plus princess scroll, quill, tea, shoe, sun and moon idles
  princess_wings 1.0.0      Celestia's and Luna's open wings on their shoulder blades
  princess_teleport 1.1.0   Celestia, Luna and Twilight teleport you both to far places, when you ask
  balloon_boarding 1.0.0    ponies stay aboard the hot-air balloon
  teleport 1.0.0            places and tp debug commands
  pegasus_ride_v2 2.2.1     ride a winged friend (princesses too); someone else's mod, adapted
  fishing 0.3.1             readable pier fishing, five species, a live-well bucket
  kissing 1.2.0             hold K to kiss the pony in front of you

To build a pack, from the game project:
  mods/build_packs.sh <id>      (or no id for all)
It writes mods/release_packs/<name>-v<version>.pck.
