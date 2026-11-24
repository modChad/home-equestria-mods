extends RefCounted
## The idles, as turns over time. turns(idle, t, side) returns [bone, axis, degrees] for the
## moment `t` seconds in, axis "pitch" (about her right: + lifts a nose or swings a leg forward),
## "yaw" (about her up) or "roll" (about her forward). `side` (+1 / -1) picks the leg and the way
## she turns; the same idle mirrored. Each idle eases in and out of nothing by itself, so its
## first and last moments leave her as she was.

const LENGTH := {
	"stretch": 6.0,
	"stretch_deep": 6.0,
	"paw": 3.8,
	"doze": 10.0,
	"preen": 10.0,
	"magic_brush": 8.0,
	"look_round": 6.5,
	"wing_stretch": 7.0,
	"magic_sparkle": 6.0,
	"stargaze": 12.0,
	"scroll": 9.5,
	"tea": 9.4,
	"write": 13.6,
	"shoe": 8.4,
	"sun": 12.0,
	"moon": 12.0,
	"tippy_taps": 3.6,
	"mood_sad": 4.5,
	"mood_shy": 4.0,
	"mood_angry": 2.6,
	"mood_surprised": 2.4,
	"shake": 3.2,
	"hoof_fringe": 5.6,
	"hoof_hat": 5.0,
	"ear_scratch": 5.6,
	"graze": 7.0,
	"graze_magic": 8.8,
}
## Played only on a pony already sitting by herself (main.gd _sit_pick), never sat down for at
## random; forced (the lab, Idle Life Debug) she sits first. Earth ponies only.
const SEATED := ["ear_scratch"]
## Only earth ponies and pegasi (main.gd): unicorns and alicorns have the magic brush.
const HORNLESS := ["hoof_fringe", "hoof_hat"]
## Never picked at random (main.gd _choose): played when a pony gets excited, or when her AI gives
## her line one of MOODS' faces (main.gd _excitement).
const TRIGGERED := ["tippy_taps", "mood_sad", "mood_shy", "mood_angry", "mood_surprised"]
## Her AI's line face (face_poses.gd LINE_FACES) -> the mood reaction it starts (dev 2026-11-24).
const MOODS := {"sad": "mood_sad", "shy": "mood_shy", "angry": "mood_angry", "ponyrage": "mood_angry",
	"surprised": "mood_surprised", "fearful": "mood_surprised"}
## Not for Celestia and Luna (main.gd _choose): the full-body shake (dev 2026-11-24).
const NOT_SUN_MOON := ["shake"]
## Switched off: never picked at random, only played when forced (Idle Life Debug's `idle shake`).
## The shake read as a seizure in review (2026-11-24); see the idle_life notes.
const OFF := ["shake"]
## The tippy-taps' stomping (seconds): forehooves taking turns from TAPS.x to .y, each leg
## TAPS_RATE lifts a second (so twice that many stomps), from the reference GIF (about 6 a second).
const TAPS := Vector2(0.35, 3.0)
const TAPS_RATE := 3.0
## A stomp's shape, as parts of its cycle: up by .x, landing at .y (taps_stomp). Landing before
## half way, so one forehoof is always down.
const TAPS_STOMP := Vector2(0.2, 0.42)
## The little bounce after each landing, as a part of the full lift.
const TAPS_REBOUND := 0.12
## Each hind hoof lifts this much of a cycle after its diagonal forehoof.
const TAPS_HIND_LAG := 0.08
## How far her body drops with each landing (metres at size 1).
const TAPS_DROP := 0.012
## Only ponies with wings.
const WINGED := ["preen", "wing_stretch"]
## Only from a little before sunset to a little after sunrise (main.gd).
const NIGHT := ["doze", "stargaze"]
## She lies down or sits first (main.gd), then these play.
const RESTING := ["preen", "stargaze", "graze", "graze_magic"]
## Ponies with a horn: unicorns and alicorns.
const MAGIC := ["magic_sparkle"]
## Only ponies with a horn and a fringe (main.gd): unicorns and alicorns.
const HORNED := ["magic_brush"]
## The magic brush's beats (seconds): brush appears beside her face, fringe strokes from
## BRUSH_FRINGE.x to .y (BRUSH_STROKE seconds each), brush away.
const BRUSH_FRINGE := Vector2(1.2, 6.7)
const BRUSH_STROKE := 1.1
## Only the princesses (Celestia and Luna): they have a horn and a kingdom's letters to read.
const PRINCESS_ONLY := ["scroll", "tea", "write", "shoe", "sun", "moon"]
## The scroll's beats (seconds): it appears in a flash at SCROLL_SHOW.x and vanishes in one at
## .y; unrolls over SCROLL_OPEN, rolls back up over SCROLL_CLOSE; she reads its rows (one per
## SCROLL_LINE seconds) from SCROLL_READ, and nods once at SCROLL_NOD.
const SCROLL_SHOW := Vector2(0.9, 8.1)
const SCROLL_OPEN := Vector2(1.2, 2.3)
const SCROLL_CLOSE := Vector2(6.9, 7.8)
const SCROLL_READ := 2.5
const SCROLL_LINE := 1.0
const SCROLL_NOD := 6.55
## Tea's beats (seconds): cup and saucer appear in a flash at TEA_SHOW.x and vanish at .y; the
## cup lifts from the saucer to just before her muzzle over TEA_LIFT, comes to her lips for each
## of TEA_SIPS, and goes back down to the saucer over TEA_DOWN.
const TEA_SHOW := Vector2(0.8, 8.1)
const TEA_LIFT := Vector2(1.2, 2.2)
const TEA_SIPS := [Vector2(2.4, 3.8), Vector2(5.0, 6.2)]
const TEA_DOWN := Vector2(6.6, 7.5)
## Writing's beats (seconds): a blank scroll and a quill appear at WRITE_SHOW.x and vanish at .y;
## the scroll unrolls over WRITE_OPEN, the quill writes one row in each of WRITE_LINES (the last
## her signature), she nods at WRITE_NOD, and it rolls up over WRITE_CLOSE.
const WRITE_SHOW := Vector2(0.9, 12.5)
const WRITE_OPEN := Vector2(1.2, 2.2)
## Before each row the quill dips into the inkwell (where there is one) over WRITE_DIPS.
const WRITE_DIPS := [Vector2(2.3, 3.2), Vector2(4.6, 5.5), Vector2(6.9, 7.8), Vector2(9.2, 10.1)]
const WRITE_LINES := [Vector2(3.4, 4.5), Vector2(5.7, 6.8), Vector2(8.0, 9.1), Vector2(10.3, 10.9)]
const WRITE_NOD := 11.1
const WRITE_CLOSE := Vector2(11.6, 12.3)
## The shoe check's beats (seconds): a foreleg lifts over SHOE_LIFT; its shoe slides off in her
## magic over SHOE_OFF, comes up before her face over SHOE_UP, turns upside down over SHOE_FLIP,
## is shaken over SHOE_SHAKE (a pebble drops out at SHOE_PEBBLE), turns back over SHOE_UNFLIP,
## goes back to her hoof over SHOE_BACK and is on again at SHOE_ON; the hoof comes down over
## SHOE_DOWN.
const SHOE_LIFT := Vector2(0.3, 1.0)
const SHOE_OFF := Vector2(1.3, 1.7)
const SHOE_UP := Vector2(1.7, 2.9)
const SHOE_FLIP := Vector2(3.0, 3.4)
const SHOE_SHAKE := Vector2(3.4, 4.6)
const SHOE_PEBBLE := 3.85
const SHOE_UNFLIP := Vector2(4.7, 5.1)
const SHOE_BACK := Vector2(5.2, 6.5)
const SHOE_ON := 6.6
const SHOE_DOWN := Vector2(7.1, 7.8)
## The sun check: only around sunrise and sunset (SUN_HOURS, main.gd), and only Celestia (it's
## her sun). She takes off with the
## game's own flight (a hover SUN_ALTITUDE metres up, at size 1, for SUN_HOVER seconds), turns to
## face the sun, lights her horn over SUN_GLOW with a warm smile and squint, then lands. The idle
## ends when she is down (LENGTH is only its longest).
const SUN_ONLY := ["princess_celestia", "celestia"]
## The moon check: the same, for Luna and her moon, around moonrise and moonset (the moon's height
## within SUN_HOURS), and only when at least MOON_LIT of it is lit.
const MOON_ONLY := ["princess_luna", "luna"]
const MOON_LIT := 0.25
const SUN_ALTITUDE := 1.5
const SUN_HOVER := 5.0
## Sun height (sine of its elevation) she may tend it between: about -2 to 15 degrees.
const SUN_HOURS := Vector2(-0.035, 0.26)
const SUN_GLOW := Vector2(1.6, 4.4)
## Not for Celestia and Luna for now (main.gd): see MOD_IDEAS.md.
const NOT_PRINCESSES := ["preen", "wing_stretch"]
## The magic sparkle: the sparks drift up from her horn over these seconds (main.gd).
const SPARKS := Vector2(1.0, 4.4)
const LICK_START := 2.0
const LICK_SPOT := 5.0
const LICK_END := 7.6
const LICK_RATE := 1.4
## Her head turns toward the preened wing's side.
const LAB_HY := -1.0
## Idles whose hooves are put back on the ground every frame (idle_pose.gd _plant): hind hooves
## stay where they stood, forehooves are brought down to the ground.
const PLANTED := ["stretch", "stretch_deep"]
## The deep stretch: forelegs may swing past their joint limits, only as far as the reach needs
## (the light stretch keeps every joint inside them and tips her only as far as they allow).
const FREE_REACH := ["stretch_deep"]
## Bones turned past the game's joint limits (idle_pose.gd), per idle. The tippy-taps' forelegs
## and hind legs (dev 2026-11-23: override on): within the limits a hoof barely leaves the ground.
const LEG_BONES := ["pony_shoulder_L", "pony_shoulder_R", "pony_upperArm_L", "pony_upperArm_R",
	"pony_lowerArm_L", "pony_lowerArm_R", "pony_wrist_L", "pony_wrist_R", "pony_hand_L", "pony_hand_R",
	"pony_femur_L", "pony_femur_R", "pony_tibia_L", "pony_tibia_R", "pony_legLower_L", "pony_legLower_R",
	"pony_tarsal_L", "pony_tarsal_R", "pony_hoof_L", "pony_hoof_R"]
