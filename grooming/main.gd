extends Node
## Grooming: a mane & tail brush, a coat brush, and wing preening.
##
## How it works
##   - Both brushes are briefcase items, given once per world. They are added as non-edible entries
##     in the game's item data (merge/world/food/definitions.json), the sturdiest route: script
##     extensions do not compile over the released game's binary scripts in 0.1.1.
##   - VR: stroke a pony with the brush; the bristles touching the right part of her is enough.
##     Preening: stroke a pegasus' or alicorn's wing with your hand.
##   - Desktop: brush in hand, look at her mane, tail or coat, hold the mouse button
##     (a small input node placed last under the root, so it sees the click before the briefcase).
##     Preening: pet her wing with an empty hand (the game's own petting).
##   - Each action has its own animation on her (groom_pose.gd) and on the brush (desktop strokes).
##   - Finishing a grooming (GOAL seconds of good strokes) raises friendship, and love with an adult
##     pony already fond of Anon. The pony's AI is told what happened. Each pony and action pays at most
##     once per COOLDOWN seconds; brushing past that is just nice.
## Fillies, colts and a young player get friendship only (the game's impressions code drops romance
## for them too). A pony who is angry or asked for space turns away.

const ID := "grooming"
const POSE := preload("res://mods/grooming/groom_pose.gd")
## The princesses' mane, tail and wings are built into their body model: the mod's own reach for those.
const BUILT_IN := preload("res://mods/grooming/built_in_hair.gd")
const PONY_SCRIPT := "res://world/characters/hybrid_mare/hybrid_mare.gd"
const MANE_BRUSH := "food:groom-mane-brush"
const COAT_BRUSH := "food:groom-coat-brush"
## Bristle tips in the item visual's frame (the game centres the model on its bounds;
## tools/make_models.gd prints those centres).
const BRISTLE := {"food:groom-mane-brush": Vector3(0, -0.0214, -0.07685), "food:groom-coat-brush": Vector3(0, -0.0305, 0)}
const INPUT := preload("res://mods/grooming/input_catcher.gd")
## The game's spa feathers: stray feathers pinned crooked on her open wing, and the loose feather
## that drifts down once one comes free (world/minigames/spa/spa_feathers.gd).
const FEATHERS := preload("res://world/minigames/spa/spa_feathers.gd")
## Sounds (res://mods/grooming/sounds/). Brushing and feathers: Anon's own recordings. Wing flaps:
## "Large Wings Flap" by AntumDeluge, CC0 (opengameart.org/content/large-wings-flap).
const SND := "res://mods/grooming/sounds/"
## Coat: one random bristle stroke per brush stroke.
const COAT_STROKES := 8
## Mane and tail: one continuous brushing loop while strokes land, faded out when they stop.
const MANE_LOOP := SND + "mane_brushing_loop.ogg"
const LOOP_DB := -8.0
const LOOP_LINGER := 0.35
## A feather coming free: one of 19 takes, never one of the last 3, pitch and volume varied.
const FEATHER_TAKES := 19
const FEATHER_NO_REPEAT := 3
## Her wings spreading for preening (one flap), and the shake when preening is done (three flaps).
const WINGS_OPEN := SND + "wings_open.wav"
const WING_SHAKE := SND + "wing_shake.wav"
## Wing flaps in wing_shake.wav (seconds from its start).
const FLAP_TIMES := [0.0, 0.88, 1.72]
## Ruffled feathers she has when her wings open for preening.
const RUFFLED := Vector2i(3, 5)
## Seconds of preening on one feather before it is smoothed and the loose one drifts off.
const FEATHER_SECONDS := 0.9
## A hand this close to a ruffled feather preens it (VR, metres).
const FEATHER_REACH := 0.07
## Desktop: the crosshair this close to a feather's line picks it.
const FEATHER_AIM := 0.06
## Seconds the open wings wait for the first preen before she folds them again.
const PREEN_GAP := 10.0
const MANE_REGIONS := ["mane", "tail", "head"]
const COAT_REGIONS := ["neck", "withers", "back", "barrel", "shoulder", "chest", "rump", "flank", "belly", "leg"]
## Seconds of good strokes that complete one grooming.
const GOAL := {"mane": 10.0, "tail": 8.0, "coat": 14.0, "preen": 10.0}
## Real seconds before the same pony pays again for the same action.
const COOLDOWN := 600.0
## Friendship and love tag values (the game doubles positive gains and caps them per sitting).
const FRIENDSHIP := {"mane": 2, "tail": 2, "coat": 2, "preen": 3}
const ROMANCE := {"mane": 1, "tail": 1, "coat": 1, "preen": 2}
const THOUGHTS := {
	"mane": "Anon brushed my mane so gently. I could get used to that.",
	"tail": "Anon brushed out my tail. It feels so light and soft now.",
	"coat": "Anon brushed my coat all over. I'm so relaxed I could nap.",
	"preen": "Anon preened my wings, feather by feather. That was... really nice.",
}
const MEMORIES := {
	"mane": "Anon brushed your mane with a mane brush.",
	"tail": "Anon brushed your tail with a mane brush.",
	"coat": "Anon brushed your coat with a body brush.",
	"preen": "Anon preened your wings with his hands, smoothing every feather.",
}
const TICK := 0.05
const DESKTOP_REACH := 1.6
## A contact gap shorter than this keeps the session (and its animation) going.
const GAP := 1.5
## VR brush speeds that count as a stroke (m/s).
const MIN_SPEED := 0.03
const MAX_SPEED := 2.0
const CONTACT := 0.06
const WING_HOLD := 0.75   # hybrid_open_wings.hold_at: 1 = half open, lower = wider
const SHAKE_SECONDS := 2.4

