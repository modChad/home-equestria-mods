extends Node
## Idle Life: ten more idles for ponies standing about (idles.gd), alongside the game's own
## fidgets (world/life/day/pony_fidgets.gd: stretch, yawn, hoof lift, turn, tail swish, sky look).
##
## Who: the game's own test for its fidgets, pony_fidgets.gd level() == STAND: settled on her
## feet, under her own daily life, nopony talking to, touching, holding, leading or seating her,
## awake, and drawn in full detail. One pony at a time each, every WAIT seconds or so, never while
## one of the game's own fidgets or a hoof lift is playing. The moment she stops qualifying
## (spoken to, touched, called away) the idle fades out in FADE_OUT seconds.
##
## How: an IdlePose modifier (idle_pose.gd) added as her skeleton's last child for the idle's
## length, plus, where an idle needs it, her face (eyes through the expressions' touch channel,
## the head's own ear shapes, the mouth), a tail swish (the tail spring's own kick) and her wings
## (hybrid_open_wings.gd hold_at, as the game's spa does). Everything is handed back when the
## idle ends, and when the mod is switched off.

const FIDGETS := preload("res://world/life/day/pony_fidgets.gd")
const IDLES := preload("res://mods/idle_life/idles.gd")
const POSE := preload("res://mods/idle_life/idle_pose.gd")
const BRUSH := preload("res://mods/idle_life/models/brush.scn")
const UNICORN_MAGIC := preload("res://world/characters/magic/unicorn_magic.gd")
const FRINGE := preload("res://mods/idle_life/fringe.gd")
const POSE_READER := preload("res://mods/idle_life/pose_reader.gd")
## How long before looking again for a fringe not found (milliseconds).
const FRINGE_RETRY_MS := 30000
## Ponies who never brush their manes (canonically not the sort), or have no fringe to brush.
const NO_BRUSH := ["king_sombra", "tempest_shadow", "shining_armor", "prince_blueblood", "jackpot",
	"night_light", "silver_spanner", "comet_tail", "pokey_pierce"]
const MAGIC_AURA := preload("res://world/characters/magic/magic_aura.gd")
const OWNER := "idle_life"
const WAIT := Vector2(18.0, 45.0)
const FIRST_WAIT := Vector2(5.0, 25.0)
const FADE_OUT := 0.35
const SCAN := 0.5
const CHECK := 0.25
const WING_HOLD := 0.75
## Sun height (sine of its elevation) under which ponies may doze off: about 5 degrees, so they
## get drowsy from a little before sunset until a little after sunrise.
const NIGHT_SUN := 0.08
## How wide the preened wing is held (hybrid_open_wings.gd hold_at: 0 fully open, 1 half open).
const PREEN_SPREAD := 0.35
## Lab: force lying or sitting.
static var LAB_REST := ""
static var LAB_DEBUG := false

## pony -> {pose, idle, side, time, check, leaving, fade, wings, ears, lids, mouth, kicked}
var _rows: Dictionary = {}
## pony -> seconds until she may start one
var _waits: Dictionary = {}
var _last: Dictionary = {}
var _scan := 0.0
var _rng := RandomNumberGenerator.new()
## pony -> her fringe (fringe.gd find()), found once: _fringe(). {"retry": msec} while none found.
var _fringes: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func _exit_tree() -> void:
	for pony: Variant in _rows.keys(): _finish(pony)
	for pony: Variant in _fringes.keys():
		if not is_instance_valid(pony): continue
		var sk: Variant = (pony as Node).get("skeleton")
		var reader: Node = (sk as Node).get_node_or_null(FRINGE.READER) if sk is Node else null
		if reader != null: reader.queue_free()


func _physics_process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN
		_pick(SCAN)
	for pony: Variant in _rows.keys(): _advance(pony, delta)


# ---------------------------------------------------------------- choosing

func _ponies() -> Array:
	var game: Node = Mods.game
	if not is_instance_valid(game): return []
	var mares: Variant = game.get("mares")
	return mares if mares is Array else []


