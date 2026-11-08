extends Node
## Kissing: hold K to kiss the pony in front of you, without carrying her first.
##
## The game already has a standing kiss (player/pony_kisser.gd), but it only starts once his mouth
## is within 5.5 cm of her face, which standing up in practice only happens while carrying her.
## This mod has the pony he faces walk up to him, he bends down to her if she is shorter, and starts
## the game's own kiss (PonyAffection.begin): her kiss pose reaches her lips to his. Whether she
## kisses back (relationship_runtime affection_allowed), the deep kiss once it is held DEEP_AFTER
## (0.6 s) with lips together, the forehead kiss for fillies and colts, turning away and bucking
## when unwelcome: all the game's.
##
## The kisser ends any kiss once her body (its root) is 1.8 m from his eyes, which isn't scaled with
## the pony size settings: at JRHNBR size and up her nose alone is further out than that. So for
## the kisses it starts this mod does the kisser's per-tick work itself (her target, his eye and
## facing, the near plane, the deep kiss holding him), with distances scaled to her size; the
## kisser still owns the K/X button (letting go, pressing again to end a deep kiss).
##
## Desktop: hold K. VR: lean in until your mouth is within LEAN_REACH of her lips for LEAN_SECONDS.
## Ponies within WITNESS_RANGE remember seeing the kiss (her own memory of it is the game's).

const REACH := 1.5 # Metres, flat, from his eyes to her nose (times her size above Canon).
const FACING := 0.82 # cos(35 deg): how squarely he must face her.
const APPROACH_SECONDS := 4.0 # Walking up, then her lips reaching his: each gets this long.
const CONTACT := 0.06 # Lips this close count as met (the game's own reach is 0.055).
const PULL_BACK := 0.2 # A light kiss ends once he draws back this far (as the kisser).
const KEEP := 1.8 # Her root to his eyes, metres at Canon size, past which a kiss ends.
const COME_NOSE := 0.38 # She walks up until her nose is this far (flat) from his eyes, at Canon size.
const COME_SPEED := 0.6
const LEAN_REACH := 0.08
const LEAN_SECONDS := 0.4
const LEAN_BREAK := 0.15
const WITNESS_RANGE := 10.0
const RECORD_GAP := 180.0
var LAB_DEBUG := false # Set by the lab (tools/_kiss_lab).

var _kisser: Node
var _after: Node
## A pony walking up to him before the kiss.
var _coming: Node3D
var _coming_time := 0.0
var _coming_still := 0.0
var _coming_last := Vector3.ZERO
var _nav_owner := ""
var _nav_wander := true
## The affection node of a kiss this mod started and drives.
var _mine: Node
var _met := false
var _mine_time := 0.0
var _vr_kiss := false
var _far := 0.0
## VR: the pony whose lips his are near, and for how long.
var _lean_pony: Node3D
var _lean_time := 0.0
## pony -> {"deep": bool} for a kiss under way, written to memory once it ends.
var _pending: Dictionary = {}
var _recorded: Dictionary = {}
var _hooked: Dictionary = {}


func _ready() -> void:
	# Before the kisser (-20): her kiss is hidden from it for its tick (so its unscaled checks
	# don't end it), then handed back by _after (-19), which does the kisser's work for it.
	process_physics_priority = -25
	_after = _helper("AfterKisser", "after_kisser", -19)
	# After her Affection (-5) steers her and before her body moves (0): a tall pony holds her ground.
	_helper("AfterAffection", "after_affection", -4)
	Mods.on_node("res://player/pony_kisser.gd", func(node: Node) -> void: _kisser = node)


## A child node whose physics tick, at `priority`, calls this node's `method`.
func _helper(node_name: String, method: String, priority: int) -> Node:
	var node := Node.new()
	node.name = node_name
	var script := GDScript.new()
	script.source_code = "extends Node\nvar host\nfunc _physics_process(d):\n\tif is_instance_valid(host): host.%s(d)\n" % method
	script.reload()
	node.set_script(script)
	node.process_physics_priority = priority
	node.set("host", self)
	add_child(node)
	return node