## pony -> {tool, good, last, pose, side, done, shake, wings, aside}
var _sessions: Dictionary = {}
var _tick := 0.0
var _last_tip: Dictionary = {}   # side -> Vector3
var _desk_down := false
var _desk_hit: Dictionary = {}
var _desk_blend := 0.0
var _desk_stroke := 0.0
var _desk_item: Node3D
var _sound_clock := 0.0
var _refused: Dictionary = {}    # pony -> msec
var _audio: AudioStreamPlayer3D
var _catcher: Node
var _loop: AudioStreamPlayer3D
var _loop_until := 0
var _loop_pitch := 1.0
var _loop_at := Vector3.INF
var _recent_feathers: Array[int] = []
var _built_in := BUILT_IN.new()


func _ready() -> void:
	add_to_group("grooming_mod")
	add_to_group("interaction_hint_sources")
	Mods.world_ready.connect(_on_world)
	Mods.world_closed.connect(_on_world_closed)
	_audio = AudioStreamPlayer3D.new()
	_audio.volume_db = -14.0; _audio.max_distance = 8.0
	add_child(_audio)
	_loop = AudioStreamPlayer3D.new()
	_loop.max_distance = 8.0
	add_child(_loop)
	if Mods.game != null: _on_world(Mods.game)


func _on_world(game: Node) -> void:
	_place_catcher.call_deferred()
	# Hand out the brushes once per world.
	var state := Mods.state(ID)
	if bool(state.get("granted_brushes", false)): return
	var inventory: Node = game.get("inventory")
	if inventory == null: return
	var store: Variant = inventory.get("inventory")
	if store == null or not store.has_method("grant"): return
	var mane: int = store.grant(MANE_BRUSH)
	var coat: int = store.grant(COAT_BRUSH)
	if mane >= 0 and coat >= 0:
		state.granted_brushes = true
		Mods.save_changed()
		print("[grooming] brushes added to the briefcase")
	else:
		print("[grooming] no room for the brushes yet; trying again next load")


func _on_world_closed(_game: Node) -> void:
	for pony: Variant in _sessions.keys(): _end(pony, true)
	_sessions.clear()
	_desk_down = false; _desk_hit = {}; _desk_item = null


## The desktop click must reach us before the briefcase's own _input, which runs earlier the later
## a node is in the tree: so a tiny node goes last under the root, re-placed for every world.
func _place_catcher() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(_catcher):
		_catcher = INPUT.new()
		_catcher.name = "GroomingInput"
		_catcher.set("groomer", self)
		get_tree().root.add_child(_catcher)
	get_tree().root.move_child(_catcher, -1)


func _game() -> Node:
	var game: Node = Mods.game
	return game if is_instance_valid(game) and game.is_inside_tree() else null


# ---------------------------------------------------------------- desktop

## Called by input_catcher.gd. True when the click was used.
func desktop_click(pressed: bool) -> bool:
	if not pressed:
		var was := _desk_down
		_desk_down = false
		return was
	var feather := _desktop_feather()
	if not feather.is_empty():
		_desk_down = true
		_desk_hit = feather
		return true
	var hit := _desktop_target()
	if hit.is_empty() or str(hit.get("tool", "")).is_empty(): return false
	if not _willing(hit.target): _turn_away(hit.target); return true
	_desk_down = true
	_desk_hit = hit
	return true


## Desktop preening: the ruffled feather under the crosshair on a wing opened for preening, with no
## brush in hand. {target, feather, point, tool: "feather"} or {}.
func _desktop_feather() -> Dictionary:
	var game := _game()
	if game == null: return {}
	var inventory: Node = game.get("inventory")
	if inventory == null or not bool(inventory.get("_desktop")): return {}
	var held: Dictionary = inventory.get("held")
	if held.has("desktop") and is_instance_valid(held.desktop) and str((held.desktop as Node).get_meta("item_id", "")) in [MANE_BRUSH, COAT_BRUSH]: return {}
	var camera: Camera3D = inventory.get("camera")
	if camera == null: return {}
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var best := {}
	var best_gap := FEATHER_AIM
	for pony: Variant in _sessions:
		var session: Dictionary = _sessions[pony]
		if session.tool != "preen" or not is_instance_valid(pony): continue
		for feather: Variant in session.feathers:
			if not is_instance_valid(feather): continue
			for point: Vector3 in [FEATHERS.root_point(feather), FEATHERS.tip_point(feather), (FEATHERS.root_point(feather) + FEATHERS.tip_point(feather)) * 0.5]:
				var to := point - origin
				var along := to.dot(forward)
				if along <= 0.1 or along > DESKTOP_REACH: continue
				var gap := (to - forward * along).length()
				if gap < best_gap: best_gap = gap; best = {"target": pony, "feather": feather, "point": point, "tool": "feather"}
	return best


