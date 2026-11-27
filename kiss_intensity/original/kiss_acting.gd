extends RefCounted
## Kiss intensity: the small acting of one returned kiss. Numbers only; ext/affection.gd applies
## them through the game's own controls (the kiss pose's target and facing, mouth shapes, lids,
## ear shapes). One per kissed pony, made when the kiss starts and dropped when it ends.
##
## Everything here is small, slow and irregular: cycle lengths, waits and depths are drawn anew
## each time, and the slow drifts are sums of waves that never line up, so nothing reads as a loop.
## Nothing here takes her lips off his: the lip target moves a few millimetres up or down his mouth and
## a few millimetres in; her head turns about her lips.

const KI := preload("res://mods/kiss_intensity/kiss_terms.gd")

## The lip cycle: her lips open a little, close over one of his lips, hold, let go. Seconds.
const CYCLE := Vector2(1.8, 2.5)
## Her lip target below or above his mouth (metres) for his lower or upper lip (x lower, y upper).
## Small, and smaller upward (critique 2026-11-25): a whole centimetre moved her nose to his eyes,
## the eye guard pushed her off his lips, and "his lower lip" landed on his chin.
const LIP_STEP := Vector2(0.004, 0.003)
## The slight press in while she holds his lip (metres).
const PRESS := 0.0025
## Her head's tilt with the lip she takes, and its slow drift on top (degrees).
const TILT_WITH_LIP := 3.0
const TILT_DRIFT := 1.5
const TURN_DRIFT := 1.6
## Lids at level 0 and at the top (0 open, 1 shut), and the least they close to in a look at him
## (half-lid, never wide open).
const LIDS := Vector2(0.42, 0.90)
const LIDS_LOOK := 0.5
## Fastest her lids open, lid units a second (0.4 from shut to half-lid takes about 0.7 s), and
## fastest they close (a soft close, not a snap).
const LIDS_OPEN_RATE := 0.6
const LIDS_CLOSE_RATE := 2.5
## Past this her lids close all the way (dev 2026-11-22: stopping at 90% left a slit at the bottom
## that looked weird; "she needs to close her eyes all the way past a certain point").
const LIDS_SHUT_FROM := 0.8
## Seconds between two eye events (a flutter, or a look up at him).
const EYE_WAIT := Vector2(4.0, 9.0)
const EAR_WAIT := Vector2(6.0, 14.0)
const EAR_SECONDS := 0.28
const SWALLOW_WAIT := Vector2(11.0, 19.0)
const SWALLOW_SECONDS := 0.55

var rng := RandomNumberGenerator.new()
var clock := 0.0

## Lip cycle. which: -1 his lower lip, +1 his upper lip.
var which := -1.0
var cycles := 0
var lower_cycles := 0
var upper_cycles := 0
var open := 0.0
var grip := 0.0
var lip_offset := 0.0
var press := 0.0
var tilt := 0.0 # Radians about his forward axis.
var turn := 0.0 # Radians about his up axis.
var nod := 0.0 # Radians about his right axis (the swallow).
var _cycle_time := 0.0
var _cycle_length := 2.1

## Eyes. look: 0..1, her eyes on his.
var lids := 0.42
var look := 0.0
var _eye_wait := 2.2
var _eye_event := ""
var _eye_time := 0.0
var _eye_length := 1.0
var _eye_depth := 0.3

## Small things.
var ear_shape := ""
var ear := 0.0
var swallow := 0.0
var _ear_wait := 5.0
var _ear_time := -1.0
var _swallow_wait := 9.0
var _swallow_time := -1.0

## How far the separate tongue is out, 0..1.
var tongue := 0.0
## Tongue kissing (dev 2026-11-22: a small tongue popping out for a second read as a "mlem"; it
## must be as wide as her mouth and work like tongue kissing does). From TONGUE_FROM the kiss
## goes through long open-mouthed stretches: her jaw works slowly, her mouth opens wide, her
## tongue stays with his, sliding deeper and back with each slow push, sweeping, rolling and
## curling. Between stretches she kisses with closed lips for a while. Seconds of each.
const TONGUE_STRETCH := Vector2(6.0, 10.0)
const LIPS_STRETCH := Vector2(2.5, 4.5)
## Seconds of one slow push of her jaw and tongue (the rhythm drifts inside this range).
const TONGUE_PUSH := Vector2(1.8, 2.6)
## Seconds the mouth takes to open into a stretch and close out of it.
const TONGUE_EASE := 0.9
## Seconds into the running stretch, -1 between stretches.
var tongue_time := -1.0
var tongue_stretches := 0
## Where her tongue tip is heading off its line: x across, y up, each -1..1 (slow, irregular).
var circle := Vector2.ZERO
## How far her jaw is open in a stretch, 0..1 (rises with each push), its roll (-1..1) and how
## far the tongue tip curls up (0..1).
var jaw := 0.0
var roll := 0.0
var curl := 0.0
var _tongue_wait := 1.2
var _tongue_length := 8.0
var _push := 0.0
var _push_length := 2.2


