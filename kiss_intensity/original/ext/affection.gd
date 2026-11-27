extends "res://world/relationships/pony_affection.gd"
## Kiss intensity (devanon): what her body shows as a returned kiss builds.
##
## The kiss itself stays the game's (this script's base) and the Kissing mod's. One value drives
## everything here: the Kissing mod's `level` on her KissingFeelings node, cut off at the ceiling
## kiss_terms() gives (kiss_terms.gd, which also holds the levels and the switches).
## Her head is moved only through the kiss pose's own inputs (his mouth point and his facing,
## affection_pose.gd), so the pose's joint limits and eye clearance apply to all of it. The
## game's own slow sway and its change of side stay as they are.
##
## Adults only: a filly, a colt and a young player get the game's forehead kiss and never reach
## this script's own lines (begin() hands them straight to the base). A kiss she turns away from
## builds nothing. Nothing here runs while she is not being kissed: every tick below hangs off the
## base's own _process, which is off outside a kiss and its afterglow.

const KI := preload("res://mods/kiss_intensity/kiss_terms.gd")
const KI_BREATH_FX := preload("res://mods/kiss_intensity/breath_effects.gd")
const KI_WING_LIFT := preload("res://mods/kiss_intensity/wing_lift.gd")
const KI_ACTING := preload("res://mods/kiss_intensity/kiss_acting.gd")
const KI_FACE := preload("res://mods/kiss_intensity/kiss_face.gd")
const KI_TONGUE := preload("res://mods/kiss_intensity/kiss_tongue.gd")
const KI_MANE_FADE := preload("res://mods/kiss_intensity/mane_fade.gd")
## A breather: lips apart over PART_OUT seconds, held, back together from PART_IN_FROM.
const KI_PART_SECONDS := 4.2
const KI_PART_OUT := 1.4
const KI_PART_IN_FROM := 2.8
## Seconds of lip contact before the first breather (from BREATHER_FROM), then between two:
## at BREATHER_FROM, and [least, most] at level 1.
const KI_FIRST_TOGETHER := Vector2(4.5, 6.0)
const KI_TOGETHER_LOW := 13.0
const KI_TOGETHER_TOP := Vector2(8.0, 10.0)
## The lightest blush of a returned kiss (the first blush), as a share of the full one.
const KI_FIRST_BLUSH := 0.15
## The in-between answer: a laugh, a blush and a look aside, this long.
const KI_BETWEEN_SECONDS := 2.4
## Turning away (the answer "away"): her head turns aside and down over the first part, is held
## until KI_AWAY_HOLD and comes slowly back by KI_AWAY_SECONDS. Radians: down, aside, roll.
const KI_AWAY_HOLD := 1.9
const KI_AWAY_SECONDS := 3.0
const KI_AWAY_LOOK := Vector3(-0.25, 0.8, 0.08)
## Her lips on his (critique 2026-11-25): her lip seam to his, metres. Off his lips past CONTACT.x
## (the eye guard pushed her back, outside a breather) her open mouth and tongue ease shut over
## CONTACT_EASE seconds; gone by CONTACT.y.
const KI_CONTACT := Vector2(0.02, 0.04)
const KI_CONTACT_EASE := 0.2
## The blush at the top of the kiss: full strength from BLUSH_FULL, then deeper and up to a
## quarter wider from BLUSH_DEEP (dev's ordinary blush was the top before, one pink for every coat).
const KI_BLUSH_FULL := 0.75
const KI_BLUSH_DEEP := 0.6
const KI_BLUSH_GROW := 0.25
## Sound levels (dB) for the parting lips, the breath and the lips meeting again.
const KI_PART_DB := -27.0
const KI_BREATH_DB := -24.0
const KI_REJOIN_DB := -30.0

