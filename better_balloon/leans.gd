extends Node
## Better Balloon: passengers looking out over the rim (rim_lean.gd poses her; crates.gd has the
## spots). For now on a test key: 6 while aboard makes the nearest passenger get up, trot to the
## nearest spot by the wall, lean on the rim for
## LEAN_SECONDS and go back to where she was and sit; 6 again ends it early.
## She stays the balloon's passenger throughout (its moving support carries her). From the first hop
## until she is back in her place her own motion is paused, as balloon.gd's climb does: no walking,
## no collision pushing her about (pressed to the wall in a moving basket she was stepped up onto the
## rail); the hops move her in the basket's frame, the lean slides her in.

const CRATES := preload("res://mods/better_balloon/crates.gd")
const LEAN := preload("res://mods/better_balloon/rim_lean.gd")
const KEY := KEY_6
const LEAN_SECONDS := 20.0 # key 6
const AUTO_GAP := Vector2(30.0, 90.0) # seconds between leans while flying
const AUTO_LEAN := Vector2(10.0, 30.0) # seconds each lasts
const SPOT_CLEAR := 0.75 # metres: a spot is free with nopony (and not Anon) this close to it
const PATH_CLEAR := 0.45 # and nopony this close to her way there
const STAND_WAIT := 2.0 # Most seconds to wait for her to stand up.
const STEP_LENGTH := 0.35 # Canon metres per bouncing step as she trots across the deck,
const STEP_SECONDS := 0.28 # each taking this long,
const STEP_BOB := 0.035 # with this much bounce.
const START_BACK := 0.6 # Canon metres from the wall she first lands at, then settles from.
const BACK_OFF := 0.18 # Canon metres further back than her leaning spot until she rises.
const SETTLE_SECONDS := 0.4

var _job: Dictionary = {}
var _next_auto := -1.0 # seconds until the next lean (counted while flying)
var _last_actor: Node = null


func _ready() -> void:
	process_physics_priority = 100 # after the balloon (-80) and the ponies have moved this tick


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or (event as InputEventKey).physical_keycode != KEY: return
	if not _job.is_empty():
		if _job.stage in ["stand", "go", "settle", "lean"]: _end_lean()
		return
	var balloon := _balloon_with_anon()
	if balloon == null: return
	if _start(balloon): get_viewport().set_input_as_handled()


func _balloon_with_anon() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if not node is Node3D or not node.has_method("holds_player") or not "passengers" in node: continue
		var player: Variant = node.get("_player")
		if is_instance_valid(player) and bool(node.call("holds_player", player)): return node as Node3D
	return null


func _start(balloon: Node3D, auto := false) -> bool:
	var player: Node3D = balloon.get("_player")
	var best: Dictionary = {}
	var best_d := INF
	var choices: Array[Dictionary] = []
	for row: Variant in balloon.get("passengers"):
		if not row is Dictionary or bool((row as Dictionary).get("leaving", false)): continue
		var actor: Variant = (row as Dictionary).get("actor")
		if not is_instance_valid(actor) or not actor is Node3D or actor.get("_held") == true: continue
		if not (actor as Node).has_method("request_posture") or not (actor as Node).has_method("reset_motion"): continue
		choices.append(row)
		var d := (actor as Node3D).global_position.distance_to(player.global_position)
		if d < best_d: best_d = d; best = row
	if auto and not choices.is_empty():
		# Somepony other than the last one, when there's a choice.
		var others := choices.filter(func(r: Dictionary) -> bool: return r.actor != _last_actor)
		best = (others if not others.is_empty() else choices).pick_random()
	if best.is_empty():
		print("[better_balloon] key 6: no passenger to lean on the rim")
		return false
	var actor: Node3D = best.actor
	var sk: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if sk == null: return false
	var crate := false # the rim is low enough for everypony now
	var spot: Dictionary = {}
	var spot_d := INF
	var size: float = float(actor.get("body_scale")) if actor.get("body_scale") != null else 1.0
	for candidate: Dictionary in CRATES.SPOTS:
		var stand := Vector3(candidate.wall.x, CRATES.top_y(candidate), candidate.wall.z) - (candidate.out as Vector3) * START_BACK * size
		if not _spot_clear(balloon, stand, actor): continue
		var foot := balloon.to_global(stand)
		var d := foot.distance_to(actor.global_position)
		if d < spot_d: spot_d = d; spot = candidate
	if spot.is_empty():
		if not auto: print("[better_balloon] no free spot by the wall")
		return false
	var lean: Node = sk.get_node_or_null("BetterBalloonLean")
	if lean == null:
		lean = LEAN.new()
		lean.name = "BetterBalloonLean"
		lean.set("mare", actor)
		sk.add_child(lean)
	sk.move_child(lean, -1) # last, after the game's own modifiers
	_last_actor = actor
	_job = {"balloon": balloon, "row": best, "actor": actor, "lean": lean, "spot": spot, "stage": "stand", "t": 0.0,
		"seconds": randf_range(AUTO_LEAN.x, AUTO_LEAN.y) if auto else LEAN_SECONDS,
		"home": balloon.global_transform.affine_inverse() * actor.global_transform}
	actor.call("request_posture", "stand")
	print("[better_balloon] %s gets up to look over the rim" % str(best.get("id", actor.name)))
	return true