## The shake rolls her back further than the spine's limits (about 6 degrees) allow.
const FREE_BONES := {"tippy_taps": LEG_BONES, "mood_sad": LEG_BONES, "mood_shy": LEG_BONES,
	"mood_angry": LEG_BONES, "mood_surprised": LEG_BONES, "shake": ["pony_spine1", "pony_spine2", "pony_spine3"],
	"hoof_fringe": LEG_BONES, "hoof_hat": LEG_BONES, "ear_scratch": LEG_BONES, "graze": LEG_BONES}
## And her neck and head for the hoof forelock sweep (idle_pose.gd checks both lists).
const FREE_NECK := {"hoof_fringe": ["pony_neck1", "pony_neck2", "pony_head"], "hoof_hat": ["pony_neck1", "pony_neck2", "pony_head"],
	"ear_scratch": ["pony_neck1", "pony_neck2", "pony_head", "pony_spine1", "pony_spine2", "pony_spine3", "pony_flank_L", "pony_flank_R"],
	"graze": ["pony_neck1", "pony_neck2", "pony_head", "pony_spine1", "pony_spine2", "pony_spine3"]}
## Played instead of the light stretch half the time (main.gd).
const VARIANTS := {"stretch": "stretch_deep"}
## Turns that follow how far she tips (idle_pose.gd tip_trim): the body tip itself and what
## balances it.
const TIP_BONES := ["pony_hips", "pony_flank_L", "pony_flank_R", "pony_neck1", "pony_neck2", "pony_head"]
## Degrees above level each wing's drawn tip is held in the stretch, seen from in front or behind:
## with the feathers' sweep the wings read as about 45 degrees (a wide V, well apart).
const WING_ANGLE := 37.0


static func length(idle: String) -> float:
	return float(LENGTH.get(idle, 0.0))


## 0 -> 1 over `rise` seconds, held, back to 0 over the last `fall` seconds.
static func envelope(t: float, total: float, rise: float, fall: float) -> float:
	return smoothstep(0.0, rise, t) * (1.0 - smoothstep(total - fall, total, t))


static func turns(idle: String, t: float, side: float, pony: Node = null) -> Array:
	var leg := "_R" if side > 0.0 else "_L"
	match idle:
		"stretch", "stretch_deep": return _stretch(t, side)
		"paw": return _paw(t, side, leg)
		"preen": return _preen(t, side)
		"magic_brush": return _magic_brush(t, side)
		"doze": return _doze(t, side, leg)
		"look_round": return _look_round(t, side)
		"wing_stretch": return _wing_stretch(t, side)
		"magic_sparkle": return _magic_sparkle(t, side)
		"stargaze": return _stargaze(t, side)
		"scroll": return _scroll(t, side)
		"tea": return _tea(t, side)
		"write": return _write(t, side)
		"shoe": return _shoe(t, side)
		"tippy_taps": return _tippy_taps(t, side)
		"mood_sad": return _mood_sad(t, side, leg)
		"mood_shy": return _mood_shy(t, side, leg)
		"mood_angry": return _mood_angry(t, side, leg)
		"mood_surprised": return _mood_surprised(t, side)
		"shake": return _shake(t, side)
		"hoof_fringe": return _hoof_fringe(t, side, leg)
		"hoof_hat": return _hoof_hat(t, side, leg)
		"ear_scratch": return _ear_scratch(t, side, leg)
		"graze": return _graze(t, side, leg, pony != null and pony.scene_file_path.contains("/princesses/"))
		"graze_magic": return _graze_magic(t, side)
	return []


