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
const SCROLL := preload("res://mods/idle_life/scroll.gd")
const TEA := preload("res://mods/idle_life/tea.gd")
const SHOE := preload("res://mods/idle_life/shoe.gd")
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
## Lab only: the scroll's float spot (ahead, below, to her left) in metres at Canon size, to try distances.
static var LAB_SCROLL := Vector3.ZERO

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
		if idle in IDLES.PRINCESS_ONLY and not (_princess(pony) and _horned(pony)): continue
		if idle == "sun" and (not _sun_pony(pony) or not _sun_hours()): continue
		if idle == "moon" and (not _moon_pony(pony) or not _moon_hours()): continue
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
	if idle in IDLES.PRINCESS_ONLY:
		if not (_princess(pony) and _horned(pony)): return false
		var holder: Node = pony.get_parent() if pony.get_parent() != null else pony
		if idle in ["sun", "moon"]:
			var hers := _sun_pony(pony) if idle == "sun" else _moon_pony(pony)
			if not hers or not _winged(pony) or not pony.has_method("_ensure_flight"): return false
			pony.call("_ensure_flight")
			var flight: Variant = pony.get("flight")
			if flight == null: return false
			if not bool(flight.call("request", pony.global_position, IDLES.SUN_HOVER, false, IDLES.SUN_ALTITUDE)):
				if LAB_DEBUG: print("SUN no flight: ", flight.get("reason"))
				return false
			row.flight = flight
		elif idle == "shoe":
			var near := SHOE.body(pony)
			var bsk: Skeleton3D = near.get_node_or_null(near.skeleton) as Skeleton3D if near != null else null
			# Always her left foreleg: on the right the floating shoe goes through her mane.
			row.side = -1.0
			row.leg = "_L"
			var without: ArrayMesh = SHOE.mesh_without(near, bsk, row.leg) if bsk != null else null
			if without == null: return false
			row.near = near
			row.body_sk = bsk
			row.near_mesh = near.mesh
			row.without = without
		elif idle in ["scroll", "write"]:
			var scroll := SCROLL.make(idle == "write", "luna" if _moon_pony(pony) else "celestia")
			holder.add_child(scroll)
			scroll.visible = false
			row.scroll = scroll
			if idle == "write":
				var kit := "luna" if _moon_pony(pony) else "celestia"
				row.quill = SCROLL.make_quill(kit)
				holder.add_child(row.quill)
				(row.quill as Node3D).visible = false
				var inkwell := SCROLL.make_inkwell(kit)
				if inkwell != null:
					holder.add_child(inkwell)
					inkwell.visible = false
					row.inkwell = inkwell
		else:
			# Her own tea set: Luna's for Luna, Celestia's otherwise.
			var set := "luna" if _moon_pony(pony) else "celestia"
			row.cup = TEA.make_cup(set)
			row.saucer = TEA.make_saucer(set)
			for thing: Node3D in [row.cup, row.saucer]:
				holder.add_child(thing)
				thing.visible = false
		# What her eyes follow (the writing, the cup), and what she was watching before.
		var eye := Node3D.new()
		eye.name = "IdleLifeScrollEye"
		holder.add_child(eye)
		row.gaze_eye = eye
		row.gaze_was = pony.get("action_gaze_target")
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
		if not _still_free(pony, row): row.leaving = true
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
	if not bool(row.get("recorded", false)) and not bool(row.leaving) and float(row.time) >= RECORD_AT * total: _record(pony, row)
	if row.has("flight") and float(row.time) > 1.0 and not bool(row.flight.call("active")):
		row.time = maxf(float(row.time), total - 0.6)
	if float(row.time) >= total or fade <= 0.0:
		if row.has("stage") and str(row.stage) == "preening": _rise(pony, row)
		else: _finish(pony)


