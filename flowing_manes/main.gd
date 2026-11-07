extends Node
## Flowing Manes: Princess Celestia's and Princess Luna's manes and tails flow like in the show.
##
## The princesses' hair is part of their body model (princesses/<id>_body.glb): a mane mesh rigid
## on the head bone and a tail mesh on the five body tail bones, each with its own material, whose
## texture v runs from root to tip. This mod
##   - swaps those two meshes' materials for flowing copies of the game's own cel and outline
##     shaders (wave_shader.gd): a travelling wave root -> tip, plus twinkling sparkles (Celestia)
##     or slowly drifting stars (Luna);
##   - adds a gentle travelling sway to the five tail bones (tail_sway.gd).
## No game file is replaced. Switching the mod off restores the original materials at once.

const PRINCESS := "res://world/characters/princesses/princess_hybrid.gd"
const SHADERS := preload("res://mods/flowing_manes/wave_shader.gd")
const SWAY := preload("res://mods/flowing_manes/tail_sway.gd")
const FADE_SECONDS := 1.5
const CHECK_EVERY := 0.5

## Per princess at the "show" preset: wave amplitude as a share of the hair's length, speed
## (cycles/s), waves along a strand, sparkles (strength, colour, drift along the strand per second,
## cells across x along) and, for Luna, the see-through glowing edge (glow.gdshader) in place of
## the outline: colour with alpha, width as a share of the hair's length, tip fade.
const LOOKS := {
	"celestia": {
		"mane": {"amp": 0.085, "speed": 0.4, "waves": 1.4, "sparkle": 1.3, "color": Color(1.0, 0.98, 0.92), "drift": 0.0, "cells": Vector2(12, 18)},
		"tail": {"amp": 0.06, "speed": 0.36, "waves": 1.2, "sparkle": 1.1, "color": Color(1.0, 0.98, 0.92), "drift": 0.0, "cells": Vector2(10, 16)},
	},
	"luna": {
		"mane": {"amp": 0.1, "speed": 0.34, "waves": 1.3, "sparkle": 1.5, "color": Color(0.85, 0.92, 1.0), "drift": 0.35, "cells": Vector2(16, 20),
			"glow": Color(0.68, 0.52, 1.0, 0.6), "glow_width": 0.05, "tip_fade": 0.4},
		"tail": {"amp": 0.075, "speed": 0.31, "waves": 1.1, "sparkle": 1.4, "color": Color(0.85, 0.92, 1.0), "drift": 0.3, "cells": Vector2(14, 18),
			"glow": Color(0.68, 0.52, 1.0, 0.6), "glow_width": 0.05, "tip_fade": 0.4},
	},
}
## Presets scale the look: wave size, speed, sparkles, Luna's glow.
const PRESETS := {
	"subtle": {"amp": 0.5, "speed": 0.85, "sparkle": 0.7, "glow": 0.7},
	"show": {"amp": 1.0, "speed": 1.0, "sparkle": 1.0, "glow": 1.0},
	"dramatic": {"amp": 1.6, "speed": 1.15, "sparkle": 1.3, "glow": 1.3},
}
const SETTINGS_UI := preload("res://mods/flowing_manes/settings_ui.gd")
const ID := "flowing_manes"
## Player settings (Settings > Graphics > Flowing Manes), kept per player, not per world.
const DEFAULTS := {"celestia": true, "luna": true, "emotions": true, "celestia_colour": true, "luna_colour": true, "daybreaker": true, "preset": "show", "motion": 1.0, "speed": 1.0, "sparkle": 1.0, "glow": 1.0}