## This kiss's answer and ceiling. Empty while this pack has no part in what she is doing.
var _ki_terms: Dictionary = {}
## An answer asked in the held moment, for the begin() of the same physics tick.
var _ki_pending: Dictionary = {}
var _ki_pending_tick := -1
var _ki_meter: Node
var _ki_ceiling := 0.0
var _ki_level := -1.0
var _ki_fx: Node3D
var _ki_wings: RefCounted
var _ki_wing_wait := 0.0
var _ki_together := -1.0
var _ki_act: RefCounted
var _ki_mouth := false
## From the game's mouth point to his visible mouth, in his head's axes, metres. Set by
## ext/main.gd each tick while his own face is drawn in his view; zero otherwise.
var ki_his_lips := Vector3.ZERO
var _ki_ear := ""
var _ki_tongue: Node3D
var _ki_release_lids := 0.5
var _ki_step_left := 0.0
var ki_lower_lip := Vector3.INF
var ki_jaw := 0.0
var _ki_lip_rig: Skeleton3D
var _ki_lip_bones := Vector2i(-1, -1)
var _ki_lower := Vector3.ZERO
var _ki_upper := Vector3.ZERO
## From her lip seam to her upper lip bone (the point the kiss pose steers), in her head rig's
## space, sampled at the start of the kiss before any mouth opens.
var _ki_seam := Vector3.ZERO
## 0..1: her lips on his (eased), outside a breather.
var _ki_contact := 1.0
var _ki_fade: RefCounted
var _ki_blush_deep := Color.WHITE
var _ki_part := -1.0
var _ki_exhaled := false
var _ki_rejoined := false
var _ki_strand := false
var _ki_sculpt := false
var _ki_decals: Dictionary = {}
var _ki_log := 0.0
## "" / "hold" (the held moment) / "between" (the in-between answer) / "away" (she turns away).
var _ki_scene := ""
var _ki_scene_time := 0.0
var _ki_seen := 0.0
var _ki_eye := Vector3.INF
var _ki_side := 1.0
var _ki_laughed := false
## Counted for the review fixture.
var ki_parts := 0


## Stands in for the relationship runtime during the game's own begin(), so the rules are asked
## once per lean-in (by kiss_terms) and the game then acts on that same answer.
class KiAnswered extends Node:
	var real: Node
	var yes := false
	var bonds: Variant:
		get: return real.get("bonds")
	var game: Variant:
		get: return real.get("game")
	func affection_allowed(_actor: Node3D, _kind: String) -> bool: return yes
	func note_refused_kiss(id: String) -> void:
		if real.has_method("note_refused_kiss"): real.call("note_refused_kiss", id)
	func note_kiss(id: String, by_her: bool) -> void:
		if real.has_method("note_kiss"): real.call("note_kiss", id, by_her)


func begin(value: String, point: Vector3, by_her := false) -> bool:
	if value != "kiss" or not is_instance_valid(mare): return super(value, point, by_her)
	var pending: Dictionary = _ki_pending if _ki_pending_tick == Engine.get_physics_frames() else {}
	_ki_pending = {}
	_ki_scene_stop()
	_ki_end_kiss()
	if by_her:
		# Her own kiss: nothing to ask. The ceiling is still her bond's.
		var hers: bool = super(value, point, true)
		if hers and kind == "kiss": _ki_begin({"answer": "back", "ceiling": KI.ceiling_for(mare)})
		return hers
	var runtime: Variant = mare.get_meta("relationship_runtime") if mare.has_meta("relationship_runtime") else null
	# In the game's own order: a spa client, a sleeper, a filly, a colt and a young player never
	# reach the question. Their kiss (the forehead kiss) is the game's alone.
	if mare.has_meta("spa_client") or mare.sleeping or mare.identity.filly or _young_player() or not runtime is Node:
		return super(value, point, false)
	var terms: Dictionary = pending if not pending.is_empty() else KI.kiss_terms(mare)
	var answer := str(terms.get("answer", "away"))
	if answer == "wait": return false
	if answer == "between":
		ki_between(eye if eye.is_finite() else point)
		return true
	var proxy := KiAnswered.new()
	proxy.real = runtime
	proxy.yes = answer == "back"
	mare.set_meta("relationship_runtime", proxy)
	var ok: bool = super(value, point, false)
	mare.set_meta("relationship_runtime", runtime)
	proxy.free()
	if kind == "kiss": _ki_begin(terms)
	elif answer == "away" and _buck_time < 0.0 and kind.is_empty() and KI.on("turn_away"): ki_away(eye if eye.is_finite() else point)
	return ok