## Excited tippy-taps (references/hoof stompies.gif): the forehooves stomp in turn, quick and
## light, each with its diagonal hind hoof, her chest bobbing with each stomp and swaying onto the planted leg, head up and tilted.
## Face (eyes squeezed shut, big grin) and tail: main.gd.
static func _tippy_taps(t: float, side: float) -> Array:
	var total := float(LENGTH.tippy_taps)
	var e := envelope(t, total, 0.35, 0.6)
	var go := _taps_go(t)
	var out: Array = []
	var sway := 0.0
	for i in 2:
		var leg := "_R" if (i == 0) == (side > 0.0) else "_L"
		# Each leg half a cycle after the other (TAPS_STOMP: up, slam down, a little rebound).
		var lift := taps_stomp(_taps_cycle(t, 0.5 * i)) * go
		# Knee up, hoof tucked back under it (past the game's joint limits: FREE_BONES).
		out.append(["pony_upperArm" + leg, "pitch", 12.0 * lift])
		out.append(["pony_lowerArm" + leg, "pitch", 50.0 * lift])
		out.append(["pony_wrist" + leg, "pitch", -65.0 * lift])
		# The diagonal hind leg taps a beat (TAPS_HIND_LAG) after it, a little smaller: hock bent,
		# hoof lifted under her, so the stomp ripples back through her body.
		var hind := "_L" if leg == "_R" else "_R"
		var back := taps_stomp(_taps_cycle(t, 0.5 * i - TAPS_HIND_LAG)) * go
		out.append(["pony_femur" + hind, "pitch", -16.0 * back])
		out.append(["pony_tibia" + hind, "pitch", 8.0 * back])
		out.append(["pony_legLower" + hind, "pitch", 48.0 * back])
		out.append(["pony_tarsal" + hind, "pitch", -48.0 * back])
		out.append(["pony_hoof" + hind, "pitch", -8.0 * back])
		sway += lift * (1.0 if leg == "_R" else -1.0)
	# Chest and head dip with each landing (her body drops too: hips_shift), weight onto the planted leg.
	var dip := taps_dip(t)
	out.append(["pony_spine3", "pitch", -2.5 * dip])
	out.append(["pony_spine3", "roll", 3.0 * sway])
	out.append(["pony_neck1", "pitch", 6.0 * e - 4.0 * dip])
	out.append(["pony_neck2", "pitch", 3.0 * e])
	out.append(["pony_head", "pitch", 4.0 * e + 3.0 * dip])
	out.append(["pony_head", "roll", side * 7.0 * e])
	out.append(["pony_neck1", "yaw", side * 3.0 * e])
	return out


## The stomping's strength: eased in and out so the first and last lifts are smaller.
static func _taps_go(t: float) -> float:
	return smoothstep(TAPS.x - 0.1, TAPS.x + 0.25, t) * (1.0 - smoothstep(TAPS.y - 0.3, TAPS.y, t))


## Where a leg is in its stomp (0..1), `offset` cycles behind or ahead.
static func _taps_cycle(t: float, offset: float) -> float:
	return fposmod((t - TAPS.x) * TAPS_RATE + offset, 1.0)


## One stomp's lift (0..1) over its cycle `u`: up eased over the first TAPS_STOMP.x, held a moment,
## slammed down (speeding up) to land at TAPS_STOMP.y, a small rebound, then still.
static func taps_stomp(u: float) -> float:
	var up := TAPS_STOMP.x
	var land := TAPS_STOMP.y
	if u < up: return smoothstep(0.0, up, u)
	if u < land - 0.12: return 1.0
	if u < land:
		var k := (u - (land - 0.12)) / 0.12
		return 1.0 - k * k
	if u < land + 0.16: return TAPS_REBOUND * sin((u - land) / 0.16 * PI)
	return 0.0


## How far her body is dipped (0..1) after the latest forehoof landing.
static func taps_dip(t: float) -> float:
	var dip := 0.0
	for i in 2:
		var since := _taps_cycle(t, 0.5 * i) - TAPS_STOMP.y
		if since >= 0.0 and since < 0.3: dip = maxf(dip, sin(since / 0.3 * PI))
	return dip * _taps_go(t)


## Where her whole body is moved at `t` (idle_pose.gd moves her hips): metres at size 1, x to her
## right, y up, z forward. Her hooves go with it, so keep it small.
static func hips_shift(idle: String, t: float) -> Vector3:
	match idle:
		"tippy_taps": return Vector3(0.0, -TAPS_DROP * taps_dip(t), 0.0)
		"mood_angry": return Vector3(0.0, -0.018 * _angry_dip(t), 0.0)
		"mood_surprised":
			var hop := _surprise_hop(t)
			return Vector3(0.0, 0.03 * hop, -0.025 * _surprise_back(t))
	return Vector3.ZERO


## Sad (her AI's sad face): head and neck sink, a little slump, and one forehoof drags slowly
## forward and back across the ground twice. Face and ears: the AI's own face.
static func _mood_sad(t: float, side: float, leg: String) -> Array:
	var total := float(LENGTH.mood_sad)
	var e := envelope(t, total, 0.8, 1.0)
	var gate := smoothstep(1.3, 1.6, t) * (1.0 - smoothstep(3.4, 3.7, t))
	var k := fposmod((t - 1.4) / 1.1, 1.0)
	var lift := sin(k * PI) * gate
	return [
		["pony_neck1", "pitch", -14.0 * e],
		["pony_neck2", "pitch", -8.0 * e],
		["pony_head", "pitch", -8.0 * e],
		["pony_head", "roll", side * 4.0 * e],
		["pony_spine3", "pitch", -2.0 * e],
		["pony_upperArm" + leg, "pitch", 9.0 * sin(k * TAU) * gate],
		["pony_lowerArm" + leg, "pitch", 22.0 * lift],
		["pony_wrist" + leg, "pitch", -26.0 * lift],
	]


## Shy (her AI's shy face): head dips and turns away to one side, tilted, while one forehoof rubs
## the ground in three small scuffs, edging in toward the other.
static func _mood_shy(t: float, side: float, leg: String) -> Array:
	var total := float(LENGTH.mood_shy)
	var e := envelope(t, total, 0.6, 0.9)
	var gate := smoothstep(0.9, 1.1, t) * (1.0 - smoothstep(2.9, 3.1, t))
	var k := fposmod((t - 1.0) / 0.66, 1.0)
	var lift := sin(k * PI) * gate
	return [
		["pony_neck1", "pitch", -8.0 * e],
		["pony_head", "pitch", -12.0 * e],
		["pony_neck1", "yaw", side * 14.0 * e],
		["pony_head", "yaw", side * 6.0 * e],
		["pony_head", "roll", -side * 8.0 * e],
		["pony_upperArm" + leg, "pitch", 4.0 * lift],
		["pony_upperArm" + leg, "roll", -side * 4.0 * e],
		["pony_lowerArm" + leg, "pitch", 30.0 * lift],
		["pony_wrist" + leg, "pitch", -38.0 * lift],
	]


## Angry (her AI's angry or ponyrage face): head lowered as one forehoof comes up high, slammed down
## (her body dips with it), then a toss of the head up and to the side.
const ANGRY_STAMP := 0.62
static func _mood_angry(t: float, side: float, leg: String) -> Array:
	var total := float(LENGTH.mood_angry)
	var e := envelope(t, total, 0.3, 0.7)
	var lift := 0.0
	if t < 0.5: lift = smoothstep(0.12, 0.5, t)
	elif t < ANGRY_STAMP:
		var k := (t - 0.5) / (ANGRY_STAMP - 0.5)
		lift = 1.0 - k * k
	elif t < ANGRY_STAMP + 0.15: lift = 0.1 * sin((t - ANGRY_STAMP) / 0.15 * PI)
	var dip := _angry_dip(t)
	var toss := sin(clampf((t - 0.9) / 0.8, 0.0, 1.0) * PI)
	var low := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(0.8, 1.2, t))
	return [
		["pony_upperArm" + leg, "pitch", 18.0 * lift],
		["pony_lowerArm" + leg, "pitch", 65.0 * lift],
		["pony_wrist" + leg, "pitch", -70.0 * lift],
		["pony_spine3", "pitch", -3.0 * dip],
		["pony_neck1", "pitch", (-8.0 * low - 6.0 * dip + 14.0 * toss) * e],
		["pony_head", "pitch", 8.0 * toss * e],
		["pony_head", "roll", side * 12.0 * toss * e],
		["pony_neck1", "yaw", -side * 8.0 * toss * e],
	]


static func _angry_dip(t: float) -> float:
	return sin(clampf((t - ANGRY_STAMP) / 0.3, 0.0, 1.0) * PI)