## What the desktop brush points at: {target, point, normal, region, tool, item} or {}.
func _desktop_target() -> Dictionary:
	var game := _game()
	if game == null: return {}
	var inventory: Node = game.get("inventory")
	if inventory == null or not bool(inventory.get("_desktop")): return {}
	var held: Dictionary = inventory.get("held")
	if not held.has("desktop") or not is_instance_valid(held.desktop): return {}
	var item: Node3D = held.desktop
	var item_id := str(item.get_meta("item_id", ""))
	if item_id not in [MANE_BRUSH, COAT_BRUSH]: return {}
	var camera: Camera3D = inventory.get("camera")
	if camera == null: return {}
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * DESKTOP_REACH
	var best := {}
	var closest := INF
	for pony: Variant in _ponies(game):
		if (pony as Node3D).global_position.distance_squared_to(origin) > 9.0: continue
		var touch: Node = pony.get("touch_body")
		if touch == null or not touch.has_method("desktop_offer"): continue
		var hit: Dictionary = touch.desktop_offer(origin, end)
		if item_id == MANE_BRUSH: hit = _with_hair(pony, hit, origin, end, 1.0)
		if hit.is_empty(): continue
		var distance := origin.distance_to(hit.point)
		if distance < closest: closest = distance; best = hit
	if best.is_empty(): return {}
	best.tool = _tool_for(item_id, str(best.region))
	best.item = item
	return best


## Desktop, empty hand: a winged pony's wing under the crosshair. {target, point} or {}.
func _desktop_wing() -> Dictionary:
	var game := _game()
	if game == null: return {}
	var inventory: Node = game.get("inventory")
	if inventory == null or not bool(inventory.get("_desktop")): return {}
	var held: Dictionary = inventory.get("held")
	if held.has("desktop") and is_instance_valid(held.desktop): return {}
	var camera: Camera3D = inventory.get("camera")
	if camera == null: return {}
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * DESKTOP_REACH
	for pony: Variant in _ponies(game):
		if (pony as Node3D).global_position.distance_squared_to(origin) > 9.0 or not _winged(pony): continue
		var touch: Node = pony.get("touch_body")
		if touch == null or not touch.has_method("desktop_offer"): continue
		var hit: Dictionary = touch.desktop_offer(origin, end)
		if not hit.is_empty() and str(hit.region) == "wing": return {"target": pony, "point": hit.point}
	return {}


## A mane or tail built into her body (the princesses), when it is nearer than the game's hit.
func _with_hair(pony: Node3D, hit: Dictionary, from: Vector3, to: Vector3, radius_scale: float) -> Dictionary:
	var hair := _built_in.hair_hit(pony, from, to, radius_scale)
	if hair.is_empty(): return hit
	if hit.is_empty() or from.distance_to(hair.point) <= from.distance_to(Vector3(hit.point)) + 0.03: return hair
	return hit


func _winged(pony: Variant) -> bool:
	var identity: Variant = pony.get("identity")
	return identity != null and identity.has_method("has_wings") and bool(identity.has_wings())


func _preen_count(pony: Variant) -> String:
	var session: Dictionary = _sessions.get(pony, {})
	if session.is_empty(): return ""
	return "%d/%d" % [int(session.smoothed), int(session.total)]


func _tool_for(item_id: String, region: String) -> String:
	if item_id == MANE_BRUSH and region in MANE_REGIONS: return "tail" if region == "tail" else "mane"
	if item_id == COAT_BRUSH and region in COAT_REGIONS: return "coat"
	return ""


## The game's hint line under the crosshair (interaction_hint_sources).
func interaction_hint() -> Dictionary:
	var feather := _desktop_feather()
	if not feather.is_empty():
		return {"target": feather.target, "text": "Hold click · Preen feather  %s" % _preen_count(feather.target), "point": feather.point, "outline": null}
	var wing := _desktop_wing()
	if not wing.is_empty():
		var session: Dictionary = _sessions.get(wing.target, {})
		var text := "Pet her wing · Open it for preening"
		if not session.is_empty() and session.tool == "preen":
			text = "Preen: aim at a ruffled feather  %s" % _preen_count(wing.target) if bool(session.spawned) else "Preening: her wings are opening"
		return {"target": wing.target, "text": text, "point": wing.point, "outline": null}
	var hit := _desktop_target()
	if hit.is_empty(): return {}
	var text := ""
	match str(hit.tool):
		"mane": text = "Hold click · Brush mane"
		"tail": text = "Hold click · Brush tail"
		"coat": text = "Hold click · Brush coat"
		_: text = "Mane brush: mane and tail" if str(hit.item.get_meta("item_id", "")) == MANE_BRUSH else "Coat brush: her coat"
	var session: Dictionary = _sessions.get(hit.target, {})
	if not session.is_empty() and session.tool == hit.tool and not bool(session.done):
		text += "  %d%%" % int(100.0 * float(session.good) / float(GOAL[session.tool]))
	return {"target": hit.target, "text": text, "point": hit.point, "outline": null}


