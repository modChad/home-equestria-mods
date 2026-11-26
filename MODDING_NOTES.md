# Home: Equestria: notes for every mod

## Rules and how-tos

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
- **Typing:** game 0.3.1 empties the InputMap of gameplay keys while a text field has focus (`world/ui/typing_guard.gd`; Typing Lock retired). Raw key checks (`Input.is_key_pressed`, `physical_keycode`) still fire: guard them with `preload("res://world/ui/typing_guard.gd").active()`. For someone else's mod, patch it (mod.json `patches` + `extends`, like `pegasus_ride_v2_patch` and Dance Mod fixes). Headless checks with `--path` load the player's installed packs too (`user://mods`).
- **Headless checks:** in a `--script` SceneTree, autoloads (e.g. `Mods`) aren't there yet in `_init`; `await process_frame` first.
- **Testing new animations:** the dev has given the user permission to bypass his rules (e.g. joint limits) when testing new animations.
- **Docs:** after a build, update the mod's line in MOD_IDEAS.md and its notes in the project (`mods/notes/<id>.md`); game bugs go in BUGS.md, general lessons here.
- **Git:** pull only, never push, no commits.

## Blender on the game's rig

- Setting `pose_bone.matrix` on this rig adds scale (non-orthogonal rest matrices): reset `scale` and `location` after each set.
- glTF bone tails point sideways, so IK `use_tail` aims the wrong point: target the `*_end` bones' heads with `use_tail=False`.
- In renders, hide the mane (stiff rest pose); the horn and crown don't follow the head (the game drives them from the face rig).
- The second Blender (port 9877) is reached from the MCP-connected one (9876) by its addon's protocol: null-terminated JSON `{"type": "execute", "code": ..., "strict_json": true}`.
- **Props (Idle Life 1.4.0):** run `obj_import` inside `temp_override(window=...)`; on shared meshes scale the mesh data rather than `transform_apply`; render with the Standard view transform (AgX/Filmic wash out colours); export glb Y-up, then `godot --headless --import` to make the .import files.
- **Props (Fishing 0.4.0):** alternatively read the glb at bake time with `GLTFDocument.append_from_file` + `generate_scene` and save a `.scn` (no editor import needed); convert curve objects to meshes before export; `render_viewport_to_path` writes to /tmp, so render with `bpy.ops.render.render(write_still=True)` to a project path instead.

## Joint limits (pony rig)

- **Where:** `world/characters/locomotion/pony_joint_limits.gd`, on each pony as `joint_limits` (`constrain(bone, basis)`; runs in C++ through `native/pony_solver` when that loads). Any bone turn a mod makes through it is clamped, so a turn past a limit silently does little or nothing.
- **How they're made:** not hand-set. For each leg, spine, neck and head bone, the hinge axis and range come from the game's own animation clips (the largest bend in them, plus 5°; plus 3° of sideways "swing"). Then floors: shoulder/flank at least −28..35°, upperArm/femur at least −45..35°, spine at least −8..8°, neck/head at least −30..30° with 28° swing. A bend the clips never make (e.g. a joint bent the "wrong" way) is clamped to about 5°.
- **Measured (Twilight, right side, degrees, about the bone's hinge axis, roughly the model's +X; the sign versus Idle Life's "pitch" is not yet confirmed):**

  | Bone | Lower | Upper | Swing |
  |---|---|---|---|
  | shoulder | −28 | 35 | 18 |
  | upperArm | −45 | 35 | 20 |
  | lowerArm | −15 | **94** | 12 |
  | wrist | −71 | 8 | 11 |
  | hand | −89 | 8 | 15 |
  | finger | −75 | 20 | 19 |
  | flank | −31 | 35 | 23 |
  | femur | −45 | 35 | 18 |
  | tibia | −27 | 34 | 15 |
  | legLower | −15 | 70 | 9 |
  | tarsal | −76 | 5 | 5 |
  | hoof | −48 | 5 | 21 |
  | spine1 | −11 | 32 | 6 |
  | neck1, head | −30 | 30 | 28 |

- **Lesson (Idle Life tippy-taps, 2026-11-23):** a foreleg lift with lowerArm at −34° only raised the hoof ~1 cm, most likely because lowerArm only bends to −15° that way; its big bend is the other way (+94°). Idle Life's paw idle may have the same problem (lowerArm −22..−32°; its hoof only lifts ~6 cm). Check a joint's range before posing it.
- **Re-measure:** `tools/_il_lab/limits.tscn` prints the limits (`xvfb-run godot --xr-mode off --path . res://tools/_il_lab/limits.tscn | grep ^LIM`). Idle Life's lab `--soles` prints hoof heights to check a lift.
- **Bypassing:** Idle Life's `idle_pose.gd` `_turn(..., free = true)` skips the limits (used for the deep stretch). Per the note above, the dev allows bypassing them when testing new animations.
