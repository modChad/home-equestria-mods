# Pathfinding Fix

By modChad. Version 1.0.0, for game 0.3.0.

Ponies pick better routes:

- **Roads and trails:** routes up to 200 m now search all loaded ground, so ponies follow a road
  instead of cutting across whatever lies on the straight line.
- **Detours:** going around rivers, lakes and buildings needs fewer retries and can reach further.
- **Size:** each pony's personal space (crowd avoidance) follows her size setting, filly or stallion.
- **Celestia:** her height allowance is 1.85 m (was 1.95 m), so she fits through ordinary house
  doors. Luna's stays 1.45 m. Both now scale correctly with the pony size setting.

Quest 3 (standalone) gets a lighter version: road-aware routes up to 80 m with a smaller search
budget, and the game's own detour limit. On the lowest quality tiers the game's routing stays.
Made for desktop; Quest support is attempted but not tested.

## Install

Put `pathfinding-fix-v1.0.0.pck` in your mods folder and start the game. Zones that were already
loaded when you switch it on pick up the route changes the next time they load.

## Notes

Routes over 200 m, or searches that run out of budget, fall back to the game's own method.
The longer searches use more CPU on a background thread.
