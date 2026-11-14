extends "res://world/navigation/walk_grid_service.gd"
## Pathfinding Fix (modChad): the zone's walk grid service with better route choice.
## main.gd swaps each new WalkGridService onto this script before its _ready.
##
## 1. Roads: the game's coarse chunk corridor (native and GDScript alike) scores every 16 m tile
##    the same, ignoring roads, trails, slopes and water, and the exact search then stays inside
##    that band (plus one tile). Routes up to fix.corridor_off_m search every resident tile
##    instead, so the cheapest route (roads included) wins. If that search runs out of budget,
##    it is asked once more with the game's corridor, as before.
## 2. Detours: a failed route grows its tile set by fix.expand_step tiles per retry (game: 12) up
##    to fix.route_chunks (game: 128), so going around a river or lake needs fewer re-searches.
## Quest 3 standalone (Android) gets a lighter set: shorter open searches with a smaller budget,
## the game's 128-tile cap (it keeps only 384 tiles resident), and no open search at all on a
## quality tier that lowered the game's own search limit (the potato tiers). Searches run on the
## native worker threads, not the render or physics thread, but those cores are shared.

const PLANNER_FIX := preload("res://mods/pathfinding_fix/walk_planner_fix.gd")
const BUDGET_REASON := "Search budget reached"
const QUEST := {"corridor_off_m": 80.0, "open_limit": 150000, "expand_step": 24, "route_chunks": ROUTE_CHUNKS}
const DESKTOP := {"corridor_off_m": 200.0, "open_limit": 400000, "expand_step": 32, "route_chunks": ROUTE_CHUNKS * 2}
var fix: Dictionary = QUEST if OS.has_feature("android") else DESKTOP


## True when this route search should use the game's coarse corridor.
func _fix_wants_corridor(job: Dictionary) -> bool:
	if bool(job.get("fix_force_corridor", false)): return true
	# A tier that cut the game's own budget is a slow device: keep the game's search there.
	if _search_limit < WalkPlanner.LIMIT: return true
	var from: Vector3 = job.get("from", Vector3.ZERO)
	var to: Vector3 = job.get("to", Vector3.ZERO)
	return Vector2(from.x - to.x, from.z - to.z).length() > float(fix.corridor_off_m)


## The game's _submit_native with the corridor choice (and its budget) added to the intent.
func _submit_native(job: Dictionary, snapshot: Dictionary) -> PackedInt64Array:
	if _native_world < 0:
		_native_world = NATIVE_BACKEND.acquire_world()
		if _native_world < 0: return PackedInt64Array()
	var native := NATIVE_BACKEND.instance()
	_sync_native(snapshot)
	var requester: Object = job.callback.get_object() if job.callback.is_valid() else null
	var key: int = requester.get_instance_id() if requester != null else 0
	var handle := _native_actor_for(key, NATIVE_BACKEND.profile_of(job.profile))
	if handle.size() != 2:
		push_error("Native route search could not register a %s actor; using the GDScript search" % zone_id)
		return PackedInt64Array()
	_native_generation += 1
	var corridor := _fix_wants_corridor(job)
	var intent := {"owner": key, "generation": _native_generation, "from": job.from, "goal": job.to,
		"any_floor": bool(job.get("any_floor", false)), "relaxed": bool(job.get("relaxed", false)),
		"expansion_limit": _search_limit if corridor else maxi(_search_limit, int(fix.open_limit)),
		"use_corridor": corridor,
		"priority": 1 if bool(job.get("priority", false)) else 0}
	var extra: Dictionary = job.get("extra", {})
	if extra.has("escape_reach"): intent["escape_reach"] = float(extra.escape_reach)
	if extra.has("blocked"): intent["blocked"] = extra.blocked
	var accepted: int = native.submit_intent(handle[0], handle[1], intent)
	if accepted != _native_generation:
		push_error("Native route search rejected a %s request; using the GDScript search" % zone_id)
		return PackedInt64Array()
	search_counts.native += 1
	return PackedInt64Array([handle[0], handle[1], _native_generation])


## The game's _search with the fixed planner (GDScript fallback only).
func _search(snapshot: Dictionary, job: Dictionary) -> void:
	var planner = PLANNER_FIX.new()
	planner.cancel_signal = job.cancel_signal
	planner.shared = _search_room
	planner.limit = _search_limit
	if job.kind == "wander":
		_pending_result = {"destination":planner.wander(snapshot,job.from,job.profile,job.radius,job.interest,job.get("home",Vector3.INF),job.get("leash",INF),job.get("context",{})), "intent":job.get("intent", "Exploring")}
	else:
		planner.fix_use_corridor = _fix_wants_corridor(job)
		_pending_result = planner.plan(snapshot,job.from,job.to,job.profile,job.get("any_floor",false),job.get("relaxed",false))


## The game's _expand_route with a budget fallback and bigger, larger-capped expansions.
func _expand_route(job: Dictionary, result: Dictionary) -> bool:
	if job.kind != "path" or not result.get("path",PackedVector3Array()).is_empty(): return false
	# An open search that ran out of budget: once more inside the game's corridor.
	if str(result.get("reason", "")) == BUDGET_REASON and not _fix_wants_corridor(job):
		job["fix_force_corridor"] = true
		_enqueue_path(job)
		return true
	var candidates: Array = result.get("frontier",[])
	var end_chunk := WalkGrid.chunk_of(WalkGrid.column(job.to))
	candidates.sort_custom(func(a,b): return Vector2(a-end_chunk).length_squared()<Vector2(b-end_chunk).length_squared())
	var added := 0
	for c in candidates:
		var center := Vector3((c.x+.5)*16.0,0,(c.y+.5)*16.0)
		if center.x+8 < bounds.position.x or center.x-8 > bounds.end.x or center.z+8 < bounds.position.z or center.z-8 > bounds.end.z: continue
		if c in job.chunks: continue
		if job.chunks.size() >= int(fix.route_chunks):
			result.reason = "Route needs more than the resident chunk budget; no unsafe shortcut returned"
			break
		job.chunks.append(c); added += 1
		if added >= int(fix.expand_step): break
	if added == 0: return false
	_enqueue_path(job)
	return true
