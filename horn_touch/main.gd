extends Node
## Horn Touch (modChad) entry.
##
## Desktop: hold the left mouse button on her horn and move the mouse to stroke it. This mod picks
## the horn itself (horn.gd pick; Celestia's and Luna's fitted horns have no touch hull at all),
## shows its own prompt, takes the click before the game's petting and drives the pet hand (_own).
## VR (attempted, untested): grip within VR_REACH of her horn and slide the
## hand along it.
##
## Below Close Friend, or while she is angry at him, she blasts him away with a bolt of magic: the
## game's buck knockback and daze (receive_buck), then this mod's longer daze (daze.gd) with his
## movement locked, DAZE_SECONDS or ALICORN_DAZE_SECONDS. Touching her horn again within
## AGAIN_SECONDS of that earns her real buck (pony_affection.gd buck, as an unwelcome kiss does).
## Each unwanted touch costs trust (player_bonds unwanted_contact) and is a strike against him.
##
## Close Friend and up: she lets him, shy and flustered; stroking builds until her horn
## overloads in a burst of sparkles in her magic colour (fx.gd), then she needs a moment.
##
## Ponies within WITNESS_RANGE (and she herself) remember it (world_context.record). At AVOID_AT
## strikes word gets around town and unicorns step away from him; each apology to a unicorn he
## wronged (said to her in conversation) takes one strike off, at most once per APOLOGY_EVERY
## per pony. Strikes are kept in the world save (Mods.state). Never fillies or colts, never a
## young player (horn.gd eligible).
const HORN := preload("res://mods/horn_touch/horn.gd")
const FX := preload("res://mods/horn_touch/fx.gd")
const DAZE := preload("res://mods/horn_touch/daze.gd")
const PLAYER_VIEW := preload("res://world/player_view.gd")
const SUBTITLES := preload("res://mods/horn_touch/subtitles.gd")
const SUBTITLE_AFTER := 4.0 # Seconds after the daze ends that subtitles still show.
const ID := "horn_touch"

const WELCOME_STAGE := 2 # close_friend in player_bonds STAGES.
const DAZE_SECONDS := 15.0
const ALICORN_DAZE_SECONDS := 30.0
const AGAIN_SECONDS := 30.0
const BOLT_DELAY := 0.12 # The beam lands, then he flies.
const BOLT_PUSH := 6.0
const BOLT_LIFT := 2.4
const REFUSED_COOLDOWN := 4.0 # After a bolt her horn is off limits this long (no double strikes).
const STROKE_PEAK := 1.2 # Metres of hand travel along her horn to overload it.
const HOLD_SECONDS := 12.0 # Just holding her horn overloads it after this long.
const STROKE_FADE := 0.06 # Per second while not stroking.
const AFTER_BURST := 20.0 # Seconds before her horn can be stroked again after an overload.
const TOUCH_GAP := 0.6 # Seconds without contact before a touch counts as ended.
const VR_REACH := 0.06
const VR_GRIP := 0.6
const WITNESS_RANGE := 10.0
const RECORD_GAP := 60.0
const AVOID_AT := 5
const AVOID_RANGE := 8.0
const AVOID_STEP := 12.0
const AVOID_EVERY := 3.0
const APOLOGY_EVERY := 120.0
const PICK_RADIUS := 0.035 # Click ray to horn axis, metres at Canon size.
const REACH := 1.6 # desktop_interactions.gd TOUCH_REACH.
const OWNER := preload("res://player/desktop_action_owner.gd")
const PRINCESSES := {"luna": "moon", "celestia": "everfree", "twilight_sparkle": "everfree"}
const PRINCESS_AT := 5 # Her own unwanted touches before she acts.
const EXILE := preload("res://mods/horn_touch/exile.gd")
const APOLOGY := "\\b(sorry|apologi[sz]e|my apologies|forgive me|i was wrong|my bad)\\b"
var DEBUG := "--horn-touch-debug" in OS.get_cmdline_user_args()

## pony -> {"stroke", "last" (point), "seen" (msec), "spark" (s), "fluster" (s), "noted"}
var _touch: Dictionary = {}
## pony -> msec before which her horn is ignored.
var _cooldown: Dictionary = {}
## id -> msec of her last refusal.
var _refused_at: Dictionary = {}
var _recorded: Dictionary = {}
var _avoid_next: Dictionary = {}
var _approach_chance: Dictionary = {} # navigator -> its own approach_player_chance
var _apology_at: Dictionary = {}
var _lock_until := 0
var _locked: Node
var _director: Object
var _apology_re := RegEx.create_from_string(APOLOGY)
var _subtitles: CanvasLayer
## Desktop hold on a horn this mod picked itself: {pony, point, normal, touching, started} or {}.
var _own: Dictionary = {}
var _logged_fit: Dictionary = {}
## Spoken reactions waiting for the director to be free: [{id, text, at, until}] (msec).
var _reactions: Array = []