func _pick(step: float) -> void:
	for pony: Variant in _waits.keys():
		if not is_instance_valid(pony): _waits.erase(pony); _last.erase(pony)
	for pony: Variant in _ponies():
		if not is_instance_valid(pony) or not pony is Node3D or _rows.has(pony): continue
		if not _waits.has(pony): _waits[pony] = _rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
		if not _free(pony):
			_waits[pony] = maxf(float(_waits[pony]), 3.0)
			continue
		_waits[pony] = float(_waits[pony]) - step
		if float(_waits[pony]) > 0.0: continue
		_waits[pony] = _rng.randf_range(WAIT.x, WAIT.y)
		play(pony, _choose(pony))


## Standing about with time on her hooves, and nothing of the game's own playing on her.
func _free(pony: Node3D, resting := false) -> bool:
	var nav: Node = pony.get_node_or_null("Navigator")
	if FIDGETS.level(pony, nav, false) != (FIDGETS.REST if resting else FIDGETS.STAND): return false
	var affection: Node = pony.get_node_or_null("Affection")
	if affection != null and affection.has_method("fidget_active") and bool(affection.fidget_active()): return false
	var hoof: Variant = pony.get("hoof_hold")
	if hoof != null and hoof.has_method("active") and bool(hoof.active()): return false
	return true


## The princesses' bodies (and far bigger wings) are their own models.
func _princess(pony: Node) -> bool:
	return pony.scene_file_path.contains("/princesses/")


func _horned(pony: Node) -> bool:
	var identity: Variant = pony.get("identity")
	var magic: Variant = pony.get("magic")
	return identity != null and identity.has_method("has_horn") and bool(identity.has_horn()) and magic != null and is_instance_valid(magic)


func _winged(pony: Node) -> bool:
	var identity: Variant = pony.get("identity")
	return identity != null and identity.has_method("has_wings") and bool(identity.has_wings())


## Sunset to sunrise, and a little either side: the sun below a few degrees.
func _drowsy_hours() -> bool:
	var clock := get_node_or_null("/root/TimeOfDay")
	if clock == null or not clock.has_method("sun_elevation"): return false
	return float(clock.sun_elevation()) < NIGHT_SUN


func _choose(pony: Node3D) -> String:
	var options: Array = []
	for idle: String in IDLES.LENGTH:
		if idle in IDLES.VARIANTS.values(): continue
		if idle in IDLES.WINGED and not _winged(pony): continue
		if idle in IDLES.NIGHT and not _drowsy_hours(): continue
		if idle in IDLES.HORNED and not _brushes(pony): continue
		if idle in IDLES.MAGIC and not _horned(pony): continue
		# Shelved for the princesses: their open wings don't fit their bodies yet (a known game bug).
		if idle in IDLES.NOT_PRINCESSES and _princess(pony): continue
		if idle == str(_last.get(pony, "")) or str(IDLES.VARIANTS.get(idle, "")) == str(_last.get(pony, "")): continue
		options.append(idle)
	var chosen: String = options[_rng.randi_range(0, options.size() - 1)]
	# Half the time its variant (the light stretch or the deep one).
	if IDLES.VARIANTS.has(chosen) and _rng.randf() < 0.5: chosen = IDLES.VARIANTS[chosen]
	return chosen


# ---------------------------------------------------------------- playing