## A tall pony (reach.gd) bows to him instead of walking in once their lips meet: the kiss pose's
## steps toward him (pony_affection.gd _steer) would walk her chest into him, her head over his.
## She still turns.
func after_affection(_delta: float) -> void:
	# Before their lips meet she may still step in to reach him; after, she holds her ground.
	if not _met or not is_instance_valid(_reach) or not is_instance_valid(_mine) or _mine.get("_stepping") != true: return
	var mare: Node3D = _mine.get("mare")
	var camera: Camera3D = _kisser.get("camera") if is_instance_valid(_kisser) else null
	if not is_instance_valid(mare) or not is_instance_valid(camera): return
	var to := camera.global_position - mare.global_position
	to.y = 0.0
	if to.length() > 0.05 and mare.has_method("face_direction"): mare.face_direction(to.normalized())
	elif mare.has_method("stop"): mare.stop()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_kisser) or not _kisser.is_inside_tree(): return
	var camera: Camera3D = _kisser.get("camera")
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	_hook_ponies()
	_flush_pending()
	if _mine != null:
		if is_instance_valid(_mine) and str(_mine.get("kind")) == "kiss" and _kisser.get("_active") == _mine:
			_kisser.set("_active", null) # Hidden for the kisser's tick; after_kisser hands it back.
		else:
			_drop_mine()
	if _mine == null:
		if _kisser.get("controller") != null: _vr_lean(camera, delta)
		elif _can_start(): _desktop_start(camera)
		else: _stop_coming()
	_desktop_bend()


func _scale_of(pony: Node) -> float:
	return maxf(1.0, float(pony.get("body_scale"))) if is_instance_valid(pony) and pony.get("body_scale") != null else 1.0


# ---------------------------------------------------------------- starting

func _can_start() -> bool:
	if is_instance_valid(_kisser.get("_active")) or _kisser.get("_used_hold") == true: return false
	var body: Variant = _kisser.get("body")
	if is_instance_valid(body) and (body.get("controls_locked") == true or body.get_meta("knocked_down", false)): return false
	return true


func _desktop_start(camera: Camera3D) -> void:
	if _kisser.get("_down") != true or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_stop_coming()
		return
	if is_instance_valid(_coming):
		_come(camera)
		return
	var pony := _faced_pony(camera)
	if pony == null: return
	var mouth: Vector3 = _kisser.mouth_world()
	# Lips already touching: the game's own kiss takes it this very tick.
	if pony.kiss_contact_distance(mouth, -camera.global_basis.z.normalized()) <= CONTACT: return
	var welcomed := _welcomed(pony)
	if LAB_DEBUG: print("[kissing] faced %s welcomed=%s nose=%.2f size=%.2f" % [pony.name, welcomed, _nose_gap(pony, camera), _scale_of(pony)])
	# Only a pony who would kiss him back comes to him; any other answers where she stands
	# (turns her face away, a forehead kiss for a filly, nothing while asleep).
	if not welcomed or _nose_gap(pony, camera) <= COME_NOSE * _scale_of(pony):
		_start(pony, camera)
		return
	_coming = pony
	_coming_time = 0.0
	_coming_still = 0.0
	_coming_last = pony.global_position
	_claim(pony)
	_come(camera)


## The pony he faces most squarely within reach, not carried and not already in a hug or kiss.
func _faced_pony(camera: Camera3D) -> Node3D:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.01: return null
	forward = forward.normalized()
	var best: Node3D = null
	var best_dot := FACING
	for pony: Variant in _kisser.get("ponies"):
		if not is_instance_valid(pony) or not (pony as Node3D).is_inside_tree() or not (pony as Node3D).is_visible_in_tree(): continue
		if not pony.has_method("listen_point") or not pony.has_method("kiss_contact_distance"): continue
		if pony.has_method("is_held") and pony.is_held(): continue
		var affection: Node = pony.get_node_or_null("Affection")
		if affection == null or not str(affection.get("kind")).is_empty(): continue
		var to: Vector3 = pony.listen_point() - camera.global_position
		to.y = 0.0
		if to.length() > REACH * _scale_of(pony) or to.length() < 0.05: continue
		var dot := forward.dot(to.normalized())
		if dot > best_dot:
			best = pony
			best_dot = dot
	return best