var _exile: Node


func _ready() -> void:
	add_to_group("interaction_hint_sources")
	_exile = EXILE.new()
	_exile.name = "Exile"
	_exile.host = self
	add_child(_exile)


## A short message at the top of the screen that fades out (as Kissing's).
func note(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position.y = 60.0
	layer.add_child(label)
	add_child(layer)
	var tween := label.create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)


func _log(text: String) -> void:
	if DEBUG: print("[horn_touch] ", text)


# ------------------------------------------------------------------ world

func _game() -> Node:
	var game: Variant = Mods.game
	return game if is_instance_valid(game) else null

func _body() -> Node3D:
	var game := _game()
	var inventory: Variant = game.get("inventory") if game != null else null
	var body: Variant = inventory.get("player_body") if inventory is Object and is_instance_valid(inventory) else null
	return body if body is Node3D and is_instance_valid(body) else null

func _ponies() -> Array:
	var game := _game()
	var mares: Variant = game.get("mares") if game != null else null
	return mares if mares is Array else []

func _state() -> Dictionary:
	var s: Dictionary = Mods.state(ID)
	if not s.get("wronged") is Dictionary: s["wronged"] = {}
	if not s.has("strikes"): s["strikes"] = 0
	return s

func _strikes() -> int:
	return int(_state().get("strikes", 0))


func _physics_process(delta: float) -> void:
	if _game() == null: return
	_hook_director()
	_update_lock()
	_update_own()
	_tick_reactions()
	var now := Time.get_ticks_msec()
	var seen: Dictionary = {}
	for contact: Dictionary in _contacts():
		var pony: Node3D = contact.pony
		if seen.has(pony): continue
		seen[pony] = true
		_on_contact(pony, contact.point, str(contact.side), delta, now)
	for pony: Variant in _touch.keys():
		if seen.has(pony): continue
		if not is_instance_valid(pony): _touch.erase(pony); continue
		var row: Dictionary = _touch[pony]
		row.stroke = maxf(0.0, float(row.stroke) - STROKE_FADE * delta)
		if now - int(row.seen) > int(TOUCH_GAP * 1000.0): _end_touch(pony as Node3D)
	_avoid(now)


## His hands on a horn this tick: [{pony, point, side}].
func _contacts() -> Array:
	var out: Array = []
	# Desktop: the game's own pet, while its hit is on her horn's hull.
	var desk: Node = get_tree().get_first_node_in_group("desktop_interactions")
	if is_instance_valid(desk) and str(desk.get("_action")) == "pet":
		var target: Variant = desk.get("_target")
		var offer: Variant = desk.get("_offer")
		if target is Node3D and is_instance_valid(target) and offer is Dictionary:
			var entry: Variant = (offer as Dictionary).get("entry")
			# A princess's head horn hull is hidden inside her fitted horn: hers is picked by _own.
			if entry is Dictionary and str((entry as Dictionary).get("region", "")) == HORN.HULL_REGION and not HORN.fitted(target):
				out.append({"pony": target, "point": desk.get("_point"), "side": "desktop"})
	if not _own.is_empty() and (bool(_own.touching) or Time.get_ticks_msec() - int(_own.started) > 700):
		out.append({"pony": _own.pony, "point": _own.point, "side": "desktop"})
	# VR: a gripping hand at her horn.
	var body := _body()
	if body == null: return out
	for side: String in ["Left", "Right"]:
		var controller := body.find_child("XRController" + side, true, false) as XRController3D
		if controller == null or not controller.get_is_active() or controller.get_float("grip") < VR_GRIP: continue
		var hand := body.find_child("PhysicsHand" + side, true, false) as Node3D
		var at: Vector3 = hand.global_position if hand != null else controller.global_position
		for pony: Variant in _ponies():
			if not pony is Node3D or not is_instance_valid(pony): continue
			if (pony as Node3D).global_position.distance_squared_to(at) > 9.0 or not HORN.eligible(pony): continue
			if HORN.distance(pony, at) <= VR_REACH:
				out.append({"pony": pony, "point": at, "side": side.to_lower()})
				break
	return out


# ------------------------------------------------------------------ touching