## Starts `idle` on `pony` now. False if it cannot play on her. `forced` (tests, previews) plays
## it to the end whether or not she stays free.
func play(pony: Node3D, idle: String, side := 0.0, forced := false) -> bool:
	if _rows.has(pony) or IDLES.length(idle) <= 0.0: return false
	var skeleton: Variant = pony.get("skeleton")
	if not skeleton is Skeleton3D: return false
	var row := {"idle": idle, "side": side if side != 0.0 else (1.0 if _rng.randf() < 0.5 else -1.0),
		"time": 0.0, "check": CHECK, "leaving": false, "fade": 1.0, "forced": forced, "wings": null, "ears": "", "lids": false, "mouth": false, "kicked": false}
	if idle in IDLES.RESTING:
		# Down first: lying or sitting, half and half (stargazing: sitting); the idle waits until she
		# has settled.
		if (idle in IDLES.WINGED and not _winged(pony)) or not pony.has_method("request_posture"): return false
		row.rest = "sit" if idle == "stargaze" or _rng.randf() < 0.5 else "lie_down"
		if not LAB_REST.is_empty(): row.rest = LAB_REST
		if not bool(pony.request_posture(row.rest)): return false
		row.stage = "settling"
		row.wait = 0.0
	if idle in IDLES.HORNED:
		# Asked for now: look again for her fringe rather than wait out a miss.
		if forced and not _fringe(pony).has("strokes"): _fringes[pony] = {"retry": 0}
		if not _brushes(pony): return false
		# Brushed on the side her fringe sweeps to (either, when it falls evenly).
		var fringe := _fringe(pony)
		if float(fringe.side) != 0.0: row.side = float(fringe.side)
		if not (fringe.strokes as Dictionary).has(float(row.side)): row.side = float((fringe.strokes as Dictionary).keys()[0])
		var brush: Node3D = BRUSH.instantiate()
		brush.name = "IdleLifeBrush"
		(pony.get_parent() if pony.get_parent() != null else pony).add_child(brush)
		brush.scale = Vector3.ONE * 0.001
		brush.global_position = _brush_near(pony, row)
		var magic: Node = pony.get("magic")
		magic.call("hold", true)
		row.brush = brush
		# The game's own magic aura in her colour (as glow_object gives), sized for the full brush:
		# glow_object measures the brush as it is now, still shrunk to nothing.
		var aura: Node3D = MAGIC_AURA.create(brush, magic.get("color"), 1.0, 0.13 * _size(pony))
		row.glows = [aura] if aura != null else []
	if idle in ["stretch", "stretch_deep", "wing_stretch"] and _winged(pony):
		row.wings = _open_wings(pony, 0.0)
	if idle in IDLES.MAGIC:
		if not _horned(pony): return false
		row.sparks = []
	var pose: SkeletonModifier3D = POSE.new()
	pose.name = "IdleLife"
	pose.mare = pony
	pose.idle = idle
	pose.side = row.side
	(skeleton as Skeleton3D).add_child(pose)
	row.pose = pose
	_rows[pony] = row
	_last[pony] = idle
	return true


func _advance(pony: Variant, delta: float) -> void:
	var row: Dictionary = _rows[pony]
	if not is_instance_valid(pony) or not is_instance_valid(row.pose):
		_finish(pony); return
	if row.has("stage") and not _rest_stage(pony, row, delta): return
	row.time = float(row.time) + delta
	var total := IDLES.length(row.idle)
	# Still hers to do? Checked a few times a second; anything else fades it out quickly.
	row.check = float(row.check) - delta
	if row.check <= 0.0 and not bool(row.leaving) and not bool(row.forced):
		row.check = CHECK
		if not _free(pony, row.has("stage")): row.leaving = true
	if bool(row.leaving): row.fade = maxf(float(row.fade) - delta / FADE_OUT, 0.0)
	var fade := float(row.fade)
	row.pose.time = row.time
	row.pose.fade = fade
	# Kept her skeleton's last modifier (the open wings' own modifier, among others, may be added
	# after it and would undo its turns), the pose reader after it.
	var sk: Node = (row.pose as Node).get_parent()
	if sk != null and (row.pose as Node).get_index() < sk.get_child_count() - 1:
		sk.move_child(row.pose, -1)
		var reader := sk.get_node_or_null(FRINGE.READER)
		if reader != null: sk.move_child(reader, -1)
	_face(pony, row, fade)
	if float(row.time) >= total or fade <= 0.0:
		if row.has("stage") and str(row.stage) == "preening": _rise(pony, row)
		else: _finish(pony)


## A resting idle's way down and back up. True while the idle itself plays (stage "preening").
func _rest_stage(pony: Node3D, row: Dictionary, delta: float) -> bool:
	row.wait = float(row.wait) + delta
	var status: Dictionary = pony.posture_status() if pony.has_method("posture_status") else {}
	var requested := str(status.get("requested", ""))
	var settled := bool(status.get("settled", true))
	match str(row.stage):
		"settling":
			# Someone else asked for another posture, or she never got down: not hers any more.
			if requested != str(row.rest) and not (row.rest == "sit" and requested == "lie_down"):
				_finish(pony); return false
			if settled and float(row.wait) > 0.4:
				row.stage = "preening"
				row.wait = 0.0
				if row.idle == "preen": row.wings = _open_wings(pony, PREEN_SPREAD)
				return true
			if float(row.wait) > 6.0: _rise(pony, row)
			return false
		"rising":
			_one_wing(pony, row)
			if (requested == "stand" and settled) or float(row.wait) > 5.0: _finish(pony)
			return false
	return true