## Desktop brush animation: the brush model leaves the hand and strokes over her, then comes back.
func _animate_desktop_brush(delta: float) -> void:
	var item: Node3D = _desk_hit.get("item", null) if _desk_down else _desk_item
	if _desk_down and is_instance_valid(item): _desk_item = item
	_desk_blend = move_toward(_desk_blend, 1.0 if _desk_down and not _desk_hit.is_empty() else 0.0, delta / 0.2)
	if not is_instance_valid(_desk_item): return
	var model := _visual(_desk_item)
	if model == null: return
	if _desk_blend <= 0.0:
		model.transform = Transform3D.IDENTITY
		_desk_item = null
		return
	if _desk_hit.is_empty() or str(_desk_hit.tool) == "feather": return
	var tool := str(_desk_hit.tool)
	var pony: Node3D = _desk_hit.target
	var normal: Vector3 = Vector3(_desk_hit.normal).normalized()
	# Stroke direction along her surface: down the mane and tail, toward her tail on the coat.
	var along := Vector3.DOWN if tool in ["mane", "tail"] else pony.global_basis.z
	along = (along - normal * along.dot(normal))
	if along.length() < 0.05: along = (pony.global_basis.z - normal * pony.global_basis.z.dot(normal))
	along = along.normalized()
	_desk_stroke += delta * (1.4 if tool in ["mane", "tail"] else 2.2)
	var t := fposmod(_desk_stroke, 1.0)
	var length := 0.12 if tool in ["mane", "tail"] else 0.07
	# Mane and tail: a long stroke down, lifted on the way back. Coat: short brisk flicks with a curl.
	var travel := 0.0
	var lift := 0.0
	if t < 0.7:
		travel = lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, t / 0.7))
	else:
		travel = lerpf(0.5, -0.5, smoothstep(0.0, 1.0, (t - 0.7) / 0.3)); lift = sin((t - 0.7) / 0.3 * PI) * 0.03
	var side_curl := 0.0 if tool != "coat" else sin(_desk_stroke * TAU) * 0.012
	var tangent := normal.cross(along).normalized()
	var point: Vector3 = Vector3(_desk_hit.point) + along * travel * length + normal * lift + tangent * side_curl
	# Brush frame: bristles (-Y) into her, head (-Z) along the stroke.
	var y := normal
	var z := -along
	var x := y.cross(z).normalized()
	var brush_basis := Basis(x, y, z).orthonormalized()
	var bristle: Vector3 = BRISTLE.get(str(_desk_item.get_meta("item_id", "")), Vector3.ZERO)
	var goal := Transform3D(brush_basis, point - brush_basis * bristle)
	var local_goal := (_desk_item as Node3D).global_transform.affine_inverse() * goal
	model.transform = Transform3D.IDENTITY.interpolate_with(local_goal, _desk_blend)


# ---------------------------------------------------------------- per tick

func _physics_process(delta: float) -> void:
	_animate_desktop_brush(delta)
	_animate_sessions(delta)
	_tick_loop(delta)
	_tick += delta
	if _tick < TICK: return
	var dt := _tick
	_tick = 0.0
	var game := _game()
	if game == null: return
	_sense_desktop(game, dt)
	_sense_vr_brushes(game, dt)
	_sense_preening(game, dt)
	_expire(dt)


func _sense_desktop(_game_node: Node, dt: float) -> void:
	if not _desk_down: return
	if str(_desk_hit.get("tool", "")) == "feather" or (_desk_hit.is_empty() and not _desktop_feather().is_empty()):
		var feather := _desktop_feather()
		if feather.is_empty(): return
		_desk_hit = feather
		_preen_feather(feather.target, feather.feather, Vector3(_desktop_camera_point(feather.point)), dt)
		return
	var hit := _desktop_target()
	if hit.is_empty() or str(hit.tool).is_empty() or (not _desk_hit.is_empty() and hit.target != _desk_hit.target):
		# Looked away: the stroke stops, the button press stays until released.
		_desk_hit = {}
		return
	_desk_hit = hit
	_stroke(hit.target, str(hit.tool), hit.point, dt)


func _sense_vr_brushes(game: Node, dt: float) -> void:
	var inventory: Node = game.get("inventory")
	if inventory == null or bool(inventory.get("_desktop")): return
	var held: Dictionary = inventory.get("held")
	for side: String in held.keys():
		if side == "desktop": continue
		var item: Variant = held[side]
		if not is_instance_valid(item): _last_tip.erase(side); continue
		var item_id := str((item as Node).get_meta("item_id", ""))
		if item_id not in [MANE_BRUSH, COAT_BRUSH]: _last_tip.erase(side); continue
		var model := _visual(item)
		if model == null: continue
		var xform: Transform3D = model.global_transform
		var tip := xform * Vector3(BRISTLE[item_id])
		var speed := 0.0
		if _last_tip.has(side): speed = tip.distance_to(_last_tip[side]) / dt
		_last_tip[side] = tip
		var down := -xform.basis.y.normalized()
		for pony: Variant in _ponies(game):
			if (pony as Node3D).global_position.distance_to(tip) > 2.5: continue
			var touch: Node = pony.get("touch_body")
			if touch == null or not touch.has_method("desktop_offer"): continue
			var hit: Dictionary = touch.desktop_offer(tip - down * 0.08, tip + down * 0.05)
			if item_id == MANE_BRUSH: hit = _with_hair(pony, hit, tip - down * 0.08, tip + down * 0.05, 1.3)
			if hit.is_empty() or Vector3(hit.point).distance_to(tip) > CONTACT: continue
			var tool := _tool_for(item_id, str(hit.region))
			if tool.is_empty(): continue
			if speed < MIN_SPEED or speed > MAX_SPEED: _hold(pony, tool); break
			if not _willing(pony): _turn_away(pony); break
			_stroke(pony, tool, hit.point, dt)
			if inventory.has_method("_haptic") and randf() < 0.15: inventory.call("_haptic", side)
			break