## Feelings -> how the hair behaves (multipliers on the look, plus extras). `fire` is Celestia's
## solar flare (Daybreaker) and Luna's night (Nightmare Moon) when she is angry.
const MOODS := {
	"neutral": {"amp": 1.0, "speed": 1.0, "turb": 0.0, "sag": 0.0, "dim": 1.0, "tint": Color(1, 1, 1), "glow": 0.0, "fire": 0.0, "sparkle": 1.0},
	"happy": {"amp": 1.2, "speed": 1.2, "turb": 0.05, "sag": 0.0, "dim": 1.0, "tint": Color(1, 1, 1), "glow": 0.55, "fire": 0.0, "sparkle": 2.4},
	"calm": {"amp": 0.9, "speed": 0.8, "turb": 0.0, "sag": 0.1, "dim": 1.0, "tint": Color(1, 0.97, 0.93), "glow": 0.15, "fire": 0.0, "sparkle": 1.25},
	"sad": {"amp": 0.5, "speed": 0.5, "turb": 0.0, "sag": 1.0, "dim": 0.72, "tint": Color(0.78, 0.82, 0.94), "glow": 0.0, "fire": 0.0, "sparkle": 0.2},
	"fear": {"amp": 0.6, "speed": 0.9, "turb": 0.35, "sag": 0.6, "dim": 0.7, "tint": Color(0.8, 0.82, 0.92), "glow": 0.0, "fire": 0.0, "sparkle": 0.4},
	"surprised": {"amp": 1.5, "speed": 1.6, "turb": 0.2, "sag": 0.0, "dim": 1.0, "tint": Color(1, 1, 1), "glow": 0.3, "fire": 0.0, "sparkle": 1.6},
	"annoyed": {"amp": 1.1, "speed": 1.4, "turb": 0.35, "sag": 0.0, "dim": 0.85, "tint": Color(1, 0.82, 0.68), "glow": 0.0, "fire": 0.3, "sparkle": 1.0},
	"angry": {"amp": 1.35, "speed": 1.9, "turb": 0.75, "sag": 0.0, "dim": 0.42, "tint": Color(1, 0.5, 0.3), "glow": 0.0, "fire": 1.2, "sparkle": 1.2},
	"rage": {"amp": 1.5, "speed": 2.3, "turb": 0.8, "sag": 0.0, "dim": 0.32, "tint": Color(1, 0.5, 0.25), "glow": 0.0, "fire": 1.35, "sparkle": 1.4},
}
## The game's face names (pony_dialogue_tags.gd) and moods (pony_impressions.gd) -> MOODS.
const FEELINGS := {
	"happy": "happy", "delighted": "happy", "silly": "happy", "affectionate": "happy", "anticipation": "happy",
	"relaxed": "calm", "amused": "calm", "crookedsmile": "calm", "shy": "calm",
	"sad": "sad", "pain": "sad", "fearful": "fear", "disgusted": "fear", "surprised": "surprised",
	"annoyed": "annoyed", "angersmug": "annoyed", "suspicious": "annoyed", "angry": "angry", "ponyrage": "rage",
}
## Luna's night when angry: her hair darkens, her stars blaze and her rim turns icy.
const NIGHT_TINT := Color(0.6, 0.62, 0.85)
const NIGHT_RIM := Color(0.45, 0.75, 1.0, 0.8)
## Movement: metres of trail per m/s of walking and per rad/s of turning, its cap, its lag (s).
const TRAIL_WALK := 0.1
const TRAIL_TURN := 0.12
const TRAIL_MAX := 0.35
const TRAIL_LAG := 0.35
const MOOD_EASE := 0.7
const FEEL_EVERY := 0.25
var config: Dictionary = DEFAULTS.duplicate()
var _ui: RefCounted

## pony -> {surfaces: [{mi, index, original, flowing}], sway, amount, target}
var _ponies: Dictionary = {}
var _check := 0.0
## 0..1 for every princess; tools and other mods can lower it (set_strength).
var strength := 1.0


func _ready() -> void:
	add_to_group("flowing_manes")
	_load_config()
	Mods.on_node(PRINCESS, _track)
	_ui = SETTINGS_UI.new(self)
	Mods.on_node("res://world/ui/settings_page.gd", _ui.attach)


func defaults() -> Dictionary:
	return DEFAULTS.duplicate()


func _config_path() -> String:
	return Mods.data_folder(ID).path_join("settings.cfg")


func _load_config() -> void:
	var file := ConfigFile.new()
	if file.load(_config_path()) != OK: return
	for key: String in DEFAULTS:
		var value: Variant = file.get_value("flowing_manes", key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int): config[key] = value
	if not PRESETS.has(str(config.preset)): config.preset = "show"