## Back on her hooves (if her posture is still the one this idle asked for).
func _rise(pony: Node3D, row: Dictionary) -> void:
	if row.get("wings") != null and is_instance_valid(row.wings): row.wings.call("release_hold", OWNER)
	if is_instance_valid(row.get("pose")): (row.pose as Node).queue_free()
	_release_face(pony, row)
	var status: Dictionary = pony.posture_status() if pony.has_method("posture_status") else {}
	var requested := str(status.get("requested", ""))
	if requested == str(row.rest) or (row.rest == "sit" and requested == "lie_down"): pony.request_posture("stand")
	row.stage = "rising"
	row.wait = 0.0


## While one wing is preened, the other shows folded (the game opens both together); kept up
## until the open wings have folded away again.
func _one_wing(pony: Node3D, row: Dictionary) -> void:
	var flight: Variant = pony.get("flight")
	var wings: Variant = flight.get("wings") if flight != null else null
	if wings == null or not is_instance_valid(wings): return
	var other := "_L" if float(row.side) > 0.0 else "_R"
	var any_open := false
	for mi: Variant in wings.get("meshes"):
		if is_instance_valid(mi) and (mi as Node3D).visible: any_open = true
	if not any_open: return
	for mi: Variant in wings.get("meshes"):
		if is_instance_valid(mi) and String((mi as Node).name).contains("open" + other): (mi as Node3D).visible = false
	for mi: Variant in wings.get("folded"):
		if is_instance_valid(mi) and String((mi as Node).name).contains("folded" + other): (mi as Node3D).visible = true


## The idle's face, ears, mouth, tail and wings, moment by moment.
func _face(pony: Node3D, row: Dictionary, fade: float) -> void:
	var t := float(row.time)
	var total := IDLES.length(row.idle)
	match str(row.idle):
		"doze":
			var sink := smoothstep(0.5, 4.0, t) * (1.0 - smoothstep(total - 1.6, total - 0.4, t))
			var start := smoothstep(6.9, 7.05, t) * (1.0 - smoothstep(7.4, 8.4, t))
			_lids(pony, row, sink * (1.0 - start) * fade)
			_ears(pony, row, "ears_side", 0.7 * sink * (1.0 - start) * fade)
		"preen":
			var tongue := IDLES.tongue(t) * fade
			_mouth(pony, row, 0.0, {"open_lips": 0.55 * tongue, "tongue": tongue})
			_lids(pony, row, IDLES.envelope(t, total, 1.4, 1.6) * fade)
			_one_wing(pony, row)
			if t > total - 1.2 and row.wings != null and is_instance_valid(row.wings):
				row.wings.call("release_hold", OWNER); row.wings = null
		"magic_brush":
			_move_brush(pony, row, fade)
			# Eyes half closed, enjoying it, while the fringe is brushed.
			var at := float(row.time)
			_lids(pony, row, 0.45 * fade * smoothstep(IDLES.BRUSH_FRINGE.x, IDLES.BRUSH_FRINGE.x + 0.6, at) * (1.0 - smoothstep(IDLES.BRUSH_FRINGE.y - 0.3, IDLES.BRUSH_FRINGE.y + 0.3, at)))
		"stretch", "stretch_deep":
			# Tail up in an arch as she tips forward, kept up through the hold.
			var kicks := int(row.get("kicks", 0))
			if kicks < 3 and t > 1.0 + 1.1 * kicks:
				row.kicks = kicks + 1
				_lift_tail(pony, 2.4 if kicks == 0 else 1.4)
			if t > total - 1.3 and row.wings != null and is_instance_valid(row.wings):
				row.wings.call("release_hold", OWNER); row.wings = null
		"paw":
			pass
		"look_round":
			_ears(pony, row, "ears_alert", 0.85 * IDLES.envelope(t, total, 0.3, 1.0) * fade)
		"wing_stretch":
			_expression(pony, row, 0.0, 0.5 * IDLES.envelope(t, total, 1.4, 1.6) * fade)
			if t > total - 1.1 and row.wings != null and is_instance_valid(row.wings):
				row.wings.call("release_hold", OWNER); row.wings = null
		"magic_sparkle":
			_sparkle(pony, row, fade)
			_expression(pony, row, 0.6 * IDLES.envelope(t, total, 1.0, 1.0) * fade, 0.0)
		"stargaze":
			# Calm, a little smile, a slow blink now and then.
			var cycle := fposmod(t, 4.3)
			var blink := smoothstep(0.0, 0.15, cycle) * (1.0 - smoothstep(0.35, 0.55, cycle)) if t > 3.0 else 0.0
			var calm := IDLES.envelope(t, total, 2.0, 1.5) * fade
			_expression(pony, row, 0.45 * calm, (0.2 + 0.8 * blink) * calm)