func _ki_begin(terms: Dictionary) -> void:
	_ki_release_lids = 0.5
	KI.reload()
	_ki_meter = mare.get_node_or_null("KissingFeelings")
	if _ki_meter == null: return # Without the Kissing mod's meter there is nothing to show.
	_ki_lip_rig = mare.boop_node.head_skeleton
	_ki_lip_bones = Vector2i(_ki_lip_rig.find_bone("mFaceLipLowerCenter"), _ki_lip_rig.find_bone("mFaceLipUpperCenter"))
	if _ki_lip_bones.x >= 0 and _ki_lip_bones.y >= 0:
		_ki_sample_lips()
		_ki_seam = (_ki_upper - _ki_lower) * 0.5
		_ki_lip_rig.skeleton_updated.connect(_ki_sample_lips)
	_ki_contact = 1.0
	_ki_terms = terms
	_ki_ceiling = clampf(float(terms.get("ceiling", 0.0)), 0.0, 1.0)
	_ki_level = 0.0
	_ki_together = -1.0
	_ki_log = 0.0
	_ki_act = KI_ACTING.new()
	_ki_act.small = KI.on("small_motions")
	if KI.on("blush") and _ki_decals.is_empty():
		var boop: Variant = mare.get("boop_node")
		for decal_name: String in ["BlushLeft", "BlushRight", "BlushNose"]:
			var decal: Decal = (boop as Node).get_node_or_null(decal_name) as Decal if boop is Node else null
			# The nose blush's size is the game's to set each tick (hybrid_boop.gd): its colour only.
			if decal != null: _ki_decals[decal] = [decal.modulate, decal.size if decal_name != "BlushNose" else Vector3.ZERO]
		_ki_blush_deep = _ki_deep_tint()
	if KI.on("wings") and _ki_wings == null: _ki_wings = KI_WING_LIFT.take(mare)


## The level her body shows now: the Kissing mod's, cut off at this kiss's ceiling.
func _ki_live_level() -> float:
	if not is_instance_valid(_ki_meter): return 0.0
	return clampf(float(_ki_meter.get("level")), 0.0, _ki_ceiling)


## For ext/main.gd: the level of the kiss this pack is showing, or -1 when it shows none.
func ki_level() -> float:
	return _ki_level if kind == "kiss" and not _ki_terms.is_empty() else -1.0


func _deep_kiss(delta: float) -> void:
	super(delta)
	if kind != "kiss" or _ki_terms.is_empty(): return # The base may end the kiss on this frame.
	var level := _ki_live_level()
	_ki_level = level
	# Her lids are part of the acting: half-lidded, fluttering, more shut as the level rises.
	if KI.on("eyes") and _ki_act != null: mare.expressions.stare(true, float(_ki_act.lids))
	_ki_log -= delta
	if _ki_log <= 0.0:
		_ki_log = 1.0
		var wings_now := "-" if _ki_wings == null or not _ki_wings.held() else "tuck %.2f half %.2f" % [float(_ki_wings.wings.get("tuck")), float(_ki_wings.wings.get("half"))]
		var cycles := "-" if _ki_act == null else "%d lower %d upper" % [int(_ki_act.lower_cycles), int(_ki_act.upper_cycles)]
		print("[kiss_intensity] level=%.2f ceiling=%.2f lids=%.2f lip cycles=%s tongue=%.2f jaw=%.2f seam-gap=%.1fcm contact=%.2f breathers=%d wings=%s" % [level, _ki_ceiling, float(mare.expressions.stare_lids), cycles, 0.0 if _ki_act == null else float(_ki_act.tongue), ki_jaw, ki_lip_gap() * 100.0, _ki_contact, ki_parts, wings_now])


## The full seven-centimetre breather eases out, holds and returns over 4.2 seconds.
func _breather(delta: float) -> bool:
	if _ki_terms.is_empty() or not KI.on("breather"): return super(delta)
	if _ki_part < 0.0:
		if _ki_level < KI.BREATHER_FROM: return false
		if _ki_together < 0.0: _ki_together = randf_range(KI_FIRST_TOGETHER.x, KI_FIRST_TOGETHER.y)
		_ki_together = maxf(0.0, _ki_together - delta) # Below 0 means "not counting yet".
		if _ki_together > 0.0: return false
		# She lets go of his lip first: a breather never starts in the middle of a lip cycle.
		if _ki_act != null and float(_ki_act.grip) > 0.12: return false
		_ki_part = 0.0
		_ki_exhaled = false
		_ki_rejoined = false
		_ki_strand = KI.on("saliva_bridge") and _ki_level >= KI.STRAND_FROM
		ki_parts += 1
		if _ki_act != null: _ki_act.look_now()
		if KI.on("sounds"): mare.boop_node.play_kiss(KI_PART_DB, true)
	_ki_part += delta
	# The base reads these two: the deep kiss does not run out, smack or hum during a breather.
	_pause = _ki_part
	_pause_length = KI_PART_SECONDS
	pose.pause = smoothstep(0.0, KI_PART_OUT, _ki_part) * (1.0 - smoothstep(KI_PART_IN_FROM, KI_PART_SECONDS, _ki_part))
	if _ki_part >= KI_PART_OUT * 0.8 and not _ki_exhaled:
		_ki_exhaled = true
		if KI.on("breath_clouds"):
			# From between her lips, out of the gap to one side and up, away from both faces
			# (dev 2026-11-22: it drifted back into her face).
			var his: Basis = face.orthonormalized()
			var aside := 1.0 if randf() < 0.5 else -1.0
			_ki_effects().exhale(_ki_lips(0.5), his.x * aside * 0.75 + his.y * 0.55 + Vector3.UP * 0.25)
		if KI.on("sounds"): mare.boop_node.play_breath(KI_BREATH_DB)
	if _ki_part >= KI_PART_SECONDS - 0.2 and not _ki_rejoined:
		_ki_rejoined = true
		if KI.on("sounds"): mare.boop_node.play_kiss(KI_REJOIN_DB, true)
	if _ki_part < KI_PART_SECONDS: return true
	_ki_part = -1.0
	_pause = -1.0
	pose.pause = 0.0
	if is_instance_valid(_ki_fx): _ki_fx.clear_bridge()
	var top := clampf(inverse_lerp(KI.BREATHER_FROM, 1.0, _ki_level), 0.0, 1.0)
	_ki_together = lerpf(KI_TOGETHER_LOW, randf_range(KI_TOGETHER_TOP.x, KI_TOGETHER_TOP.y), top)
	return false