func _init() -> void:
	rng.seed = randi()
	_cycle_length = rng.randf_range(CYCLE.x, CYCLE.y)
	_eye_wait = rng.randf_range(1.5, 3.0)
	_ear_wait = rng.randf_range(EAR_WAIT.x, EAR_WAIT.y) * 0.6
	_swallow_wait = rng.randf_range(SWALLOW_WAIT.x, SWALLOW_WAIT.y) * 0.7


## A slow wander in -1..1 that does not repeat within a kiss.
static func drift(t: float) -> float:
	return 0.6 * sin(t * TAU) + 0.4 * sin(t * TAU * 1.618 + 1.3)


static func bump(u: float, rise: float, top: float, fall: float) -> float:
	return smoothstep(rise, top, u) * (1.0 - smoothstep(top, fall, u))


## Off: no drift of her head, no ear flick, no swallow, no press (the "small_motions" switch).
var small := true


## level: what her body shows now. together: her lips are on his. parted: 0..1, how far a
## breather has her lips off his. tongue_in: 0..1, how far a breather holds her tongue back.
## steady: her head is not in the middle of changing sides (a tongue stretch never starts then).
func tick(delta: float, level: float, together: bool, parted: float, tongue_in: float, steady := true) -> void:
	clock += delta
	var ease := 1.0 - exp(-delta / 0.3)
	var on_him := together and parted < 0.05
	if on_him:
		_cycle_time += delta
		if _cycle_time >= _cycle_length:
			_cycle_time -= _cycle_length
			_cycle_length = rng.randf_range(CYCLE.x, CYCLE.y)
			cycles += 1
			if which < 0.0: lower_cycles += 1
			else: upper_cycles += 1
			# Mostly the other lip next; now and then the same one again.
			if rng.randf() > 0.2: which = -which
		var p := _cycle_time / _cycle_length
		open = bump(p, 0.0, 0.20, 0.42)
		grip = smoothstep(0.24, 0.44, p) * (1.0 - smoothstep(0.78, 1.0, p))
	else:
		_cycle_time = 0.0
		open = move_toward(open, 0.0, delta * 2.0)
		grip = move_toward(grip, 0.0, delta * 2.0)
	var held := 1.0 - parted
	lip_offset = lerpf(lip_offset, (LIP_STEP.y if which > 0.0 else -LIP_STEP.x) * held if together else 0.0, ease)
	var wander := 1.0 if small else 0.0
	press = PRESS * grip * wander
	var slow := 1.0 - exp(-delta / 0.6)
	tilt = lerpf(tilt, deg_to_rad(which * TILT_WITH_LIP * held + TILT_DRIFT * drift(clock * 0.31) * wander) if together else 0.0, slow)
	turn = lerpf(turn, deg_to_rad(TURN_DRIFT * drift(clock * 0.19 + 2.0) * wander) if together else 0.0, slow)
	_eyes(delta, level)
	if small: _small(delta, on_him)
	else:
		ear = 0.0
		swallow = 0.0
		nod = 0.0
	# Tongue kissing: long open-mouthed stretches with closed-lip kissing between them.
	var may := together and steady and level >= KI.TONGUE_FROM and tongue_in < 0.5
	var out := 0.0
	var opened := 0.0
	if tongue_time < 0.0:
		if may: _tongue_wait -= delta
		if may and _tongue_wait <= 0.0:
			tongue_time = 0.0
			tongue_stretches += 1
			_tongue_length = rng.randf_range(TONGUE_STRETCH.x, TONGUE_STRETCH.y)
	else:
		tongue_time += delta
		var into := smoothstep(0.0, TONGUE_EASE, tongue_time) * (1.0 - smoothstep(_tongue_length - TONGUE_EASE, _tongue_length, tongue_time))
		# One slow push: jaw opens and her tongue slides deeper, then eases back a little.
		_push += delta / _push_length
		if _push >= 1.0:
			_push -= 1.0
			_push_length = rng.randf_range(TONGUE_PUSH.x, TONGUE_PUSH.y)
		var wave := 0.5 - 0.5 * cos(_push * TAU)
		opened = into
		out = into * (0.62 + 0.38 * wave) * (1.0 - tongue_in)
		jaw = into * (0.45 + 0.55 * wave)
		if tongue_time >= _tongue_length or not together or level < KI.TONGUE_FROM:
			tongue_time = -1.0
			_tongue_wait = rng.randf_range(LIPS_STRETCH.x, LIPS_STRETCH.y)
	if tongue_time < 0.0: jaw = move_toward(jaw, 0.0, delta * 1.5)
	# Slow and irregular: across, up, roll and curl wander, never a fast loop.
	circle = Vector2(drift(clock * 0.21 + 3.0), drift(clock * 0.27 + 7.0))
	roll = drift(clock * 0.17 + 11.0)
	curl = clampf(0.45 + 0.4 * drift(clock * 0.23 + 13.0), 0.0, 1.0)
	tongue = lerpf(tongue, out, 1.0 - exp(-delta / 0.25))
	# In a stretch the lip grip gives way to the open mouth.
	grip *= 1.0 - opened