## Her shoulders over her hooves (metres) standing: from her rig's rest pose, so it doesn't matter
## that she is sitting now.
func _shoulders(actor: Node3D, sk: Skeleton3D) -> float:
	var arm := sk.find_bone("pony_upperArm_L")
	var hoof := sk.find_bone("pony_finger_L_end")
	if arm < 0 or hoof < 0: return 1.0
	return (sk.get_bone_global_rest(arm).origin.y - sk.get_bone_global_rest(hoof).origin.y) * sk.global_basis.get_scale().y


func _end_lean() -> void:
	if _job.is_empty(): return
	if is_instance_valid(_job.lean): _job.lean.set("want", false)
	if _job.stage in ["stand", "go", "settle"]:
		_job.stage = "unlean" # nothing to come down from; straight back
	elif _job.stage == "lean":
		_job.stage = "unlean"
	_job.t = 0.0


## Free: nopony else (sitting, standing or on her way) and not Anon within SPOT_CLEAR of `stand`
## (balloon-local), so she never walks into or through anyone.
func _spot_clear(balloon: Node3D, stand: Vector3, actor: Node3D) -> bool:
	var player: Variant = balloon.get("_player")
	var feet: Vector3 = balloon.to_local((player as Node3D).global_position) if is_instance_valid(player) else Vector3.INF
	if feet.is_finite() and Vector2(feet.x - stand.x, feet.z - stand.z).length() < SPOT_CLEAR: return false
	for row: Variant in balloon.get("passengers"):
		var other: Variant = (row as Dictionary).get("actor") if row is Dictionary else null
		if not is_instance_valid(other) or other == actor: continue
		var at := balloon.to_local((other as Node3D).global_position)
		if Vector2(at.x - stand.x, at.z - stand.z).length() < SPOT_CLEAR: return false
		# Nopony in her way there either.
		var from := balloon.to_local(actor.global_position)
		var path := Vector2(stand.x - from.x, stand.z - from.z)
		var to_other := Vector2(at.x - from.x, at.z - from.z)
		var k := clampf(to_other.dot(path) / maxf(path.length_squared(), 0.0001), 0.0, 1.0)
		if (to_other - path * k).length() < PATH_CLEAR: return false
	return true


func _physics_process(delta: float) -> void:
	if _job.is_empty():
		_auto(delta)
		return
	var balloon: Node3D = _job.balloon
	var actor: Node3D = _job.actor
	var lean: Node = _job.lean
	if not is_instance_valid(balloon) or not is_instance_valid(actor) or not is_instance_valid(lean) or not (balloon.get("passengers") as Array).has(_job.row) or actor.get("_held") == true:
		_abandon()
		return
	var spot: Dictionary = _job.spot
	var out: Vector3 = (balloon.global_basis * (spot.out as Vector3)).normalized()
	lean.set("wall_point", balloon.to_global(spot.wall))
	lean.set("wall_out", out)
	var size: float = float(actor.get("body_scale")) if actor.get("body_scale") != null else 1.0
	_job.t += delta
	match str(_job.stage):
		"stand":
			var status: Dictionary = actor.call("posture_status")
			if (str(status.get("kind")) == "stand" and bool(status.get("settled", true))) or _job.t > STAND_WAIT:
				var foot := Vector3(spot.wall.x, CRATES.top_y(spot), spot.wall.z) - (spot.out as Vector3) * START_BACK * size
				var facing := Basis(Vector3.UP, atan2(-(spot.out as Vector3).x, -(spot.out as Vector3).z))
				_hop_to(Transform3D(facing, foot), size, "settle")
		"go":
			_hop_step(balloon, actor)
		"settle":
			# Standing a little back from where she'll lean, so her nose clears the wall as she rises.
			var need: float = float(lean.get("step_need")) - BACK_OFF * size
			if absf(need) > 0.002: actor.global_position += out * need * minf(1.0, delta * 8.0)
			if _job.t > SETTLE_SECONDS:
				lean.set("want", true)
				_job.stage = "lean"; _job.t = 0.0
		"lean":
			var need: float = lean.get("step_need")
			if absf(need) > 0.002: lean.call("slide", out * need * minf(1.0, delta * 3.0))
			if _job.t > float(_job.get("seconds", LEAN_SECONDS)): _end_lean()
		"unlean":
			lean.set("want", false)
			if float(lean.get("weight")) <= 0.0:
				_hop_to(_job.home, size, "home")
		"home":
			pass


