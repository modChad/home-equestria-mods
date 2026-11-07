extends Node
## =====================================================================
##  Pegasus Ride - rev 5 "princesses": rev 4 "roof & bridge safe", plus a saddle measured from
##  each pony's own back (Celestia and Luna too) and a friendship gate that is enforced.
##
##  Fly across Equestria on the back of any winged friend.
##  N to mount, V to cruise, P to explore. Name places in conversation.
## =====================================================================

const PLACES := preload("res://world/navigation/place_directory.gd")
const DESKTOP_PLAYER := preload("res://player/desktop_player.gd")
const XR_PLAYER := preload("res://player/xr_grounded_body.gd")

# ------------------------------------------------------------------ Basics
const RANGE := 20.0
const HOVER_SECONDS := 3600.0
const MOUNT_RETRY_SECONDS := 1.5
const TAKEOFF_GRACE_SECONDS := 2.0

# ------------------------------------------------------- Cruise height
## Safety margin above the highest obstacle (roof, bridge, tree, terrain).
const CLEARANCE := 28.0
## A steeper approach from above, so she doesn't clip neighbouring roofs.
const GLIDE_RATIO := 0.35
const GLIDE_MIN := 4.0
const GLIDE_MAX := 14.0
const EXPLORE_HOVER_ABOVE := 18.0

# ------------------------------------------------------------- Seat
## Anon's eyes above the saddle point while seated (metres).
const SEAT_EYE := 0.68
## Where he sits along her back: 0 her withers .. 1 her hips.
const SEAT_ALONG := 0.4
## Lab only: report how each saddle was found.
static var LAB_SADDLE := false

# ------------------------------------------------------- Unlocking
## Bond stages (player_bonds.gd STAGES) that unlock a ride: Friend and beyond.
const FRIEND_STAGES := ["friend", "close_friend", "dating", "engaged", "married"]

# ------------------------------------------------------------- Exploring
const EXPLORE_PAUSE_SECONDS := 8.0
const EXPLORE_MAX_TRIES := 10
const EXPLORE_SKIP_NEAR := 60.0
## Words that ask for a ride, one of which must be in what he says to get on by voice.
const RIDE_WORDS := ["fly", "ride", "your back", "take me up", "into the air", "into the sky", "lift off", "flug", "flieg"]
## Seconds after he gets off before words alone can put him back on (N still works at once).
const VOICE_REMOUNT_WAIT := 30.0

# ------------------------------------------------------------- Diagnostics
const DIAG_FLIGHT := false
const STUCK_SECONDS := 5.0
const STUCK_METRES := 0.8
## After a re-route around an obstacle, seconds before the guard looks again.
const GUARD_PAUSE := 1.5
## Her rider's head above her feet, per unit of her size (her back plus a seated Anon).
const RIDER_TOP := 1.2
const PROMPT_NAMES := 20

# =====================================================================
#  State
# =====================================================================
var _pony: CharacterBody3D
var _exec: Node
var _player: CharacterBody3D
var _anon: Node3D

var _mounted := false
var _ever_airborne := false
var _mode := ""
var _dest := ""
var _mount_block_until := 0.0
## When he last got off (seconds), for VOICE_REMOUNT_WAIT.
var _landed_at := -1000.0
var _mounted_at := 0.0

var _yaw := 0.0
var _key := false
var _cent := Vector3.ZERO
var _explore_wait := 0.0
var _visited: Array[String] = []
var _last_player_text := ""
var _warned_rel := false

var _saved_floor := 0
var _saved_layer := 0
var _saved_mask := 0
var _mask_saved := false

var _diag_at := -100.0
var _guard_until := 0.0
var _stuck_at := Vector3.INF
var _stuck_for := 0.0

var _place_rows: Array[Dictionary] = []
var _place_text := ""
var _places_ready := false

# =====================================================================
#  Setup
# =====================================================================
func _ready() -> void:
	name = "PegasusRide"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 90
	print("[PegasusRide] rev 5 (princesses) loaded - N ride, V cruise, P explore")


func _exit_tree() -> void:
	_release(false)


# =====================================================================
#  Main loop
# =====================================================================
func _physics_process(delta: float) -> void:
	_refs()
	_check_input()
	_check_voice_commands()

	if not _mounted:
		return
	if not is_instance_valid(_pony) or not is_instance_valid(_player):
		_dismount(false)
		return

	_prompt()
	_ai()

	if _mode == "explore_pause":
		_sync()
		_keep_hover_alive()
		_explore_wait -= delta
		if _explore_wait <= 0.0:
			_explore()
		return

	_sync()

	var fly: Variant = _pony.get("flight")
	if fly == null:
		_dismount(true)
		return

	var now := Time.get_ticks_msec() / 1000.0
	var is_active := bool(fly.call("active"))

	# Keep her airborne while taking off or hovering, in case pony_flight.gd goes idle too early.
	if not is_active and (_mode == "hover" or now - _mounted_at < TAKEOFF_GRACE_SECONDS):
		_keep_hover_alive()
		is_active = bool(fly.call("active"))

	if is_active:
		_ever_airborne = true
		if _mode == "cruise":
			_maintain_cruise_loop(fly)
		_guard_flight_obstacles(fly)
		_check_stuck(delta)
		_diag_flight()
		return

	# Flight over.
	if _mode == "explore_leg":
		_begin_explore_pause()
		return

	var arr := _dest
	var had_goal := _mode == "destination"
	var flew := _ever_airborne
	_dismount(true)
	if flew and had_goal and not arr.is_empty():
		_speak("You just flew Anon on your back to " + arr + " and touched down right in front "
			+ "of it. Make a cool, proud remark about the flight.", "arr")


