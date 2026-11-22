extends Node
## Ponies having a go at Pin the Tail on the Pony. A pony who answers with [pin_the_tail] (main.gd
## heard_reply) walks to the poster, puts on a blindfold, turns round and round, feels her way to the
## wall and pins her tail wherever she ends up. One player at a time, Anon included.
##
## She is moved the way Trixie's show moves its audience (show_audience.gd): her navigator under
## owner "pin_the_tail:<id>", which the day planner and living world leave alone, paused in the
## living world and held from her day plan until she is let go. Anything else taking her navigator
## (the player, a story, her own needs) ends her turn quietly.

const OWNER := "pin_the_tail:"
const ESSENCE := preload("res://world/life/essence.gd")
const ART := preload("res://mods/pin_the_tail/art.gd")
const SFX := preload("res://world/audio/interaction_sounds.gd")

## Shop-room metres (main.gd POSTER_AT is on the west wall at x -6.295, facing +x).
## She starts this far out from the wall, in front of the poster.
const START_OUT := 2.2
## Blindfolded, she stops this far from the wall to pin.
const REACH_OUT := 0.75
## Ponies further than this from the poster are not taken (they would wander across town).
const JOIN_RANGE := 30.0
## Her aim: sideways wander while walking blind (metres, standard deviation, clamped), and how far
## the pin lands from where she ends up, sideways and up or down.
const WANDER_SIDE := 0.55
const WANDER_LIMIT := 1.8
const PIN_SPREAD := Vector2(0.18, 0.22)
## Some ponies are steadier than others (multiplies the spread).
const STEADINESS := {"twilight_sparkle": 0.8, "applejack": 0.85, "pinkie_pie": 0.7, "rarity": 1.0,
	"rainbow_dash": 1.15, "fluttershy": 1.2, "derpy_hooves": 1.8, "spike": 1.1}
## Seconds for each step of her turn.
const WALK_LIMIT := 60.0
const BLINDFOLD_SECONDS := 1.4
const SPIN_SECONDS := 2.6
const SPIN_SPEED := 7.0
const GROPE_LIMIT := 25.0
const REACH_SECONDS := 1.0
const AFTER_SECONDS := 3.0
## The blindfold band around her head, relative to her head bone (her forward and up), metres for
## a pony of standard size. Nudge these if it sits too high, low, far forward or back.
const BAND_FORWARD := 0.07
const BAND_UP := 0.05
const BAND_RADIUS := 0.105
const BAND_THICKNESS := 0.022
const HEAD_BONES := ["pony_head", "Head", "mHead"]

## main.gd.
var game: Node
## The one pony playing now: {id, actor, phase, t, spot, goal, side, spin, band, was_*}. Empty when none.
var _turn: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## The name of the pony playing now, or "".
func player_name() -> String:
	if _turn.is_empty(): return ""
	return str(game.get("knowledge").call("pony_name", _turn.id))


## Ponies blindfolded right now (for warmer and colder).
func blind_ids() -> Array:
	if _turn.is_empty() or not str(_turn.phase) in ["blindfold", "spin", "grope", "reach"]: return []
	return [_turn.id]


## A pony asked to play (her reply had [pin_the_tail]). False when she can't right now.
func request(id: String) -> bool:
	if id == "" or not _turn.is_empty() or bool(game.call("player_blind")): return false
	var poster: Node3D = game.call("poster")
	var knowledge: Node = game.get("knowledge")
	var actor: Node3D = knowledge.call("pony", id) if knowledge != null else null
	if poster == null or actor == null or not actor.is_inside_tree(): return false
	if actor.global_position.distance_to(poster.global_position) > JOIN_RANGE: return false
	var nav: Node = actor.get_node_or_null("Navigator")
	if nav == null or str(nav.get("reserved_by")) != "": return false
	if bool(actor.get("sleeping")) or (actor.has_method("is_held") and bool(actor.call("is_held"))): return false
	var flight: Variant = actor.get("flight")
	if flight is Node and (flight as Node).has_method("active") and bool((flight as Node).call("active")): return false
	_take(id, actor, nav)
	return true


func _take(id: String, actor: Node3D, nav: Node) -> void:
	var population: Variant = Mods.game.get("population") if Mods.game != null else null
	var runner: Node = Mods.game.get_node_or_null("DayRunner") if Mods.game != null else null
	var was_paused := false
	var core: RefCounted = null
	if population is Node:
		was_paused = bool(ESSENCE.record(population, id).get("paused", false))
		core = ESSENCE.core(population)
	var runner_held: Variant = runner.get("held") if runner != null else null
	_turn = {"id": id, "actor": actor, "phase": "walk", "t": 0.0, "side": 0.0, "spin": 0.0, "band": null,
		"was_owner": str(nav.get("command_owner")), "was_wander": bool(nav.get("wander_enabled")),
		"was_paused": was_paused, "runner": runner, "was_held": (runner_held as Dictionary).get(id) if runner_held is Dictionary else null}
	if core != null: core.pause_resident(id, true, "Playing pin the tail on the pony")
	if runner_held is Dictionary: (runner_held as Dictionary)[id] = true
	if actor.has_method("request_posture"): actor.call("request_posture", "stand")
	nav.call("stay")
	nav.set("command_owner", OWNER + id)
	nav.set("wander_enabled", false)
	_turn.spot = _floor_point(START_OUT, 0.0)
	nav.call("go_to", _turn.spot, _enum(nav, "Gait", "WALK", 1))
	print("[pin_the_tail] %s is having a go" % id)