## Still free (_free), not counting the scroll's own gaze: an action gaze makes the game's
## fidget test say she is busy.
func _still_free(pony: Node3D, row: Dictionary) -> bool:
	if row.has("flight") and row.flight != null and bool(row.flight.call("active")):
		# Up in the air the fidget test says she isn't standing: only being spoken to or held
		# counts (she lands by herself either way).
		return not is_instance_valid(pony.get("conversation_target")) and not bool(pony.get("_held"))
	var eye: Variant = row.get("gaze_eye")
	var ours: bool = is_instance_valid(eye) and pony.get("action_gaze_target") == eye
	if ours: pony.set("action_gaze_target", null)
	var free := _free(pony, row.has("stage"))
	if ours: pony.set("action_gaze_target", eye)
	return free


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
		"scroll":
			_move_scroll(pony, row, fade)
			# Reading: lids a little down, ears forward; a small smile at what she reads.
			var reading := smoothstep(IDLES.SCROLL_OPEN.x, IDLES.SCROLL_OPEN.y, t) * (1.0 - smoothstep(IDLES.SCROLL_CLOSE.x, IDLES.SCROLL_CLOSE.y, t))
			var pleased := smoothstep(IDLES.SCROLL_NOD - 0.6, IDLES.SCROLL_NOD, t) * (1.0 - smoothstep(IDLES.SCROLL_SHOW.y, total - 0.3, t))
			_expression(pony, row, 0.5 * pleased * fade, 0.3 * reading * fade)
			_ears(pony, row, "ears_alert", 0.5 * reading * fade)
		"write":
			_move_scroll(pony, row, fade)
			# Concentrating while she writes: lids a little down, ears forward; pleased at the end.
			var writing := smoothstep(IDLES.WRITE_OPEN.y, IDLES.WRITE_LINES[0].x, t) * (1.0 - smoothstep(IDLES.WRITE_LINES[3].y, IDLES.WRITE_NOD, t))
			var done := smoothstep(IDLES.WRITE_NOD - 0.4, IDLES.WRITE_NOD, t) * (1.0 - smoothstep(IDLES.WRITE_SHOW.y, total - 0.3, t))
			_expression(pony, row, 0.5 * done * fade, 0.35 * writing * fade)
			_ears(pony, row, "ears_alert", 0.55 * writing * fade)
		"sun", "moon":
			_sun(pony, row, fade)
		"shoe":
			_move_shoe(pony, row, fade)
			# Curious, ears forward, while she looks it over; pleased once the pebble is out.
			var looking := smoothstep(IDLES.SHOE_LIFT.x, IDLES.SHOE_OFF.x, t) * (1.0 - smoothstep(IDLES.SHOE_ON, IDLES.SHOE_DOWN.y, t))
			var pleased := smoothstep(IDLES.SHOE_PEBBLE, IDLES.SHOE_PEBBLE + 0.4, t) * (1.0 - smoothstep(IDLES.SHOE_DOWN.x, total - 0.2, t))
			_expression(pony, row, 0.5 * pleased * fade, 0.15 * looking * fade)
			_ears(pony, row, "ears_alert", 0.6 * looking * fade)
		"tea":
			_move_tea(pony, row, fade)
			# Eyes closed for each sip, then a contented little smile.
			var sip := IDLES.tea_sip(t)
			var after := smoothstep(IDLES.TEA_SIPS[0].y - 0.3, IDLES.TEA_SIPS[0].y + 0.3, t) * (1.0 - smoothstep(IDLES.TEA_SHOW.y, total - 0.3, t))
			_expression(pony, row, 0.55 * after * fade, (0.15 + 0.75 * sip) * IDLES.envelope(t, total, 1.0, 1.2) * fade)
			_mouth(pony, row, 0.0, {"open_soft": 0.25 * sip * fade})
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
	_drop_scroll(pony, row)
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


# ---------------------------------------------------------------- the scroll

## How big the scroll is (times scroll.gd's size, at size 1).
const SCROLL_SCALE := 1.3
## Where the scroll floats, from her head as she starts (metres at Canon size): ahead, below, to her
## left. Clear of Flowing Manes' fuller manes.
const SCROLL_AT := Vector3(0.45, 0.06, 0.10)
## How far across each row her gaze goes (of the writing's width): her head follows her gaze,
## so this is kept small for a slight sway rather than a full turn per line.
const SCROLL_SWAY := 0.3