## Live guard against bridges and roofs during flight. The rays start clear of her body and
## Anon's (sized to her: at the bigger pony sizes the old fixed offsets started inside her and hit
## her own touch and wing hulls every frame, rewriting the route each frame so she never moved),
## skip every collider belonging to her or to Anon, and a re-route is given time to work before the
## next one.
func _guard_flight_obstacles(fly: Variant) -> void:
	if _mode == "landing":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _guard_until:
		return
	var space := _pony.get_world_3d().direct_space_state
	var pos := _pony.global_position
	var s := _body_scale()
	var exclude := _own_colliders()

	# 1. A bridge or roof overhang above her and her rider.
	var up_q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * (RIDER_TOP * s + 0.9), pos + Vector3.UP * 25.0, 1, exclude)
	var up_hit := space.intersect_ray(up_q)

	# 2. A building or roof ahead, at her body's height.
	var vel := _pony.velocity
	var fwd := Vector3(vel.x, 0.0, vel.z)
	if fwd.length_squared() < 0.25:
		fwd = -_pony.global_basis.z
	fwd = fwd.normalized()
	var from := pos + Vector3.UP * (0.5 * s) + fwd * (0.9 * s)
	var fwd_q := PhysicsRayQueryParameters3D.create(from, from + fwd * (8.0 * s), 1, exclude)
	var fwd_hit := space.intersect_ray(fwd_q)

	if up_hit.is_empty() and fwd_hit.is_empty():
		return
	_guard_until = now + GUARD_PAUSE

	var safe_y := _obstacle_top_at(pos + fwd * 6.0) + CLEARANCE
	var cur_cruise := float(fly.get("cruise_y"))
	if safe_y > cur_cruise:
		fly.set("cruise_y", safe_y)
	var rt: Variant = fly.get("_route")
	if rt is Array and not (rt as Array).is_empty():
		var arr: Array[Vector3] = []
		# Climb straight away, so she doesn't stay stuck under a bridge or in a roof.
		if up_hit.is_empty():
			arr.append(Vector3(pos.x, maxf(pos.y + 8.0, safe_y), pos.z))
		else:
			# Under a bridge: back off a little first, then climb.
			var back := pos - fwd * 5.0
			arr.append(Vector3(back.x, pos.y + 1.0, back.z))
			arr.append(Vector3(back.x, safe_y, back.z))
		for p in (rt as Array):
			if p is Vector3:
				var v := p as Vector3
				arr.append(Vector3(v.x, maxf(v.y, safe_y) if v != (rt as Array).back() else v.y, v.z))
		fly.set("_route", arr)
		if DIAG_FLIGHT:
			print("[PegasusRide] obstacle %s - climbing to %.0f" % ["above" if not up_hit.is_empty() else "ahead", safe_y])


## Anon's other colliders (hands, held things, body parts) taken out of the world while he rides,
## and put back after. The game's own flight checks a sphere around her (0.7 m across per unit of
## her size, at her chest) for anything in her way, and only ignores her: at the bigger pony sizes
## that sphere takes in her rider too, so she saw him as an obstacle, refused to move and the stuck
## check fired over and over. His body itself is already switched off in _mount.
var _rider_layers := {}

func _quiet_rider(on: bool) -> void:
	if on:
		_rider_layers.clear()
		for root: Variant in [_player, _anon]:
			if not (root is Node and is_instance_valid(root)):
				continue
			for node: Node in (root as Node).find_children("*", "CollisionObject3D", true, false):
				var body := node as CollisionObject3D
				if body == _player or _rider_layers.has(body):
					continue
				_rider_layers[body] = [body.collision_layer, body.collision_mask]
				body.collision_layer = 0
				body.collision_mask = 0
		return
	for body: Variant in _rider_layers:
		if is_instance_valid(body):
			(body as CollisionObject3D).collision_layer = int(_rider_layers[body][0])
			(body as CollisionObject3D).collision_mask = int(_rider_layers[body][1])
	_rider_layers.clear()


## Her size (body_scale), for distances measured on her body.
func _body_scale() -> float:
	var b: Variant = _pony.get("body_scale") if is_instance_valid(_pony) else null
	return clampf(float(b), 0.25, 4.0) if (b is float or b is int) else 1.0


## Every collider that is part of her or of Anon (body, touch and wing hulls, hands), for rays.
func _own_colliders() -> Array[RID]:
	var out: Array[RID] = []
	for root: Variant in [_pony, _player, _anon]:
		if not (root is Node and is_instance_valid(root)):
			continue
		if root is CollisionObject3D:
			out.append((root as CollisionObject3D).get_rid())
		for node: Node in (root as Node).find_children("*", "CollisionObject3D", true, false):
			out.append((node as CollisionObject3D).get_rid())
	return out


## Stuck detection: frees her automatically after a few seconds.
func _check_stuck(delta: float) -> void:
	if _mode == "hover" or _mode == "explore_pause":
		_stuck_for = 0.0
		return
	var at := _pony.global_position
	if not _stuck_at.is_finite() or at.distance_to(_stuck_at) > STUCK_METRES:
		_stuck_at = at
		_stuck_for = 0.0
		return
	_stuck_for += delta
	if _stuck_for < STUCK_SECONDS:
		return

	var fly_now: Variant = _pony.get("flight")
	push_warning("[PegasusRide] Stuck for %.1f s - lifting her clear. size=%.2f mode=%s state=%s reason=%s blocked=%s route=%s" % [
		_stuck_for, _body_scale(), _mode, str(fly_now.get("state")) if fly_now != null else "-",
		str(fly_now.get("reason")) if fly_now != null else "-", str(fly_now.get("_blocked")) if fly_now != null else "-",
		str((fly_now.get("_route") as Array).size()) if fly_now != null and fly_now.get("_route") is Array else "-"])
	_stuck_for = 0.0
	_stuck_at = Vector3.INF

	var safe_y := _obstacle_top_at(at) + CLEARANCE
	_pony.global_position = Vector3(at.x, maxf(at.y + 6.0, safe_y - 10.0), at.z)
	if _mode == "explore_leg":
		_begin_explore_pause()
	elif _mode == "cruise":
		_cruise()
	else:
		var fly: Variant = _pony.get("flight")
		if fly != null and fly.has_method("land"):
			fly.call("land")
		_mode = "landing"


