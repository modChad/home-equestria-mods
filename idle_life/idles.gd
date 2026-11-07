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
}
## Only ponies with wings.
const WINGED := ["preen", "wing_stretch"]
## Only from a little before sunset to a little after sunrise (main.gd).
const NIGHT := ["doze", "stargaze"]
## She lies down or sits first (main.gd), then these play.
const RESTING := ["preen", "stargaze"]
## Ponies with a horn: unicorns and alicorns.
const MAGIC := ["magic_sparkle"]
## Only ponies with a horn and a fringe (main.gd): unicorns and alicorns.
const HORNED := ["magic_brush"]
## The magic brush's beats (seconds): brush appears beside her face, fringe strokes from
## BRUSH_FRINGE.x to .y (BRUSH_STROKE seconds each), brush away.
const BRUSH_FRINGE := Vector2(1.2, 6.7)
const BRUSH_STROKE := 1.1
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


static func turns(idle: String, t: float, side: float) -> Array:
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
	return []


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


## Pawing the ground: one forehoof lifts and scrapes back three times, head low watching it.
static func _paw(t: float, side: float, leg: String) -> Array:
	var e := envelope(t, LENGTH.paw, 0.5, 0.6)
	# Three scrapes: each a lift forward then a drag back.
	var scrape := 0.0
	var cycle := clampf((t - 0.5) / 2.7, 0.0, 1.0) * 3.0
	if t > 0.5 and t < 3.2: scrape = sin(cycle * TAU)
	return [
		["pony_upperArm" + leg, "pitch", (16.0 + 14.0 * scrape) * e],
		["pony_lowerArm" + leg, "pitch", (-22.0 - 10.0 * maxf(scrape, 0.0)) * e],
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