## A floor point in front of the poster: `out` metres from the wall, `side` metres along it
## (positive = toward the shop's back wall, the viewer's right).
func _floor_point(out: float, side: float) -> Vector3:
	var at: Vector3 = game.call("poster_at")
	return game.call("room_point", Vector3(at.x + out, 0.90, at.z - side))


func _physics_process(delta: float) -> void:
	if _turn.is_empty(): return
	var actor: Variant = _turn.actor
	var poster: Node3D = game.call("poster")
	if not actor is Node3D or not is_instance_valid(actor) or not (actor as Node3D).is_inside_tree() or poster == null:
		_finish(false); return
	var nav: Node = (actor as Node3D).get_node_or_null("Navigator")
	# Taken by the player, a story or her own needs: her turn is over.
	if nav == null or str(nav.get("command_owner")) != OWNER + str(_turn.id):
		_finish(false); return
	_turn.t = float(_turn.t) + delta
	_place_band()
	var here := (actor as Node3D).global_position
	match str(_turn.phase):
		"walk":
			var spot: Vector3 = _turn.spot
			if Vector2(here.x - spot.x, here.z - spot.z).length() < 0.6 or _arrived(nav):
				nav.call("stay")
				nav.set("face_point", poster.global_position)
				_next("face")
			elif float(_turn.t) > WALK_LIMIT or _stuck(nav):
				_finish(true)
		"face":
			nav.set("face_point", poster.global_position)
			if float(_turn.t) > 1.2:
				_put_on_band()
				SFX.play_at(actor, "prop_blanket")
				_next("blindfold")
		"blindfold":
			if float(_turn.t) > BLINDFOLD_SECONDS: _next("spin")
		"spin":
			# Round and round: her navigator turns her toward a point that circles her.
			_turn.spin = float(_turn.spin) + SPIN_SPEED * delta
			nav.set("face_point", here + Vector3(cos(float(_turn.spin)), 0.0, sin(float(_turn.spin))) * 2.0)
			if float(_turn.t) > SPIN_SECONDS:
				var steady: float = float(STEADINESS.get(_turn.id, 1.0))
				_turn.side = clampf(_rng.randfn(0.0, WANDER_SIDE * steady), -WANDER_LIMIT, WANDER_LIMIT)
				_turn.goal = _floor_point(REACH_OUT, float(_turn.side))
				nav.set("face_point", Vector3.INF)
				nav.call("go_to", _turn.goal, _enum(nav, "Gait", "WALK", 1))
				_next("grope")
		"grope":
			var goal: Vector3 = _turn.goal
			if Vector2(here.x - goal.x, here.z - goal.z).length() < 0.35 or _arrived(nav) or float(_turn.t) > GROPE_LIMIT or _stuck(nav):
				nav.call("stay")
				nav.set("face_point", here - poster.global_basis.z * 3.0)
				_next("reach")
		"reach":
			nav.set("face_point", here - poster.global_basis.z * 3.0)
			if float(_turn.t) > REACH_SECONDS:
				_pin(actor as Node3D, poster)
				_take_off_band()
				nav.set("face_point", poster.global_position)
				_next("after")
		"after":
			if float(_turn.t) > AFTER_SECONDS: _finish(true)


func _next(phase: String) -> void:
	_turn.phase = phase
	_turn.t = 0.0


## A value of one of the navigator's enums (pony_navigator.gd Gait, State), read from its script so
## a renumbering cannot break this.
func _enum(nav: Node, enum_name: String, key: String, fallback: int) -> int:
	var script: Variant = nav.get_script()
	if not script is Script: return fallback
	var values: Variant = (script as Script).get_script_constant_map().get(enum_name)
	return int((values as Dictionary).get(key, fallback)) if values is Dictionary else fallback


func _arrived(nav: Node) -> bool:
	return nav.get("state") == _enum(nav, "State", "ARRIVED", -100)


func _stuck(nav: Node) -> bool:
	var state: Variant = nav.get("state")
	return (state == _enum(nav, "State", "UNREACHABLE", -100) or state == _enum(nav, "State", "BLOCKED", -100)) and float(_turn.t) > 3.0