## Surprised (her AI's surprised or fearful face): a little startled hop, all four hooves tucked as
## she pops up and lands a touch further back, head pulled up and back; then she settles.
static func _mood_surprised(t: float, _side: float) -> Array:
	var hop := _surprise_hop(t)
	var back := _surprise_back(t)
	var out: Array = []
	for s in ["_L", "_R"]:
		out.append(["pony_upperArm" + s, "pitch", 10.0 * hop])
		out.append(["pony_lowerArm" + s, "pitch", 35.0 * hop])
		out.append(["pony_wrist" + s, "pitch", -40.0 * hop])
		out.append(["pony_legLower" + s, "pitch", 20.0 * hop])
		out.append(["pony_tarsal" + s, "pitch", -20.0 * hop])
	out.append(["pony_neck1", "pitch", 12.0 * back])
	out.append(["pony_neck2", "pitch", 6.0 * back])
	out.append(["pony_head", "pitch", 6.0 * back])
	return out


## The surprised hop (0..1, up and down again) and how far she has drawn back (0..1, held, eased off).
static func _surprise_hop(t: float) -> float:
	return sin(clampf((t - 0.05) / 0.4, 0.0, 1.0) * PI)


static func _surprise_back(t: float) -> float:
	return smoothstep(0.05, 0.25, t) * (1.0 - smoothstep(0.8, 2.0, t))


## The full-body shake (a wet-dog shake; not for Celestia and Luna): head a little low, then a fast
## side-to-side roll that runs from her head back along her spine to her hips, and a last flick of
## the head. Eyes shut and tail flicks: main.gd.
const SHAKE := Vector2(0.5, 2.6)
const SHAKE_RATE := 5.5
static func _shake(t: float, side: float) -> Array:
	var total := float(LENGTH.shake)
	var brace := envelope(t, total, 0.4, 0.6)
	var s := shake_amount(t)
	var out: Array = [["pony_neck1", "pitch", -6.0 * brace]]
	# [bone, axis, degrees, lag in cycles]: the wave travels from her head back to her hips.
	for wave: Array in [["pony_head", "roll", 22.0, 0.0], ["pony_head", "yaw", 10.0, 0.05],
			["pony_neck2", "roll", 10.0, 0.05], ["pony_neck1", "yaw", 12.0, 0.1],
			["pony_spine3", "roll", 7.0, 0.2], ["pony_spine2", "roll", 7.0, 0.28],
			["pony_spine1", "roll", 6.0, 0.35], ["pony_hips", "roll", 5.0, 0.45]]:
		out.append([wave[0], wave[1], side * float(wave[2]) * s * sin((t * SHAKE_RATE - float(wave[3])) * TAU)])
	# A last quick flick of the head.
	var flick := smoothstep(2.6, 2.7, t) * (1.0 - smoothstep(2.9, 3.05, t))
	out.append(["pony_head", "roll", side * 10.0 * flick * sin(t * 8.0 * TAU)])
	return out


## How hard she is shaking (0..1).
static func shake_amount(t: float) -> float:
	return smoothstep(SHAKE.x, SHAKE.x + 0.3, t) * (1.0 - smoothstep(SHAKE.y - 0.4, SHAKE.y, t))


## The big stretch (the "downward pony"): her body tips forward about the hips so the chest
## goes down and her rump up on straight hind legs, head low looking ahead, deepening while held.
## The forelegs are not posed here: idle_pose.gd (PLANTED) keeps the hind hooves where they stood
## and reaches each foreleg out straight to the ground in front of her chest, so the forehooves
## slide forward as she sinks and back as she rises. Wings and tail: main.gd.
static func _stretch(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.stretch, 1.5, 1.4)
	var deepen := smoothstep(1.5, 4.0, t) * (1.0 - smoothstep(LENGTH.stretch - 1.4, LENGTH.stretch, t))
	var tip := (48.0 + 8.0 * deepen) * e
	var out := [["pony_hips", "pitch", -tip]]
	for s in ["_L", "_R"]:
		out.append(["pony_flank" + s, "pitch", tip])
		out.append(["pony_tibia" + s, "pitch", -4.0 * e])
	out.append(["pony_spine2", "pitch", 4.0 * e])
	out.append(["pony_spine3", "pitch", 4.0 * e])
	out.append(["pony_neck1", "pitch", 0.0 * e])
	out.append(["pony_neck2", "pitch", 2.0 * e])
	out.append(["pony_head", "pitch", (24.0 - 4.0 * deepen) * e])
	out.append(["pony_head", "roll", side * 4.0 * deepen * e])
	# Wings: idle_pose.gd sets them to WING_ANGLE (wing_lift).
	return out


## The stretch's wings (shown only on winged ponies, held open by main.gd): how far they are
## brought to WING_ANGLE (0..1), and the flutter added as the stretch peaks (degrees).
static func wing_lift(idle: String, t: float) -> Vector2:
	if not idle in ["stretch", "stretch_deep"]: return Vector2.ZERO
	var e := envelope(t, LENGTH.stretch, 1.5, 1.4)
	var flutter := sin(t * TAU * 7.0) * smoothstep(3.2, 3.6, t) * (1.0 - smoothstep(4.4, 4.8, t))
	return Vector2(e, 7.0 * flutter * e)


## How far the paw's elbow bends (degrees) at rest in the scrape.
static var PAW_BEND := 18.0
## Pawing the ground: one forehoof lifts and scrapes back three times, head low watching it.
static func _paw(t: float, side: float, leg: String) -> Array:
	var e := envelope(t, LENGTH.paw, 0.5, 0.6)
	# Three scrapes: each a lift forward then a drag back.
	var scrape := 0.0
	var cycle := clampf((t - 0.5) / 2.7, 0.0, 1.0) * 3.0
	if t > 0.5 and t < 3.2: scrape = sin(cycle * TAU)
	return [
		["pony_upperArm" + leg, "pitch", (16.0 + 14.0 * scrape) * e],
		# Bent the way the game's joint limits allow (+, up to 94 degrees): at -22..-32 the hoof
		# barely lifted, as the limit that way is -15 (2026-11-24, MODDING_NOTES.md).
		["pony_lowerArm" + leg, "pitch", (PAW_BEND + 12.0 * maxf(scrape, 0.0)) * e],
		["pony_wrist" + leg, "pitch", (-26.0 + 10.0 * scrape) * e],
		["pony_hand" + leg, "pitch", -10.0 * e],
		["pony_neck1", "pitch", -10.0 * e],
		["pony_neck2", "pitch", -6.0 * e],
		["pony_head", "pitch", -8.0 * e],
		["pony_neck1", "yaw", LAB_HY * side * 5.0 * e],
	]