## Half-lidded, drifting shut as the level rises. A flutter is a quick close and back, never an
## opening (dev 2026-11-22: lids fluttering open from half-lid, and lids sinking slowly to 90% then
## flying open, both read wrong). A look at him is rare, slow and only to half-lid: eased open over
## most of a second, held, eased shut again. Her lids never open faster than LIDS_OPEN_RATE.
func _eyes(delta: float, level: float) -> void:
	var base := lerpf(LIDS.x, LIDS.y, smoothstep(0.0, 0.85, level)) + 0.03 * drift(clock * 0.13 + 5.0)
	if base >= LIDS_SHUT_FROM: base = 1.0
	var opening := 0.0
	var closing := 0.0
	look = 0.0
	if _eye_event.is_empty():
		_eye_wait -= delta
		if _eye_wait <= 0.0:
			# She looks at him less often as her eyes close with the level.
			_eye_event = "look" if base < 1.0 and rng.randf() < lerpf(0.35, 0.12, level) else "flutter"
			_eye_time = 0.0
			_eye_length = rng.randf_range(2.4, 3.2) if _eye_event == "look" else rng.randf_range(0.55, 0.8)
			_eye_depth = rng.randf_range(0.6, 1.0)
	else:
		_eye_time += delta
		var u := _eye_time / _eye_length
		if _eye_event == "look":
			opening = maxf(0.0, base - LIDS_LOOK) * smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.62, 1.0, u))
			look = smoothstep(0.08, 0.32, u) * (1.0 - smoothstep(0.6, 0.92, u))
		else:
			# Two quick dips toward shut, the second smaller, back to where they were.
			closing = (1.0 - base) * _eye_depth * (bump(u, 0.0, 0.14, 0.34) + 0.6 * bump(u, 0.4, 0.54, 0.78))
		if u >= 1.0:
			_eye_event = ""
			_eye_wait = rng.randf_range(EYE_WAIT.x, EYE_WAIT.y)
	var goal := clampf(base - opening + closing, 0.12, 1.0)
	# Closing is soft but quick (a flutter's dip still reads); opening is always eased.
	lids = move_toward(lids, goal, (LIDS_CLOSE_RATE if goal > lids else LIDS_OPEN_RATE) * delta)


## A look at him now (the start of a breather).
func look_now() -> void:
	_eye_event = "look"
	_eye_time = 0.0
	_eye_length = rng.randf_range(2.6, 3.2)


## An ear flick and a small swallow, each on its own irregular wait.
func _small(delta: float, on_him: bool) -> void:
	if _ear_time < 0.0:
		ear = 0.0
		_ear_wait -= delta
		if _ear_wait <= 0.0:
			_ear_time = 0.0
			ear_shape = "ears_alert" if rng.randf() < 0.5 else "ears_side"
	else:
		_ear_time += delta
		ear = 0.8 * sin(PI * clampf(_ear_time / EAR_SECONDS, 0.0, 1.0))
		if _ear_time >= EAR_SECONDS:
			_ear_time = -1.0
			ear = 0.0
			_ear_wait = rng.randf_range(EAR_WAIT.x, EAR_WAIT.y)
	if _swallow_time < 0.0:
		swallow = 0.0
		# Only while she holds his lip, so it never falls on the open part of a cycle.
		if on_him: _swallow_wait -= delta
		if _swallow_wait <= 0.0 and grip > 0.9: _swallow_time = 0.0
	else:
		_swallow_time += delta
		swallow = sin(PI * clampf(_swallow_time / SWALLOW_SECONDS, 0.0, 1.0))
		if _swallow_time >= SWALLOW_SECONDS:
			_swallow_time = -1.0
			swallow = 0.0
			_swallow_wait = rng.randf_range(SWALLOW_WAIT.x, SWALLOW_WAIT.y)
	nod = deg_to_rad(-1.2) * swallow