## A point between her lips (world): 0 her lower lip, 1 her upper lip.
func _ki_lips(share: float) -> Vector3:
	if not is_instance_valid(_ki_lip_rig) or _ki_lip_bones.x < 0 or _ki_lip_bones.y < 0:
		return mouth_point() - Vector3.UP * 0.006 * (1.0 - share)
	return _ki_lip_rig.global_transform * _ki_lower.lerp(_ki_upper, share)


func _ki_sample_lips() -> void:
	_ki_lower = _ki_lip_rig.get_bone_global_pose(_ki_lip_bones.x).origin
	_ki_upper = _ki_lip_rig.get_bone_global_pose(_ki_lip_bones.y).origin


## World offset from her lip seam to the point the kiss pose steers (her upper lip bone).
func _ki_seam_lift() -> Vector3:
	return _ki_lip_rig.global_basis * _ki_seam if is_instance_valid(_ki_lip_rig) else Vector3.ZERO


## His lips: the seam of his drawn face while it shows, else the game's mouth point (world).
func _ki_his_seam() -> Vector3:
	return target + face.orthonormalized() * ki_his_lips


## How far her lip seam is from his (metres). Her seam is her upper lip bone less the rest offset,
## so her own jaw opening does not count as a gap.
func ki_lip_gap() -> float:
	if kind != "kiss" or not is_instance_valid(_ki_lip_rig) or _ki_lip_bones.y < 0: return 0.0
	return (_ki_lip_rig.global_transform * _ki_upper - _ki_seam_lift()).distance_to(_ki_his_seam())


func _ki_effects() -> Node3D:
	if not is_instance_valid(_ki_fx):
		_ki_fx = KI_BREATH_FX.new()
		_ki_fx.name = "KissIntensityEffects"
		add_child(_ki_fx)
	return _ki_fx


func _process(delta: float) -> void:
	super(delta)
	if not is_instance_valid(mare): return
	if not _ki_scene.is_empty(): _ki_scene_tick(delta)
	if not _ki_decals.is_empty(): _ki_blush_tick()
	if _ki_wings != null: _ki_wing_tick(delta)
	if kind == "kiss" and not _ki_terms.is_empty():
		_ki_face_tick(delta)
		_ki_pose_write()
	_ki_fade_tick()
	if is_processing(): return
	# The base has just switched itself off (nothing of its own is left to run).
	if not _ki_scene.is_empty(): set_process(true)
	else: _ki_let_go()


## Her blush follows the level. The game still places and fades the decals (hybrid_boop.gd);
## this scales their strength, and keeps scaling until the game's own blush has faded.
func _ki_blush_tick() -> void:
	var boop: Node = mare.boop_node
	var kissing := kind == "kiss" and not _ki_terms.is_empty()
	if not kissing and float(boop.get("blush_amount")) <= 0.0:
		_ki_restore_blush()
		return
	var level := _ki_live_level()
	var blush := lerpf(KI_FIRST_BLUSH, 1.0, smoothstep(KI.BLUSH_FROM, KI_BLUSH_FULL, level))
	# A line face with a blush of its own (shy, affectionate) is never dimmed.
	blush = maxf(blush, float(mare.expressions.blush_weight))
	var deeper := smoothstep(KI_BLUSH_DEEP, 1.0, level)
	if kissing:
		boop.sustain_blush()
		# The game's strong blush (full colour instead of three quarters) near the top.
		if level >= 0.85: boop.set("strong_blush_time", maxf(float(boop.get("strong_blush_time")), 0.2))
	for decal: Decal in _ki_decals:
		if not is_instance_valid(decal): continue
		var kept: Array = _ki_decals[decal]
		var tint: Color = (kept[0] as Color).lerp(_ki_blush_deep, deeper)
		tint.a = (kept[0] as Color).a * blush
		decal.modulate = tint
		if kept[1] != Vector3.ZERO: decal.size = (kept[1] as Vector3) * (1.0 + KI_BLUSH_GROW * deeper)