## Preening a wing (held half open by main.gd): neck curled back to it, nose in the feathers,
## nuzzling.
static func _preen(t: float, side: float) -> Array:
	var total := float(LENGTH.preen)
	# The wing comes forward first, then her head goes to it; both leave in reverse.
	var wing := envelope(t, total, 1.0, 1.4)
	var head := smoothstep(0.6, 1.8, t) * (1.0 - smoothstep(total - 2.2, total - 1.0, t))
	var lick := _lick(t)
	# Two spots along the wing: in near the shoulder first, then further out.
	var spot := smoothstep(LICK_SPOT - 0.3, LICK_SPOT + 0.4, t)
	# The shake as the wing folds back.
	var shake := sin(t * TAU * 9.0) * smoothstep(total - 1.6, total - 1.4, t) * (1.0 - smoothstep(total - 1.0, total - 0.7, t))
	var base := "pony_WingBase" + ("_R" if side > 0.0 else "_L")
	# The wing itself is brought to her muzzle by idle_pose.gd (wing_amount); here only its shake.
	return [
		[base, "roll", -side * 10.0 * shake * wing],
		# Head round to the wing and down into it, licking.
		["pony_spine3", "yaw", LAB_HY * side * 6.0 * head],
		["pony_neck1", "yaw", LAB_HY * side * (24.0 + 4.0 * spot) * head],
		["pony_neck2", "yaw", LAB_HY * side * (22.0 + 4.0 * spot) * head],
		["pony_head", "yaw", LAB_HY * side * (20.0 + 3.0 * lick) * head],
		["pony_neck1", "pitch", (-8.0 - 4.0 * spot) * head],
		["pony_neck2", "pitch", -6.0 * head],
		["pony_head", "pitch", (-14.0 + 5.0 * lick) * head],
		["pony_head", "roll", side * 12.0 * head],
	]


## Brushing her fringe by magic (the brush itself is main.gd's): head tipped a little toward the
## brushed side and chin down to meet the strokes, nodding gently with them.
static func _magic_brush(t: float, side: float) -> Array:
	var total := float(LENGTH.magic_brush)
	var e := smoothstep(BRUSH_FRINGE.x - 0.8, BRUSH_FRINGE.x, t) * (1.0 - smoothstep(BRUSH_FRINGE.y, total - 0.4, t))
	var stroke := sin((t - BRUSH_FRINGE.x) * TAU / BRUSH_STROKE)
	return [
		["pony_neck2", "roll", side * 3.0 * e],
		["pony_head", "roll", side * (9.0 + 1.5 * stroke) * e],
		["pony_head", "pitch", (-7.0 + 2.0 * stroke) * e],
		["pony_head", "yaw", LAB_HY * -side * 4.0 * e],
	]


## Something catches her ear: ears up, then head and neck turn to look, a little tilt of
## curiosity, a second glance a bit further along, and back.
static func _look_round(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.look_round, 0.9, 1.2)
	var along := smoothstep(3.0, 3.6, t) * (1.0 - smoothstep(LENGTH.look_round - 1.4, LENGTH.look_round, t))
	var yaw := LAB_HY * side * (1.0 + 0.3 * along)
	return [
		["pony_spine3", "yaw", yaw * 6.0 * e],
		["pony_neck1", "yaw", yaw * 16.0 * e],
		["pony_neck2", "yaw", yaw * 14.0 * e],
		["pony_head", "yaw", yaw * 12.0 * e],
		["pony_neck1", "pitch", 4.0 * e],
		["pony_head", "pitch", 5.0 * e],
		["pony_head", "roll", -side * 6.0 * e * (1.0 - along)],
	]


## A wing stretch (both held open by main.gd): one wing raised and reached out with a quiver,
## her head turned away to give it room, then the other, then both fold.
static func _wing_stretch(t: float, side: float) -> Array:
	var out := []
	var total := float(LENGTH.wing_stretch)
	var turns := [[side, 1.0, 3.5], [-side, 3.4, 5.9]]
	var look := 0.0
	for turn: Array in turns:
		var s := float(turn[0])
		var a := float(turn[1])
		var b := float(turn[2])
		var e := smoothstep(a, a + 0.8, t) * (1.0 - smoothstep(b - 0.6, b, t))
		var quiver := sin(t * TAU * 8.0) * smoothstep(a + 0.8, a + 1.0, t) * (1.0 - smoothstep(b - 0.9, b - 0.6, t))
		var wing := "_R" if s > 0.0 else "_L"
		var raise := -1.0 if s > 0.0 else 1.0
		out.append(["pony_WingBase" + wing, "roll", raise * (24.0 + 3.0 * quiver) * e])
		out.append(["pony_WingBase" + wing, "pitch", -12.0 * e])
		# Her head turns away from the raised wing (toward it, the wing sweeps through her head).
		look -= s * e
	var head := envelope(t, total, 1.0, 1.0)
	out.append(["pony_neck1", "yaw", LAB_HY * look * 10.0 * head])
	out.append(["pony_neck2", "yaw", LAB_HY * look * 8.0 * head])
	out.append(["pony_head", "yaw", LAB_HY * look * 8.0 * head])
	out.append(["pony_head", "pitch", 4.0 * head])
	return out


## A little magic for the fun of it: sparks drift up from her horn (main.gd) and she watches them
## rise, head tipped up and a little to one side.
static func _magic_sparkle(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.magic_sparkle, 0.8, 1.2)
	var rise := smoothstep(SPARKS.x, SPARKS.y, t) * (1.0 - smoothstep(LENGTH.magic_sparkle - 1.2, LENGTH.magic_sparkle, t))
	return [
		["pony_neck1", "pitch", (2.0 + 6.0 * rise) * e],
		["pony_neck2", "pitch", 4.0 * rise * e],
		["pony_head", "pitch", (3.0 + 12.0 * rise) * e],
		["pony_head", "roll", side * 7.0 * e],
	]


## Stargazing, sitting (main.gd sits her down): head tipped back to the sky, drifting slowly
## from one patch of stars to another.
static func _stargaze(t: float, side: float) -> Array:
	var total := float(LENGTH.stargaze)
	var e := envelope(t, total, 1.8, 1.8)
	var drift := sin((t - 1.0) * 0.45) * side
	return [
		["pony_neck1", "pitch", 16.0 * e],
		["pony_neck2", "pitch", 10.0 * e],
		["pony_head", "pitch", 18.0 * e],
		["pony_neck1", "yaw", LAB_HY * drift * 8.0 * e],
		["pony_head", "yaw", LAB_HY * drift * 6.0 * e],
		["pony_head", "roll", drift * 3.0 * e],
	]


## How far the preened wing is brought to her muzzle (0..1): forward first, away last.
static func wing_amount(t: float) -> float:
	return envelope(t, LENGTH.preen, 1.0, 1.4)


## Each lick: the muzzle drawn along the feathers (0 -> 1 -> back), about 1.4 a second, from
## LICK_START until LICK_END, with a pause as she moves to the second spot.
static func _lick(t: float) -> float:
	if t < LICK_START or t > LICK_END or absf(t - LICK_SPOT) < 0.35: return 0.0
	var phase := fposmod((t - LICK_START) * LICK_RATE, 1.0)
	return smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.45, 0.9, phase))


## The tongue's weight for a lick (main.gd): out as the muzzle draws along, back in between.
static func tongue(t: float) -> float:
	if t < LICK_START or t > LICK_END or absf(t - LICK_SPOT) < 0.35: return 0.0
	var phase := fposmod((t - LICK_START) * LICK_RATE, 1.0)
	return smoothstep(0.05, 0.25, phase) * (1.0 - smoothstep(0.55, 0.75, phase))


## Dozing on her feet: head sinks slowly, one hind hoof cocked to rest on its toe; near the end a
## little start as she catches herself, then she settles back up.
static func _doze(t: float, side: float, leg: String) -> Array:
	var total := float(LENGTH.doze)
	var sink := smoothstep(0.0, 4.5, t) * (1.0 - smoothstep(total - 1.5, total, t))
	# The start: at 7 s her head bobs up quickly, then sinks again a little.
	var start := smoothstep(6.9, 7.1, t) * (1.0 - smoothstep(7.1, 8.0, t))
	var head := sink * (1.0 - 0.7 * start)
	var rest := envelope(t, total, 1.5, 1.2)
	return [
		["pony_neck1", "pitch", -16.0 * head],
		["pony_neck2", "pitch", -8.0 * head],
		["pony_head", "pitch", -10.0 * head],
		["pony_head", "roll", side * 4.0 * head],
		["pony_tibia" + leg, "pitch", 10.0 * rest],
		["pony_legLower" + leg, "pitch", 26.0 * rest],
		["pony_tarsal" + leg, "pitch", -14.0 * rest],
		["pony_hoof" + leg, "pitch", -30.0 * rest],
	]