## She would kiss him back (player_bonds welcomes, the same test the game's kiss makes, with no
## side effects), and is a grown pony awake.
func _welcomed(pony: Node3D) -> bool:
	if pony.get("sleeping") == true or _forehead(pony): return false
	var runtime: Variant = pony.get_meta("relationship_runtime") if pony.has_meta("relationship_runtime") else null
	if runtime == null: return false
	var bonds: Variant = runtime.get("bonds")
	if bonds == null or not bonds.has_method("welcomes"): return false
	return bool(bonds.welcomes(str(pony.get_meta("relationship_id", "")), "kiss"))


## Flat distance from her nose to his eyes.
func _nose_gap(pony: Node3D, camera: Camera3D) -> float:
	var to: Vector3 = pony.listen_point() - camera.global_position
	to.y = 0.0
	return to.length()


## Walking up to him: she faces him and steps in, then the kiss starts. Blocked (by his body, say)
## she starts it from there, her neck reaching the rest of the way, unless that's too far.
func _come(camera: Camera3D) -> void:
	var pony := _coming
	var delta := get_physics_process_delta_time()
	var size := _scale_of(pony)
	_coming_time += delta
	var gap := _nose_gap(pony, camera)
	var moved := pony.global_position.distance_to(_coming_last)
	_coming_last = pony.global_position
	_coming_still = _coming_still + delta if moved < COME_SPEED * size * delta * 0.2 else 0.0
	var blocked := _coming_time > 0.6 and _coming_still > 0.5
	if gap <= COME_NOSE * size or (blocked and gap <= 2.0 * COME_NOSE * size):
		_stop_coming()
		_start(pony, camera)
		return
	if blocked or _coming_time > APPROACH_SECONDS or pony.get("sleeping") == true or (pony.has_method("is_held") and pony.is_held()):
		if LAB_DEBUG: print("[kissing] she couldn't come close enough: nose %.2f m" % gap)
		_stop_coming()
		_kisser.set("_used_hold", true)
		return
	var to := camera.global_position - pony.global_position
	to.y = 0.0
	if to.length() < 0.05: return
	pony.set("steer_through_touch", true)
	if pony.has_method("face_direction"): pony.face_direction(to.normalized())
	var forward := -pony.global_basis.z
	forward.y = 0.0
	# Walk once she's turned most of the way toward him.
	if forward.normalized().dot(to.normalized()) > 0.85 and pony.has_method("set_desired_velocity"):
		pony.set_desired_velocity(to.normalized() * COME_SPEED * size)


func _stop_coming() -> void:
	if not is_instance_valid(_coming):
		_coming = null
		return
	if _coming.has_method("stop"): _coming.stop()
	_release(_coming)
	_coming = null


## Her navigator holds still (no wandering or schedule) while she walks up, as PonyAffection does.
func _claim(pony: Node3D) -> void:
	var nav: Node = pony.get_node_or_null("Navigator")
	if nav == null or nav.get("command_owner") == null: return
	_nav_owner = str(nav.get("command_owner"))
	_nav_wander = nav.get("wander_enabled") == true
	if nav.has_method("stay"): nav.stay()
	nav.set("command_owner", "kissing")
	nav.set("wander_enabled", false)


func _release(pony: Node3D) -> void:
	var nav: Node = pony.get_node_or_null("Navigator")
	if nav == null or str(nav.get("command_owner")) != "kissing": return
	if nav.has_method("stay"): nav.stay()
	nav.set("command_owner", _nav_owner)
	nav.set("wander_enabled", _nav_wander)


## The game's kiss, as try_kiss starts it once lips touch; this mod then drives it.
func _start(pony: Node3D, camera: Camera3D, vr := false) -> void:
	var affection: Node = pony.get_node_or_null("Affection")
	if affection == null: return
	var ok: bool = affection.begin("kiss", _kisser.mouth_world())
	# One attempt per hold, kissed back or not (a refusal is one event, as in the game).
	_kisser.set("_used_hold", true)
	if not ok: return
	_kisser.set("kisses", int(_kisser.get("kisses")) + 1)
	if str(affection.get("kind")) != "kiss": return # Turned away, asleep, or a filly's forehead kiss.
	affection.set("eye", camera.global_position)
	affection.set("face", camera.global_basis.orthonormalized())
	# Started before the kisser's tick: hidden from it until after_kisser hands it over.
	_kisser.set("_active", null)
	_mine = affection
	_met = false
	_mine_time = 0.0
	_vr_kiss = vr
	_far = 0.0
	_best_gap = INF
	_stall = 0.0
	_reach = _reach_for(pony, affection) if _scale_of(pony) >= TALL else null
	if _reach != null: _reach.set("want", true)
	if LAB_DEBUG: print("[kissing] start ", pony.name)