## The scroll idle, moment by moment: her horn lights, a scroll appears in a flash of her magic in
## front of her, unrolls, she reads it row by row (her attention follows the writing, so her eyes
## and head do), rolls it up and it vanishes in another flash.
func _move_scroll(pony: Node3D, row: Dictionary, fade: float) -> void:
	var scroll: Variant = row.get("scroll")
	var magic: Variant = pony.get("magic")
	if not scroll is Node3D or not is_instance_valid(scroll) or magic == null or not is_instance_valid(magic): return
	var t := float(row.time)
	var size := _size(pony)
	if not bool(row.get("lit", false)) and t > 0.3:
		row.lit = true
		magic.call("hold", true)
	# Where it floats: fixed from where her head was as she started, in front of her muzzle and a
	# little below, so it holds still while her head moves to read it.
	if not row.has("anchor") or t < 0.1:
		var head := _bone_at(pony, "pony_head")
		var forward := head - _bone_at(pony, "pony_hips")
		forward.y = 0.0
		forward = forward.normalized() if not forward.is_zero_approx() else -pony.global_basis.z.normalized()
		row.forward = forward
		var at := LAB_SCROLL if LAB_SCROLL != Vector3.ZERO else SCROLL_AT
		row.anchor = head + (forward * at.x + Vector3.DOWN * at.y + Vector3.UP.cross(forward) * at.z) * size
	var forward: Vector3 = row.forward
	var colour: Color = magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")
	var writes := str(row.idle) == "write"
	var show: Vector2 = IDLES.WRITE_SHOW if writes else IDLES.SCROLL_SHOW
	var opening: Vector2 = IDLES.WRITE_OPEN if writes else IDLES.SCROLL_OPEN
	var closing: Vector2 = IDLES.WRITE_CLOSE if writes else IDLES.SCROLL_CLOSE
	var gone := t > show.y or fade < 0.5
	if t > show.x and not gone and not bool(row.get("shown", false)):
		row.shown = true
		(scroll as Node3D).visible = true
		UNICORN_MAGIC.burst(scroll, Vector3.ZERO, colour, 1.4, 0.12 * size)
		magic.call("cast", 0.8)
		var aura: Node3D = MAGIC_AURA.create(scroll, magic.get("color"), 1.0, 0.24 * size)
		row.glows = [aura] if aura != null else []
		if is_instance_valid(row.get("inkwell")):
			(row.inkwell as Node3D).visible = true
			var well_aura: Node3D = MAGIC_AURA.create(row.inkwell, magic.get("color"), 1.0, 0.06 * size)
			if well_aura != null: (row.glows as Array).append(well_aura)
		if is_instance_valid(row.get("quill")):
			(row.quill as Node3D).visible = true
			var quill_aura: Node3D = MAGIC_AURA.create(row.quill, magic.get("color"), 1.0, 0.07 * size)
			if quill_aura != null: (row.glows as Array).append(quill_aura)
	if gone and bool(row.get("shown", false)) and not bool(row.get("vanished", false)):
		row.vanished = true
		var flash := Node3D.new()
		flash.name = "IdleLifeSpark"
		(scroll as Node).get_parent().add_child(flash)
		flash.global_position = (scroll as Node3D).global_position
		UNICORN_MAGIC.burst(flash, Vector3.ZERO, colour, 1.6, 0.16 * size)
		row.sparks = row.get("sparks", []) + [[flash, t, 0.0]]
		magic.call("cast", 0.6)
		_drop_scroll(pony, row)
		return
	if not bool(row.get("shown", false)): return
	# Facing her, its top tipped back toward her a little; bobbing gently in her magic.
	var z := (-forward + Vector3.UP * 0.3).normalized()
	var y := (Vector3.UP - z * Vector3.UP.dot(z)).normalized()
	var grow := smoothstep(show.x, show.x + 0.3, t)
	var scale := maxf(SCROLL_SCALE * size * grow, 0.001)
	(scroll as Node3D).global_basis = Basis(y.cross(z), y, z).scaled(Vector3.ONE * scale)
	(scroll as Node3D).global_position = Vector3(row.anchor) + Vector3.UP * sin(t * 2.2) * 0.006 * size
	var open := smoothstep(opening.x, opening.y, t) * (1.0 - smoothstep(closing.x, closing.y, t))
	SCROLL.set_open(scroll, open)
	if writes:
		_move_quill(pony, row, scroll, t, scale)
		return
	# Her eyes on it: along each row of writing in turn, back to the start of the next.
	var eye: Variant = row.get("gaze_eye")
	if eye is Node3D and is_instance_valid(eye):
		var spot := Vector3(0.0, SCROLL.HEIGHT * 0.2, 0.0)
		var read := (t - IDLES.SCROLL_READ) / IDLES.SCROLL_LINE
		if read >= 0.0 and read < SCROLL.LINES.size():
			var line := int(read)
			var u := read - line
			# Across the row in 80% of the time, then back to the next row's start.
			var across := lerpf(-1.0, 1.0, smoothstep(0.0, 0.8, u)) if u < 0.8 else lerpf(1.0, -1.0, (u - 0.8) / 0.2)
			spot = SCROLL.line_spot(line if u < 0.8 else mini(line + 1, SCROLL.LINES.size() - 1), across * SCROLL_SWAY)
		(eye as Node3D).global_position = (scroll as Node3D).global_transform * spot
		# Held as an action gaze (a fixed look, as when she watches what she's handed), not her
		# attention, which glances away now and then.
		if pony.get("action_gaze_target") != eye and pony.has_method("set_action_gaze"): pony.call("set_action_gaze", eye)


## Where the quill rests between rows and before and after writing, in the scroll's space: up
## beside its right edge, a little toward her.
const QUILL_REST := Vector3(-0.15, 0.06, 0.04)
## The quill's slant, in the scroll's space: up, toward her and out to the right, like a pen in
## a hand.
const QUILL_SLANT := Vector3(-0.35, 0.75, 0.55)
## The quill's size against the scroll's.
const QUILL_SCALE := 1.4
## Where the inkwell floats, in the scroll's space: beside its lower left edge (her left, clear
## of a mane falling on her right), toward her.
const INKWELL_AT := Vector3(-0.22, -0.11, 0.05)