func _on_contact(pony: Node3D, point: Vector3, side: String, delta: float, now: int) -> void:
	if not HORN.eligible(pony): return
	if now < int(_cooldown.get(pony, 0)) or pony.get("sleeping") == true or pony.is_held():
		if side == "desktop": _end_desktop_pet()
		return
	var row: Variant = _touch.get(pony)
	if row == null:
		if HORN.stage(pony) < WELCOME_STAGE or HORN.angry(pony):
			_refuse(pony, side, now)
			return
		row = {"stroke": 0.0, "last": point, "seen": now, "spark": 0.0, "fluster": 0.0, "noted": false}
		_touch[pony] = row
		_log("%s lets him touch her horn" % HORN.pony_id(pony))
	var r: Dictionary = row
	r.seen = now
	var seg := HORN.segment(pony)
	if not seg.is_empty():
		var axis: Vector3 = (Vector3(seg[1]) - Vector3(seg[0])).normalized()
		# Holding builds slowly on its own; travel along the horn (stroking) builds faster.
		r.stroke = float(r.stroke) + delta / HOLD_SECONDS + absf((point - Vector3(r.last)).dot(axis)) / STROKE_PEAK
	r.last = point
	var level := clampf(float(r.stroke), 0.0, 1.0)
	_flustered(pony, r, level, delta)
	if not bool(r.noted) and level > 0.15:
		r.noted = true
		_record(pony, "stroke")
	if DEBUG and int(level * 10.0) != int(r.get("logged", -1)):
		r.logged = int(level * 10.0)
		_log("%s: horn %d%%" % [HORN.pony_id(pony), int(level * 100.0)])
	if level >= 1.0: _overload(pony, seg, side, now)


## Shy and nervous, warming as it builds: blush and peeks (fluster), a smile and heavier lids,
## and her horn sparkling more and more often.
func _flustered(pony: Node3D, r: Dictionary, level: float, delta: float) -> void:
	var expressions: Variant = pony.get("expressions")
	if expressions is Object:
		(expressions as Object).call("touch", "horn_touch", .25 + .55 * level, .2 + .5 * level)
		r.fluster = float(r.fluster) - delta
		if float(r.fluster) <= 0.0:
			(expressions as Object).call("fluster", 2.5, true)
			r.fluster = 2.0
	r.spark = float(r.spark) - delta
	if level > .25 and float(r.spark) <= 0.0:
		var magic: Variant = pony.get("magic")
		if magic is Object and is_instance_valid(magic): (magic as Object).call("sparkle")
		r.spark = lerpf(1.4, .3, level)


func _end_touch(pony: Node3D) -> void:
	_touch.erase(pony)
	if not is_instance_valid(pony): return
	var expressions: Variant = pony.get("expressions")
	if expressions is Object: (expressions as Object).call("release_touch", "horn_touch")


func _overload(pony: Node3D, seg: Array, side: String, now: int) -> void:
	_log("%s: horn overload" % HORN.pony_id(pony))
	if not seg.is_empty(): FX.overload(pony, seg[0], seg[1], HORN.color(pony))
	var expressions: Variant = pony.get("expressions")
	if expressions is Object: (expressions as Object).call("fluster", 5.0, true)
	_end_touch(pony)
	_cooldown[pony] = now + int(AFTER_BURST * 1000.0)
	if side == "desktop": _end_desktop_pet()
	_record(pony, "burst")
	_react_to_overload(pony)


func _end_desktop_pet() -> void:
	_end_own()
	var desk: Node = get_tree().get_first_node_in_group("desktop_interactions")
	if is_instance_valid(desk) and str(desk.get("_action")) == "pet" and desk.has_method("_finish"): desk.call("_finish")


# ------------------------------------------------------------------ refusing

func _refuse(pony: Node3D, side: String, now: int) -> void:
	var id := HORN.pony_id(pony)
	var again := now - int(_refused_at.get(id, -1000000000)) < int(AGAIN_SECONDS * 1000.0)
	_refused_at[id] = now
	_cooldown[pony] = now + int(REFUSED_COOLDOWN * 1000.0)
	if side == "desktop": _end_desktop_pet()
	var bonds: Object = HORN.bonds_of(pony)
	if bonds != null and not id.is_empty() and bonds.has_method("unwanted_contact"): bonds.unwanted_contact(id, "horn")
	_strike(id)
	var mouth: Variant = pony.get("head").get("mouth") if pony.get("head") is Object else null
	if mouth is Object:
		(mouth as Object).call("set_expression", "pout", 1.0)
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_instance_valid(mouth): (mouth as Object).call("set_expression", "pout", 0.0))
	var body := _body()
	if body == null: return
	# A princess's own fifth time: Luna banishes him to the moon, Celestia and Twilight send him
	# into the Everfree (exile.gd). If that can't happen now, the usual zap below.
	var hers := int((_state().wronged as Dictionary).get(id, 0))
	if PRINCESSES.has(id) and hers >= PRINCESS_AT and not _exile.busy:
		_punish(pony, id, again)
		return
	_zap_or_buck(pony, id, again)