## A smile and her lids, through the expressions' touch channel.
func _expression(pony: Node3D, row: Dictionary, smile: float, lids: float) -> void:
	var expressions: Variant = pony.get("expressions")
	if expressions == null or not expressions.has_method("touch"): return
	expressions.touch(OWNER, clampf(smile, 0.0, 1.0), clampf(lids, 0.0, 1.0))
	row.lids = true


## The magic sparkle's sparks: her horn lit, then three little bursts of her magic leaving its tip
## one after another and drifting up and forward, each fading out on its way.
func _sparkle(pony: Node3D, row: Dictionary, fade: float) -> void:
	var magic: Variant = pony.get("magic")
	if magic == null or not is_instance_valid(magic): return
	var t := float(row.time)
	var sparks: Array = row.sparks
	if not bool(row.get("lit", false)) and t > 0.6 and fade > 0.5:
		row.lit = true
		magic.call("cast", IDLES.SPARKS.y - 0.6)
	var size := _size(pony)
	var tip := _horn_tip(pony, magic)
	var due := sparks.size()
	if due < 3 and t > IDLES.SPARKS.x + 0.7 * due and fade > 0.5:
		var holder := Node3D.new()
		holder.name = "IdleLifeSpark"
		(pony.get_parent() if pony.get_parent() != null else pony).add_child(holder)
		holder.global_position = tip
		var colour: Color = magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")
		UNICORN_MAGIC.burst(holder, Vector3.ZERO, colour, 2.4, 0.07 * size)
		sparks.append([holder, t, _rng.randf_range(-1.0, 1.0)])
	var basis := pony.global_basis.orthonormalized()
	for spark: Array in sparks:
		var holder: Variant = spark[0]
		if not is_instance_valid(holder): continue
		var age := t - float(spark[1])
		# Up and a little forward and to one side, slowing as it goes.
		var rise := (1.0 - exp(-age * 0.9)) * 0.55 * size
		(holder as Node3D).global_position = tip + basis.y * rise - basis.z * rise * 0.35 + basis.x * float(spark[2]) * rise * 0.3
		if age > 3.0: (holder as Node).queue_free()