## Reading a scroll held in her magic: head a little down toward it, a small nod at the end of
## what she reads. Her eyes and the head's turn follow the writing (main.gd: her attention).
static func _scroll(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.scroll, 1.0, 1.3)
	var nod := smoothstep(SCROLL_NOD, SCROLL_NOD + 0.25, t) * (1.0 - smoothstep(SCROLL_NOD + 0.25, SCROLL_NOD + 0.6, t))
	return [
		["pony_neck1", "pitch", -5.0 * e],
		["pony_neck2", "pitch", -3.0 * e],
		["pony_head", "pitch", (-6.0 - 8.0 * nod) * e],
	]


## How far into a sip she is (0 cup held before her .. 1 at her lips, tipped).
static func tea_sip(t: float) -> float:
	var k := 0.0
	for sip: Vector2 in TEA_SIPS:
		k = maxf(k, smoothstep(sip.x, sip.x + 0.5, t) * (1.0 - smoothstep(sip.y - 0.45, sip.y, t)))
	return k


## Tea: head a little down toward the cup, then up a touch for each sip as it tips.
static func _tea(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.tea, 1.0, 1.2)
	var sip := tea_sip(t)
	return [
		["pony_neck1", "pitch", -4.0 * e],
		["pony_head", "pitch", (-5.0 + 9.0 * sip) * e],
	]


## How far the quill has written along each row (x, y, z, w: rows 0..3), 0..1.
static func write_progress(t: float) -> Vector4:
	var done := Vector4()
	for i in WRITE_LINES.size():
		var row: Vector2 = WRITE_LINES[i]
		done[i] = clampf((t - row.x) / (row.y - row.x), 0.0, 1.0)
	return done


## Writing: head a little down toward the scroll, a small nod at the end (her signature).
static func _write(t: float, side: float) -> Array:
	var e := envelope(t, LENGTH.write, 1.0, 1.3)
	var nod := smoothstep(WRITE_NOD, WRITE_NOD + 0.25, t) * (1.0 - smoothstep(WRITE_NOD + 0.25, WRITE_NOD + 0.6, t))
	return [
		["pony_neck1", "pitch", -6.0 * e],
		["pony_neck2", "pitch", -3.0 * e],
		["pony_head", "pitch", (-7.0 - 8.0 * nod) * e],
	]


## The shoe check: one foreleg folded up and back so the sole of her hoof faces behind her (as a
## farrier holds it), held while the shoe is off.
static func _shoe(t: float, side: float) -> Array:
	var leg := "_R" if side > 0.0 else "_L"
	var up := smoothstep(SHOE_LIFT.x, SHOE_LIFT.y, t) * (1.0 - smoothstep(SHOE_DOWN.x, SHOE_DOWN.y, t))
	return [
		["pony_upperArm" + leg, "pitch", 8.0 * up],
		["pony_lowerArm" + leg, "pitch", -85.0 * up],
		["pony_wrist" + leg, "pitch", -45.0 * up],
		["pony_hand" + leg, "pitch", -15.0 * up],
	]


## Hoof forelock sweep (dev 2026-11-24; earth ponies and pegasi): her head dips and turns toward
## the side her forelock falls (main.gd picks `side`; a random one when it falls evenly), the
## forehoof on that side comes up to her brow and sweeps the forelock out of her eyes twice, then
## the hoof goes down and her head comes back up with a little settling shake. Neutral face.
## Past the neck's and legs' joint limits (FREE_BONES): a hoof cannot reach her head otherwise.
## FRINGE_POSE: [neck1 pitch, neck2 pitch, head pitch, neck yaw, head roll, upperArm pitch,
## lowerArm pitch, wrist pitch, upperArm roll in, sweep roll out] (degrees), tuned in the lab.
static var FRINGE_POSE := PackedFloat32Array([-16.0, -16.0, -14.0, -6.0, 4.0, 122.0, 15.0, -20.0, -5.0, 10.0])
## Beats (seconds): head down and hoof up over FRINGE_UP, sweeps over FRINGE_SWEEPS, back down
## over FRINGE_DOWN, the settle shake over FRINGE_SETTLE.
const FRINGE_UP := Vector2(0.2, 1.4)
const FRINGE_SWEEPS := Vector2(1.5, 3.9)
const FRINGE_DOWN := Vector2(4.0, 4.9)
const FRINGE_SETTLE := Vector2(4.7, 5.4)
static func _hoof_fringe(t: float, side: float, leg: String) -> Array:
	var q := FRINGE_POSE
	var head := fringe_tuck(t)
	var hoof := smoothstep(FRINGE_UP.x + 0.3, FRINGE_UP.y, t) * (1.0 - smoothstep(FRINGE_DOWN.x - 0.1, FRINGE_DOWN.y - 0.2, t))
	# Two sweeps: in toward the middle of her brow, then out past her eye, the head leaning into it.
	var sweep := 0.0
	if t > FRINGE_SWEEPS.x and t < FRINGE_SWEEPS.y:
		var k := (t - FRINGE_SWEEPS.x) / (FRINGE_SWEEPS.y - FRINGE_SWEEPS.x) * 2.0
		sweep = 0.5 - 0.5 * cos(fposmod(k, 1.0) * TAU)
	var settle := sin(clampf((t - FRINGE_SETTLE.x) / (FRINGE_SETTLE.y - FRINGE_SETTLE.x), 0.0, 1.0) * TAU * 2.0) * (1.0 - smoothstep(FRINGE_SETTLE.x, FRINGE_SETTLE.y, t))
	return [
		["pony_neck1", "pitch", q[0] * head],
		["pony_neck2", "pitch", q[1] * head],
		["pony_head", "pitch", q[2] * head],
		["pony_neck1", "yaw", side * (q[3] * head - 4.0 * sweep * head)],
		["pony_head", "roll", side * (q[4] * head + 3.0 * sweep * head) + side * 6.0 * settle],
		["pony_upperArm" + leg, "pitch", q[5] * hoof],
		["pony_lowerArm" + leg, "pitch", q[6] * hoof],
		["pony_wrist" + leg, "pitch", q[7] * hoof],
		["pony_upperArm" + leg, "roll", -side * (q[8] * hoof - q[9] * sweep * hoof)],
	]


## How much the hoof forelock sweep's hoof aims at her forelock (idle_pose.gd _reach_hoof): in
## once the hoof is up, out before it comes down.
static func fringe_reach(t: float) -> float:
	return smoothstep(FRINGE_UP.y - 0.5, FRINGE_UP.y, t) * (1.0 - smoothstep(FRINGE_DOWN.x - 0.1, FRINGE_DOWN.x + 0.3, t))


## How far down her forelock's stroke (0 top .. 1 brow) the hoof's sweep starts and ends up.
static var FRINGE_LOW := 0.6
## How far her head is tucked (0..1).
static func fringe_tuck(t: float) -> float:
	return smoothstep(FRINGE_UP.x, FRINGE_UP.y - 0.2, t) * (1.0 - smoothstep(FRINGE_DOWN.x, FRINGE_DOWN.y, t))