## The writing idle's quill: to the start of each row, along it as the ink appears behind its
## nib (a little up-and-down scribble), lifted between rows, then back to rest. Her eyes follow
## the nib (kept to SCROLL_SWAY of its reach across, so her head doesn't swing).
func _move_quill(pony: Node3D, row: Dictionary, scroll: Node3D, t: float, scale: float) -> void:
	var quill: Variant = row.get("quill")
	if not quill is Node3D or not is_instance_valid(quill): return
	SCROLL.set_written(scroll, IDLES.write_progress(t))
	# The inkwell: upright beside the scroll's lower right, a little toward her.
	var well: Variant = row.get("inkwell")
	var mouth := Vector3.INF
	var sb0 := scroll.global_basis.orthonormalized()
	if well is Node3D and is_instance_valid(well):
		var flat_z := Vector3(sb0.z.x, 0.0, sb0.z.z).normalized()
		var flat_x := Vector3.UP.cross(flat_z).normalized()
		(well as Node3D).global_basis = Basis(flat_x, Vector3.UP, flat_z).scaled(Vector3.ONE * scale)
		(well as Node3D).global_position = scroll.global_transform * INKWELL_AT
		mouth = (well as Node3D).global_position + Vector3.UP * SCROLL.INKWELL_MOUTH * scale
	var tip := QUILL_REST
	var want := Vector3.INF
	var rows: Array = IDLES.WRITE_LINES
	var dips: Array = IDLES.WRITE_DIPS
	if t > dips[0].x - 0.4 and t < rows[rows.size() - 1].y:
		for i in rows.size():
			var dip: Vector2 = dips[i]
			var span: Vector2 = rows[i]
			if t < span.x:
				tip = SCROLL.ink_spot(i, 0.0) + Vector3(0.0, 0.0, 0.02)
				# Into the inkwell first: above its mouth, down into the ink, up again, then to the row.
				if mouth.is_finite() and t >= dip.x - 0.4 and t < dip.y:
					var u := (t - dip.x) / (dip.y - dip.x)
					var depth := SCROLL.INKWELL_MOUTH - SCROLL.INKWELL_DIP
					want = mouth + Vector3.UP * (0.03 * scale if u < 0.3 or u > 0.65 else -depth * scale)
				break
			if t <= span.y:
				var along := (t - span.x) / (span.y - span.x)
				tip = SCROLL.ink_spot(i, along) + Vector3(0.0, sin(t * 38.0) * 0.0025, 0.004)
				break
	var step := 1.0 - exp(-get_physics_process_delta_time() / 0.05)
	if not want.is_finite(): want = scroll.global_transform * tip
	var now: Vector3 = (quill as Node3D).get_meta("idle_life_at", want)
	now = now.lerp(want, step)
	(quill as Node3D).set_meta("idle_life_at", now)
	var sb := scroll.global_basis.orthonormalized()
	var up := (sb * QUILL_SLANT).normalized()
	var x := (sb.x - up * sb.x.dot(up)).normalized()
	(quill as Node3D).global_basis = Basis(x, up, x.cross(up)).scaled(Vector3.ONE * scale * QUILL_SCALE)
	(quill as Node3D).global_position = now
	var eye: Variant = row.get("gaze_eye")
	if eye is Node3D and is_instance_valid(eye):
		var local := scroll.global_transform.affine_inverse() * now
		(eye as Node3D).global_position = scroll.global_transform * Vector3(local.x * SCROLL_SWAY, local.y, 0.0)
		if pony.get("action_gaze_target") != eye and pony.has_method("set_action_gaze"): pony.call("set_action_gaze", eye)


## The scroll gone, her horn let go, her attention handed back.
func _drop_scroll(pony: Variant, row: Dictionary) -> void:
	if row.has("near_mesh") and is_instance_valid(row.get("near")):
		(row.near as MeshInstance3D).mesh = row.near_mesh
	row.erase("near_mesh")
	if is_instance_valid(row.get("pebble")): (row.pebble as Node).queue_free()
	row.erase("pebble")
	if not row.has("scroll") and not row.has("cup") and not row.has("loose"): return
	if row.has("glows"): UNICORN_MAGIC.unglow_object(row.glows)
	row.erase("glows")
	for key: String in ["scroll", "quill", "inkwell", "cup", "saucer", "loose"]:
		if is_instance_valid(row.get(key)): (row[key] as Node).queue_free()
	if is_instance_valid(pony):
		if pony.get("action_gaze_target") == row.get("gaze_eye") and pony.has_method("set_action_gaze"):
			pony.call("set_action_gaze", row.get("gaze_was") if is_instance_valid(row.get("gaze_was")) else null)
		var magic: Variant = pony.get("magic")
		if bool(row.get("lit", false)) and magic != null and is_instance_valid(magic): magic.call("hold", false)
	if is_instance_valid(row.get("gaze_eye")): (row.gaze_eye as Node).queue_free()
	row.erase("scroll"); row.erase("loose"); row.erase("quill"); row.erase("inkwell"); row.erase("cup"); row.erase("saucer"); row.erase("gaze_eye"); row.lit = false


# ---------------------------------------------------------------- tea

## How big the cup and saucer are (times tea.gd's sizes, at size 1).
const TEA_SCALE := 1.0

## Her lips, between the face rig's upper and lower lip (the body's MOUNT_MOUTH is left
## unfitted on the princesses: about 34 cm below Celestia's head).
func _mouth_at(pony: Node3D) -> Vector3:
	var head: Variant = pony.get("head")
	var sk: Variant = head.get("skeleton") if head != null else null
	if sk is Skeleton3D and is_instance_valid(sk):
		var upper := (sk as Skeleton3D).find_bone("mFaceLipUpperCenter")
		var lower := (sk as Skeleton3D).find_bone("mFaceLipLowerCenter")
		if upper >= 0 and lower >= 0:
			var g := (sk as Skeleton3D).global_transform
			return (g * (sk as Skeleton3D).get_bone_global_pose(upper).origin).lerp(g * (sk as Skeleton3D).get_bone_global_pose(lower).origin, 0.5)
	return _bone_at(pony, "MOUNT_MOUTH")