## Hoers size and up (reach.gd): her neck finishes the reach down to his lips after the game's
## kiss pose. One per pony, kept on her skeleton right after the kiss pose, idle between kisses.
const TALL := 2.0
const REACH_SCRIPT := preload("res://mods/kissing/reach.gd")
var _reach: Node


func _reach_for(pony: Node3D, affection: Node) -> Node:
	var pose: Variant = affection.get("pose")
	if not pose is Node or not is_instance_valid(pose) or (pose as Node).get_parent() == null: return null
	var sk: Node = (pose as Node).get_parent()
	var made: Node = sk.get_node_or_null("KissingReach")
	if made == null:
		made = REACH_SCRIPT.new()
		made.name = "KissingReach"
		made.set("mare", pony)
		made.set("affection", affection)
		sk.add_child(made)
	sk.move_child(made, (pose as Node).get_index() + 1)
	return made


func _reach_off() -> void:
	if is_instance_valid(_reach): _reach.set("want", false)
	_reach = null


# ---------------------------------------------------------------- driving the kiss

## After the kisser's tick (-19): her kiss handed back to it (so its button handling, and the
## game's "is he kissing" checks, see it) and the kisser's per-tick work done with scaled limits.
func after_kisser(delta: float) -> void:
	if _mine == null or not is_instance_valid(_kisser): return
	if not is_instance_valid(_mine) or str(_mine.get("kind")) != "kiss":
		_drop_mine()
		return
	_kisser.set("_active", _mine)
	var camera: Camera3D = _kisser.get("camera")
	var mare: Node3D = _mine.get("mare")
	if not is_instance_valid(camera) or not is_instance_valid(mare):
		_end_mine("lost")
		return
	_mine_time += delta
	var mouth: Vector3 = _kisser.mouth_world()
	var forward := -camera.global_basis.z.normalized()
	var deep: bool = _mine.get("deep") == true
	var lips: float = _mine.mouth_point().distance_to(mouth) if _mine.has_method("mouth_point") else INF
	var gap: float = minf(mare.kiss_contact_distance(mouth, forward), lips)
	var held := _held(gap, delta)
	var body: Variant = _kisser.get("body")
	if is_instance_valid(body) and (body.get("controls_locked") == true or body.get_meta("knocked_down", false)):
		_end_mine("controls locked")
		return
	if _kisser.get("controller") == null and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_end_mine("mouse freed")
		return
	if mare.global_position.distance_to(camera.global_position) > KEEP * _scale_of(mare):
		_end_mine("too far")
		return
	if not _met:
		if gap <= CONTACT:
			_met = true
			_mine_time = 0.0
			if LAB_DEBUG: print("[kissing] lips met")
		elif not held or _mine_time > APPROACH_SECONDS or _stalled(gap, delta):
			_end_mine("let go" if not held else "out of reach")
			return
		else:
			# Light until their lips meet; the 0.6 s before it may turn deep counts from then.
			_mine.set("elapsed", 0.0)
			_mine.set("deep", false)
			deep = false
	elif not deep and (not held or gap > PULL_BACK):
		_end_mine("let go" if not held else "pulled back")
		return
	_mine.set("target", mouth)
	_mine.set("eye", camera.global_position)
	_mine.set("face", camera.global_basis.orthonormalized())
	if _kisser.has_method("_kiss_near"): _kisser.call("_kiss_near", true)
	# While she holds him in a deep kiss, he can't walk off (turning still works), as the kisser does.
	if is_instance_valid(body):
		if deep: body.set_meta("kiss_hold", true)
		elif body.has_meta("kiss_hold"): body.remove_meta("kiss_hold")


