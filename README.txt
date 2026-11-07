Home: Equestria mods (made for game version 0.3.0-maredev)

packs/   ready-to-use .pck files: put them in the game's mods folder and switch each on in Settings -> Mods
source/  each mod's source folder (res://mods/<id>/), with its own README.md
MOD_IDEAS.md  the mod list: what's done, known bugs, and ideas for later
lab_tools/    test scenes for rendering and checking mods (unzip into the game folder as tools/; see LAB_README.md); not part of any mod

Mods:
  flowing_manes 1.0.0      Celestia's and Luna's manes and tails flow, with mood colours (settings under More)
  grooming 1.0.2           brushes and wing preening, with princess support (manes, tails, feathers)
  balloon_boarding 1.0.0   lets ponies board the hot air balloon instead of being pushed out
  teleport 1.0.0           teleport command with a list of locations
  princess_teleport 1.0.0  Celestia, Luna and Twilight can teleport you both to far places
  idle_life 1.0.0          ten new idle animations
  pegasus_ride_v2 2.2.1    ride a winged friend (princesses too); someone else's mod, adapted (see its CHANGES.md)

To rebuild a pack from source, copy its folder to res://mods/<id>/ in the game project and run:
  godot --headless --xr-mode off --path <project> --script res://tools/modding/build_mod.gd -- <id>