## Changes one setting, saves it and re-dresses every princess at once.
func set_setting(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or config.get(key) == value: return
	config[key] = value
	var file := ConfigFile.new()
	for k: String in config: file.set_value("flowing_manes", k, config[k])
	DirAccess.make_dir_recursive_absolute(Mods.data_folder(ID))
	file.save(_config_path())
	for pony: Variant in _ponies.keys():
		if is_instance_valid(pony): _apply(pony)


func _enabled(pony: Node) -> bool:
	return bool(config.get(_id(pony), true))


func _track(pony: Node) -> void:
	if _ponies.has(pony) or not pony is Node3D: return
	_ponies[pony] = {"surfaces": [], "sway": null, "amount": 0.0, "clock": randf() * 10.0, "mood": MOODS.neutral.duplicate(),
		"feeling": "neutral", "raw": "neutral", "flame": 0.0, "feel_check": 0.0, "forced": "", "last_pos": Vector3.INF, "last_yaw": 0.0, "trail": Vector3.ZERO, "turn": 0.0}
	pony.tree_exiting.connect(_forget.bind(pony), CONNECT_ONE_SHOT)
	_apply(pony)


func _forget(pony: Node) -> void:
	_ponies.erase(pony)


func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 1.0)


## "subtle", "show" or "dramatic".
func set_preset(name: String) -> void:
	if PRESETS.has(name): set_setting("preset", name)


func _process(delta: float) -> void:
	_check -= delta
	var recheck := _check <= 0.0
	if recheck: _check = CHECK_EVERY
	for pony: Variant in _ponies.keys():
		if not is_instance_valid(pony): _ponies.erase(pony); continue
		var row: Dictionary = _ponies[pony]
		# A re-dress (shading version, rebuilt model) puts the game's materials back.
		if recheck and _enabled(pony) and _needs_apply(row): _apply(pony)
		var far: bool = pony.get(&"sim_tier") != null and int(pony.get(&"sim_tier")) >= 2
		var goal := 0.0 if far else strength
		row.amount = move_toward(float(row.amount), goal, delta / FADE_SECONDS)
		if row.surfaces.is_empty() and not is_instance_valid(row.sway): continue
		_feel(pony, row, delta)
		_move(pony, row, delta)
		_drive(pony, row)


## Her feeling now: the face she is speaking with, else her lingering mood toward Anon, eased.
func _feel(pony: Node3D, row: Dictionary, delta: float) -> void:
	row.feel_check = float(row.feel_check) - delta
	if float(row.feel_check) <= 0.0:
		row.feel_check = FEEL_EVERY
		row.raw = _raw_feeling(pony, row)
		row.feeling = row.raw if bool(config.get("emotions", true)) else "neutral"
	var goal: Dictionary = MOODS.get(row.feeling, MOODS.neutral)
	var t := 1.0 - exp(-delta / MOOD_EASE)
	# Daybreaker has her own switch: her anger can set her mane alight even with emotions or mood
	# colours off.
	var flame := 0.0
	if _id(pony) == "celestia" and bool(config.get("daybreaker", true)):
		flame = float(MOODS.get(row.raw, MOODS.neutral).fire)
	row.flame = lerpf(float(row.flame), flame, t)
	var mood: Dictionary = row.mood
	for key: String in goal:
		if goal[key] is Color: mood[key] = (mood[key] as Color).lerp(goal[key], t)
		else: mood[key] = lerpf(float(mood[key]), float(goal[key]), t)
	row.clock = float(row.clock) + delta * float(mood.speed)


## What she feels (a forced feeling first), whatever the emotion settings say.
func _raw_feeling(pony: Node, row: Dictionary) -> String:
	if not str(row.forced).is_empty(): return str(FEELINGS.get(row.forced, row.forced)) if MOODS.has(FEELINGS.get(row.forced, row.forced)) else "neutral"
	var face := ""
	var expressions: Variant = pony.get("expressions")
	if expressions != null and expressions.get("dialogue_face") != null: face = str(expressions.get("dialogue_face"))
	if face.is_empty():
		var game: Node = Mods.game
		var context: Variant = game.get("world_context") if is_instance_valid(game) else null
		var impressions: Variant = context.get("impressions") if context != null else null
		var id := str(pony.get_meta("relationship_id", ""))
		if impressions != null and is_instance_valid(impressions) and not id.is_empty() and impressions.has_method("profile"):
			var profile: Variant = impressions.call("profile", id)
			if profile is Dictionary: face = str((profile as Dictionary).get("mood", ""))
	return str(FEELINGS.get(face, "neutral"))