## Tea, moment by moment: her horn lights, a cup on its saucer appears in a flash of her magic in
## front of her, the cup lifts to just before her muzzle and comes to her lips for each sip,
## tipping toward her, then goes back to the saucer and both vanish in another flash.
func _move_tea(pony: Node3D, row: Dictionary, fade: float) -> void:
	var cup: Variant = row.get("cup")
	var saucer: Variant = row.get("saucer")
	var magic: Variant = pony.get("magic")
	if not cup is Node3D or not is_instance_valid(cup) or not is_instance_valid(saucer) or magic == null or not is_instance_valid(magic): return
	var t := float(row.time)
	var size := _size(pony)
	var s := TEA_SCALE * size
	if not bool(row.get("lit", false)) and t > 0.3:
		row.lit = true
		magic.call("hold", true)
	# Her facing, and where the saucer floats: fixed from where her mouth was as she started.
	if not row.has("anchor") or t < 0.1:
		var forward := _bone_at(pony, "pony_head") - _bone_at(pony, "pony_hips")
		forward.y = 0.0
		forward = forward.normalized() if not forward.is_zero_approx() else -pony.global_basis.z.normalized()
		row.forward = forward
		var mouth := _mouth_at(pony)
		row.anchor = mouth + forward * 0.2 * size + Vector3.DOWN * 0.17 * size
		row.hold = mouth + forward * 0.13 * size + Vector3.DOWN * 0.07 * size
		row.ahead = _bone_at(pony, "pony_head") + forward * 1.5 * size
	var forward: Vector3 = row.forward
	var colour: Color = magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")
	var show := IDLES.TEA_SHOW
	var gone := t > show.y or fade < 0.5
	if t > show.x and not gone and not bool(row.get("shown", false)):
		row.shown = true
		(cup as Node3D).visible = true
		(saucer as Node3D).visible = true
		UNICORN_MAGIC.burst(saucer, Vector3.ZERO, colour, 1.4, 0.1 * size)
		magic.call("cast", 0.8)
		var glows: Array = []
		for thing: Node3D in [cup, saucer]:
			var aura: Node3D = MAGIC_AURA.create(thing, magic.get("color"), 1.0, 0.09 * size)
			if aura != null: glows.append(aura)
		row.glows = glows
	if gone and bool(row.get("shown", false)) and not bool(row.get("vanished", false)):
		row.vanished = true
		var flash := Node3D.new()
		flash.name = "IdleLifeSpark"
		(cup as Node).get_parent().add_child(flash)
		flash.global_position = (saucer as Node3D).global_position
		UNICORN_MAGIC.burst(flash, Vector3.ZERO, colour, 1.6, 0.13 * size)
		row.sparks = row.get("sparks", []) + [[flash, t, 0.0]]
		magic.call("cast", 0.6)
		_drop_scroll(pony, row)
		return
	if not bool(row.get("shown", false)): return
	var grow := maxf(s * smoothstep(show.x, show.x + 0.3, t), 0.001)
	var bob := Vector3.UP * sin(t * 2.0) * 0.004 * size
	var right := Vector3.UP.cross(-forward).normalized()
	# The saucer: level, floating where it appeared.
	(saucer as Node3D).global_basis = Basis(right, Vector3.UP, right.cross(Vector3.UP)).scaled(Vector3.ONE * grow)
	(saucer as Node3D).global_position = Vector3(row.anchor) + bob
	var on_saucer := Vector3(row.anchor) + bob + Vector3.UP * 0.008 * grow
	# The cup: on the saucer, up before her muzzle, to her lips for each sip (tipped toward her),
	# and back down.
	var sip := IDLES.tea_sip(t)
	var held := Vector3(row.hold) + bob
	var up := smoothstep(IDLES.TEA_LIFT.x, IDLES.TEA_LIFT.y, t) * (1.0 - smoothstep(IDLES.TEA_DOWN.x, IDLES.TEA_DOWN.y, t))
	var tip := deg_to_rad(55.0) * sip
	# Upright, handle to her right, its top tipped back toward her by `tip`.
	var cup_up := (Vector3.UP * cos(tip) - forward * sin(tip)).normalized()
	var basis := Basis(right, cup_up, right.cross(cup_up)).orthonormalized()
	var want := on_saucer.lerp(held, up)
	if sip > 0.0:
		# Its rim (the side nearest her) at her lips.
		var lips := _mouth_at(pony) - forward * 0.025 * size + Vector3.DOWN * 0.01 * size
		var rim := basis * (TEA.rim_point(basis.inverse() * -forward) * grow)
		want = held.lerp(lips - rim, sip)
	var step := 1.0 - exp(-get_physics_process_delta_time() / 0.08)
	var now: Vector3 = (cup as Node3D).get_meta("idle_life_at", want)
	now = now.lerp(want, step)
	(cup as Node3D).set_meta("idle_life_at", now)
	(cup as Node3D).global_basis = basis.scaled(Vector3.ONE * grow)
	(cup as Node3D).global_position = now
	# Her eyes on the cup, easing to straight ahead for each sip: a gaze on a cup at her lips would
	# pull her head down after it, and letting go lets her head wander off mid-sip.
	var eye: Variant = row.get("gaze_eye")
	if eye is Node3D and is_instance_valid(eye) and pony.has_method("set_action_gaze"):
		(eye as Node3D).global_position = (now + cup_up * TEA.CUP_HEIGHT * grow).lerp(Vector3(row.ahead), sip)
		if pony.get("action_gaze_target") != eye: pony.call("set_action_gaze", eye)


# ---------------------------------------------------------------- the shoe check