# =====================================================================
#  References
# =====================================================================
func _refs() -> void:
	if not is_instance_valid(_anon):
		_anon = get_tree().root.find_child("AnonBody", true, false) as Node3D

	if not is_instance_valid(_player):
		# 1. Through DesktopAnon.player_body (desktop).
		if is_instance_valid(_anon) and is_instance_valid(_anon.get_parent()):
			var pb: Variant = _anon.get_parent().get("player_body")
			if pb is CharacterBody3D:
				_player = pb as CharacterBody3D
		# 2. Up the parent chain (VR / XRGroundedBody).
		if not is_instance_valid(_player) and is_instance_valid(_anon):
			var n: Node = _anon.get_parent()
			while n != null and not (n is CharacterBody3D):
				n = n.get_parent()
			if n is CharacterBody3D:
				_player = n as CharacterBody3D
		# 3. Search the scene for a DesktopPlayer or XRGroundedBody.
		if not is_instance_valid(_player):
			for node in get_tree().root.find_children("*", "CharacterBody3D", true, false):
				var scr: Variant = node.get_script()
				if scr == DESKTOP_PLAYER or scr == XR_PLAYER:
					_player = node as CharacterBody3D
					break

	if is_instance_valid(_pony) and not is_instance_valid(_exec):
		var sc2 := get_tree().current_scene
		var dir: Node = sc2.get("director") if is_instance_valid(sc2) else null
		if dir == null:
			dir = get_tree().get_first_node_in_group("conversation_director")
		if dir != null:
			var acts: Variant = dir.get("actions")
			if acts is Node and (acts as Node).get("executors") != null:
				_exec = ((acts as Node).get("executors") as Dictionary).get(_pid())


func _id_of(p: Node) -> String:
	if not is_instance_valid(p):
		return ""
	var ident: Variant = p.get("identity")
	if ident != null and ident is Object:
		var id_str := str((ident as Object).get("id"))
		if not id_str.is_empty():
			return id_str
	return p.name.to_snake_case()


func _pid() -> String:
	return _id_of(_pony)


func _feet() -> Vector3:
	if is_instance_valid(_anon) and is_instance_valid(_player):
		var c: Variant = _anon.get("_camera")
		if c is XRCamera3D and is_instance_valid(c):
			return Vector3((c as XRCamera3D).global_position.x, _player.global_position.y,
				(c as XRCamera3D).global_position.z)
	if is_instance_valid(_player):
		return _player.global_position
	if is_instance_valid(_anon):
		return _anon.global_position
	return Vector3.INF


func _pony_scale() -> float:
	var best := 0.0
	var s := get_node_or_null("/root/Settings")
	if s != null and s.has_method("pony_scale"):
		var v: Variant = s.call("pony_scale")
		if v is float or v is int:
			best = maxf(best, float(v))
	if is_instance_valid(_pony):
		var b: Variant = _pony.get("body_scale")
		if b is float or b is int:
			best = maxf(best, float(b))
	if best < 0.2 or best > 4.0:
		return 1.0
	return best


# =====================================================================
#  Input
# =====================================================================
func _check_input() -> void:
	var press := false
	if Input.is_key_pressed(KEY_N):
		press = true
	if not press and is_instance_valid(_anon):
		for f in ["_right_hand", "_left_hand"]:
			var h: Variant = _anon.get(f)
			if h is XRController3D and is_instance_valid(h):
				var c := h as XRController3D
				if c.is_button_pressed("by_button") and c.get_float("grip") > 0.65:
					press = true

	if press and not _key:
		_key = true
		_toggle()
	elif not press:
		_key = false

	if not _mounted:
		return
	if Input.is_key_pressed(KEY_V) and _mode != "cruise":
		_cruise()
	if Input.is_key_pressed(KEY_P) and _mode != "explore_leg" and _mode != "explore_pause":
		_explore()


func _toggle() -> void:
	if _mounted:
		_land_or_step_off()
		return
	if Time.get_ticks_msec() / 1000.0 < _mount_block_until:
		return
	_refs()
	if not is_instance_valid(_player):
		push_warning("[PegasusRide] Cancelled: player body not found.")
		return
	var p := _nearest()
	if p == null:
		push_warning("[PegasusRide] No winged friend within %.0f m (strangers and acquaintances won't carry you)." % RANGE)
		return
	_pony = p
	_exec = null
	_refs()
	_mount()


func _land_or_step_off() -> void:
	var fly: Variant = _pony.get("flight") if is_instance_valid(_pony) else null
	if fly != null and bool(fly.call("active")):
		_mode = "landing"
		_dest = ""
		fly.call("land")
	else:
		_dismount(false)


# =====================================================================
#  Mounting and dismounting
# =====================================================================
func _mount() -> void:
	# Important: create her flight controller first if she has none yet.
	if _pony.has_method("_ensure_flight"):
		_pony.call("_ensure_flight")

	var fly: Variant = _pony.get("flight")
	if fly == null:
		push_warning("[PegasusRide] This pony can't fly (flight == null).")
		_mount_block_until = Time.get_ticks_msec() / 1000.0 + MOUNT_RETRY_SECONDS
		return

	var nav: Node = _pony.get_node_or_null("Navigator")
	if is_instance_valid(nav):
		if nav.has_method("stay"):
			nav.call("stay")
		nav.set("wander_enabled", false)
	if _pony.has_method("request_posture"):
		_pony.call("request_posture", "stand")
	if _pony.has_method("set_sim_tier"):
		_pony.call("set_sim_tier", 0, 0)

	var up: Vector3 = _pony.global_position + Vector3.UP * (6.0 * _pony_scale())
	var ok := _manual_takeoff(up)
	if not ok and fly.has_method("request"):
		ok = bool(fly.call("request", up, HOVER_SECONDS, false, 6.0 * _pony_scale(), false))
	if not ok:
		push_warning("[PegasusRide] Takeoff failed - staying on the ground.")
		_mount_block_until = Time.get_ticks_msec() / 1000.0 + MOUNT_RETRY_SECONDS
		_release(false)
		return

	_saved_floor = int(_player.get("platform_floor_layers"))
	_saved_layer = _player.collision_layer
	_saved_mask = _player.collision_mask
	_mask_saved = true
	_player.set("platform_floor_layers", 0)
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_quiet_rider(true)

	if is_instance_valid(_anon) and _anon.get("force_seated") != null:
		_anon.set("force_seated", true)

	_pony.set_meta("player_rider", _player)
	_yaw = _pony.global_rotation.y

	_mounted = true
	_mounted_at = Time.get_ticks_msec() / 1000.0
	_ever_airborne = true
	_mode = "hover"
	_dest = ""
	_visited.clear()
	_stuck_at = Vector3.INF
	_stuck_for = 0.0
	_build_places()
	_sync()

	print("[PegasusRide] mounted: %s scale=%.2f" % [_pid(), _pony_scale()])
	_speak("Anon just climbed onto your back and you lifted off into a hover! Enthusiastically "
		+ "ask him where in Equestria he wants you to fly him, if he wants to cruise around, or "
		+ "if he wants to explore random places across the map.", "mount")