## Wing preening: the game's own petting on her wing (VR hand or desktop pet).
func _sense_preening(game: Node, dt: float) -> void:
	for pony: Variant in _ponies(game):
		var identity: Variant = pony.get("identity")
		if identity == null or not identity.has_method("has_wings") or not identity.has_wings(): continue
		var touch: Node = pony.get("touch_body")
		if touch == null or not bool(touch.get("petting")) or str(touch.get("pet_region")) != "wing": continue
		if not _willing(pony): _turn_away(pony); continue
		_stroke(pony, "preen", Vector3.INF, dt)
	# VR: a hand at a ruffled feather preens it.
	var inventory: Node = game.get("inventory")
	if inventory == null or bool(inventory.get("_desktop")) or not inventory.has_method("hand_sample"): return
	for pony: Variant in _sessions.keys():
		var session: Dictionary = _sessions.get(pony, {})
		if session.is_empty() or session.tool != "preen" or (session.feathers as Array).is_empty(): continue
		for side: String in ["left", "right"]:
			var sample: Dictionary = inventory.call("hand_sample", side)
			if not bool(sample.get("active", false)): continue
			var hand: Vector3 = sample.get("tip", Vector3.INF)
			var palm: Vector3 = sample.get("grip_position", Vector3.INF)
			for feather: Variant in (session.feathers as Array).duplicate():
				if not is_instance_valid(feather): continue
				var root: Vector3 = FEATHERS.root_point(feather)
				var tip: Vector3 = FEATHERS.tip_point(feather)
				var near := false
				for p: Vector3 in [hand, palm]:
					if p.is_finite() and Geometry3D.get_closest_point_to_segment(p, root, tip).distance_to(p) < FEATHER_REACH: near = true
				if near:
					_preen_feather(pony, feather, hand if hand.is_finite() else palm, dt)
					if randf() < 0.2: inventory.call("_haptic", side)
					break


## The camera, for the desktop preening wiggle (the feather bends toward where you look from).
func _desktop_camera_point(fallback: Vector3) -> Vector3:
	var camera := _camera()
	return camera.global_position if camera != null else fallback


## One preening touch on a ruffled feather: it wiggles toward the hand, and after FEATHER_SECONDS it
## is smoothed out: the loose feather comes free and drifts down. All smoothed: preening is done.
func _preen_feather(pony: Node3D, feather: Node3D, toward: Vector3, dt: float) -> void:
	var session: Dictionary = _sessions.get(pony, {})
	if session.is_empty() or session.tool != "preen" or not is_instance_valid(feather): return
	session.last = Time.get_ticks_msec()
	session.ending = false
	session.side = _side_of(pony)
	(session.pose as Node).set("phase", float((session.pose as Node).get("phase")) + dt * TAU * 0.8)
	var work: Dictionary = session.work
	var t: float = float(work.get(feather, 0.0)) + dt
	work[feather] = t
	FEATHERS.bend(feather, toward, 0.5 + 0.5 * sin(t * 18.0))
	if pony.has_method("begin_touch") and not pony.call("is_held"): pony.call("begin_touch", Vector3.ZERO, 0.5)
	if t < FEATHER_SECONDS: return
	work.erase(feather)
	(session.feathers as Array).erase(feather)
	session.smoothed = int(session.smoothed) + 1
	var game := _game()
	var loose: Node3D = FEATHERS.detach(feather, game if game != null else get_tree().current_scene)
	if loose != null: _play_feather(loose.global_position)
	var expressions: Variant = pony.get("expressions")
	if expressions != null and expressions.has_method("fluster"): expressions.fluster(0.5)
	if (session.feathers as Array).is_empty():
		session.done = true
		_reward(pony, "preen", float(session.good) + float(session.smoothed) * FEATHER_SECONDS)
		# Done: a good shake of the wings, then she folds them.
		session.shake = 0.0
		_flutter(pony)
		session.last = Time.get_ticks_msec() + int((SHAKE_SECONDS - GAP) * 1000.0)


## Stray feathers go on once the wings have settled open (where the feathers rest).
func _spawn_ruffled(pony: Node3D, session: Dictionary) -> void:
	var wings: Variant = session.wings
	if bool(session.spawned) or wings == null or not is_instance_valid(wings): return
	if float(wings.get("tuck")) > 0.01 or absf(float(wings.get("half")) - float(wings.get("hold_goal"))) > 0.02: return
	session.spawned = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var meshes: Variant = wings.get("meshes")
	var made: Array[Node3D] = FEATHERS.spawn(pony, rng.randi_range(RUFFLED.x, RUFFLED.y), rng, meshes if meshes is Array else [])
	if made.is_empty():
		# Her open wings' hulls may still be fitting: try a few times a second, for up to six seconds.
		var now := Time.get_ticks_msec()
		if now < int(session.get("scatter_at", 0)): session.spawned = false; return
		session.scatter_at = now + 250
		made = BUILT_IN.scatter_feathers(pony, rng.randi_range(RUFFLED.x, RUFFLED.y), rng)
		session.scatter_tries = int(session.get("scatter_tries", 0)) + 1
		if made.is_empty() and int(session.scatter_tries) < 24:
			session.spawned = false
			return
	session.feathers = made
	session.total = made.size()
	if made.is_empty():
		print("[grooming] no feather bones to ruffle on %s; preening by petting time instead" % _pony_id(pony))


# ---------------------------------------------------------------- sessions