## For tools and other mods: show a feeling ("" returns to her own).
func force_feeling(pony: Node, name: String) -> void:
	if _ponies.has(pony): _ponies[pony].forced = name


## Movement: the hair streams back as she walks and swings out as she turns, with a little lag.
func _move(pony: Node3D, row: Dictionary, delta: float) -> void:
	var at := pony.global_position
	var yaw := pony.global_rotation.y
	if not Vector3(row.last_pos).is_finite() or delta <= 0.0:
		row.last_pos = at; row.last_yaw = yaw; return
	var velocity := (at - Vector3(row.last_pos)) / delta
	var turn := wrapf(yaw - float(row.last_yaw), -PI, PI) / delta
	row.last_pos = at; row.last_yaw = yaw
	velocity.y = 0.0
	if velocity.length() > 8.0: velocity = Vector3.ZERO   # a teleport, not a step
	var goal := (-velocity * TRAIL_WALK + pony.global_basis.x * turn * TRAIL_TURN).limit_length(TRAIL_MAX)
	var t := 1.0 - exp(-delta / TRAIL_LAG)
	row.trail = Vector3(row.trail).lerp(goal, t)
	row.turn = lerpf(float(row.turn), clampf(turn, -3.0, 3.0), t)


## The viewer's head: the active camera (desktop) or the headset's centre (VR, one point for both
## eyes, so the hair matches in each eye).
func _viewer() -> Vector3:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	return camera.global_position if camera != null else Vector3.INF


## Her skull centre, nose tip and skull radius in world space (from her boop node, which tracks the
## real head), or {} when she has none.
func _head(pony: Node3D) -> Dictionary:
	var boop: Variant = pony.get("boop_node")
	if boop == null or not is_instance_valid(boop) or not boop.has_method("skull_world") or not boop.has_method("nose_world"): return {}
	var skull: Vector3 = boop.call("skull_world")
	var nose: Vector3 = boop.call("nose_world")
	if not skull.is_finite() or not nose.is_finite(): return {}
	var radius := 0.09
	var r: Variant = boop.get("SKULL_RADIUS")
	var head_skeleton: Variant = boop.get("head_skeleton")
	if r != null and head_skeleton is Node3D:
		radius = float(r) * maxf((head_skeleton as Node3D).global_basis.get_scale().x, 0.01)
	return {"skull": skull, "nose": nose, "radius": radius}