## She has had enough: her reaction first, then the spell.
func _punish(pony: Node3D, id: String, again: bool) -> void:
	var what: String = PRINCESSES[id]
	_log("%s: %s" % [id, what])
	_record(pony, what)
	var done := false
	var name := str(pony.get("identity").get("display_name")) if pony.get("identity") != null else id
	if what == "moon":
		_react(id, "[Your horn] Anon has grabbed your horn without asking for the fifth time, after every warning. Your patience is gone: you are banishing him to the moon for a day, as you once were. Pronounce it aloud, royally and in character, as your horn charges.", 0.0)
		_announce("%s banished Anon to the moon for a whole day for grabbing her horn again and again. He has been gone since." % name)
		done = await _exile.banish_to_moon(pony, HORN.color(pony))
	else:
		_react(id, "[Your horn] Anon has grabbed your horn without asking for the fifth time, after every warning. Enough: you are teleporting him somewhere in the Everfree Forest to think about what he has done. Say so aloud, in character, as your horn charges.", 0.0)
		_announce("%s teleported Anon into the Everfree Forest for grabbing her horn again and again." % name)
		done = await _exile.send_to_everfree(pony, HORN.color(pony))
	if not done and is_instance_valid(pony): _zap_or_buck(pony, id, again)


## Everyone hears of a princess's punishment.
func _announce(text: String) -> void:
	var game := _game()
	var memory: Variant = game.get("world_context") if game != null else null
	var cast := _cast()
	if not memory is Object or not memory.has_method("record") or cast.is_empty(): return
	var everyone: Array = []
	for id: Variant in cast: everyone.append(str(id))
	memory.call("record", "horn_touch", text, everyone, ["player"])


func _zap_or_buck(pony: Node3D, id: String, again: bool) -> void:
	var body := _body()
	if body == null: return
	var seconds := ALICORN_DAZE_SECONDS if HORN.alicorn(pony) else DAZE_SECONDS
	# Warned once already: the game's own buck, as for a kiss pressed after a refusal.
	var affection: Node = pony.get_node_or_null("Affection")
	if again and affection != null and affection.has_method("buck") and affection.buck(body):
		_log("%s bucks him" % id)
		_record(pony, "buck")
		_react_to_refusal(pony, true)
		get_tree().create_timer(1.0).timeout.connect(_daze.bind(pony, seconds))
		return
	_log("%s zaps him (%.0f s daze)" % [id, seconds])
	var seg := HORN.segment(pony)
	var tip: Vector3 = seg[1] if not seg.is_empty() else pony.global_position + Vector3.UP
	var chest := body.global_position + Vector3.UP * 1.2
	FX.bolt(pony, tip, chest, HORN.color(pony))
	if pony.has_method("look_at_player"): pony.call("look_at_player")
	_record(pony, "refused")
	_react_to_refusal(pony, false)
	get_tree().create_timer(BOLT_DELAY).timeout.connect(func() -> void:
		if not is_instance_valid(body) or not is_instance_valid(pony): return
		var away := body.global_position - pony.global_position; away.y = 0.0
		if away.length() < .05: away = -body.global_basis.z
		if body.has_method("receive_buck"): body.call("receive_buck", away.normalized() * BOLT_PUSH + Vector3.UP * BOLT_LIFT)
		_daze(pony, seconds))