## How much the back of her mane follows her skull at the full tuck (main.gd: the hair link).
const FRINGE_FOLLOW := 0.8


## Reseating her hat (dev 2026-11-24; earth ponies and pegasi in a hat): the hoof forelock sweep's
## pose, but the hoof goes to the front of her hat's brim, tips it up and back (the hat moves with
## it where it can: main.gd), holds a moment, and tugs it back down into place; then a little nod.
## Beats (seconds): up over HAT_UP, tip over HAT_TIP, held until HAT_SEAT.x, reseated over
## HAT_SEAT, down over HAT_DOWN, the nod over HAT_NOD.
const HAT_UP := Vector2(0.2, 1.3)
const HAT_TIP := Vector2(1.4, 2.0)
const HAT_SEAT := Vector2(2.6, 3.2)
const HAT_DOWN := Vector2(3.4, 4.2)
const HAT_NOD := Vector2(4.0, 4.7)
## As FRINGE_POSE, with a deeper tuck: her hat sits higher than her forelock.
static var HAT_POSE := PackedFloat32Array([-28.0, -26.0, -20.0, -6.0, 4.0, 128.0, 10.0, -20.0, -5.0, 10.0])
static func _hoof_hat(t: float, side: float, leg: String) -> Array:
	var q := HAT_POSE
	var head := smoothstep(HAT_UP.x, HAT_UP.y - 0.2, t) * (1.0 - smoothstep(HAT_DOWN.x, HAT_DOWN.y, t))
	var hoof := smoothstep(HAT_UP.x + 0.3, HAT_UP.y, t) * (1.0 - smoothstep(HAT_DOWN.x - 0.1, HAT_DOWN.y - 0.2, t))
	var nod := sin(clampf((t - HAT_NOD.x) / (HAT_NOD.y - HAT_NOD.x), 0.0, 1.0) * PI)
	# Her head tips back a touch as the hat goes up, and dips into the tug down.
	var tip := hat_tip(t)
	return [
		["pony_neck1", "pitch", q[0] * head],
		["pony_neck2", "pitch", q[1] * head],
		["pony_head", "pitch", q[2] * head + 4.0 * tip * head - 5.0 * nod],
		["pony_neck1", "yaw", side * q[3] * head],
		["pony_head", "roll", side * q[4] * head],
		["pony_upperArm" + leg, "pitch", q[5] * hoof],
		["pony_lowerArm" + leg, "pitch", q[6] * hoof],
		["pony_wrist" + leg, "pitch", q[7] * hoof],
		["pony_upperArm" + leg, "roll", -side * q[8] * hoof],
	]


## How far her hat is tipped up (0..1): up over HAT_TIP, held, back down over HAT_SEAT.
static func hat_tip(t: float) -> float:
	return smoothstep(HAT_TIP.x, HAT_TIP.y, t) * (1.0 - smoothstep(HAT_SEAT.x, HAT_SEAT.y, t))


## How much the reseat's hoof aims at the brim (idle_pose.gd _reach_hoof).
static func hat_reach(t: float) -> float:
	return smoothstep(HAT_UP.y - 0.5, HAT_UP.y, t) * (1.0 - smoothstep(HAT_DOWN.x - 0.1, HAT_DOWN.x + 0.3, t))


## Ear scratch (dev 2026-11-24; earth ponies, only when already sitting): she leans away from one
## hind leg and tilts her head down toward it, the leg comes forward and up and the hoof scratches
## quickly behind that ear (aimed by idle_pose.gd's reach solver, main.gd), eyes squeezed shut and
## a hint of tongue; then the leg goes down and her head comes back up with a little ear shake.
## Beats (seconds): lean and tilt over SCRATCH_LEAN, leg up over SCRATCH_UP, scratching over
## SCRATCH (SCRATCH_RATE strokes a second), leg down over SCRATCH_DOWN.
const SCRATCH_LEAN := Vector2(0.2, 1.0)
const SCRATCH_UP := Vector2(0.6, 1.4)
const SCRATCH := Vector2(1.5, 3.8)
const SCRATCH_RATE := 5.0
const SCRATCH_DOWN := Vector2(3.9, 4.7)
## [neck1 pitch, neck1 yaw, head roll, head pitch, spine lean, femur pitch, tibia pitch,
## legLower pitch, tarsal pitch] (degrees): the approach before the reach solver.
static var SCRATCH_POSE := PackedFloat32Array([-55.0, -70.0, 60.0, -10.0, 14.0, 90.0, 0.0, 20.0, -20.0])
static func _ear_scratch(t: float, side: float, _leg: String) -> Array:
	var total := float(LENGTH.ear_scratch)
	var q := SCRATCH_POSE
	var lean := smoothstep(SCRATCH_LEAN.x, SCRATCH_LEAN.y, t) * (1.0 - smoothstep(SCRATCH_DOWN.x + 0.2, total - 0.3, t))
	var up := scratch_leg(t)
	var hind := "_R" if side > 0.0 else "_L"
	var settle := sin(clampf((t - (total - 1.0)) / 0.6, 0.0, 1.0) * TAU * 1.5) * (1.0 - smoothstep(total - 0.6, total - 0.2, t))
	return [
		["pony_neck1", "pitch", q[0] * lean],
		["pony_neck1", "yaw", side * q[1] * lean],
		["pony_head", "roll", side * q[2] * lean + side * 5.0 * settle],
		["pony_head", "pitch", q[3] * lean],
		# Her weight onto the other haunch.
		["pony_spine1", "roll", -side * q[4] * lean],
		["pony_spine3", "roll", -side * q[4] * 0.6 * lean],
		["pony_femur" + hind, "pitch", q[5] * up],
		["pony_tibia" + hind, "pitch", q[6] * up],
		["pony_legLower" + hind, "pitch", q[7] * up],
		["pony_tarsal" + hind, "pitch", q[8] * up],
	]


## How far the scratching leg is up (0..1).
static func scratch_leg(t: float) -> float:
	return smoothstep(SCRATCH_UP.x, SCRATCH_UP.y, t) * (1.0 - smoothstep(SCRATCH_DOWN.x, SCRATCH_DOWN.y, t))


## How hard she is scratching (0..1), and the stroke (-1..1) at `t`.
static func scratching(t: float) -> float:
	return smoothstep(SCRATCH.x - 0.1, SCRATCH.x + 0.2, t) * (1.0 - smoothstep(SCRATCH.y - 0.2, SCRATCH.y, t))


static func scratch_stroke(t: float) -> float:
	return sin((t - SCRATCH.x) * SCRATCH_RATE * TAU)


## Turns put on after the reach solver (idle_pose.gd), so they move the leg it has aimed: the
## ear scratch's strokes, the lower leg kicking quickly at the hock and stifle (SCRATCH_KICK
## degrees) so the hoof rakes up and down behind her ear.
const SCRATCH_KICK := Vector2(10.0, 16.0)
static func after_reach(idle: String, t: float, side: float) -> Array:
	if idle != "ear_scratch": return []
	var hind := "_R" if side > 0.0 else "_L"
	var k := scratch_stroke(t) * scratching(t)
	return [
		["pony_tibia" + hind, "pitch", SCRATCH_KICK.x * k],
		["pony_legLower" + hind, "pitch", SCRATCH_KICK.y * k],
	]