## Pushes clock, mood and trail into every flowing material and the tail sway.
func _drive(pony: Node3D, row: Dictionary) -> void:
	var mood: Dictionary = row.mood
	var head := _head(pony)
	var luna := _id(pony) == "luna"
	var fire := float(mood.fire)
	var tint: Color = mood.tint
	var dim := float(mood.dim)
	var sparkle := float(mood.sparkle)
	if luna:
		fire = minf(fire, 1.0)
		# Her anger is night, not flame: darker hair, blazing stars, an icy rim.
		tint = Color(1, 1, 1).lerp(NIGHT_TINT, fire)
		dim = lerpf(dim, 0.85, minf(1.0, fire * 1.5))
		sparkle *= 1.0 + 1.2 * fire
	# Colour changes switched off for her: the hair still moves with her feelings, in her own colours.
	if not bool(config.get(_id(pony) + "_colour", true)):
		fire = 0.0; tint = Color(1, 1, 1); dim = 1.0
	var glow_amt := float(mood.glow) if bool(config.get(_id(pony) + "_colour", true)) else 0.0
	if not luna:
		var angry: Dictionary = MOODS.angry
		if bool(config.get("daybreaker", true)):
			# The flame, with the angry colouring under it, however the other switches are set.
			var ft := clampf(float(row.flame) / float(angry.fire), 0.0, 1.0)
			fire = float(row.flame)
			tint = tint.lerp(angry.tint, ft)
			dim = lerpf(dim, float(angry.dim), ft)
		else:
			# No flame: her anger only warms and dulls her colours a little.
			var soften := 0.8 * clampf(float(mood.fire) / float(angry.fire), 0.0, 1.0)
			fire = 0.0
			tint = tint.lerp(Color(1, 1, 1), soften)
			dim = lerpf(dim, 1.0, soften)
	# Faded out (far away, lowered strength): her own colours come back with the motion.
	var amount := clampf(float(row.amount), 0.0, 1.0)
	tint = Color(1, 1, 1).lerp(tint, amount)
	dim = lerpf(1.0, dim, amount)
	for surface: Dictionary in row.surfaces:
		var mat: ShaderMaterial = surface.flowing
		var base: Dictionary = mat.get_meta("fm_base", {})
		if base.is_empty(): continue
		var mi: MeshInstance3D = surface.mi
		var trail := Vector3.ZERO
		if is_instance_valid(mi): trail = mi.global_basis.inverse() * Vector3(row.trail)
		var shared := {"fm_amount": row.amount, "fm_clock": row.clock, "fm_amp": float(base.amp) * float(mood.amp),
			"fm_turb": mood.turb, "fm_sag": mood.sag, "fm_trail": trail, "fm_head_r": 0.0}
		if surface.get("part") == "mane" and not head.is_empty() and is_instance_valid(mi):
			var to_mesh := mi.global_transform.affine_inverse()
			shared.fm_head_c = to_mesh * Vector3(head.skull)
			shared.fm_nose = to_mesh * Vector3(head.nose)
			shared.fm_head_r = float(head.radius) / maxf(mi.global_basis.get_scale().x, 0.0001)
			var viewer := _viewer()
			shared.fm_view = to_mesh * viewer if viewer.is_finite() else to_mesh * (Vector3(head.nose) + (Vector3(head.nose) - Vector3(head.skull)) * 100.0)
		for key: String in shared: mat.set_shader_parameter(key, shared[key])
		mat.set_shader_parameter("fm_sparkle", float(base.sparkle) * sparkle)
		mat.set_shader_parameter("fm_glow_amt", glow_amt)
		mat.set_shader_parameter("fm_fire", 0.0 if luna else fire)
		# Both the lit colour and the cel shader's shadow band (which it uses on the shaded side).
		for key: String in ["color", "shadow_color"]:
			if base.get(key) is Color:
				var c: Color = base[key]
				mat.set_shader_parameter(key, Color(c.r * tint.r * dim, c.g * tint.g * dim, c.b * tint.b * dim, c.a))
		var next: Variant = mat.next_pass
		if next is ShaderMaterial:
			for key: String in shared: (next as ShaderMaterial).set_shader_parameter(key, shared[key])
			# The outline takes her mood's colour too (a blue line round a flame looks wrong).
			var line: Dictionary = (next as ShaderMaterial).get_meta("fm_line", {})
			for key: String in line:
				var c: Color = line[key]
				var hot := Color(1.0, 0.45, 0.15).lerp(c, 0.35)
				var lc := c.lerp(hot, fire) if not luna else c
				(next as ShaderMaterial).set_shader_parameter(key, Color(lc.r * lerpf(1.0, dim, 0.5), lc.g * lerpf(1.0, dim, 0.5), lc.b * lerpf(1.0, dim, 0.5), lc.a))
			if base.rim is Color:
				var rim: Color = (base.rim as Color).lerp(NIGHT_RIM, fire if luna else 0.0)
				(next as ShaderMaterial).set_shader_parameter("fm_glow_color", Color(rim.r * dim, rim.g * dim, rim.b * dim, rim.a))
	if is_instance_valid(row.sway):
		row.sway.amount = row.amount
		row.sway.speed_scale = float(mood.speed)
		row.sway.swing_scale = float(mood.amp) * (1.0 + 0.5 * float(mood.turb))
		var local: Vector3 = pony.global_basis.orthonormalized().inverse() * Vector3(row.trail)
		row.sway.trail_side = clampf(local.x / TRAIL_MAX, -1.0, 1.0)
		row.sway.trail_lift = clampf(-local.z / TRAIL_MAX, -1.0, 1.0) - float(mood.sag) * 0.5