## Her lips have stopped getting closer to his (her neck at its limit): over each STALL_SECONDS
## window they must close by STALL_GAIN metres, or she gives up (after a first STALL_SECONDS).
const STALL_SECONDS := 1.0
const STALL_GAIN := 0.02
var _best_gap := INF # The gap at the start of the current window.
var _stall := 0.0 # Seconds into the current window.


func _stalled(gap: float, delta: float) -> bool:
	_stall += delta
	if _stall < STALL_SECONDS: return false
	var stuck := _mine_time > 1.5 and gap > _best_gap - STALL_GAIN
	_best_gap = gap
	_stall = 0.0
	return stuck


## Desktop: K still held (the kisser's latch). VR: still leaning in.
func _held(gap: float, delta: float) -> bool:
	if not _vr_kiss: return _kisser.get("_down") == true
	_far = _far + delta if gap > LEAN_BREAK else 0.0
	return _far < 0.3 or _kisser.get("_down") == true


func _end_mine(why: String) -> void:
	if LAB_DEBUG: print("[kissing] ended: ", why)
	if is_instance_valid(_kisser):
		_kisser.set("_active", _mine)
		_kisser.call("_end_contact")
	_mine = null
	_reach_off()


## Her kiss ended by itself (the deep kiss runs out, or the kisser's button ended it).
func _drop_mine() -> void:
	if is_instance_valid(_kisser):
		if _kisser.get("_active") == _mine or not is_instance_valid(_kisser.get("_active")): _kisser.call("_end_contact")
	_mine = null
	_reach_off()


# ---------------------------------------------------------------- desktop: bending down

## A standing Anon's lips are well above a Canon pony's (Celestia's by about 35 cm), more than
## her neck can reach, so he bends down to her as Ctrl's crouch does: while she comes to him and
## through the kiss, the desktop player's standing eye height (desktop_player.gd _stand_eye, which
## its crouch ease follows) is lowered to just above her lips, then put back. A pony taller than
## him lowers her own head; he doesn't stretch up.
const BEND_ABOVE := 0.12 # His eyes this far above her lips.
const BEND_MIN := 0.55 # Never lower than a crouch (desktop_player CROUCH_RATIO).
var _bend_pony: Node3D
var _stand_eye := -1.0
var _bend_lips := 0.0


func _desktop_bend() -> void:
	if not is_instance_valid(_kisser) or _kisser.get("controller") != null: return
	var body: Variant = _kisser.get("body")
	if not is_instance_valid(body) or body.get("_stand_eye") == null: return
	var pony: Node3D = _coming
	if pony == null and is_instance_valid(_mine): pony = _mine.get("mare")
	if not is_instance_valid(pony):
		_unbend(body)
		return
	if _stand_eye < 0.0: _stand_eye = float(body.get("_stand_eye"))
	# Her lips' height as she stands, taken once as he starts to bend: the bend must not chase
	# her lips as they reach up to his.
	if pony != _bend_pony:
		_bend_pony = pony
		var affection: Node = pony.get_node_or_null("Affection")
		var at: Vector3 = affection.mouth_point() if affection != null and affection.has_method("mouth_point") else pony.listen_point()
		_bend_lips = at.y - pony.global_position.y
	var want := pony.global_position.y + _bend_lips - (body as Node3D).global_position.y + BEND_ABOVE
	body.set("_stand_eye", clampf(want, _stand_eye * BEND_MIN, _stand_eye))


func _unbend(body: Variant) -> void:
	_bend_pony = null
	if _stand_eye < 0.0: return
	if is_instance_valid(body): body.set("_stand_eye", _stand_eye)
	_stand_eye = -1.0


# ---------------------------------------------------------------- VR: leaning in