## The long daze over the game's buck daze, and his movement locked until it's over.
func _daze(pony: Node3D, seconds: float) -> void:
	var body := _body()
	if body == null: return
	var color := HORN.color(pony) if is_instance_valid(pony) else Color.WHITE
	DAZE.play(PLAYER_VIEW.camera(body), seconds, color)
	_lock_until = maxi(_lock_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	_locked = body
	_update_lock()


func _update_lock() -> void:
	if not is_instance_valid(_locked): _locked = null; return
	if Time.get_ticks_msec() < _lock_until:
		# Set after the knockdown has started (it refuses a locked body), and every tick so a menu
		# closing doesn't hand him his legs back early.
		if _locked.get("controls_locked") != true: _locked.set("controls_locked", true)
	else:
		_locked.set("controls_locked", false)
		_locked = null


# ------------------------------------------------------------------ desktop horn pick

func _desk() -> Node:
	var desk: Node = get_tree().get_first_node_in_group("desktop_interactions")
	return desk if is_instance_valid(desk) else null


## The horn under his click ray, nearer than whatever the game's own pick found, or {}.
func _horn_pick() -> Dictionary:
	var desk := _desk()
	if desk == null or not desk.call("_social_free") or not str(desk.get("_action")).is_empty(): return {}
	var camera: Camera3D = desk.get("camera")
	if not is_instance_valid(camera): return {}
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH
	var best: Dictionary = {}
	for pony: Variant in _ponies():
		if not pony is Node3D or not is_instance_valid(pony) or (pony as Node3D).global_position.distance_squared_to(from) > 9.0: continue
		if not HORN.eligible(pony) or pony.is_held(): continue
		HORN.fitted(pony)
		if DEBUG and not _logged_fit.has(pony) and (pony as Node).has_meta("horn_touch_fitted"):
			_logged_fit[pony] = true
			var seg := HORN.segment(pony)
			_log("%s: fitted horn %s, segment %s, length %.3f" % [HORN.pony_id(pony), str(HORN.fitted(pony)), str(seg), (Vector3(seg[1]).distance_to(seg[0]) if seg.size() == 2 else -1.0)])
		var hit := HORN.pick(pony, from, to, PICK_RADIUS)
		if hit.is_empty() or (not best.is_empty() and float(hit.distance) >= float(best.distance)): continue
		hit.pony = pony
		best = hit
	if best.is_empty(): return {}
	# The game's own pick wins only when it is clearly in front: another pony, or her own body well
	# before the horn. Her head behind it, or the hidden head horn hull inside it, never does.
	var game_pick: Dictionary = desk.call("_select")
	if not game_pick.is_empty():
		var ahead := float(best.distance) - from.distance_to(game_pick.point)
		var entry: Variant = game_pick.get("entry")
		var hidden_horn := entry is Dictionary and str((entry as Dictionary).get("region", "")) == HORN.HULL_REGION
		if game_pick.target != best.pony and ahead > .02: return {}
		if game_pick.target == best.pony and not hidden_horn and ahead > .08: return {}
	return best


## Left click on a horn: taken before the game's _unhandled_input sees it.
func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT: return
	if not button.pressed:
		_end_own(); return
	if not _own.is_empty(): return
	var desk := _desk()
	if desk == null or not desk.call("_available"): return
	var hit := _horn_pick()
	if hit.is_empty(): return
	var inventory: Node = desk.get("inventory")
	if not OWNER.claim(inventory, self): return
	_own = {"pony": hit.pony, "point": hit.point, "normal": hit.normal, "t": float(hit.t), "touching": false, "started": Time.get_ticks_msec()}
	_log("hand to %s's horn" % HORN.pony_id(hit.pony))
	if not is_instance_valid(desk.get("_avatar")) and desk.has_method("_bind_presentation"): desk.call("_bind_presentation")
	var avatar: Variant = desk.get("_avatar")
	if avatar is Object and is_instance_valid(avatar):
		if avatar.has_signal("action_contact") and not avatar.action_contact.is_connected(_on_hand_contact):
			avatar.action_contact.connect(_on_hand_contact)
		if not (avatar as Object).call("request_action", "pet", hit.point, hit.normal): _log("hand busy or out of reach")
	get_viewport().set_input_as_handled()


func _update_own() -> void:
	if _own.is_empty(): return
	var desk := _desk()
	var pony: Variant = _own.pony
	if desk == null or not is_instance_valid(pony) or not desk.call("_available") or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_own(); return
	var camera: Camera3D = desk.get("camera")
	var from := camera.global_position
	# Held, the hand stays on her horn as her head moves: the click ray only slides it along the
	# horn while it still points near it. It lets go on release or once she is out of reach.
	var aimed := HORN.pick(pony, from, from - camera.global_basis.z * (REACH + .3), PICK_RADIUS * 3.0)
	if not aimed.is_empty(): _own.t = float(aimed.t)
	var hit := HORN.at(pony, float(_own.get("t", .5)), from)
	if hit.is_empty() or from.distance_to(hit.point) > REACH + .4: _end_own(); return
	_own.point = hit.point; _own.normal = hit.normal
	# A slow palm stroke along the middle of the horn while held.
	var stroke := sin(maxf(0.0, (Time.get_ticks_msec() - int(_own.started)) / 1000.0 - .3) * TAU / 1.4) * .18
	var shown: Vector3 = HORN.at(pony, float(_own.t) + stroke, from).get("point", hit.point)
	var avatar: Variant = desk.get("_avatar")
	if avatar is Object and is_instance_valid(avatar) and not (avatar as Object).call("update_action_target", "pet", shown, hit.normal):
		(avatar as Object).call("request_action", "pet", shown, hit.normal)
	# A welcome touch is petting her head to the game (her smile, her excitement building).
	if bool(_own.touching) and _touch.has(pony):
		var touch: Variant = pony.get("touch_body")
		if touch is Object and is_instance_valid(touch): (touch as Object).call("desktop_pet", "head")


func _on_hand_contact(kind: String, _at: Vector3, _side: String) -> void:
	if kind == "pet" and not _own.is_empty(): _own.touching = true


func _end_own() -> void:
	if _own.is_empty(): return
	var pony: Variant = _own.pony
	_own = {}
	if is_instance_valid(pony):
		var touch: Variant = (pony as Node).get("touch_body")
		if touch is Object and is_instance_valid(touch): (touch as Object).call("desktop_pet_end")
	var desk := _desk()
	if desk == null: return
	var avatar: Variant = desk.get("_avatar")
	if avatar is Object and is_instance_valid(avatar): (avatar as Object).call("cancel_action")
	OWNER.release(desk.get("inventory"), self)


## The prompt for a horn (interaction_hints.gd asks every hint source; while this mod holds
## the desktop it asks only the owner).
func interaction_hint() -> Dictionary:
	if not _own.is_empty():
		return {"target": _own.pony, "point": _own.point, "text": "Release click · Stop", "outline": null, "visible_pick": true}
	var desk := _desk()
	if desk == null or not desk.call("_available"): return {}
	var hit := _horn_pick()
	if hit.is_empty(): return {}
	return {"target": hit.pony, "point": hit.point, "text": "Hold click · Stroke horn", "outline": null, "visible_pick": true}


# ------------------------------------------------------------------ strikes and talk

func _strike(id: String) -> void:
	if id.is_empty(): return
	var s := _state()
	var before := int(s.strikes)
	s.strikes = before + 1
	(s.wronged as Dictionary)[id] = int((s.wronged as Dictionary).get(id, 0)) + 1
	Mods.save_changed()
	_log("strikes %d" % int(s.strikes))
	if before < AVOID_AT and int(s.strikes) >= AVOID_AT: _word_gets_around()


func _hook_director() -> void:
	var game := _game()
	var director: Variant = game.get("director") if game != null else null
	if not director is Object or not is_instance_valid(director) or director == _director: return
	_director = director
	if director.has_signal("transcript") and not director.transcript.is_connected(_on_transcript):
		director.transcript.connect(_on_transcript)
	if director.has_signal("reply") and not director.reply.is_connected(_on_reply):
		director.reply.connect(_on_reply)


## What a pony says while he is dazed (and a moment after) also shows as a clear subtitle.
func _on_reply(id: String, text: String) -> void:
	if Time.get_ticks_msec() > _lock_until + int(SUBTITLE_AFTER * 1000.0): return
	if not is_instance_valid(_subtitles):
		_subtitles = SUBTITLES.new()
		_subtitles.name = "HornTouchSubtitles"
		add_child(_subtitles)
	var pony: Variant = _node_for(id)
	var identity: Variant = (pony as Node).get("identity") if pony is Node and is_instance_valid(pony) else null
	var name := str(identity.get("display_name")) if identity is Resource else id.replace("_", " ").capitalize()
	var color: Color = HORN.color(pony) if pony is Node and is_instance_valid(pony) and identity is Resource and identity.has_horn() else Color(1, .85, .5)
	_subtitles.say(name, text, color)


## Anon said something; the director picks who hears it right after (conversation_director.gd),
## so the listener is read a moment later.
func _on_transcript(text: String) -> void:
	if _apology_re.search(text.to_lower()) == null: return
	_apologised.call_deferred()


func _apologised() -> void:
	if not is_instance_valid(_director): return
	var id := str(_director.get("_current"))
	var s := _state()
	var wronged: Dictionary = s.wronged
	if id.is_empty() or int(wronged.get(id, 0)) <= 0: return
	var now := Time.get_ticks_msec()
	if now - int(_apology_at.get(id, -1000000000)) < int(APOLOGY_EVERY * 1000.0): return
	_apology_at[id] = now
	wronged[id] = int(wronged[id]) - 1
	if int(wronged[id]) <= 0: wronged.erase(id)
	s.strikes = maxi(0, int(s.strikes) - 1)
	Mods.save_changed()
	_log("%s accepts an apology; strikes %d" % [id, int(s.strikes)])
	var pony: Variant = _node_for(id)
	if pony is Node3D: _record(pony, "apology")
	if int(s.strikes) < AVOID_AT: _restore_approach()


## Unicorns who've heard step away from him: only on their own time (no story or AI command),
## never one he is talking to (so he can still apologise).
func _avoid(now: int) -> void:
	if _strikes() < AVOID_AT:
		if not _approach_chance.is_empty(): _restore_approach()
		return
	var body := _body()
	if body == null: return
	var talking := str(_director.get("_current")) if is_instance_valid(_director) else ""
	for pony: Variant in _ponies():
		if not pony is Node3D or not is_instance_valid(pony) or not HORN.eligible(pony) or PRINCESSES.has(HORN.pony_id(pony)): continue
		var nav: Node = (pony as Node).get_node_or_null("Navigator")
		if nav == null: continue
		if not _approach_chance.has(nav):
			_approach_chance[nav] = float(nav.get("approach_player_chance"))
			nav.set("approach_player_chance", 0.0)
		var away: Vector3 = (pony as Node3D).global_position - body.global_position; away.y = 0.0
		if away.length() > AVOID_RANGE or now < int(_avoid_next.get(pony, 0)): continue
		if HORN.pony_id(pony) == talking or is_instance_valid(nav.get("_conversation_target")): continue
		if pony.get("sleeping") == true or pony.is_held() or pony.is_speaking(): continue
		var owner := str(nav.get("command_owner"))
		if not owner.is_empty() and not (nav.has_method("autonomous_command") and nav.autonomous_command()): continue
		if away.length() < .05: away = -body.global_basis.z
		nav.go_to((pony as Node3D).global_position + away.normalized() * AVOID_STEP, 0) # 0: Gait.TROT, they run.
		_avoid_next[pony] = now + int(AVOID_EVERY * 1000.0)


func _restore_approach() -> void:
	for nav: Variant in _approach_chance:
		if is_instance_valid(nav): (nav as Node).set("approach_player_chance", _approach_chance[nav])
	_approach_chance.clear()


# ------------------------------------------------------------------ reactions

const ORDINALS := ["first", "second", "third", "fourth", "fifth"]


func _times(n: int) -> String:
	return ORDINALS[n - 1] if n >= 1 and n <= ORDINALS.size() else "%dth" % n


## She says something about it, then the nearest onlookers do, each in their own way (the
## director's own contact reaction: an observed event she answers aloud, in character).
func _react_to_refusal(pony: Node3D, bucked: bool) -> void:
	var id := HORN.pony_id(pony)
	var cast := _cast()
	if not cast.has(id): return
	var s := _state()
	var hers := int((s.wronged as Dictionary).get(id, 1))
	var total := int(s.strikes)
	var identity: Resource = pony.get("identity")
	var name := str(identity.get("display_name")) if identity != null else id
	var her := "his" if identity != null and identity.get("stallion") == true else "her"
	var she := "he" if her == "his" else "she"
	var what := "grabbed your horn again after you had warned him off, so you bucked him away with your hind legs" if bucked \
		else "grabbed your horn without asking, so you blasted him away with a jolt of your magic"
	var mine := "[Your horn] Anon just %s; he is on the ground, dazed. A unicorn's horn is delicate and private. This is the %s time he has done this to you. React aloud, in character, to what he did%s." \
		% [what, _times(hers), (", and you are running out of patience" if hers >= 2 else "")]
	_react(id, mine, 1.4)
	# Onlookers: the nearest one, two once he makes a habit of it.
	var count := 2 if total >= 3 or hers >= 2 else 1
	var delay := 6.0
	for row: Array in _onlookers(pony, count):
		var other: Node = row[2]
		var other_identity: Resource = other.get("identity")
		var unicorn: bool = other_identity != null and other_identity.has_horn()
		var did := "%s again after %s had warned him off, and %s bucked him" % [name + "'s horn", she, she] if bucked \
			else "%s without asking, and %s blasted him away with %s magic" % [name + "'s horn", she, her]
		var habit := "" if total <= 1 else " Word is that he has grabbed unicorns' horns %d times now." % total
		var text := "[Something you just saw] Anon grabbed %s; he is lying on the ground, dazed. Touching a unicorn's horn uninvited is a serious breach of manners.%s%s React aloud in a way that suits your personality and how you feel about Anon and %s." \
			% [did, habit, (" You are a unicorn yourself." if unicorn else ""), name]
		_react(str(row[1]), text, delay)
		delay += 6.0


## The nearest awake ponies within WITNESS_RANGE of her: [[distance, id, node]], at most `count`.
func _onlookers(pony: Node3D, count: int) -> Array:
	var id := HORN.pony_id(pony)
	var cast := _cast()
	var near: Array = []
	for other_id: Variant in cast:
		var other: Variant = (cast[other_id] as Dictionary).get("node")
		if str(other_id) == id or other == pony or not other is Node3D or not is_instance_valid(other): continue
		var d := (other as Node3D).global_position.distance_to(pony.global_position)
		if d <= WITNESS_RANGE and other.get("sleeping") != true: near.append([d, str(other_id), other])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return near.slice(0, count)


## Her horn just burst into sparkles: she reacts, then the nearest onlooker, in their own way.
func _react_to_overload(pony: Node3D) -> void:
	var id := HORN.pony_id(pony)
	if _cast().has(id):
		_react(id, "Anon has been gently stroking your horn, and it just overflowed in a burst of sparkles in your magic colour. You are flustered and blushing, a little dazed. React briefly and in character; a shy word, a giggle or just [silence] all fit.", 1.2)
	var identity: Resource = pony.get("identity")
	var name := str(identity.get("display_name")) if identity != null else id
	var her := "his" if identity != null and identity.get("stallion") == true else "her"
	var she := "he" if her == "his" else "she"
	for row: Array in _onlookers(pony, 1):
		var other: Node = row[2]
		var other_identity: Resource = other.get("identity")
		var unicorn: bool = other_identity != null and other_identity.has_horn()
		var text := "[Something you just saw] Anon was gently stroking %s's horn with %s permission, and %s horn just overflowed in a harmless burst of sparkles; %s is blushing and flustered. A unicorn only lets someone very close touch %s horn.%s React aloud in a way that suits your personality and how you feel about Anon and %s: teasing, embarrassed, delighted, scandalised or quietly amused all fit." \
			% [name, her, her, she, her, (" You are a unicorn yourself." if unicorn else ""), name]
		_react(str(row[1]), text, 6.0)


func _react(id: String, text: String, delay: float) -> void:
	var now := Time.get_ticks_msec()
	_reactions.append({"id": id, "text": text, "at": now + int(delay * 1000.0), "until": now + int((delay + 25.0) * 1000.0)})


## One at a time, whenever the director is free (it drops a reaction while it is busy).
func _tick_reactions() -> void:
	if _reactions.is_empty() or not is_instance_valid(_director): return
	var now := Time.get_ticks_msec()
	_reactions = _reactions.filter(func(r: Dictionary) -> bool: return now < int(r.until))
	if _reactions.is_empty() or now < int(_reactions[0].at): return
	if str(_director.get("state")) != "idle" or not _director.has_method("_on_physical_reaction"): return
	var r: Dictionary = _reactions.pop_front()
	_log("%s reacts" % str(r.id))
	_director.call("_on_physical_reaction", "contact", str(r.id), true, str(r.text))


# ------------------------------------------------------------------ memory

const LINES := {
	"refused": "Anon grabbed %s's horn without asking, and she blasted him away with her magic.",
	"buck": "Anon grabbed %s's horn again after she had warned him off, and she bucked him.",
	"stroke": "%s let Anon gently stroke her horn, shy and flustered.",
	"burst": "%s's horn overflowed in a burst of sparkles while Anon stroked it, leaving her blushing.",
	"apology": "Anon apologised to %s for grabbing her horn.",
	"moon": "Anon grabbed %s's horn for the fifth time, and she banished him to the moon.",
	"everfree": "Anon grabbed %s's horn for the fifth time, and she teleported him into the Everfree Forest.",
}


func _cast() -> Dictionary:
	var game := _game()
	var director: Variant = game.get("director") if game != null else null
	var cast: Variant = director.get("characters") if director is Object and is_instance_valid(director) else null
	return cast if cast is Dictionary else {}


func _node_for(id: String) -> Variant:
	var row: Variant = _cast().get(id)
	return (row as Dictionary).get("node") if row is Dictionary else null


## Ponies nearby and she herself remember it, as Kissing records a kiss.
func _record(pony: Node3D, what: String) -> void:
	var game := _game()
	var memory: Variant = game.get("world_context") if game != null else null
	var cast := _cast()
	if not memory is Object or not memory.has_method("record") or cast.is_empty(): return
	var id := ""
	for key: Variant in cast:
		if (cast[key] as Dictionary).get("node") == pony: id = str(key)
	if id.is_empty(): return
	var key := "%s:%s" % [id, what]
	var now := Time.get_ticks_msec()
	if what != "apology" and now - int(_recorded.get(key, -1000000000)) < int(RECORD_GAP * 1000.0): return
	var witnesses := [id]
	for other_id: Variant in cast:
		var other: Variant = (cast[other_id] as Dictionary).get("node")
		if other == pony or not other is Node3D or not is_instance_valid(other): continue
		if (other as Node3D).global_position.distance_to(pony.global_position) <= WITNESS_RANGE: witnesses.append(str(other_id))
	var identity: Resource = pony.get("identity")
	var text: String = LINES[what] % (str(identity.get("display_name")) if identity != null else id)
	if identity != null and identity.get("stallion") == true:
		text = text.replace(" she ", " he ").replace(" her ", " his ").replace(" her.", " him.").replace("her,", "him,")
	if str(memory.call("record", "horn_touch", text, witnesses, [id, "player"])).is_empty(): return
	_recorded[key] = now
	_log("recorded %s: %s" % [str(witnesses), text])


## Five unwanted touches: the whole town hears of it.
func _word_gets_around() -> void:
	var game := _game()
	var memory: Variant = game.get("world_context") if game != null else null
	var cast := _cast()
	if not memory is Object or not memory.has_method("record") or cast.is_empty(): return
	var everyone: Array = []
	for id: Variant in cast: everyone.append(str(id))
	var text := "Word is going around town that Anon keeps grabbing unicorns' horns without asking. Unicorns are keeping their distance from him until he apologises."
	memory.call("record", "horn_touch", text, everyone, ["player"])
	_log("word gets around")


func _exit_tree() -> void:
	_end_own()
	_restore_approach()
	for pony: Variant in _touch.keys():
		if is_instance_valid(pony): _end_touch(pony as Node3D)
	if is_instance_valid(_locked): _locked.set("controls_locked", false)
	if is_instance_valid(_director) and _director.has_signal("transcript") and _director.transcript.is_connected(_on_transcript):
		_director.transcript.disconnect(_on_transcript)
	if is_instance_valid(_director) and _director.has_signal("reply") and _director.reply.is_connected(_on_reply):
		_director.reply.disconnect(_on_reply)
	for node in get_tree().get_nodes_in_group("horn_touch_fx"): node.queue_free()