## The blush colour at the top of the kiss, from her coat: a deeper red on a warm coat, a
## saturated pink on a pale one, a deeper pink on the rest. The game's own blush stays the start.
func _ki_deep_tint() -> Color:
	var identity: Variant = mare.get("identity")
	var coat: Variant = identity.get("coat_fill") if identity is Object else null
	if not coat is Color: return Color(0.95, 0.24, 0.44)
	var c: Color = coat
	if c.s < 0.22 and c.v > 0.72: return Color(1.0, 0.16, 0.42)
	if (c.h < 0.15 or c.h > 0.93) and c.s >= 0.22: return Color(0.80, 0.05, 0.14)
	return Color(0.95, 0.24, 0.44)


func _ki_restore_blush() -> void:
	for decal: Decal in _ki_decals:
		if not is_instance_valid(decal): continue
		var kept: Array = _ki_decals[decal]
		decal.modulate = kept[0]
		if kept[1] != Vector3.ZERO: decal.size = kept[1]
	_ki_decals.clear()


## Wings follow the level through the kiss and back down as it fades afterwards.
func _ki_wing_tick(delta: float) -> void:
	_ki_wings.tick(_ki_live_level(), delta)
	if kind == "kiss":
		_ki_wing_wait = 0.0
		return
	_ki_wing_wait += delta
	# Folded again: handed back once excitement no longer asks for open wings (it does for a
	# second after a kiss), or after three seconds whatever it asks.
	if not _ki_wings.held() or (_ki_wings.folded() and (not _ki_wings.asked_open() or _ki_wing_wait > 3.0)):
		_ki_wings.release()
		_ki_wings = null


func _physics_process(delta: float) -> void:
	super(delta)
	# The base has just handed his mouth point and facing to the pose; the acting goes on top.
	if kind == "kiss" and not _ki_terms.is_empty(): _ki_pose_write()
	if _ki_step_left > 0.0:
		_ki_step_left = maxf(0.0, _ki_step_left - delta)
		if not kind.is_empty() or mare.is_held() or mare.sleeping or not mare.grounded() or _buck_time >= 0.0:
			_ki_step_left = 0.0
		mare.back_up(0.32 * smoothstep(0.0, 0.20, _ki_step_left))


## The lip cycle and the small motions of her head, given to the kiss pose as a mouth point a
## centimetre up or down his mouth and a facing turned a few degrees. The pose turns her head
## about her lips, inside its own limits; her lips stay on his.
func _ki_pose_write() -> void:
	var acted := _ki_act != null and KI.on("lip_cycle")
	var his: Basis = face.orthonormalized()
	# Her lip seam goes to his (critique 2026-11-25): the pose steers her upper lip bone, which sits
	# above her seam, so with the chin-up her nose met his mouth and her open mouth hung under his.
	# His own face is drawn in his view (ext/main.gd): her lips go to his visible mouth.
	pose.target = _ki_his_seam() + _ki_seam_lift()
	# The neck eases its forward lean during the breather. Compensate at the target so
	# the visible lip travels the full seven centimetres, within the normal IK limits.
	if _ki_part >= 0.0: pose.target -= his.z * 0.016 * pose.pause
	if not acted: return
	pose.target += his.y * float(_ki_act.lip_offset) + his.z * float(_ki_act.press)
	pose.face = Basis(his.z, float(_ki_act.tilt)) * Basis(his.y, float(_ki_act.turn)) * Basis(his.x, float(_ki_act.nod)) * his