func _dismount(beside: bool) -> void:
	_release(beside)


func _release(beside := false) -> void:
	var flew := _ever_airborne
	if is_instance_valid(_pony):
		_pony.remove_meta("player_rider")
		var nav: Node = _pony.get_node_or_null("Navigator")
		if is_instance_valid(nav):
			nav.set("wander_enabled", true)

	if is_instance_valid(_anon) and _anon.get("force_seated") != null:
		_anon.set("force_seated", false)
	_quiet_rider(false)

	if is_instance_valid(_player):
		if _mask_saved:
			_player.set("platform_floor_layers", _saved_floor)
			_player.collision_layer = _saved_layer
			_player.collision_mask = _saved_mask
			_mask_saved = false
		_player.velocity = Vector3.ZERO
		if beside and flew and is_instance_valid(_pony):
			var off := _feet() - _player.global_position
			off.y = 0.0
			var side := _pony.global_basis.x.normalized()
			_player.global_position = _pony.global_position \
				+ side * (0.95 * _pony_scale()) + Vector3.UP * 0.05 - off

	if _mounted:
		_landed_at = Time.get_ticks_msec() / 1000.0
		_end_ride_status()
	_mounted = false
	_ever_airborne = false
	_mode = ""
	_dest = ""
	_stuck_at = Vector3.INF
	_stuck_for = 0.0


# =====================================================================
#  Unlocking
# =====================================================================
## Friends and up (the game's own bond stages, player_bonds.gd: friend, close friend, dating,
## engaged, married) may carry Anon. When the bonds system can't be found, everypony may.
func _friend_ok(p: Node) -> bool:
	var pid := _id_of(p)
	if pid.is_empty():
		return false
	var bonds := _find_bonds()
	if bonds == null or not bonds.has_method("record_for"):
		return true
	var rec: Variant = bonds.call("record_for", pid)
	if not rec is Dictionary:
		return true
	var stage := str((rec as Dictionary).get("stage", "acquaintance"))
	return stage in FRIEND_STAGES


func _find_impressions() -> Node:
	var dir := get_tree().get_first_node_in_group("conversation_director")
	if is_instance_valid(dir):
		var wc: Variant = dir.get("world_context")
		if wc is Node and (wc as Node).get("impressions") is Node:
			return (wc as Node).get("impressions") as Node
		var imp: Variant = dir.get("impressions")
		if imp is Node:
			return imp as Node
	for n: Node in get_tree().root.find_children("*", "Node", true, false):
		if n.has_method("xp_for") or (n.has_method("get_tier_label") and n.has_method("get_score")):
			return n
	return null


func _find_bonds() -> Node:
	var dir := get_tree().get_first_node_in_group("conversation_director")
	if is_instance_valid(dir):
		var wc: Variant = dir.get("world_context")
		if wc is Node and (wc as Node).get("player_bonds") is Node:
			return (wc as Node).get("player_bonds") as Node
	var sc := get_tree().current_scene
	if is_instance_valid(sc):
		var rel: Variant = sc.get("relationships")
		if rel is Node and rel.get("bonds") is Node:
			return rel.get("bonds") as Node
		var b: Variant = sc.get("bonds")
		if b is Node:
			return b as Node
	for n: Node in get_tree().root.find_children("*", "Node", true, false):
		var inner: Variant = n.get("bonds")
		if inner is Node and (inner as Node).has_method("record_for"):
			return inner as Node
	return null


func _is_pegasus(p: Node) -> bool:
	var ident: Variant = p.get("identity")
	if ident != null and ident is Object and (ident as Object).has_method("has_wings"):
		return bool((ident as Object).call("has_wings"))
	return p.get("flight") != null or p.has_method("_ensure_flight")


func _nearest() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var bd := RANGE
	var at := _feet()
	if not at.is_finite():
		return null
	for p in get_tree().get_nodes_in_group("sim_ponies"):
		if not (is_instance_valid(p) and p is CharacterBody3D):
			continue
		if not _is_pegasus(p):
			continue
		var d := at.distance_to((p as Node3D).global_position)
		if d <= bd and _friend_ok(p):
			best = p as CharacterBody3D
			bd = d
	return best


# =====================================================================
#  Place list and safe landing spots (no roofs, no bridges)
# =====================================================================
func _build_places() -> void:
	if _places_ready:
		return
	_places_ready = true
	_place_rows.clear()
	var names := PackedStringArray()
	for raw in PLACES.entries(get_tree()):
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var eid := str(row.get("id", ""))
		if eid.is_empty() or eid.begins_with("house:"):
			continue
		_place_rows.append(row)
		if names.size() < PROMPT_NAMES:
			names.append(eid)
	_place_text = ", ".join(names)
	print("[PegasusRide] %d places known" % _place_rows.size())


func _resolve_place(query: String) -> Dictionary:
	var q := query.strip_edges()
	if q.is_empty():
		return {}
	var direct := PLACES.find(get_tree(), q)
	if not direct.is_empty():
		return direct

	var ids := PackedStringArray()
	var labels := {}
	var by_id := {}
	for row in _place_rows:
		var eid := str(row.get("id", ""))
		ids.append(eid)
		labels[eid] = str(row.get("label", eid))
		by_id[eid] = row

	var hit := PLACES.match_name(q, Array(ids), labels)
	if not hit.is_empty() and by_id.has(hit):
		return by_id[hit]

	var low := q.to_lower()
	for eid in by_id.keys():
		var row2: Dictionary = by_id[eid]
		if str(eid).to_lower().contains(low) \
				or str(row2.get("label", "")).to_lower().contains(low):
			return row2
	return {}