func _vr_lean(camera: Camera3D, delta: float) -> void:
	if not _can_start() or _kisser.get("_down") == true:
		_lean_time = 0.0
		return
	var mouth: Vector3 = _kisser.mouth_world()
	var forward := -camera.global_basis.z.normalized()
	var near: Node3D = null
	for pony: Variant in _kisser.get("ponies"):
		if not is_instance_valid(pony) or not (pony as Node3D).is_inside_tree() or not (pony as Node3D).is_visible_in_tree(): continue
		if pony.has_method("is_held") and pony.is_held(): continue
		if (pony as Node3D).global_position.distance_to(camera.global_position) > KEEP * _scale_of(pony): continue
		if pony.kiss_contact_distance(mouth, forward) <= LEAN_REACH:
			near = pony
			break
	if near == null or near != _lean_pony:
		_lean_pony = near
		_lean_time = 0.0
		return
	_lean_time += delta
	if _lean_time < LEAN_SECONDS: return
	_lean_time = 0.0
	_lean_pony = null
	_start(near, camera, true)
	if _mine == null: _kisser.set("_used_hold", false) # Turned away: another lean may try again.


# ---------------------------------------------------------------- remembering

## Every kiss, the game's own included: her reactions (hybrid_mare physical_reaction) say what
## happened. Her own memory of it is the game's (director_contacts); this tells the ponies nearby.
func _hook_ponies() -> void:
	for pony: Variant in _kisser.get("ponies"):
		if not is_instance_valid(pony) or _hooked.has(pony) or not pony.has_signal("physical_reaction"): continue
		var node: Node3D = pony
		node.physical_reaction.connect(func(kind: String) -> void: _reaction(node, kind))
		_hooked[pony] = true


func _reaction(pony: Node3D, kind: String) -> void:
	match kind:
		"kiss": _pending[pony] = {"deep": false}
		"deep_kiss":
			if _pending.has(pony): _pending[pony].deep = true
			else: _pending[pony] = {"deep": true}
		"kiss_refused": _record(pony, "refused")


func _flush_pending() -> void:
	for pony: Variant in _pending.keys():
		if not is_instance_valid(pony):
			_pending.erase(pony)
			continue
		var affection: Node = (pony as Node).get_node_or_null("Affection")
		if affection != null and str(affection.get("kind")) == "kiss": continue
		var row: Dictionary = _pending[pony]
		_pending.erase(pony)
		_record(pony, "deep" if row.deep else ("forehead" if _forehead(pony) else "kiss"))


func _forehead(pony: Node3D) -> bool:
	var identity: Variant = pony.get("identity")
	if identity != null and identity.get("filly") == true: return true
	var form := load("res://world/life/player_form.gd")
	return form != null and form.is_young(form.active(get_tree()))


const LINES := {
	"kiss": "Anon kissed %s.",
	"deep": "Anon and %s shared a long, deep kiss.",
	"forehead": "%s got a kiss on the forehead from Anon.",
	"refused": "Anon tried to kiss %s, but she turned her face away.",
}


func _record(pony: Node3D, what: String) -> void:
	var game: Variant = Mods.game
	if not is_instance_valid(game): return
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
	var witnesses := []
	for key: Variant in cast:
		var other: Variant = (cast[key] as Dictionary).get("node")
		if other == pony or not other is Node3D or not is_instance_valid(other): continue
		if (other as Node3D).global_position.distance_to(pony.global_position) <= WITNESS_RANGE: witnesses.append(str(key))
	if witnesses.is_empty(): return
	var identity: Variant = pony.get("identity")
	var name := str(identity.get("display_name")) if identity != null else id
	var text: String = LINES[what] % name
	if identity != null and identity.get("stallion") == true: text = text.replace(" she ", " he ").replace(" her ", " his ")
	if str(memory.call("record", "kissing", text, witnesses, [id, "player"])).is_empty(): return
	_recorded[pony] = now
	if LAB_DEBUG: print("[kissing] recorded ", witnesses, " ", text)


func _exit_tree() -> void:
	_stop_coming()
	_reach_off()
	# Switched off: the reach modifiers come off the ponies too.
	for pony: Variant in _hooked:
		if not is_instance_valid(pony): continue
		var sk: Variant = (pony as Node).get("skeleton")
		if sk is Node and is_instance_valid(sk) and (sk as Node).get_node_or_null("KissingReach") != null:
			(sk as Node).get_node("KissingReach").queue_free()
	if is_instance_valid(_kisser):
		if _mine != null: _end_mine("mod off")
		_unbend(_kisser.get("body"))