func _needs_apply(row: Dictionary) -> bool:
	if row.surfaces.is_empty(): return true
	for surface: Dictionary in row.surfaces:
		var mi: MeshInstance3D = surface.mi
		if not is_instance_valid(mi) or mi.get_surface_override_material(int(surface.index)) != surface.flowing: return true
	return false


func _apply(pony: Node3D) -> void:
	var row: Dictionary = _ponies[pony]
	var id := _id(pony)
	if not LOOKS.has(id): return
	if not _enabled(pony):
		_restore(row)
		if is_instance_valid(row.sway): row.sway.queue_free()
		row.sway = null
		return
	var model: Node = pony.get("_model")
	var skeleton: Skeleton3D = pony.get("skeleton")
	if model == null or skeleton == null: return
	_restore(row)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var lower := String(mi.name).to_lower()
		var part := "tail" if "tail" in lower else ("mane" if "mane" in lower else "")
		if part.is_empty() or mi.mesh == null or not mi.is_visible_in_tree(): continue
		for index in mi.mesh.get_surface_count():
			var original := mi.get_surface_override_material(index) as ShaderMaterial
			if original == null: continue
			var flowing := _flowing_material(original, mi, index, skeleton, pony, LOOKS[id][part], part)
			if flowing == null: continue
			mi.set_surface_override_material(index, flowing)
			row.surfaces.append({"mi": mi, "index": index, "original": original, "flowing": flowing, "part": part})
	if not is_instance_valid(row.sway) or row.sway.get_parent() != skeleton:
		if is_instance_valid(row.sway): row.sway.queue_free()
		var sway: SkeletonModifier3D = SWAY.new()
		sway.name = "FlowingTailSway"
		sway.pony = pony
		sway.speed = 0.32 if id == "celestia" else 0.29
		sway.seed = 1.3 if id == "celestia" else 4.1
		skeleton.add_child(sway)
		row.sway = sway
	if not row.surfaces.is_empty():
		print("[flowing_manes] %s: %d hair surfaces flowing" % [id, row.surfaces.size()])


func _flowing_material(original: ShaderMaterial, mi: MeshInstance3D, index: int, skeleton: Skeleton3D, pony: Node3D, look: Dictionary, part: String) -> ShaderMaterial:
	var base := _copy(original, SHADERS.flowing(original.shader, "base"))
	if base == null: return null
	var preset: Dictionary = PRESETS[str(config.preset)]
	var scale := {"amp": float(preset.amp) * float(config.motion), "speed": float(preset.speed) * float(config.speed),
		"sparkle": float(preset.sparkle) * float(config.sparkle), "glow": float(preset.glow) * float(config.glow)}
	if look.has("glow"):
		var glow := ShaderMaterial.new()
		glow.shader = SHADERS.glow()
		glow.set_shader_parameter("fm_glow_color", look.glow)
		glow.set_shader_parameter("fm_tip_fade", look.tip_fade)
		glow.set_shader_parameter("fm_glow", scale.glow)
		base.next_pass = glow
	elif original.next_pass is ShaderMaterial:
		var outline := _copy(original.next_pass as ShaderMaterial, SHADERS.flowing((original.next_pass as ShaderMaterial).shader, "outline"))
		base.next_pass = outline if outline != null else original.next_pass
	var strand := _strand(mi, index, skeleton, part)
	var to_mesh := mi.global_basis.orthonormalized().inverse()
	var params := {
		"fm_v_root": strand.root, "fm_v_tip": strand.tip, "fm_amount": 0.0,
		"fm_amp": float(look.amp) * float(scale.amp) * float(strand.length), "fm_speed": float(look.speed) * float(scale.speed), "fm_waves": look.waves,
		"fm_side": (to_mesh * pony.global_basis.x).normalized(), "fm_back": (to_mesh * pony.global_basis.z).normalized(),
		"fm_up": (to_mesh * pony.global_basis.y).normalized(), "fm_seed": 2.1 if part == "tail" else 0.0,
		"fm_sparkle": float(look.sparkle) * float(scale.sparkle), "fm_sparkle_color": look.color, "fm_drift": look.drift, "fm_sparkle_cells": look.cells,
	}
	if look.has("glow"): params["fm_glow_width"] = float(look.glow_width) * float(strand.length)
	base.set_meta("fm_base", {"amp": params.fm_amp, "sparkle": params.fm_sparkle,
		"color": original.get_shader_parameter("color"), "shadow_color": original.get_shader_parameter("shadow_color"), "rim": look.get("glow", null)})
	if base.next_pass is ShaderMaterial and not look.has("glow"):
		var line := {}
		for key: String in ["color", "shadow_color", "outline_color"]:
			var c: Variant = (base.next_pass as ShaderMaterial).get_shader_parameter(key)
			if c is Color: line[key] = c
		base.next_pass.set_meta("fm_line", line)
	for pass_material: Variant in [base, base.next_pass]:
		if not pass_material is ShaderMaterial: continue
		for key: String in params: (pass_material as ShaderMaterial).set_shader_parameter(key, params[key])
	return base


