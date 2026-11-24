# Home: Equestria: bugs and local game changes

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

### Quest 3: FPS drops while making a fist (hoof grab scan)
- Player report 2026-11-12 (Quest 3 standalone, 0.3.0): fists closed → about 25 FPS drops to 17–19. Overlay in the video: frame 55–60 ms vs 44–47 ms, GPU unchanged (37–42 ms), physics up (27–60 ms vs 19–27 ms). CPU, not the hand shader (the cel shader has every extra feature off).
- Cause: `player/pony_hoof_grabber.gd` `process()` runs every physics tick per hand; with a full fist (grip + trigger, `_grip_pressed`) and nothing held it calls `hoof_hold.candidate()` on every pony registered with the grabber (`game_mare_wiring.gd` adds every spawned pony, ~47 in town). `candidate()` (`world/characters/locomotion/pony_hoof_hold.gd`) first runs `globals()`, a full-skeleton `FK.forward_kinematics` in GDScript, to test 4 legs against a 9 cm reach. No distance pre-check: ~2 × 47 × 60 ≈ 5,600 full FK passes a second with both fists.
- Suggested fix: skip ponies whose root is more than ~1.5–2 m from the hand before calling `globals()`. Grab Perf works around it.

### Quest 3: grabbing a pony's leg lays the player down
- Same report: grabbing a pony's leg (Trixie, near a picnic blanket) ended with the player lying down (blanket prompts "Sit up / Shift / Get up / Hold: Sleep"). The hoof grab goes `hoof_hold.candidate()` → `begin()`; `begin()` also tells a sitting/lying pony to stand. User's theory: the limbs' hard limits stop the leg, and a lie-down action triggers on the player's avatar. Player asked to retest with different pony sizes. Unconfirmed.

### Quest 3: Luna dream has no wake hint, then the game closed itself
- In the moon dream, B is push-to-talk and ignored on purpose (`luna_dream.gd`); waking is hold A for 1.5 s, but nothing on screen says so, and the picker before it shows "B · Stay awake".
- The same session: the picture froze at 15:57:51 (free memory ~600 MB), then at 15:57:56 the game ended its own OpenXR session cleanly (no script error, no system kill, "session not stopping"). Cause not in the logcat; needs the game's own log/support bundle.

### Quest 3: native crash while the town loads
- Failed start 2026-11-12: `SIGSEGV` (null pointer, fault addr 0x228) on Godot's `VkThread` at 15:43:06, while ponies were still spawning (3–7 FPS, ~570 MB free, the Quest killing other apps for memory). Stack has no symbols, so the exact cause isn't readable; memory pressure is a likely factor.

### Quest 0.3.0 APK missing the reading fonts
- `world/books/fonts/*` (Atkinson Hyperlegible, Literata, OpenDyslexic) left out of the APK, so a fresh install fails to parse `title_screen.gd:770` (`MENU_STYLE.BOLD`) and never starts the data download. Workaround APK: `APK/HomeEquestria-0.3.0-maredev-quest-fontfix.apk` (details in the project's `claude/quest-apk-fontfix.md`).

### Desktop: typing Q in the chat gets you up from a seat or bed
- `player/desktop_player.gd` `_physics_process` (seat branch) polls `Input.is_action_pressed("stand_up")` without checking `controls_locked`, so typing any word with a "q" while seated or lying stands Anon up (WASD there is guarded). Worked around by Typing Lock 1.0.0.

### Navigation: chunk corridor ignores roads
- `walk_planner.gd` `_chunk_corridor()` and the native coarse search (`navigation_ground.cpp` `coarse_step`) score every 16 m tile as 1, ignoring paint, trails, slope and water; the exact search then stays inside that band plus one tile, so a road just outside it is never used. The native intent's `use_corridor: false` turns it off. Pathfinding Fix works around it (open search for short routes, corridor fallback on budget).

### Navigation: detours grow slowly
- `walk_grid_service.gd` `_expand_route()` adds 12 tiles per failed search (each a full re-search) up to `ROUTE_CHUNKS` 128 and the zone bounds. Pathfinding Fix raises it (32/256 desktop, 24/128 Quest).

### Celestia can't enter standard houses
- `house_interior.gd` `fits()` assumes a 0.20 local (2.0 m at scale 10) doorway for every house and wants 0.1 m to spare; Celestia's clearance is 1.95 m (`princess_hybrid.gd`), so she never fits Fluttershy's cottage, Zecora's hut or generic homes. Pathfinding Fix lowers her clearance to 1.85 m. Better: measure each door's real height.

### Princess clearance overwrites size scaling
- `princess_hybrid.gd` `_ready` sets an unscaled 1.95 / 1.45 m clearance, undoing any `set_body_scale` done before it. Pathfinding Fix keeps it at base × body_scale.

### Avoidance agent keeps its spawn size
- `pony_navigator.gd` sets `agent.radius/height` once in `_ready`; `set_body_scale` (size preset, filly, stallion) never updates them. Pathfinding Fix syncs them every 0.5 s.

### Not yet checked in game (found in code)
- **Stairs:** flat treads with a riser over `step_height` (0.117 m, 0.073 m filly) are disconnected in `WalkGrid.connected()` unless the collider is a ramp.
- **Two floor spans:** `_sample_column` keeps any surface with `normal.y > .01` (steep roofs included) as a floor span; only Hayburger, Spa and lamps set `navigation_ceiling`, so a ground floor under two such surfaces is lost.
- **Far-pony clipping:** past Terrain3D's dynamic collision window, `pony_support_recovery.gd` holds ponies at heightmap + 0.02 while the visible clipmap is coarser at range (more so on Low/Very Low), so they float or sink.

## Local game changes (not in any mod)

- **`world/modding/mod_loader.gd` (2026-11-08):** `_mod_folders()` skips folders in `NOT_MODS` (`release_packs`), so `mods/release_packs/` isn't reported as a broken mod at every launch. A game update will overwrite it; worth suggesting to the developer. Original in `~/bak/game/` on the workspace.