## The real top surface at this XZ (house roofs, doors, bridges and trees included).
func _obstacle_top_at(xz_pos: Vector3) -> float:
	var top := xz_pos.y
	var fly: Variant = _pony.get("flight") if is_instance_valid(_pony) else null
	if fly != null and fly.has_method("_terrain_y"):
		var ty := float(fly.call("_terrain_y", xz_pos))
		if is_finite(ty):
			top = maxf(top, ty)
	if not is_instance_valid(_pony):
		return top
	var space := _pony.get_world_3d().direct_space_state
	var exclude := _own_colliders()
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(xz_pos.x, top + 160.0, xz_pos.z),
		Vector3(xz_pos.x, top - 40.0, xz_pos.z),
		1 | _pony.floor_mask, exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		top = maxf(top, (hit.position as Vector3).y)
	return top


## True when there is open sky above a point (no landing under bridges or roofs).
func _has_clear_sky(point: Vector3) -> bool:
	var space := _pony.get_world_3d().direct_space_state
	var exclude := _own_colliders()
	var up_q := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 0.6, point + Vector3.UP * 120.0, 1, exclude)
	return space.intersect_ray(up_q).is_empty()


## A safe landing spot beside a place (never on a roof or under a bridge).
func _landing_near(base: Vector3) -> Vector3:
	var fly: Variant = _pony.get("flight")
	var space := _pony.get_world_3d().direct_space_state
	var exclude := _own_colliders()

	# Start 10 m from the building's centre on purpose, not at 0 (the middle of its roof).
	for d: float in [10.0, 15.0, 20.0, 26.0, 34.0, 42.0]:
		var tries := 16
		for i in tries:
			var ang := TAU * float(i) / float(tries)
			var p := base + Vector3(cos(ang), 0.0, sin(ang)) * d
			# Cast down from 140 m up, so the ray starts above every roof.
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(p.x, base.y + 140.0, p.z),
				Vector3(p.x, base.y - 40.0, p.z),
				1 | _pony.floor_mask, exclude)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var ground: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			if normal.y < 0.78:
				continue

			# Roof filter: a hit well above the terrain is a roof or a bridge.
			if fly != null and fly.has_method("_terrain_y"):
				var ty := float(fly.call("_terrain_y", ground))
				if is_finite(ty) and ground.y > ty + 2.2:
					continue

			# Bridge and indoor filter: it needs open sky above.
			if not _has_clear_sky(ground):
				continue

			# The game's own landing check: only accept a finite spot.
			if fly != null and fly.has_method("landing_surface"):
				var s: Variant = fly.call("landing_surface", ground)
				if s is Vector3 and (s as Vector3).is_finite() and _has_clear_sky(s as Vector3):
					return s as Vector3
				continue

			return ground
	return Vector3.INF


# =====================================================================
#  Routen
# =====================================================================
## Cruise height: the highest real obstacle (roof, bridge, tree, terrain) on the way, plus CLEARANCE.
func _cruise_height(start: Vector3, stop: Vector3) -> float:
	var h: float = maxf(_obstacle_top_at(start), _obstacle_top_at(stop)) + CLEARANCE
	var dist := start.distance_to(stop)
	var steps := maxi(2, ceili(dist / 10.0))
	for i in range(steps + 1):
		var sample := start.lerp(stop, float(i) / float(steps))
		h = maxf(h, _obstacle_top_at(sample) + CLEARANCE)
	return h


func _manual_route(spot: Vector3, label: String, hover_for := 0.0) -> bool:
	var fly: Variant = _pony.get("flight")
	if fly == null:
		return false
	var start := _pony.global_position
	var h := _cruise_height(start, spot)

	var flat := Vector3(spot.x - start.x, 0.0, spot.z - start.z)
	var dir := flat.normalized() if flat.length() > 0.5 else -_pony.global_basis.z
	var drop: float = maxf(4.0, h - spot.y)
	var approach := clampf(drop * GLIDE_RATIO, GLIDE_MIN, GLIDE_MAX)

	# Three-stage safe profile:
	# 1. Climb steeply to the safe cruise height h
	# 2. Fly at height h until just short of the destination
	# 3. Drop from above onto the checked landing spot
	var up := Vector3(start.x, h, start.z)
	var high_approach := Vector3(spot.x, h, spot.z) - dir * approach
	var route: Array[Vector3] = [up, high_approach, spot]

	if fly.has_method("_native_clear"):
		fly.call("_native_clear")
	if fly.has_method("_end_loop"):
		fly.call("_end_loop")
	if fly.has_method("_end_show"):
		fly.call("_end_show")
	if fly.has_method("_prepare_visuals"):
		fly.call("_prepare_visuals")

	fly.set("_provisional", true)
	fly.set("home", start)
	fly.set("destination", spot)
	fly.set("cruise_y", h)
	fly.set("hover_seconds", hover_for)
	fly.set("_route", route)
	fly.set("_returning", false)
	fly.set("_blocked", 0.0)
	fly.set("_hover_at", spot if hover_for > 0.0 else Vector3.INF)
	fly.set("loops", 0)
	fly.set("state", "cruise")
	fly.set("reason", "Flying Anon to " + label)
	_dest = label
	print("[PegasusRide] GO path=manual to=%s height=%.0f glide=%.0f distance=%.0f" % [
		label, h, approach, start.distance_to(spot)])
	return true


## Always uses the roof- and bridge-safe three-stage route.
func _go(spot: Vector3, label: String, hover_for := 0.0) -> String:
	if _manual_route(spot, label, hover_for):
		return "manual"
	push_warning("[PegasusRide] Couldn't fly to '%s'." % label)
	return ""


func _manual_takeoff(up: Vector3) -> bool:
	var fly: Variant = _pony.get("flight")
	if fly == null:
		return false
	if fly.has_method("_native_clear"):
		fly.call("_native_clear")
	if fly.has_method("_end_loop"):
		fly.call("_end_loop")
	if fly.has_method("_end_show"):
		fly.call("_end_show")
	if fly.has_method("_prepare_visuals"):
		fly.call("_prepare_visuals")

	var here := _pony.global_position
	var route: Array[Vector3] = [up]
	fly.set("_provisional", true)
	fly.set("home", here)
	fly.set("destination", up)
	fly.set("cruise_y", up.y)
	fly.set("hover_seconds", HOVER_SECONDS)
	fly.set("_route", route)
	fly.set("_hover_at", up)
	fly.set("loops", 0)
	fly.set("_loop_angle", -1.0)
	fly.set("_returning", false)
	fly.set("_blocked", 0.0)
	fly.set("state", "hover")
	fly.set("reason", "Hovering with Anon")

	var wings: Variant = fly.get("wings")
	if wings is Node and (wings as Node).has_method("set_open"):
		(wings as Node).call("set_open", true)
	var pose: Variant = fly.get("pose")
	if pose is Object and (pose as Object).has_method("choose"):
		(pose as Object).call("choose", "hover")
	return true