## Every AUTO_GAP seconds of flight with Anon aboard, somepony looks over the rim.
func _auto(delta: float) -> void:
	var balloon := _balloon_with_anon()
	if balloon == null or balloon.get("landed") == true or (balloon.get("passengers") as Array).is_empty():
		return
	if _next_auto < 0.0: _next_auto = randf_range(AUTO_GAP.x, AUTO_GAP.y)
	_next_auto -= delta
	if _next_auto > 0.0: return
	_next_auto = randf_range(AUTO_GAP.x, AUTO_GAP.y)
	_start(balloon, true)


## Trots her (balloon-local `to`) in a few bouncing steps, turning as she goes, then on to `next`.
func _hop_to(to: Transform3D, size: float, next: String) -> void:
	var balloon: Node3D = _job.balloon
	var actor: Node3D = _job.actor
	var from: Transform3D = balloon.global_transform.affine_inverse() * actor.global_transform
	var steps := maxi(2, ceili(from.origin.distance_to(to.origin) / (STEP_LENGTH * size)))
	_job.hop = {"from": from, "to": to, "steps": steps, "seconds": steps * STEP_SECONDS, "bob": STEP_BOB * size, "next": next}
	_job.stage = "go"; _job.t = 0.0
	actor.set("motion_paused", true)


func _hop_step(balloon: Node3D, actor: Node3D) -> void:
	var hop: Dictionary = _job.hop
	var k := clampf(_job.t / float(hop.seconds), 0.0, 1.0)
	var s := smoothstep(0.0, 1.0, k)
	var from: Transform3D = hop.from
	var to: Transform3D = hop.to
	var at := from.origin.lerp(to.origin, s) + Vector3.UP * absf(sin(PI * k * float(hop.steps))) * float(hop.bob)
	# She turns toward where she's going first, then into her final facing.
	var turn := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), smoothstep(0.0, 0.6, k))
	actor.global_transform = balloon.global_transform * Transform3D(Basis(turn), at)
	if k < 1.0: return
	if str(hop.next) == "home":
		actor.set("motion_paused", false)
		actor.call("reset_motion", balloon.global_transform * to)
		actor.call("request_posture", "sit")
		print("[better_balloon] back in her place")
		_job = {}
		return
	# Her feet set down afresh where she landed (one tick of her own, then paused again).
	actor.call("reset_motion", balloon.global_transform * to)
	if "single_step" in actor: actor.set("single_step", true)
	_job.stage = hop.next; _job.t = 0.0


## Something else took over (carried, taken off the balloon, freed): let go of her as she is.
func _abandon() -> void:
	if is_instance_valid(_job.get("lean")): _job.lean.set("want", false)
	if is_instance_valid(_job.get("actor")): _job.actor.set("motion_paused", false)
	_job = {}


func _exit_tree() -> void:
	if not _job.is_empty():
		var actor: Variant = _job.get("actor")
		if is_instance_valid(actor) and is_instance_valid(_job.get("balloon")):
			actor.set("motion_paused", false)
			actor.call("reset_motion", (_job.balloon as Node3D).global_transform * (_job.home as Transform3D))
		_abandon()
	for node: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if not "passengers" in node: continue
		for row: Variant in node.get("passengers"):
			var actor: Variant = (row as Dictionary).get("actor") if row is Dictionary else null
			var sk: Variant = actor.get("skeleton") if is_instance_valid(actor) else null
			if sk is Skeleton3D and (sk as Node).get_node_or_null("BetterBalloonLean") != null: (sk as Node).get_node("BetterBalloonLean").queue_free()