func _stroke(pony: Node3D, tool: String, point: Vector3, dt: float) -> void:
	var session: Dictionary = _sessions.get(pony, {})
	if not session.is_empty() and session.tool != tool:
		_end(pony, true)
		session = {}
	if not session.is_empty() and bool(session.ending): session.ending = false
	if session.is_empty():
		session = _begin(pony, tool)
		if session.is_empty(): return
	session.last = Time.get_ticks_msec()
	session.good = float(session.good) + dt
	session.side = _side_of(pony)
	(session.pose as Node).set("phase", float((session.pose as Node).get("phase")) + dt * TAU * 0.8)
	var by_time: bool = tool != "preen" or (bool(session.spawned) and int(session.total) == 0)
	if by_time and not bool(session.done) and float(session.good) >= float(GOAL[tool]):
		session.done = true
		_reward(pony, tool, float(session.good))
	if tool != "preen": _play_sound(tool, point if point.is_finite() else pony.global_position, dt)
	# She stays put while groomed, as she does while petted.
	if pony.has_method("begin_touch") and not pony.call("is_held"): pony.call("begin_touch", Vector3.ZERO, 0.5)


## Contact without a stroke (a brush held still on her): keeps the session alive, no progress.
func _hold(pony: Node3D, tool: String) -> void:
	var session: Dictionary = _sessions.get(pony, {})
	if not session.is_empty() and session.tool == tool: session.last = Time.get_ticks_msec()


func _begin(pony: Node3D, tool: String) -> Dictionary:
	var skeleton: Skeleton3D = pony.get("skeleton")
	if skeleton == null: return {}
	var pose: SkeletonModifier3D = POSE.new()
	pose.name = "GroomingPose"
	pose.mare = pony; pose.tool = tool; pose.side = _side_of(pony)
	skeleton.add_child(pose)
	var session := {"tool": tool, "good": 0.0, "last": Time.get_ticks_msec(), "pose": pose, "side": pose.side,
		"done": false, "shake": -1.0, "wings": null, "aside": false, "ending": false,
		"feathers": [], "total": 0, "smoothed": 0, "work": {}, "spawned": false}
	_sessions[pony] = session
	var expressions: Variant = pony.get("expressions")
	if expressions != null and expressions.has_method("fluster") and tool == "preen": expressions.fluster(0.6)
	if pony.has_method("set_action_gaze") and tool in ["mane", "coat"]:
		var camera: Node3D = _camera()
		if camera != null: pony.call("set_action_gaze", camera)
	if tool == "preen":
		session.wings = _open_wings(pony)
		if session.wings != null: _play_at(WINGS_OPEN, pony.global_position + Vector3.UP * 0.9, -9.0, randf_range(0.95, 1.05))
	if tool == "tail":
		var tail: Variant = pony.get("tail_motion")
		if tail != null and "aside_goal" in tail: session.aside = true
	# Her AI hears about it like petting (one line per session; the director rate-limits it).
	if pony.has_signal("physical_reaction") and tool != "preen":
		pony.emit_signal("physical_reaction", "petted:" + ("tail" if tool == "tail" else ("mane" if tool == "mane" else "back")))
	return session