func _keep_hover_alive() -> void:
	if not is_instance_valid(_pony):
		return
	var fly: Variant = _pony.get("flight")
	if fly == null:
		return
	var hover_pt: Variant = fly.get("_hover_at")
	if not (hover_pt is Vector3) or not (hover_pt as Vector3).is_finite():
		hover_pt = _pony.global_position + Vector3.UP * (5.0 * _pony_scale())
	fly.set("_provisional", true)
	fly.set("_hover_at", hover_pt)
	fly.set("destination", hover_pt)
	fly.set("hover_seconds", HOVER_SECONDS)
	fly.set("state", "hover")
	var rt: Variant = fly.get("_route")
	if not (rt is Array) or (rt as Array).is_empty():
		var new_rt: Array[Vector3] = [hover_pt as Vector3]
		fly.set("_route", new_rt)


# =====================================================================
#  Destinations
# =====================================================================
func _fly(loc_id: String) -> bool:
	var entry := _resolve_place(loc_id)
	if entry.is_empty():
		return false
	var real_id := str(entry.get("id", loc_id))
	var base := PLACES.resolve(get_tree(), real_id)
	if not base.is_finite() and entry.get("position") is Vector3:
		base = entry.get("position")
	var node: Variant = entry.get("node")
	if node is Node3D and is_instance_valid(node):
		var anc: Node3D = (node as Node3D).get_node_or_null("NavigationAnchor") as Node3D
		base = anc.global_position if anc != null else (node as Node3D).global_position
	if not base.is_finite():
		return false

	var spot := _landing_near(base)
	if not spot.is_finite():
		push_warning("[PegasusRide] No safe landing spot near %s" % real_id)
		return false

	var label := str(entry.get("label", real_id))
	var path := _go(spot, label, 0.0)
	if path.is_empty():
		_mode = "hover"
		return false
	_mode = "destination"
	return true


func _cruise() -> void:
	var fly: Variant = _pony.get("flight")
	if fly == null:
		return

	var th := PLACES.find(get_tree(), "landmark:town_hall")
	_cent = th.position if not th.is_empty() else _pony.global_position

	if fly.has_method("_native_clear"):
		fly.call("_native_clear")
	if fly.has_method("_end_loop"):
		fly.call("_end_loop")
	if fly.has_method("_end_show"):
		fly.call("_end_show")
	if fly.has_method("_prepare_visuals"):
		fly.call("_prepare_visuals")

	var here := _pony.global_position
	var h := _cruise_height(here, _cent)
	var d := Vector2(here.x - _cent.x, here.z - _cent.z)
	var a0 := atan2(d.y, d.x) if d.length() > 1.0 else 0.0

	# Obstacle height around the whole 105 m circle.
	for i in range(1, 17):
		var a := a0 + TAU * float(i) / 16.0
		var ring_pt := Vector3(_cent.x + cos(a) * 105.0, here.y, _cent.z + sin(a) * 105.0)
		h = maxf(h, _obstacle_top_at(ring_pt) + CLEARANCE)

	var pts: Array[Vector3] = []
	# Climb straight up to the safe cruise height first.
	if here.y < h - 2.0:
		pts.append(Vector3(here.x, h, here.z))
	for i in range(1, 17):
		var a := a0 + TAU * float(i) / 16.0
		pts.append(Vector3(_cent.x + cos(a) * 105.0, h, _cent.z + sin(a) * 105.0))
	pts.append(pts[0])

	fly.set("_provisional", true)
	fly.set("home", here)
	fly.set("destination", pts.back())
	fly.set("cruise_y", h)
	fly.set("hover_seconds", HOVER_SECONDS)
	fly.set("_route", pts)
	fly.set("_returning", false)
	fly.set("_blocked", 0.0)
	fly.set("_hover_at", Vector3.INF)
	fly.set("loops", 0)
	fly.set("state", "cruise")
	fly.set("reason", "Cruising with Anon")
	_mode = "cruise"
	_dest = ""
	print("[PegasusRide] Cruising safely over the roofs, height=%.0f" % h)


func _maintain_cruise_loop(fly: Variant) -> void:
	var rt: Variant = fly.get("_route")
	if not (rt is Array) or (rt as Array).size() > 2:
		return
	var h := float(fly.get("cruise_y"))
	var here := _pony.global_position
	var d := Vector2(here.x - _cent.x, here.z - _cent.z)
	var a0 := atan2(d.y, d.x) if d.length() > 1.0 else 0.0
	var pts: Array[Vector3] = []
	for i in range(1, 17):
		var a := a0 + TAU * float(i) / 16.0
		pts.append(Vector3(_cent.x + cos(a) * 105.0, h, _cent.z + sin(a) * 105.0))
	fly.set("_route", pts)
	fly.set("destination", pts.back())
	fly.set("state", "cruise")