## A new material on `shader` carrying every parameter `source` had set.
func _copy(source: ShaderMaterial, shader: Shader) -> ShaderMaterial:
	if shader == null: return null
	var out := ShaderMaterial.new()
	out.shader = shader
	out.render_priority = source.render_priority
	if source.shader != null:
		for uniform: Dictionary in source.shader.get_shader_uniform_list(true):
			var name := str(uniform.get("name", ""))
			if name.is_empty(): continue
			var value: Variant = source.get_shader_parameter(name)
			if value != null: out.set_shader_parameter(name, value)
	return out


## The strand coordinate: texture v at the root and at the tip, and the hair's length (mesh units).
## The root end is the one nearer the bone the hair hangs from (head for the mane, first tail bone).
func _strand(mi: MeshInstance3D, index: int, skeleton: Skeleton3D, part: String) -> Dictionary:
	var arrays := mi.mesh.surface_get_arrays(index)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var low := INF; var high := -INF
	for uv in uvs: low = minf(low, uv.y); high = maxf(high, uv.y)
	var low_sum := Vector3.ZERO; var high_sum := Vector3.ZERO; var low_n := 0; var high_n := 0
	var lo_box := Vector3.INF; var hi_box := -Vector3.INF
	for i in points.size():
		lo_box = lo_box.min(points[i]); hi_box = hi_box.max(points[i])
		var t := (uvs[i].y - low) / maxf(high - low, 0.0001)
		if t < 0.1: low_sum += points[i]; low_n += 1
		elif t > 0.9: high_sum += points[i]; high_n += 1
	var root_v := low; var tip_v := high
	var bone := skeleton.find_bone("pony_tail_01" if part == "tail" else "pony_head")
	if bone >= 0 and low_n > 0 and high_n > 0:
		var from_skeleton := (skeleton.global_transform.affine_inverse() * mi.global_transform).affine_inverse()
		var anchor: Vector3 = from_skeleton * skeleton.get_bone_global_rest(bone).origin
		if (high_sum / high_n).distance_to(anchor) < (low_sum / low_n).distance_to(anchor):
			root_v = high; tip_v = low
	return {"root": root_v, "tip": tip_v, "length": (hi_box - lo_box).length()}


func _id(pony: Node) -> String:
	var identity: Variant = pony.get("identity")
	var id := str(identity.get("id")) if identity != null else ""
	if identity != null and identity.has_method("character"): id = str(identity.character())
	return id


func _restore(row: Dictionary) -> void:
	for surface: Dictionary in row.surfaces:
		var mi: MeshInstance3D = surface.mi
		if is_instance_valid(mi) and mi.get_surface_override_material(int(surface.index)) == surface.flowing:
			mi.set_surface_override_material(int(surface.index), surface.original)
	row.surfaces = []


## Switched off in Settings -> Mods: the game's own materials and a still tail, at once.
func _exit_tree() -> void:
	if _ui != null: _ui.detach_all()
	for pony: Variant in _ponies.keys():
		var row: Dictionary = _ponies[pony]
		_restore(row)
		if is_instance_valid(row.sway): row.sway.queue_free()
	_ponies.clear()