## Her horn's tip, from her magic (unicorn_magic.gd measures it).
func _horn_tip(pony: Node3D, magic: Variant) -> Vector3:
	var sk: Variant = magic.get("_skeleton")
	var bone: Variant = magic.get("_bone")
	var local: Variant = magic.get("_tip_local")
	if sk is Skeleton3D and is_instance_valid(sk) and bone is int and int(bone) >= 0 and local is Vector3:
		return (sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(int(bone)) * Vector3(local)
	return _bone_at(pony, "pony_head") + Vector3.UP * 0.3 * _size(pony)


func _lids(pony: Node3D, row: Dictionary, amount: float) -> void:
	var expressions: Variant = pony.get("expressions")
	if expressions == null or not expressions.has_method("touch"): return
	expressions.touch(OWNER, 0.0, clampf(amount, 0.0, 1.0))
	row.lids = true


## One of the head's own ear shapes, only while no one else holds her ears.
func _ears(pony: Node3D, row: Dictionary, shape: String, weight: float) -> void:
	var eyes: Variant = pony.get("eye_motion")
	var ears: Variant = eyes.get("expression_ears") if eyes != null else null
	if not ears is Dictionary: return
	var shapes: Dictionary = ears
	for other: Variant in shapes.keys():
		if str(other) != shape: return   # someone else's ear shape: theirs
	if weight <= 0.001: shapes.erase(shape)
	else: shapes[shape] = clampf(weight, 0.0, 1.0)
	row.ears = shape


func _mouth(pony: Node3D, row: Dictionary, amount: float, shapes := {}) -> void:
	var head: Variant = pony.get("head")
	var mouth: Variant = head.get("mouth") if head != null else null
	if mouth == null or not mouth.has_method("set_expression"): return
	if shapes.is_empty(): shapes = {"open_soft": amount}
	for shape: String in shapes:
		mouth.set_expression(shape, clampf(float(shapes[shape]), 0.0, 1.0))
	row.mouth = shapes.keys()


## A unicorn or alicorn who brushes her fringe: not one of NO_BRUSH, and with a fringe found.
func _brushes(pony: Node3D) -> bool:
	if not _horned(pony): return false
	var identity: Variant = pony.get("identity")
	var id := str(identity.get("id")) if identity != null else ""
	if id in NO_BRUSH: return false
	return _fringe(pony).has("strokes")


func _fringe(pony: Node3D) -> Dictionary:
	var now := Time.get_ticks_msec()
	var known: Variant = _fringes.get(pony)
	# None found yet (her hair may still be loading or settling): looked for again a little later.
	if known is Dictionary and ((known as Dictionary).has("strokes") or now < int((known as Dictionary).get("retry", 0))): return known
	if known == null: pony.tree_exiting.connect(func() -> void: _fringes.erase(pony), CONNECT_ONE_SHOT)
	# A princess' swoop sways with her flowing mane: it is found and followed as drawn, so she
	# needs a pose reader first (read from the next frame on).
	if _princess(pony):
		var reader := _reader(pony)
		if reader == null:
			var sk: Skeleton3D = pony.get("skeleton")
			if sk == null: return {}
			reader = POSE_READER.new()
			reader.name = FRINGE.READER
			sk.add_child(reader)
		if (reader.get("poses") as Array).is_empty():
			_fringes[pony] = {"retry": now + 200}
			return _fringes[pony]
	var found := FRINGE.find(pony)
	if found.is_empty(): found = {"retry": now + FRINGE_RETRY_MS}
	_fringes[pony] = found
	return found


## Her pose reader (pose_reader.gd), kept as her skeleton's last child.
func _reader(pony: Node3D) -> Node:
	var sk: Skeleton3D = pony.get("skeleton")
	var reader := sk.get_node_or_null(FRINGE.READER) if sk != null else null
	if reader != null and reader.get_index() != sk.get_child_count() - 1: sk.move_child(reader, -1)
	return reader


## The pony's size against an ordinary mare (by hip height), for the brush's reach.
func _size(pony: Node3D) -> float:
	var sk: Skeleton3D = pony.get("skeleton")
	var hips := sk.find_bone("pony_hips") if sk != null else -1
	if hips < 0: return 1.0
	var height := (sk.global_transform * sk.get_bone_global_pose(hips).origin).y - pony.global_position.y
	return clampf(height / 0.59, 0.5, 2.5)


func _bone_at(pony: Node3D, name: String) -> Vector3:
	var sk: Skeleton3D = pony.get("skeleton")
	var bone := sk.find_bone(name) if sk != null else -1
	return sk.global_transform * sk.get_bone_global_pose(bone).origin if bone >= 0 else pony.global_position


## A point on the stroke down her fringe (fringe.gd), `along` 0 (beside her horn) .. 1 (her brow),
## on the hair, `lift` (metres at size 1) further out from the middle of her skull.
func _fringe_spot(pony: Node3D, row: Dictionary, along: float, lift := 0.0) -> Vector3:
	var fringe := _fringe(pony)
	var path: Array = fringe.strokes[float(row.side)]
	var f := clampf(along, 0.0, 1.0) * (path.size() - 1)
	var i := mini(int(f), path.size() - 2)
	var at := FRINGE.spot(pony, path[i]).lerp(FRINGE.spot(pony, path[i + 1]), f - i)
	var clear := 0.0
	if fringe.has("clear"):
		var c: Array = fringe.clear[float(row.side)]
		clear = lerpf(float(c[i]), float(c[i + 1]), f - i)
	return at + (at - FRINGE.centre(pony)).normalized() * ((BRUSH_OFF + lift) * float(fringe.size) + clear)


## Where the brush floats before and after: beside her face, on her fringe's side.
func _brush_near(pony: Node3D, row: Dictionary, high := 0.0) -> Vector3:
	var size := _size(pony)
	var basis := pony.global_basis.orthonormalized()
	return FRINGE.centre(pony) + basis.x * float(row.side) * 0.24 * size + basis.y * (0.12 + high) * size - basis.z * 0.12 * size


## How far off her hair the bristle tips ride (metres at size 1).
const BRUSH_OFF := 0.0
## The middle of the brush's bristles, in its model (the handle runs back along +Z from it).
const BRUSH_HEAD := Vector3(0.0, -0.032, -0.165)
## How big the brush is (times its model's size, at size 1).
const BRUSH_SCALE := 0.8

## The brush on its way: up beside her face, strokes down her fringe, and off, all in her magic.
## Bristles face her; the brush leans into each stroke.
func _move_brush(pony: Node3D, row: Dictionary, fade: float) -> void:
	if _princess(pony): _reader(pony)
	var brush: Variant = row.get("brush")
	if not brush is Node3D or not is_instance_valid(brush): return
	var t := float(row.time)
	var total := IDLES.length(row.idle)
	var target: Vector3
	var facing := Vector3.ZERO
	var direction := Vector3.DOWN
	if t < IDLES.BRUSH_FRINGE.x: target = _brush_near(pony, row)
	elif t < IDLES.BRUSH_FRINGE.y:
		# Down the fringe in contact for 60% of each stroke, then lifted away and back up.
		var u := fposmod((t - IDLES.BRUSH_FRINGE.x) / IDLES.BRUSH_STROKE, 1.0)
		var along := u / 0.6 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
		var lift := 0.0 if u < 0.6 else 0.05 * sin((u - 0.6) / 0.4 * PI)
		target = _fringe_spot(pony, row, along, lift)
		var centre := FRINGE.centre(pony)
		facing = (target - centre).normalized()
		direction = (_fringe_spot(pony, row, minf(along + 0.1, 1.0)) - _fringe_spot(pony, row, maxf(along - 0.1, 0.0))).normalized()
	else: target = _brush_near(pony, row, 0.15)
	var step := 1.0 - exp(-get_physics_process_delta_time() / 0.06)
	# Bristles (the brush's -Y) toward her, its head (-Z) leading down the stroke; floating, the
	# bristles face her side.
	var y := facing if not facing.is_zero_approx() else pony.global_basis.x.normalized() * float(row.side)
	var z := -direction
	z = (z - y * z.dot(y)).normalized()
	if z.is_zero_approx(): z = pony.global_basis.z.normalized()
	var appear := smoothstep(0.0, 0.7, t) * (1.0 - smoothstep(total - 0.8, total, t)) * fade
	var wanted := Basis(y.cross(z), y, z).orthonormalized()
	var now := (brush as Node3D).global_basis.orthonormalized()
	if LAB_DEBUG and Engine.get_physics_frames() % 6 == 0: print("BRUSHDBG t=%.2f target=%s head=%s red=%s blue=%s" % [t, target, (brush as Node3D).global_transform * BRUSH_HEAD, _fringe_spot(pony, row, 0.0), _fringe_spot(pony, row, 1.0)])
	var turned := now.slerp(wanted, minf(step * 1.5, 1.0))
	var scale := maxf(BRUSH_SCALE * _size(pony) * appear, 0.001)
	(brush as Node3D).global_basis = turned.scaled(Vector3.ONE * scale)
	# The brush's head (its bristles), not the end of its handle, goes where it is wanted.
	var head_at := (brush as Node3D).global_transform * BRUSH_HEAD
	var want := (brush as Node3D).global_position + (target - head_at)
	(brush as Node3D).set_meta("idle_life_at", (brush as Node3D).get_meta("idle_life_at", want).lerp(want, step) if (brush as Node3D).has_meta("idle_life_at") else want)
	(brush as Node3D).global_position = (brush as Node3D).get_meta("idle_life_at")


## The tail flicked up and over (its spring's own kick, inside the tail's limits).
func _lift_tail(pony: Node3D, strength: float) -> void:
	var tail: Variant = pony.get("tail_motion")
	if tail == null or not bool(tail.get("active")): return
	var springs: Variant = tail.get("springs")
	if springs == null or not springs.has_method("kick"): return
	springs.kick((pony.global_basis.y * 1.0 + pony.global_basis.z * 0.4).normalized() * strength)


func _open_wings(pony: Node3D, value := WING_HOLD) -> Node:
	if not _winged(pony): return null
	if pony.has_method("_ensure_flight"): pony.call("_ensure_flight")
	var flight: Variant = pony.get("flight")
	if flight == null: return null
	var wings: Variant = flight.get("wings")
	if wings == null:
		var script: Script = load("res://world/characters/hybrid_mare/hybrid_open_wings.gd")
		if script == null: return null
		var made: Node = script.new()
		pony.add_child(made)
		if not bool(made.call("bind", pony)): made.queue_free(); return null
		flight.set("wings", made)
		wings = made
	if not bool(wings.call("hold_at", OWNER, value)): return null
	return wings


## Ends the idle on her and hands back everything it touched.
func _finish(pony: Variant) -> void:
	var row: Dictionary = _rows.get(pony, {})
	_rows.erase(pony)
	if row.is_empty(): return
	if is_instance_valid(row.get("pose")): (row.pose as Node).queue_free()
	if not is_instance_valid(pony): return
	_release_face(pony, row)
	if row.has("stage") and str(row.stage) != "rising":
		# Ended while down (switched off, cut short): back up if the posture is still ours.
		var status: Dictionary = pony.posture_status() if pony.has_method("posture_status") else {}
		var requested := str(status.get("requested", ""))
		if requested == str(row.rest) or (row.rest == "sit" and requested == "lie_down"): pony.request_posture("stand")
	if row.get("wings") != null and is_instance_valid(row.wings): row.wings.call("release_hold", OWNER)
	_drop_brush(pony, row)
	for spark: Variant in row.get("sparks", []):
		if is_instance_valid((spark as Array)[0]): ((spark as Array)[0] as Node).queue_free()


## The magic brush gone, and her horn and its glow let go.
func _drop_brush(pony: Variant, row: Dictionary) -> void:
	if row.has("glows"): UNICORN_MAGIC.unglow_object(row.glows)
	if is_instance_valid(row.get("brush")): (row.brush as Node).queue_free()
	if row.has("brush") and is_instance_valid(pony):
		var magic: Variant = pony.get("magic")
		if magic != null and is_instance_valid(magic): magic.call("hold", false)
	row.erase("brush"); row.erase("glows")


## Her eyes, ears and mouth back to whoever else owns them.
func _release_face(pony: Node3D, row: Dictionary) -> void:
	if bool(row.get("lids")):
		var expressions: Variant = pony.get("expressions")
		if expressions != null and expressions.has_method("release_touch"): expressions.release_touch(OWNER)
	if not str(row.get("ears", "")).is_empty():
		var eyes: Variant = pony.get("eye_motion")
		var ears: Variant = eyes.get("expression_ears") if eyes != null else null
		if ears is Dictionary: (ears as Dictionary).erase(row.ears)
	var used: Variant = row.get("mouth")
	if used is Array:
		var head: Variant = pony.get("head")
		var mouth: Variant = head.get("mouth") if head != null else null
		if mouth != null and mouth.has_method("set_expression"):
			for shape: Variant in used: mouth.set_expression(str(shape), 0.0)
	row.lids = false; row.ears = ""; row.mouth = false