## The shoe check, moment by moment: her hoof lifts, her horn lights, the shoe slides off its
## hoof in her magic (her body mesh swapped for one without it, a loose copy drawn instead),
## comes up before her face, turns upside down and is shaken (a pebble drops out and falls to
## the ground), turns back, goes back onto her hoof and her own mesh is swapped back in.
func _move_shoe(pony: Node3D, row: Dictionary, fade: float) -> void:
	var magic: Variant = pony.get("magic")
	var near: Variant = row.get("near")
	var sk: Variant = row.get("body_sk")
	if not is_instance_valid(near) or not is_instance_valid(sk): return
	var t := float(row.time)
	var size := _size(pony)
	var leg: String = row.leg
	var has_magic: bool = magic != null and is_instance_valid(magic)
	if not row.has("forward") or t < 0.1:
		var forward := _bone_at(pony, "pony_head") - _bone_at(pony, "pony_hips")
		forward.y = 0.0
		forward = forward.normalized() if not forward.is_zero_approx() else -pony.global_basis.z.normalized()
		row.forward = forward
		# Up beside her muzzle on the lifted leg's side, clear of the mane hanging before her chest.
		var beside := Vector3.UP.cross(-forward).normalized() * float(row.side)
		row.beside = beside
		row.present = _bone_at(pony, "pony_head") + forward * 0.26 * size + beside * 0.2 * size + Vector3.DOWN * 0.05 * size
	var forward: Vector3 = row.forward
	var right := Vector3.UP.cross(-forward).normalized()
	var colour: Color = (magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")) if has_magic else Color.WHITE
	var hoof := SHOE.on_hoof(sk, leg)
	var eye: Variant = row.get("gaze_eye")
	var looking_at := hoof.origin
	var off := t >= IDLES.SHOE_OFF.x and t < IDLES.SHOE_ON and fade > 0.5
	if off and not row.has("loose") and not bool(row.get("back", false)):
		var loose := SHOE.loose_shoe(near, sk, leg)
		if loose == null: return
		(pony.get_parent() if pony.get_parent() != null else pony).add_child(loose)
		loose.global_transform = hoof
		(near as MeshInstance3D).mesh = row.without
		row.loose = loose
		if has_magic:
			magic.call("hold", true)
			row.lit = true
			var aura: Node3D = MAGIC_AURA.create(loose, magic.get("color"), 1.0, 0.07 * size)
			row.glows = [aura] if aura != null else []
	if row.has("loose") and not off:
		# Back on her hoof: her own mesh again.
		row.back = true
		var on_at: Vector3 = (row.loose as Node3D).global_position if is_instance_valid(row.loose) else hoof.origin
		_drop_scroll(pony, row)
		if has_magic:
			var flash := Node3D.new()
			flash.name = "IdleLifeSpark"
			(pony.get_parent() if pony.get_parent() != null else pony).add_child(flash)
			flash.global_position = on_at
			UNICORN_MAGIC.burst(flash, Vector3.ZERO, colour, 0.8, 0.05 * size)
			row.sparks = row.get("sparks", []) + [[flash, t, 0.0]]
	var loose: Variant = row.get("loose")
	if loose is Node3D and is_instance_valid(loose):
		# Off along the hoof's length (its bone's +Y runs toward the tip of her hoof).
		var slid := hoof
		slid.origin += hoof.basis.y.normalized() * 0.07 * size * smoothstep(IDLES.SHOE_OFF.x, IDLES.SHOE_OFF.y, t)
		# Held up before her: sole down; upside down: sole up.
		var upright := Basis(right, Vector3.DOWN, right.cross(Vector3.DOWN)).orthonormalized()
		var flip := smoothstep(IDLES.SHOE_FLIP.x, IDLES.SHOE_FLIP.y, t) * (1.0 - smoothstep(IDLES.SHOE_UNFLIP.x, IDLES.SHOE_UNFLIP.y, t))
		var held := Basis(right, PI * flip) * upright
		var shake := smoothstep(IDLES.SHOE_SHAKE.x, IDLES.SHOE_SHAKE.x + 0.15, t) * (1.0 - smoothstep(IDLES.SHOE_SHAKE.y - 0.15, IDLES.SHOE_SHAKE.y, t))
		var present: Vector3 = Vector3(row.present) + Vector3.UP * sin(t * 34.0) * 0.014 * size * shake
		held = Basis(forward, sin(t * 34.0 + 1.0) * 0.12 * shake) * held
		var going := smoothstep(IDLES.SHOE_UP.x, IDLES.SHOE_UP.y, t) * (1.0 - smoothstep(IDLES.SHOE_BACK.x, IDLES.SHOE_BACK.y, t))
		var from := slid if t < IDLES.SHOE_BACK.x else hoof
		var scale := hoof.basis.get_scale()
		var q := Quaternion(from.basis.orthonormalized()).slerp(Quaternion(held.orthonormalized()), going)
		# Down away from her hoof, swung well out to her side (clear of her chest, her other leg and
		# the mane hanging over her side), then up beside her muzzle; back the same way.
		var path := _shoe_path(pony, row, from.origin, present, going)
		(loose as Node3D).global_transform = Transform3D(Basis(q).scaled(scale), path)
		looking_at = (loose as Node3D).global_position
		# The pebble.
		if t >= IDLES.SHOE_PEBBLE and not row.has("pebble"):
			var pebble := MeshInstance3D.new()
			pebble.name = "IdleLifePebble"
			var ball := SphereMesh.new()
			ball.radius = 0.009 * size
			ball.height = 0.014 * size
			pebble.mesh = ball
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.48, 0.45, 0.42)
			pm.roughness = 0.9
			pebble.material_override = pm
			(pony.get_parent() if pony.get_parent() != null else pony).add_child(pebble)
			pebble.global_position = (loose as Node3D).global_position
			pebble.set_meta("fall", 0.0)
			row.pebble = pebble
	var pebble: Variant = row.get("pebble")
	if pebble is Node3D and is_instance_valid(pebble):
		var dt := get_physics_process_delta_time()
		var v := float((pebble as Node3D).get_meta("fall")) + 9.8 * dt
		var floor := pony.global_position.y + 0.006 * size
		var at := (pebble as Node3D).global_position
		at.y = maxf(at.y - v * dt, floor)
		(pebble as Node3D).set_meta("fall", v if at.y > floor else 0.0)
		(pebble as Node3D).global_position = at
	if eye is Node3D and is_instance_valid(eye) and pony.has_method("set_action_gaze"):
		(eye as Node3D).global_position = looking_at
		if pony.get("action_gaze_target") != eye: pony.call("set_action_gaze", eye)