## Her face through the kiss, written after the game's own mouth and eye writers.
func _ki_face_tick(delta: float) -> void:
	if _ki_act == null: return
	var parted := _ki_part >= 0.0
	var opening := float(pose.pause) if parted else 0.0
	# Her tongue lingers as her lips leave and leads them back: in from 0.4 s, out again just
	# before she leans back in.
	var tongue_in := smoothstep(0.3, 0.9, _ki_part) * (1.0 - smoothstep(KI_PART_IN_FROM - 0.1, KI_PART_IN_FROM + 0.5, _ki_part)) if parted else 0.0
	# Outside a breather her mouth opens and her tongue shows only while her lips are on his.
	var on_lips := 1.0 if parted else 1.0 - smoothstep(KI_CONTACT.x, KI_CONTACT.y, ki_lip_gap())
	_ki_contact = move_toward(_ki_contact, on_lips, delta / KI_CONTACT_EASE)
	var together := deep and amount > 0.98 and (parted or _ki_contact > 0.5)
	# A tongue stretch never starts while her head changes sides (the eye guard pushes hardest then).
	var steady := absf(float(pose._side_now)) >= 0.8
	_ki_act.tick(delta, _ki_level, together, opening, tongue_in if KI.on("tongue") else 1.0, steady)
	var mouth: PonyMouth = mare.head.mouth
	var tongue := float(_ki_act.tongue) * _ki_contact
	var cycle := KI.on("lip_cycle")
	ki_jaw = clampf(maxf(float(_ki_act.jaw), float(_ki_act.tongue) * 0.7), 0.0, 1.0) * _ki_contact if KI.on("tongue") else 0.0
	if deep and (cycle or parted or ki_jaw > 0.0):
		# Off his lips outside a breather: a soft pucker, not a gape.
		KI_FACE.mouth(mouth, _ki_act, amount, cycle, ki_jaw, maxf(opening, 1.0 - _ki_contact))
		_ki_mouth = true
	elif _ki_mouth:
		KI_FACE.clear_mouth(mouth)
		_ki_mouth = false
	if float(_ki_act.look) > 0.02 and eye.is_finite():
		mare.eye_motion.target_world = eye
		mare.eye_motion.target_weight = float(_ki_act.look)
	if KI.on("eyes") and KI_FACE.eyes(mare.expressions, _ki_level, float(_ki_act.look)):
		_ki_sculpt = true
	_ki_ear_tick()
	_ki_tongue_tick(tongue if KI.on("tongue") else 0.0)
	if _ki_strand:
		if not parted:
			_ki_strand = false
			return
		if not _ki_effects().bridge(_ki_lips(0.0), ki_lower_lip if ki_lower_lip.is_finite() else target, _ki_part): _ki_strand = false


## An ear flick through her face rig's own ear shapes (as the Kissing mod's earth pony fidgets
## do; a pony that has those keeps them and gets none from here).
func _ki_ear_tick() -> void:
	var eyes: Variant = mare.expressions.get("eyes")
	var ears: Variant = eyes.get("expression_ears") if eyes is Object and is_instance_valid(eyes) else null
	if not ears is Dictionary: return
	if not _ki_ear.is_empty() and (float(_ki_act.ear) <= 0.0 or _ki_ear != str(_ki_act.ear_shape)):
		(ears as Dictionary).erase(_ki_ear)
		_ki_ear = ""
	if float(_ki_act.ear) <= 0.0 or is_instance_valid(_ki_meter.get("_fidget") if is_instance_valid(_ki_meter) else null): return
	var shape := str(_ki_act.ear_shape)
	if _ki_ear.is_empty() and (ears as Dictionary).has(shape): return # Her face is already using it.
	_ki_ear = shape
	ears[shape] = float(_ki_act.ear)


## Seat the skinned tongue on her moving lip line, pointing into his open mouth.
func _ki_tongue_tick(out: float) -> void:
	if out < 0.02:
		if is_instance_valid(_ki_tongue): _ki_tongue.hide()
		return
	if not is_instance_valid(_ki_tongue):
		_ki_tongue = KI_TONGUE.new()
		add_child(_ki_tongue)
		_ki_tongue.top_level = true
		_ki_tongue.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		if not _ki_tongue.setup(mare):
			_ki_tongue.queue_free()
			_ki_tongue = null
			return
	var boop: Node = mare.boop_node
	var skeleton: Skeleton3D = boop.head_skeleton
	var head: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(int(boop._head_bone))
	var his := face.orthonormalized()
	var socket := target + his * (ki_his_lips + Vector3.BACK * 0.010 * head.basis.y.length())
	_ki_tongue.follow(head, _ki_lips(0.55), socket, out, _ki_act)


# ---------------------------------------------------------------- the held moment, the in-between

## The held moment (ext/main.gd calls this every physics tick while he leans in): she holds
## still, breath caught, eyes on him, with the first blush. `at` is his eye point.
func ki_hold(on: bool, at := Vector3.INF) -> void:
	if not is_instance_valid(mare): return
	if not on:
		if _ki_scene == "hold": _ki_scene_stop()
		return
	_ki_eye = at
	_ki_seen = _ki_scene_time
	if _ki_scene == "hold": return
	_ki_scene = "hold"
	_ki_scene_time = 0.0
	_ki_seen = 0.0
	_claim()
	set_process(true)
	mare.expressions.set_dialogue("surprised")
	if KI.on("sounds"): mare.boop_node.play_breath(KI_BREATH_DB - 3.0)