## Session ends after GAP seconds without contact. A finished preen shakes the wings out first.
func _expire(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	for pony: Variant in _sessions.keys():
		var session: Dictionary = _sessions[pony]
		if not is_instance_valid(pony) or not (pony as Node).is_inside_tree():
			_end(pony, true); continue
		var asleep := bool(pony.get("sleeping")) or bool(pony.call("is_held"))
		var gap := PREEN_GAP if session.tool == "preen" and not bool(session.done) else GAP
		if asleep or float(now - int(session.last)) / 1000.0 > gap:
			if session.tool == "preen" and bool(session.done) and float(session.shake) < 0.0 and not asleep:
				session.shake = 0.0
				session.last = now + int((SHAKE_SECONDS - GAP) * 1000.0)
				_flutter(pony)
				continue
			_end(pony, false)


## Eases each pose in and out, drives faces, wings and tail.
func _animate_sessions(delta: float) -> void:
	for pony: Variant in _sessions.keys():
		var session: Dictionary = _sessions[pony]
		var pose: Variant = session.pose
		if not is_instance_valid(pony) or not is_instance_valid(pose): continue
		var ending: bool = session.ending
		pose.amount = move_toward(float(pose.amount), 0.0 if ending else 1.0, delta / (0.6 if ending else 0.45))
		pose.side = lerpf(float(pose.side), float(session.side), clampf(delta * 3.0, 0.0, 1.0))
		var a: float = pose.amount
		var tool := str(session.tool)
		var expressions: Variant = pony.get("expressions")
		if expressions != null and expressions.has_method("touch"):
			# Smile and how shut her eyes are: content for brushing, dreamy for preening.
			var face := {"mane": Vector2(0.7, 0.55), "tail": Vector2(0.55, 0.3), "coat": Vector2(0.75, 0.7), "preen": Vector2(0.8, 0.6)}
			var f: Vector2 = face.get(tool, Vector2(0.6, 0.4))
			expressions.touch("grooming", f.x * a, f.y * a)
		if tool == "preen" and session.wings != null and is_instance_valid(session.wings):
			var wings: Node = session.wings
			_spawn_ruffled(pony, session)
			# Steady while the ruffled feathers are on (they ride her feather bones); a soft flex before.
			var hold := WING_HOLD if bool(session.spawned) else WING_HOLD - 0.08 * sin(float(pose.phase) * 1.3) * a
			if float(session.shake) >= 0.0:
				session.shake = float(session.shake) + delta
				var k := clampf(float(session.shake) / SHAKE_SECONDS, 0.0, 1.0)
				pose.shake = (1.0 - k)
				# Three big flaps in time with the sound: wide open, then back in.
				var flap := 0.0
				for at: float in FLAP_TIMES:
					flap = maxf(flap, sin(clampf((float(session.shake) - at) / 0.6, 0.0, 1.0) * PI))
				hold = clampf(WING_HOLD - WING_HOLD * flap, 0.0, 1.0)
			wings.call("hold_at", "grooming", hold)
		if bool(session.aside):
			var tail: Variant = pony.get("tail_motion")
			if tail != null:
				# Tail lifted away from the groomer, swishing gently while brushed.
				var swish := 0.12 * sin(float(pose.phase) * 0.5)
				tail.aside_goal = (-float(session.side) * 0.3 + swish) * a if not ending else 0.0
		if ending and a <= 0.0: _finish(pony)


func _end(pony: Variant, now: bool) -> void:
	var session: Dictionary = _sessions.get(pony, {})
	if session.is_empty(): return
	session.ending = true
	if is_instance_valid(pony):
		if session.tool == "coat" and bool(session.done) and not now:
			# A good long brush ends with a happy stretch.
			var affection: Node = (pony as Node).get_node_or_null("Affection")
			if affection != null and affection.has_method("fidget"): affection.call("fidget", "stretch", float(session.side) < 0.0)
		if (pony as Node).has_method("set_action_gaze") and session.tool in ["mane", "coat"]: pony.call("set_action_gaze", null)
	if now: _finish(pony)


func _finish(pony: Variant) -> void:
	var session: Dictionary = _sessions.get(pony, {})
	_sessions.erase(pony)
	if session.is_empty(): return
	if is_instance_valid(session.pose): (session.pose as Node).queue_free()
	if not is_instance_valid(pony): return
	var expressions: Variant = pony.get("expressions")
	if expressions != null and expressions.has_method("release_touch"): expressions.release_touch("grooming")
	if session.wings != null and is_instance_valid(session.wings): session.wings.call("release_hold", "grooming")
	if session.tool == "preen":
		for feather: Variant in session.feathers:
			if is_instance_valid(feather):
				var mount: Node = (feather as Node).get_parent()
				if mount != null: mount.queue_free()
	if bool(session.aside):
		var tail: Variant = pony.get("tail_motion")
		if tail != null: tail.aside_goal = 0.0


## Her flight's wing set, made the way the game's excitement and spa make it, held half open.
func _open_wings(pony: Node3D) -> Node:
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
	if not bool(wings.call("hold_at", "grooming", WING_HOLD)): return null
	return wings


# ---------------------------------------------------------------- relationship

func _pony_id(pony: Node) -> String:
	var id := str(pony.get_meta("relationship_id", ""))
	if id.is_empty():
		var identity: Variant = pony.get("identity")
		if identity != null: id = str(identity.get("id"))
	return id


func _bonds() -> Node:
	var game := _game()
	if game == null or game.get("world_context") == null: return null
	return game.world_context.get("player_bonds")


## Like hand feeding: not while she is cross with Anon or asked for space.
func _willing(pony: Node3D) -> bool:
	if bool(pony.get("sleeping")) or pony.has_meta("spa_client"): return false
	var identity: Variant = pony.get("identity")
	if identity != null and bool(identity.get("filly")): return true
	var bonds := _bonds()
	var id := _pony_id(pony)
	if bonds == null or id.is_empty(): return true
	var record: Dictionary = bonds.record_for(id)
	var space := Time.get_unix_time_from_system() < float(record.get("cooldowns", {}).get("boundary", 0.0))
	return float(bonds.anger(id)) < 35.0 and not space


func _turn_away(pony: Node3D) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_refused.get(pony, -100000)) < 4000: return
	_refused[pony] = now
	if pony.has_method("set_action_gaze"): pony.call("set_action_gaze", null)
	print("[grooming] %s turns away" % _pony_id(pony))


func _reward(pony: Node3D, tool: String, seconds: float) -> void:
	var id := _pony_id(pony)
	var game := _game()
	if id.is_empty() or game == null or game.get("world_context") == null: return
	var state := Mods.state(ID)
	if not state.has("paid"): state.paid = {}
	var key := id + ":" + tool
	var now := Time.get_unix_time_from_system()
	var expressions: Variant = pony.get("expressions")
	if expressions != null and expressions.has_method("fluster"): expressions.fluster(1.0)
	_sigh(pony)
	if now - float((state.paid as Dictionary).get(key, 0.0)) < COOLDOWN: return
	state.paid[key] = now
	Mods.save_changed()
	var context: Node = game.world_context
	var bonds := _bonds()
	var tags := {"friendship": FRIENDSHIP[tool], "mood": "relaxed", "thought": THOUGHTS[tool]}
	if bonds != null and bonds.eligible_for_romance(id):
		var stage := str(bonds.record_for(id).get("stage", "acquaintance"))
		if int(bonds.interest(id)) >= 25 or stage in ["dating", "engaged", "married"]:
			tags.romance = ROMANCE[tool]
			tags.mood = "happy"
	var impressions: Variant = context.get("impressions")
	if impressions != null and is_instance_valid(impressions):
		impressions.commit(id, tags, "grooming_%s_%d" % [tool, Time.get_ticks_usec()])
	if bonds != null:
		bonds.add_together(id, seconds)
		# A little familiarity and trust, the bond stage's own currencies (player_bonds.gd).
		if bonds.has_method("_save"):
			var r: Dictionary = bonds.record_for(id)
			r.familiarity = minf(100.0, float(r.get("familiarity", 0.0)) + 2.0)
			r.trust = minf(100.0, float(r.get("trust", 0.0)) + 1.0)
			bonds.call("_save", id, r)
	if context.has_method("record"):
		context.record("grooming", MEMORIES[tool], [id, "player"], [id, "player"])
	print("[grooming] %s enjoyed %s grooming (%s)" % [id, tool, str(tags)])