func _explore() -> void:
	_build_places()
	var picks := _place_rows.duplicate()
	for i in range(picks.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var t: Dictionary = picks[i]
		picks[i] = picks[j]
		picks[j] = t

	var tried := 0
	var here := _pony.global_position
	for row in picks:
		if tried >= EXPLORE_MAX_TRIES:
			break
		var eid := str(row.get("id", ""))
		if eid.is_empty() or eid in _visited:
			continue
		var pos := PLACES.resolve(get_tree(), eid)
		if not pos.is_finite() or pos.distance_to(here) < EXPLORE_SKIP_NEAR:
			continue
		tried += 1

		# Exploring hovers safely ABOVE the place instead of landing between roofs.
		var top_y := _obstacle_top_at(pos)
		var aerial_spot := Vector3(pos.x, top_y + EXPLORE_HOVER_ABOVE, pos.z)
		var label := str(row.get("label", eid))
		var path := _go(aerial_spot, label, EXPLORE_PAUSE_SECONDS + 5.0)
		if path.is_empty():
			continue
		_mode = "explore_leg"
		_visited.append(eid)
		if _visited.size() > 15:
			_visited.pop_front()
		print("[PegasusRide] Explore (in the air): %s height=%.0f" % [eid, aerial_spot.y])
		return

	_speak("You tried to pick a spot to explore with Anon but could not find a route. "
		+ "Say so plainly, in character, and suggest cruising instead.", "noplace")
	_cruise()


func _begin_explore_pause() -> void:
	var arrived := _dest
	_mode = "explore_pause"
	_explore_wait = EXPLORE_PAUSE_SECONDS
	var top_y := _obstacle_top_at(_pony.global_position)
	var hover_pt := Vector3(
		_pony.global_position.x,
		maxf(_pony.global_position.y, top_y + EXPLORE_HOVER_ABOVE),
		_pony.global_position.z)
	var fly: Variant = _pony.get("flight")
	if fly != null:
		var rt: Array[Vector3] = [hover_pt]
		fly.set("_provisional", true)
		fly.set("_hover_at", hover_pt)
		fly.set("destination", hover_pt)
		fly.set("hover_seconds", EXPLORE_PAUSE_SECONDS + 5.0)
		fly.set("state", "hover")
		fly.set("_route", rt)
	if not arrived.is_empty():
		_speak("You are exploring Equestria with Anon on your back and just arrived high over " + arrived
			+ ". Make a fun remark about the view of this spot before flying on to the next random destination.",
			"explore_arr")


# =====================================================================
#  AI hookup
# =====================================================================
func _ai() -> void:
	if not is_instance_valid(_exec):
		return
	var mv: Variant = _exec.get("movement")
	if not (mv is Dictionary) or (mv as Dictionary).is_empty():
		return
	var m: Dictionary = (mv as Dictionary).duplicate()
	var t := str(m.get("type", ""))
	var loc := str(m.get("location_id", ""))
	var dur := float(m.get("duration_s", 0.0))

	if t == "hover" and absf(dur - 77.0) < 1.5:
		_exec.call("_end_move", "completed", "Exploring Equestria with Anon")
		_explore()
	elif t in ["circle_over", "air_show", "loop_de_loop", "barrel_roll"]:
		_exec.call("_end_move", "completed", "Cruising around")
		_cruise()
	elif t in ["fly_to", "go_to", "lead", "go_home"]:
		if t == "go_home" and loc.is_empty():
			var hh: Variant = _exec.call("_home_house") if _exec.has_method("_home_house") else null
			loc = str(hh.call("place_id")) \
				if (hh is Node3D and (hh as Node3D).has_method("place_id")) else "landmark:town_hall"
		if loc.to_lower() == "explore":
			_exec.call("_end_move", "completed", "Exploring Equestria with Anon")
			_explore()
		else:
			_exec.call("_end_move", "completed", "Flying Anon to " + loc)
			if not _fly(loc):
				_speak("You could not find a safe place to land near '" + loc + "'. Tell Anon that "
					+ "plainly, in character, and suggest another spot.", "noplace")
	elif t in ["land", "cancel"]:
		_exec.call("_end_move", "completed", "Landing")
		_mode = "landing"
		_dest = ""
		var fly: Variant = _pony.get("flight")
		if fly != null and fly.has_method("land"):
			fly.call("land")
	else:
		_exec.call("_end_move", "completed", "Staying airborne")


func _check_voice_commands() -> void:
	var dir := get_tree().get_first_node_in_group("conversation_director")
	if dir == null:
		return
	var txt := str(dir.get("_player_text")).strip_edges().to_lower()
	if txt.is_empty() or txt == _last_player_text:
		return
	_last_player_text = txt
	var wants_explore := txt.contains("explore") or txt.contains("erkunde") or txt.contains("random place")
	var wants_cruise := txt.contains("cruise") or txt.contains("kreise") or txt.contains("fly around")
	if not wants_explore and not wants_cruise:
		return
	if not _mounted:
		# Getting on by voice needs him to ask for a ride in so many words ("explore" alone, as in
		# "let's explore the town", must not lift him off the ground), and not just after landing.
		var asks_ride := false
		for word: String in RIDE_WORDS:
			if txt.contains(word):
				asks_ride = true
				break
		if not asks_ride or Time.get_ticks_msec() / 1000.0 < _landed_at + VOICE_REMOUNT_WAIT:
			return
		_toggle()
	if not _mounted:
		return
	if wants_explore and _mode != "explore_leg":
		_explore()
	elif wants_cruise and _mode != "cruise":
		_cruise()


func _prompt() -> void:
	if not is_instance_valid(_exec):
		return
	var cmds := " If he names ANY place in Equestria, include [fly_to: <location_id>]. Some known IDs: " \
		+ _place_text + ". If he says 'explore' or wants random destinations, include [hover: 77]. " \
		+ "If he asks to cruise, include [circle_over: player]. If he asks to land, include [land]."
	var msg := "Anon is sitting on your back while you hover in the air!" + cmds
	if _mode == "cruise":
		msg = "Anon is riding on your back while you cruise through the sky!" + cmds
	elif _mode == "destination":
		msg = "Anon is riding on your back and you are flying him to " + _dest + "." + cmds
	elif _mode == "explore_leg" or _mode == "explore_pause":
		msg = "You are exploring Equestria with Anon on your back, currently at or heading to " \
			+ _dest + "." + cmds
	var recent: Variant = _exec.get("recent")
	if not (recent is Array):
		return
	var arr: Array = recent
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] is Dictionary and (arr[i] as Dictionary).get("id") == "RIDE_STATUS":
			arr.remove_at(i)
	arr.append({"id": "RIDE_STATUS", "type": "carrying_player_on_back",
		"status": "ACTIVE", "reason": msg})


## Her action notes said Anon was on her back for as long as he rode, and kept saying it after he
## got off (nothing replaced the note), so she went on believing she was carrying him. Replaced
## with a finished note when he gets off.
func _end_ride_status() -> void:
	if not is_instance_valid(_exec):
		return
	var recent: Variant = _exec.get("recent")
	if not (recent is Array):
		return
	var arr: Array = recent
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] is Dictionary and (arr[i] as Dictionary).get("id") == "RIDE_STATUS":
			arr.remove_at(i)
	arr.append({"id": "RIDE_STATUS", "type": "carrying_player_on_back", "status": "COMPLETED",
		"reason": "The flight is over: Anon got off your back and is on the ground. Do not offer to fly him again unless he asks."})
	while arr.size() > 12:
		arr.pop_front()