## Where her tail lands: in front of where she ended up, on the poster if she is lucky. Now and
## then a pony standing right where she reaches gets it instead.
func _pin(actor: Node3D, poster: Node3D) -> void:
	var steady: float = float(STEADINESS.get(_turn.id, 1.0))
	var target := ART.target_local()
	var local := Vector2(target.x + float(_turn.side) + _rng.randfn(0.0, PIN_SPREAD.x * steady),
		target.y + _rng.randfn(0.0, PIN_SPREAD.y * steady))
	var who := str(game.get("knowledge").call("pony_name", _turn.id))
	var victim := _pony_in_reach(actor)
	if victim != null and _rng.randf() < 0.6:
		var at := victim.global_position + Vector3.UP * 0.75
		var away := at - actor.global_position
		away.y = 0.0
		game.call("place_tail", victim, at, away.normalized() if away.length() > 0.01 else Vector3.UP, Vector3.UP, _turn.id, who)
		return
	var half := ART.POSTER_SIZE * 0.5
	var on_poster := absf(local.x) <= half.x and absf(local.y) <= half.y
	var at := poster.to_global(Vector3(local.x, local.y, 0.016))
	var holder: Node3D = poster if on_poster else game.call("corner")
	game.call("place_tail", holder, at, poster.global_basis.z, Vector3.UP, _turn.id, who)
	game.call("say", "%s: %s" % [who, _short(on_poster, local, target)], at + poster.global_basis.z * 0.2)


func _short(on_poster: bool, local: Vector2, target: Vector2) -> String:
	if not on_poster: return "missed the poster!"
	var cm := roundi(local.distance_to(target) * 100.0)
	return "Bullseye! %d cm" % cm if cm <= 5 else "%d cm" % cm


## Another pony right in front of her, where her hoof is about to go.
func _pony_in_reach(actor: Node3D) -> Node3D:
	var forward := -actor.global_basis.z
	for other: Node in get_tree().get_nodes_in_group("ai_characters"):
		if other == actor or not other is Node3D: continue
		var to := (other as Node3D).global_position - actor.global_position
		to.y = 0.0
		if to.length() < 1.1 and to.normalized().dot(forward) > 0.5: return other as Node3D
	return null


# ------------------------------------------------------------------ the blindfold

func _skeleton(actor: Node3D) -> Skeleton3D:
	var found: Variant = actor.get("skeleton")
	if found is Skeleton3D and is_instance_valid(found): return found as Skeleton3D
	return actor.find_child("*Skeleton*", true, false) as Skeleton3D


func _put_on_band() -> void:
	var band := MeshInstance3D.new()
	band.name = "PinTheTailBlindfold"
	var torus := TorusMesh.new()
	torus.inner_radius = BAND_RADIUS
	torus.outer_radius = BAND_RADIUS + BAND_THICKNESS
	torus.rings = 24
	band.mesh = torus
	band.material_override = ART.material("8fcbe8")
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.top_level = true
	game.call("corner").add_child(band)
	_turn.band = band
	_place_band()


func _place_band() -> void:
	var band: Variant = _turn.get("band")
	if not band is Node3D or not is_instance_valid(band): return
	var actor: Node3D = _turn.actor
	var skeleton := _skeleton(actor)
	var head := actor.global_position + Vector3.UP * 0.9
	if skeleton != null:
		for bone_name: String in HEAD_BONES:
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				head = (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin
				break
	var size := actor.global_basis.get_scale().y
	var yaw := Basis(Vector3.UP, actor.global_rotation.y)
	var forward := -yaw.z
	# A band round her head at eye level, tipped slightly so it rides over the brow.
	(band as Node3D).global_transform = Transform3D(yaw.rotated(yaw.x, 0.25).scaled(Vector3.ONE * size),
		head + forward * BAND_FORWARD * size + Vector3.UP * BAND_UP * size)


func _take_off_band() -> void:
	var band: Variant = _turn.get("band")
	if band is Node and is_instance_valid(band): (band as Node).queue_free()
	_turn.band = null


# ------------------------------------------------------------------ letting her go

## Her turn is over: the navigator, her day and her living-world record go back as they were.
func _finish(give_back: bool) -> void:
	if _turn.is_empty(): return
	var turn := _turn
	_turn = {}
	var band: Variant = turn.get("band")
	if band is Node and is_instance_valid(band): (band as Node).queue_free()
	var id: String = turn.id
	var runner: Variant = turn.get("runner")
	if runner is Node and is_instance_valid(runner):
		var held: Variant = (runner as Node).get("held")
		if held is Dictionary:
			if turn.get("was_held") != null: (held as Dictionary)[id] = turn.was_held
			else: (held as Dictionary).erase(id)
	var population: Variant = Mods.game.get("population") if Mods.game != null else null
	if population is Node:
		var core: RefCounted = ESSENCE.core(population)
		if core != null: core.pause_resident(id, bool(turn.get("was_paused", false)))
	var actor: Variant = turn.actor
	if not give_back or not actor is Node3D or not is_instance_valid(actor): return
	var nav: Node = (actor as Node3D).get_node_or_null("Navigator")
	if nav != null and str(nav.get("command_owner")) == OWNER + id:
		nav.set("face_point", Vector3.INF)
		nav.call("stay")
		nav.set("command_owner", "")
		nav.set("wander_enabled", bool(turn.get("was_wander", true)))


## The world is closing or the mod is switched off.
func stop_all() -> void:
	_finish(true)


func _exit_tree() -> void:
	_finish(true)