# ---------------------------------------------------------------- helpers

## The game's visual node of a held item (the food visual the item data points at our model).
func _visual(item: Variant) -> Node3D:
	if not is_instance_valid(item): return null
	var visual: Variant = (item as Node).get_meta("food_visual", null)
	return visual as Node3D if is_instance_valid(visual) else null


func _ponies(game: Node) -> Array:
	var out := []
	var mares: Variant = game.get("mares")
	if not mares is Array: return out
	for pony: Variant in mares:
		if is_instance_valid(pony) and (pony as Node3D).is_inside_tree() and (pony as Node3D).is_visible_in_tree() and not bool(pony.get("sleeping")):
			out.append(pony)
	return out


func _camera() -> Node3D:
	var game := _game()
	if game == null: return null
	var inventory: Node = game.get("inventory")
	return inventory.get("camera") if inventory != null else null


## +1 when Anon is on her right, -1 on her left.
func _side_of(pony: Node3D) -> float:
	var camera := _camera()
	if camera == null: return 1.0
	return 1.0 if (camera.global_position - pony.global_position).dot(pony.global_basis.x) >= 0.0 else -1.0


func _play_at(path: String, at: Vector3, volume: float, pitch: float) -> void:
	if not ResourceLoader.exists(path): return
	var player := AudioStreamPlayer3D.new()
	player.stream = load(path); player.volume_db = volume; player.pitch_scale = pitch; player.max_distance = 6.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


func _play_sound(tool: String, at: Vector3, dt: float) -> void:
	if tool in ["mane", "tail"]:
		_loop_until = Time.get_ticks_msec() + int(LOOP_LINGER * 1000.0)
		_loop_pitch = 0.92 if tool == "tail" else 1.0
		_loop_at = at
		return
	_sound_clock -= dt
	if _sound_clock > 0.0 or _audio == null: return
	_sound_clock = randf_range(0.35, 0.6)
	var path := SND + "coat_stroke_%02d.wav" % (randi() % COAT_STROKES + 1)
	if not ResourceLoader.exists(path): return
	_audio.stream = load(path)
	_audio.volume_db = randf_range(-11.0, -9.0)
	_audio.pitch_scale = randf_range(0.94, 1.06)
	_audio.global_position = at
	_audio.play()


## The mane loop follows the brush, fades in while strokes land and out once they stop.
func _tick_loop(delta: float) -> void:
	if _loop == null: return
	var on := Time.get_ticks_msec() < _loop_until
	if on and not _loop.playing:
		if _loop.stream == null:
			var stream: AudioStream = load(MANE_LOOP) if ResourceLoader.exists(MANE_LOOP) else null
			if stream == null: return
			if "loop" in stream: stream.set("loop", true)
			_loop.stream = stream
		_loop.volume_db = -40.0
		_loop.play(randf() * 12.0)
	if not _loop.playing: return
	if _loop_at.is_finite(): _loop.global_position = _loop_at
	_loop.pitch_scale = move_toward(_loop.pitch_scale, _loop_pitch, delta)
	_loop.volume_db = move_toward(_loop.volume_db, LOOP_DB if on else -40.0, delta * (60.0 if on else 90.0))
	if not on and _loop.volume_db <= -39.9: _loop.stop()


## One of the feather takes, never one of the last few, pitch and volume varied a little.
func _play_feather(at: Vector3) -> void:
	var take := randi() % FEATHER_TAKES + 1
	for i in 8:
		if take not in _recent_feathers: break
		take = randi() % FEATHER_TAKES + 1
	_recent_feathers.append(take)
	while _recent_feathers.size() > FEATHER_NO_REPEAT: _recent_feathers.pop_front()
	_play_at(SND + "feather_remove_%02d.wav" % take, at, randf_range(-8.0, -4.0), randf_range(0.92, 1.08))


func _pick(paths: Array) -> String:
	return str(paths[randi() % paths.size()])


## A finished grooming: a contented sigh in her own breath (the game's soft breaths).
func _sigh(pony: Node3D) -> void:
	var boop: Variant = pony.get("boop_node")
	if boop != null and is_instance_valid(boop) and boop.has_method("play_breath"): boop.call("play_breath", -20.0)


## The wing shake: three big flaps.
func _flutter(pony: Node3D) -> void:
	_play_at(WING_SHAKE, pony.global_position + Vector3.UP * 0.9, -7.0, randf_range(0.97, 1.03))


## Switched off in Settings → Mods: every pony goes back to normal, the brush back in the hand.
func _exit_tree() -> void:
	for pony: Variant in _sessions.keys(): _end(pony, true)
	_sessions.clear()
	if is_instance_valid(_desk_item):
		var model := _visual(_desk_item)
		if model != null: model.transform = Transform3D.IDENTITY
	if is_instance_valid(_catcher): _catcher.queue_free()