func _speak(purpose: String, tag: String) -> void:
	var dir := get_tree().get_first_node_in_group("conversation_director")
	var pid := _pid()
	if dir != null and dir.has_method("queue_generated_intent") and not pid.is_empty():
		dir.call("queue_generated_intent", pid, purpose,
			"pegasus_ride:" + tag + ":" + str(Time.get_ticks_msec()),
			func() -> bool: return is_instance_valid(_pony), Callable(), true)


# =====================================================================
#  Seating
# =====================================================================
func _sync() -> void:
	if not (is_instance_valid(_pony) and is_instance_valid(_player)):
		return
	var saddle := _saddle()
	var off := _feet() - _player.global_position

	_player.global_position = Vector3(saddle.x - off.x, saddle.y + SEAT_EYE - _eye_height(), saddle.z - off.z)
	_player.velocity = Vector3.ZERO

	var dy := angle_difference(_yaw, _pony.global_rotation.y)
	_yaw = _pony.global_rotation.y
	var vp := get_viewport()
	if (vp == null or not vp.use_xr) and absf(dy) > 0.0001:
		_player.rotation.y += dy


## Where Anon sits: on the top of her back, measured from her own body mesh, so it fits any
## pony and any size setting (Celestia's body stands far taller than an ordinary mare's at the
## same scale). The back's highest point over the middle of her back is found once per pony, held
## by the bone it is skinned to, and followed every frame. Falls back to the old fixed height.
func _saddle() -> Vector3:
	var hold := _back_point()
	if not hold.is_empty():
		var sk: Skeleton3D = hold[0]
		if is_instance_valid(sk):
			return sk.global_transform * sk.get_bone_global_pose(int(hold[1])) * Vector3(hold[2])
	var s := _pony_scale()
	var piv: Variant = _pony.get("pivot")
	var b: Basis = _pony.global_basis
	if piv is Node3D and is_instance_valid(piv):
		b = (piv as Node3D).global_basis
	return _pony.global_position + b.y * (0.66 * s) + b.z * (0.12 * s)


## pony id -> [skeleton, bone, place in the bone's frame] of her saddle point, or [] (fallback).
var _backs := {}

func _back_point() -> Array:
	var pid := _pid()
	if _backs.has(pid):
		return _backs[pid]
	_backs[pid] = []
	var sk: Variant = _pony.get("skeleton")
	if not sk is Skeleton3D:
		return []
	var skel := sk as Skeleton3D
	var hips := skel.find_bone("pony_hips")
	var withers := skel.find_bone("pony_spine3")
	if hips < 0 or withers < 0:
		return []
	var inv := _pony.global_transform.affine_inverse()
	var h := inv * (skel.global_transform * skel.get_bone_global_pose(hips).origin)
	var w := inv * (skel.global_transform * skel.get_bone_global_pose(withers).origin)
	# The seat: SEAT_ALONG of the way from her withers back to her hips, on her middle line.
	var seat := w.lerp(h, SEAT_ALONG)
	var length := h.distance_to(w)
	var back_bones := {}
	for name: String in ["pony_hips", "pony_spine1", "pony_spine2", "pony_spine3"]:
		var i := skel.find_bone(name)
		if i >= 0:
			back_bones[i] = true
	var best := -INF
	for node: Node in skel.get_children():
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or mi.skin == null or not mi.visible:
			continue
		var low := String(mi.name).to_lower()
		if "mane" in low or "tail" in low or "wing" in low or "hair" in low or "cutie" in low or "shadow" in low:
			continue
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vb: Variant = arrays[Mesh.ARRAY_BONES]
			var vw: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if vb == null or vw == null or (vb as PackedInt32Array).size() < verts.size():
				continue
			var per := (vb as PackedInt32Array).size() / verts.size()
			for v in verts.size():
				var main := 0
				var weight := -1.0
				for k in per:
					if vw[v * per + k] > weight:
						weight = vw[v * per + k]
						main = vb[v * per + k]
				if main >= mi.skin.get_bind_count():
					continue
				var bone := mi.skin.get_bind_bone(main)
				if bone < 0:
					bone = skel.find_bone(mi.skin.get_bind_name(main))
				# Her back only: skin on her spine (not her collar, crown, wings or neck).
				if bone < 0 or not back_bones.has(bone):
					continue
				var local := mi.skin.get_bind_pose(main) * verts[v]
				var at := inv * (skel.global_transform * skel.get_bone_global_pose(bone) * local)
				# Close to the seat along her body and across it (not her neck, rump or sides).
				if absf(at.x - seat.x) > 0.06 * length or absf(at.z - seat.z) > 0.15 * length:
					continue
				if at.y > best:
					best = at.y
					_backs[pid] = [skel, bone, local]
	if DIAG_FLIGHT or LAB_SADDLE:
		print("[PegasusRide] saddle for %s: %s" % [pid, "measured" if not (_backs[pid] as Array).is_empty() else "fallback"])
	return _backs[pid]


func _eye_height() -> float:
	if is_instance_valid(_anon):
		var c: Variant = _anon.get("_camera")
		if c is Node3D and is_instance_valid(c):
			return clampf((c as Node3D).global_position.y - _player.global_position.y, 0.85, 2.1)
	return 1.65


# =====================================================================
#  Diagnostics
# =====================================================================
func _diag_flight() -> void:
	if not DIAG_FLIGHT:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _diag_at < 1.0:
		return
	_diag_at = now
	var fly: Variant = _pony.get("flight")
	if fly == null:
		return
	var rt: Variant = fly.get("_route")
	var n: int = (rt as Array).size() if rt is Array else -1
	print("[PegasusRide] FLY mode=%s to=%s state=%s route=%d height=%.1f below_cruise=%.1f" % [
		_mode, _dest, str(fly.get("state")), n,
		_pony.global_position.y, _pony.global_position.y - float(fly.get("cruise_y"))])