## The held moment's question. Asks kiss_terms() and keeps the answer for the begin() that
## ext/main.gd makes in the same physics tick. "wait" is asked again on the next call.
func ki_ask() -> String:
	if _ki_pending.is_empty() or _ki_pending_tick != Engine.get_physics_frames() or str(_ki_pending.get("answer", "")) == "wait":
		_ki_pending = KI.kiss_terms(mare)
		_ki_pending_tick = Engine.get_physics_frames()
	return str(_ki_pending.get("answer", "away"))


## The in-between answer: no kiss. A breathy laugh, a blush, her head and eyes aside and a
## little down, then back to him. Her head moves through the game's own head look
## (pony_secondary_motion.gd look_toward, inside the angles the game itself uses), her face is the
## existing "shy" line face.
func ki_between(at: Vector3) -> void:
	if not is_instance_valid(mare): return
	_ki_pending = {}
	_ki_eye = at
	_ki_scene = "between"
	_ki_scene_time = 0.0
	_ki_laughed = false
	_ki_side = 1.0 if randf() < 0.5 else -1.0
	_claim()
	set_process(true)
	mare.expressions.set_dialogue("shy")


## She turns away (the answer "away", the game's own refusal): no kiss. Her head turns aside and a
## little down, her eyes off him, no smile, for a moment, then slowly back. The buck stays the game's.
func ki_away(at: Vector3) -> void:
	if not is_instance_valid(mare): return
	_ki_pending = {}
	_ki_eye = at
	_ki_scene = "away"
	_ki_scene_time = 0.0
	_ki_side = 1.0 if randf() < 0.5 else -1.0
	_claim()
	set_process(true)
	mare.expressions.set_dialogue("sad")


func _ki_scene_tick(delta: float) -> void:
	_ki_scene_time += delta
	var looked := _ki_eye.is_finite()
	if _ki_scene == "hold":
		# ext/main.gd stopped calling (he left, the mod was switched off): let go.
		if _ki_scene_time - _ki_seen > 0.25:
			ki_hold(false)
			return
		mare.stop()
		if looked:
			mare.eye_motion.target_world = _ki_eye
			mare.eye_motion.target_weight = 1.0
		if KI.on("blush"): mare.boop_node.sustain_blush(0.3)
		return
	var t := _ki_scene_time
	if _ki_scene == "away":
		# Whatever she says next has its own face.
		if mare.is_speaking() or _buck_time >= 0.0:
			_ki_scene_stop()
			return
		var turned := smoothstep(0.05, 0.5, t) * (1.0 - smoothstep(KI_AWAY_HOLD, KI_AWAY_SECONDS, t))
		mare.stop()
		mare.secondary.look_toward(Vector3(KI_AWAY_LOOK.x * turned, KI_AWAY_LOOK.y * _ki_side * turned, KI_AWAY_LOOK.z * _ki_side * turned), 0.2)
		if looked:
			var right: Vector3 = mare.global_basis.x.normalized()
			mare.eye_motion.target_world = _ki_eye + (right * 1.1 * _ki_side - Vector3.UP * 0.45) * turned
			mare.eye_motion.target_weight = turned
		if t >= KI_AWAY_SECONDS: _ki_scene_stop()
		return
	var aside := smoothstep(0.15, 0.6, t) * (1.0 - smoothstep(1.7, KI_BETWEEN_SECONDS, t))
	mare.stop()
	mare.secondary.look_toward(Vector3(-0.14 * aside, 0.45 * _ki_side * aside, 0.07 * _ki_side * aside), 0.2)
	if looked:
		var right: Vector3 = mare.global_basis.x.normalized()
		mare.eye_motion.target_world = _ki_eye + (right * 0.7 * _ki_side - Vector3.UP * 0.35) * aside
		mare.eye_motion.target_weight = 1.0
	if KI.on("blush"): mare.boop_node.sustain_blush(1.0)
	if t > 0.25 and not _ki_laughed:
		_ki_laughed = true
		var voice: Node = mare.vocal() if mare.has_method("vocal") else null
		if voice != null and KI.on("sounds"): voice.play(str(mare.identity.id), "laugh", mare.boop_node.snoot, -26.0)
	if t >= KI_BETWEEN_SECONDS: _ki_scene_stop()