# ---------------------------------------------------------------- the sun check

## Around sunrise or sunset: the sun low, just below or above the horizon.
func _sun_hours() -> bool:
	var clock := get_node_or_null("/root/TimeOfDay")
	if clock == null or not clock.has_method("sun_elevation"): return false
	var e := float(clock.sun_elevation())
	return e > IDLES.SUN_HOURS.x and e < IDLES.SUN_HOURS.y


func _sun_pony(pony: Node3D) -> bool:
	var identity: Variant = pony.get("identity")
	return _princess(pony) and identity != null and str(identity.get("id")) in IDLES.SUN_ONLY


func _moon_pony(pony: Node3D) -> bool:
	var identity: Variant = pony.get("identity")
	return _princess(pony) and identity != null and str(identity.get("id")) in IDLES.MOON_ONLY


## Around moonrise or moonset, with enough of the moon lit to be worth a look.
func _moon_hours() -> bool:
	var clock := get_node_or_null("/root/TimeOfDay")
	if clock == null or not clock.has_method("moon_direction") or not clock.has_method("moon_lit_fraction"): return false
	var e := (clock.call("moon_direction") as Vector3).y
	return e > IDLES.SUN_HOURS.x and e < IDLES.SUN_HOURS.y and float(clock.call("moon_lit_fraction")) >= IDLES.MOON_LIT


## Toward the sun (or, for `moon`, the moon) from here; a low southern sky when the clock can't say.
func _sun_dir(moon := false) -> Vector3:
	var clock := get_node_or_null("/root/TimeOfDay")
	var method := "moon_direction" if moon else "sun_direction"
	if clock != null and clock.has_method(method):
		var d: Vector3 = clock.call(method)
		if d.is_finite() and not d.is_zero_approx(): return d.normalized()
	return Vector3(0.0, 0.2, -1.0).normalized()


## The sun check, moment by moment: up in her own flight, she turns to face the sun, looks up at
## it, lights her horn (a cast and a soft burst rising toward it) with a squinting, pleased
## smile, then the flight lands her.
func _sun(pony: Node3D, row: Dictionary, fade: float) -> void:
	var t := float(row.time)
	var flight: Variant = row.get("flight")
	var flying: bool = flight != null and bool(flight.call("active"))
	var hovering: bool = flying and str(flight.get("state")) == "hover"
	if hovering and not row.has("hover_from"): row.hover_from = t
	var since := t - float(row.get("hover_from", INF))
	var sun := _sun_dir(str(row.idle) == "moon")
	# Turn to face it (by yaw only) while up.
	if flying:
		var flat := Vector3(sun.x, 0.0, sun.z)
		if not flat.is_zero_approx():
			var want := atan2(-flat.x, -flat.z)
			var step := 1.0 - exp(-get_physics_process_delta_time() / 0.5)
			pony.global_rotation.y = lerp_angle(pony.global_rotation.y, want, step)
	# Her eyes on the sun from when she's up until she starts down.
	var eye: Variant = row.get("gaze_eye")
	if eye is Node3D and is_instance_valid(eye) and pony.has_method("set_action_gaze"):
		if hovering:
			(eye as Node3D).global_position = _bone_at(pony, "pony_head") + sun * 30.0
			if pony.get("action_gaze_target") != eye: pony.call("set_action_gaze", eye)
		elif pony.get("action_gaze_target") == eye:
			pony.call("set_action_gaze", row.get("gaze_was") if is_instance_valid(row.get("gaze_was")) else null)
	# The horn.
	var magic: Variant = pony.get("magic")
	var glow := smoothstep(IDLES.SUN_GLOW.x, IDLES.SUN_GLOW.x + 0.4, since) * (1.0 - smoothstep(IDLES.SUN_GLOW.y - 0.4, IDLES.SUN_GLOW.y, since))
	if magic != null and is_instance_valid(magic) and since >= IDLES.SUN_GLOW.x and not bool(row.get("cast", false)):
		row.cast = true
		magic.call("cast", IDLES.SUN_GLOW.y - IDLES.SUN_GLOW.x)
		var colour: Color = magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")
		var holder := Node3D.new()
		holder.name = "IdleLifeSpark"
		(pony.get_parent() if pony.get_parent() != null else pony).add_child(holder)
		holder.global_position = _horn_tip(pony, magic)
		UNICORN_MAGIC.burst(holder, Vector3.ZERO, colour, 2.4, 0.1 * _size(pony))
		row.sparks = row.get("sparks", []) + [[holder, t, 0.0]]
	for spark: Variant in row.get("sparks", []):
		var holder: Variant = (spark as Array)[0]
		if not is_instance_valid(holder): continue
		var age := t - float((spark as Array)[1])
		(holder as Node3D).global_position = _horn_tip(pony, magic) + sun * (1.0 - exp(-age * 0.8)) * 0.8 * _size(pony)
		if age > 3.0: (holder as Node).queue_free()
	# A squint at the bright sun and a warm smile while she tends it.
	var up_there := smoothstep(0.0, 0.8, since) if hovering or since > 0.0 else 0.0
	_expression(pony, row, 0.6 * glow * fade, (0.35 * up_there * (1.0 if flying else 0.0) + 0.25 * glow) * fade)