## Grazing (dev 2026-11-24; every pony, princesses included, only on grass: main.gd): lying down
## first (RESTING; standing, even past every limit, her mouth stops ~27 cm off the ground), her
## head goes down to the grass in front of her, she
## takes GRAZE_BITES nibbles (a quick tug up and back with each), lifts her head halfway and
## chews, looking about, then her head comes back up. Mouth and chewing sounds: main.gd.
## Beats (seconds): down over GRAZE_DOWN, a bite at each GRAZE_BITES, halfway up over GRAZE_LIFT,
## chewing over GRAZE_CHEW (GRAZE_CHEW_RATE chews a second), back up over GRAZE_UP.
const GRAZE_DOWN := Vector2(0.3, 1.5)
const GRAZE_BITES := [1.8, 2.4, 3.0]
const GRAZE_LIFT := Vector2(3.4, 4.2)
const GRAZE_CHEW := Vector2(3.6, 6.2)
const GRAZE_CHEW_RATE := 2.6
const GRAZE_UP := Vector2(6.1, 6.9)
## [neck1 pitch, neck2 pitch, head pitch, upperArm forward] (degrees) at the bottom; tuned in the
## lab so her mouth reaches the grass.
## [neck1, neck2, head pitch, forelegs forward, chest down] (degrees): a gentler neck than the
## first try (100-120 curled her head under), her nose reaching forward and down from the poll,
## her forelegs stretched out in front and her chest lowered toward them.
static var GRAZE_POSE := PackedFloat32Array([-60.0, -15.0, -25.0, 40.0, 24.0])
## Celestia and Luna lie with their heads higher.
static var GRAZE_POSE_TALL := PackedFloat32Array([-100.0, -15.0, -10.0, 45.0, 35.0])
static func _graze(t: float, side: float, leg: String, tall := false) -> Array:
	var q := GRAZE_POSE_TALL if tall else GRAZE_POSE
	var down := smoothstep(GRAZE_DOWN.x, GRAZE_DOWN.y, t) * (1.0 - 0.55 * smoothstep(GRAZE_LIFT.x, GRAZE_LIFT.y, t)) * (1.0 - smoothstep(GRAZE_UP.x, GRAZE_UP.y, t))
	var tug := 0.0
	for b: float in GRAZE_BITES: tug = maxf(tug, sin(clampf((t - b) / 0.35, 0.0, 1.0) * PI))
	var look := sin(clampf((t - GRAZE_LIFT.y) / (GRAZE_UP.x - GRAZE_LIFT.y), 0.0, 1.0) * PI)
	var chew := sin((t - GRAZE_CHEW.x) * GRAZE_CHEW_RATE * TAU) * graze_chewing(t)
	var out: Array = [
		["pony_neck1", "pitch", q[0] * down + 4.0 * tug],
		["pony_neck2", "pitch", q[1] * down],
		["pony_head", "pitch", q[2] * down + 6.0 * tug + 3.0 * chew],
		["pony_neck1", "yaw", side * 14.0 * look * down],
	]
	var stretch := smoothstep(GRAZE_DOWN.x - 0.2, GRAZE_DOWN.y, t) * (1.0 - smoothstep(GRAZE_UP.x, GRAZE_UP.y, t))
	for s in ["_L", "_R"]:
		out.append(["pony_upperArm" + s, "pitch", q[3] * stretch])
		out.append(["pony_lowerArm" + s, "pitch", -q[3] * 0.8 * stretch])
	for b in ["pony_spine1", "pony_spine2", "pony_spine3"]:
		out.append([b, "pitch", -q[4] / 3.0 * stretch])
	return out


## How hard she is chewing (0..1), and her jaw (0 shut .. 1 open) at `t`: a nibble at each bite,
## then the chewing.
static func graze_chewing(t: float) -> float:
	return smoothstep(GRAZE_CHEW.x, GRAZE_CHEW.x + 0.3, t) * (1.0 - smoothstep(GRAZE_CHEW.y - 0.3, GRAZE_CHEW.y, t))


static func graze_jaw(t: float) -> float:
	var jaw := 0.0
	for b: float in GRAZE_BITES: jaw = maxf(jaw, sin(clampf((t - b + 0.15) / 0.3, 0.0, 1.0) * PI))
	return maxf(jaw, (0.5 + 0.5 * sin((t - GRAZE_CHEW.x) * GRAZE_CHEW_RATE * TAU)) * graze_chewing(t) * 0.9)


## Celestia's and Luna's grazing (dev 2026-11-24, for a laugh): lying down, she plucks a tuft of
## grass with her magic (main.gd, tuft.gd), shakes the soil off it, floats it up and pops it into
## her mouth, then chews
## it with her eyes shut and a smile. Her head only dips to look at it and leans in to take it.
## Beats (seconds): the tuft pops out of the ground over TUFT_PLUCK, is shaken TUFT_SHAKES times
## over TUFT_SHAKE (the soil falling off it), floats to her mouth over TUFT_FLOAT, goes in over
## TUFT_POP (her jaw wide), and she chews over TUFT_CHEW.
const TUFT_PLUCK := Vector2(1.0, 1.5)
const TUFT_SHAKE := Vector2(1.6, 2.7)
const TUFT_SHAKES := 3
const TUFT_FLOAT := Vector2(2.8, 4.0)
const TUFT_POP := Vector2(4.0, 4.3)
const TUFT_CHEW := Vector2(4.4, 7.4)
static func _graze_magic(t: float, side: float) -> Array:
	var total := float(LENGTH.graze_magic)
	var look := smoothstep(0.3, 1.0, t) * (1.0 - smoothstep(TUFT_FLOAT.x, TUFT_FLOAT.y, t))
	var lean := sin(clampf((t - TUFT_FLOAT.y + 0.4) / 0.9, 0.0, 1.0) * PI)
	var chew := sin((t - TUFT_CHEW.x) * GRAZE_CHEW_RATE * TAU) * tuft_chewing(t)
	var pleased := envelope(t, total, 4.6, 1.0) * smoothstep(TUFT_CHEW.x, TUFT_CHEW.x + 0.4, t)
	return [
		["pony_neck1", "pitch", -14.0 * look - 6.0 * lean],
		["pony_head", "pitch", -16.0 * look + 4.0 * lean + 3.0 * chew + 6.0 * pleased],
		["pony_head", "roll", side * 6.0 * pleased],
	]


static func tuft_chewing(t: float) -> float:
	return smoothstep(TUFT_CHEW.x, TUFT_CHEW.x + 0.3, t) * (1.0 - smoothstep(TUFT_CHEW.y - 0.3, TUFT_CHEW.y, t))


## Her jaw (0..1): wide for the tuft going in, then the chewing.
static func tuft_jaw(t: float) -> float:
	var wide := smoothstep(TUFT_FLOAT.y - 0.5, TUFT_POP.x, t) * (1.0 - smoothstep(TUFT_POP.y, TUFT_POP.y + 0.15, t))
	return maxf(wide, (0.5 + 0.5 * sin((t - TUFT_CHEW.x) * GRAZE_CHEW_RATE * TAU)) * tuft_chewing(t) * 0.8)


## The tuft's shake (-1..1, side to side) and how much soil is left on it (1 .. 0, a third off
## with each shake).
static func tuft_shake(t: float) -> float:
	if t < TUFT_SHAKE.x or t > TUFT_SHAKE.y: return 0.0
	var k := (t - TUFT_SHAKE.x) / (TUFT_SHAKE.y - TUFT_SHAKE.x)
	return sin(k * TUFT_SHAKES * TAU) * sin(k * PI)


static func tuft_soil(t: float) -> float:
	var k := clampf((t - TUFT_SHAKE.x) / (TUFT_SHAKE.y - TUFT_SHAKE.x), 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, k)