## Ends the held moment, the in-between answer or turning away, whichever runs.
func _ki_scene_stop() -> void:
	if _ki_scene.is_empty(): return
	_ki_scene = ""
	if not is_instance_valid(mare): return
	# A line she has started speaking keeps its own face.
	if not mare.is_speaking(): mare.expressions.finish_dialogue(0.6)
	if kind.is_empty(): _release()


# ---------------------------------------------------------------- her mane at his eyes

## Her mane fades out right in front of his eyes (critique 2026-11-25: her forelock filled his view
## from the held moment on). From the held moment through the kiss and its afterglow, for this
## mare only (mane_fade.gd).
func _ki_fade_tick() -> void:
	var wanted := KI.on("mane_fade") and (_ki_scene == "hold" or (kind == "kiss" and not _ki_terms.is_empty()) or (_ki_fade != null and kind.is_empty() and afterglow_left > 0.0))
	if wanted:
		if _ki_fade == null:
			_ki_fade = KI_MANE_FADE.new()
			_ki_fade.take(mare)
		else: _ki_fade.keep(mare)
	elif _ki_fade != null:
		_ki_fade.release()
		_ki_fade = null


# ---------------------------------------------------------------- letting go

func end() -> void:
	var soften := kind == "kiss" and _ki_act != null and KI.on("eyes")
	if kind == "kiss" and not _ki_terms.is_empty() and deep and amount > 0.98 and not mare.is_held() and not _landing and pose._rear_now < 0.001 and eye.is_finite() and eye.distance_to(mouth_point()) < 0.18:
		_ki_step_left = 0.70
	if soften: _ki_release_lids = maxf(0.5, float(_ki_act.lids))
	super()
	if soften and afterglow_left > 0.0: mare.expressions.stare(true, _ki_release_lids)
	_ki_end_kiss()


func _advance_afterglow(delta: float) -> void:
	super(delta)
	if afterglow_left > 0.0 and _ki_release_lids > 0.5 and kind.is_empty():
		_ki_release_lids = move_toward(_ki_release_lids, 0.5, delta * 0.22)
		mare.expressions.stare(true, _ki_release_lids)


func _exit_tree() -> void:
	_ki_let_go()
	super()


## The kiss is over. Wings and blush stay with the level while it fades (_process).
func _ki_end_kiss() -> void:
	if is_instance_valid(_ki_lip_rig) and _ki_lip_rig.skeleton_updated.is_connected(_ki_sample_lips):
		_ki_lip_rig.skeleton_updated.disconnect(_ki_sample_lips)
	_ki_lip_rig = null
	if (_ki_part >= 0.0 or _ki_sculpt or _ki_mouth or not _ki_ear.is_empty()) and is_instance_valid(mare) and is_instance_valid(mare.head):
		KI_FACE.clear_mouth(mare.head.mouth)
		if not _ki_ear.is_empty():
			var eyes: Variant = mare.expressions.get("eyes")
			var ears: Variant = eyes.get("expression_ears") if eyes is Object and is_instance_valid(eyes) else null
			if ears is Dictionary: (ears as Dictionary).erase(_ki_ear)
		var head: Variant = mare.expressions.show_head
		if _ki_sculpt and head is Object and (head as Object).has_method("set_face_sculpt") and str(mare.expressions.dialogue_face).is_empty():
			head.call("set_face_sculpt", {}, Vector2.ONE)
			if (head as Object).has_method("set_eye_details"): head.call("set_eye_details", 1.0, 0.0, 0.0)
	if is_instance_valid(_ki_fx): _ki_fx.queue_free()
	_ki_fx = null
	_ki_terms = {}
	_ki_level = -1.0
	_ki_part = -1.0
	_ki_strand = false
	_ki_sculpt = false
	_ki_mouth = false
	_ki_ear = ""
	_ki_act = null
	if is_instance_valid(_ki_tongue): _ki_tongue.queue_free()
	_ki_tongue = null
	ki_jaw = 0.0
	ki_lower_lip = Vector3.INF
	ki_his_lips = Vector3.ZERO
	_ki_seam = Vector3.ZERO
	_ki_contact = 1.0


## Everything given back at once: she left the scene, or the base stopped ticking.
func _ki_let_go() -> void:
	if _ki_step_left > 0.0 and is_instance_valid(mare): mare.back_up(0.0)
	_ki_step_left = 0.0
	_ki_end_kiss()
	_ki_restore_blush()
	if _ki_fade != null:
		_ki_fade.release()
		_ki_fade = null
	if _ki_wings != null:
		_ki_wings.release()
		_ki_wings = null
	_ki_scene_stop()
	_ki_meter = null