## How far the shoe drops below her hoof, and swings out to her side, on its way up (metres at
## size 1).
const SHOE_DROP := 0.1
const SHOE_SWING := 0.4

## The shoe's way from her hoof (`u` 0) to beside her muzzle (`u` 1): down, out, then a rising
## curve in to beside her muzzle, each leg eased in and out.
func _shoe_path(pony: Node3D, row: Dictionary, hoof: Vector3, present: Vector3, u: float) -> Vector3:
	var size := _size(pony)
	var beside: Vector3 = row.beside
	var down := hoof + Vector3.DOWN * SHOE_DROP * size
	down.y = maxf(down.y, pony.global_position.y + 0.06 * size)
	var out := down + beside * SHOE_SWING * size
	if u < 0.22: return hoof.lerp(down, smoothstep(0.0, 0.22, u))
	if u < 0.5: return down.lerp(out, smoothstep(0.22, 0.5, u))
	var k := smoothstep(0.5, 1.0, u)
	# Up first, then in.
	var c1 := out + Vector3.UP * (present.y - out.y) * 0.75
	var c2 := present + beside * 0.15 * size
	return out.bezier_interpolate(c1, c2, present, k)


# ---------------------------------------------------------------- remembering

## The idles worth remembering: once one is RECORD_AT of the way through, it is written to the
## game's witnessed-events memory (world_context.record, kind "idle_life") for the pony herself
## and the ponies within WITNESS_RANGE metres, which the AI reads into their prompts. %s is her
## name, %p her/his. At most one per pony every RECORD_GAP seconds.
const RECORD := {
	"scroll": "%s conjured a scroll with %p magic, read it through and made it vanish again.",
	"write": "%s conjured a blank scroll and a quill with %p magic, wrote a short note, signed it and made it vanish.",
	"tea": "%s conjured a cup of tea with %p magic, sipped it and made the cup vanish.",
	"shoe": "%s took off one of %p shoes with %p magic, shook a pebble out of it and put it back on.",
	"sun": "%s flew up a little way at %t, faced the sun and lit %p horn toward it, then landed.",
	"moon": "%s flew up a little way as the moon sat low on the horizon, faced it and lit %p horn toward it, then landed.",
	"doze": "%s dozed off on %p hooves for a moment, then woke with a little start.",
}
const RECORD_AT := 0.45
const RECORD_GAP := 180.0
const WITNESS_RANGE := 10.0
## pony -> when her last idle was recorded (msec)
var _recorded: Dictionary = {}


func _record(pony: Node3D, row: Dictionary) -> void:
	row.recorded = true
	var line: String = RECORD.get(str(row.idle), "")
	var game: Variant = Mods.game
	if line.is_empty() or not is_instance_valid(game): return
	var memory: Variant = game.get("world_context")
	var director: Variant = game.get("director")
	if memory == null or director == null or not memory.has_method("record"): return
	var cast: Variant = director.get("characters")
	if not cast is Dictionary: return
	var id := ""
	for key: Variant in cast:
		if (cast[key] as Dictionary).get("node") == pony: id = str(key)
	if id.is_empty(): return
	var now := Time.get_ticks_msec()
	if now - int(_recorded.get(pony, -1000000000)) < int(RECORD_GAP * 1000.0): return
	var witnesses := [id]
	for key: Variant in cast:
		var other: Variant = (cast[key] as Dictionary).get("node")
		if other == pony or not other is Node3D or not is_instance_valid(other): continue
		if (other as Node3D).global_position.distance_to(pony.global_position) <= WITNESS_RANGE: witnesses.append(str(key))
	var identity: Variant = pony.get("identity")
	var name := str(identity.get("display_name")) if identity != null else id
	var his := "his" if identity != null and bool(identity.get("stallion")) else "her"
	var clock := get_node_or_null("/root/TimeOfDay")
	var when := "sunrise" if clock != null and float(clock.get("hours")) < 12.0 else "sunset"
	var text := line.replace("%s", name).replace("%p", his).replace("%t", when)
	if str(memory.call("record", "idle_life", text, witnesses, [id])).is_empty(): return
	_recorded[pony] = now
	if LAB_DEBUG: print("RECORDED ", id, " ", witnesses, " ", text)
