extends Node
## Balloon Boarding: two gaps in how ponies get into the hot-air balloon
## (world/vehicles/balloon/balloon.gd), filled from outside without changing the game's files.
##
## Carried in. The balloon hops any pony out of its basket who is not following Anon (dev
## 2026-10-16: ponies must not climb in by themselves). A pony Anon carries in and sets down did
## not climb in by herself, so while Anon is aboard she is treated like an invited rider: for a
## few seconds after he lets go she is on the balloon's own list of expected riders, and the
## balloon seats her on a free spot like any follower.
##
## Stopped short. A follower walks to the ramp foot and the balloon lifts her in once she is there
## (or stuck within 6 m of the basket). A pony whose walk ends further out (a big pony, such as
## Princess Celestia, whose paths keep more room around them) just stood there and gave up. Stuck
## for STUCK seconds within REACH of the basket, she is helped up the ramp by the balloon's own
## climb.
##
## Only the balloon's own functions and fields are used, each checked first: if a game update
## changes them, the mod does nothing.

const STUCK := 2.0
const REACH := 10.0
## Seconds after Anon lets go of a pony in the basket during which she counts as invited.
const CARRY_GRACE := 4.0

var _released: Dictionary = {}   # pony -> msec Anon let go of her
var _held: Dictionary = {}       # pony -> true while Anon holds her
var _invited: Dictionary = {}    # id -> [balloon, msec until]
var _helped: Dictionary = {}     # id -> true once lifted in (one log line each)


func _ready() -> void:
	# Ahead of the balloon (-80), so a pony let go of in the basket is expected before it looks.
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	var game: Node = Mods.game
	if not is_instance_valid(game): return
	var population: Variant = game.get("population")
	if population == null or not is_instance_valid(population): return
	var live: Variant = population.get("live")
	if not live is Dictionary: return
	for balloon: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if not _usable(balloon): continue
		_carried_in(balloon, live)
		_stopped_short(balloon)
	_expire()


func _usable(balloon: Node) -> bool:
	if not is_instance_valid(balloon) or not balloon is Node3D: return false
	for method: String in ["contains", "holds_player", "_climb"]:
		if not balloon.has_method(method): return false
	return balloon.get("saved_passengers") is Dictionary and balloon.get("passengers") is Array and balloon.get("_boarding") is Dictionary


func _anon_aboard(balloon: Node) -> bool:
	var player: Variant = balloon.get("_player")
	return is_instance_valid(player) and bool(balloon.call("holds_player", player))


func _aboard(balloon: Node, actor: Node) -> bool:
	for row: Variant in balloon.get("passengers"):
		if row is Dictionary and (row as Dictionary).get("actor") == actor: return true
	return false


## A pony Anon holds in the basket, or has just set down there, with him aboard: an expected rider
## (the balloon leaves a held pony be, and seats an expected one once she is let go).
func _carried_in(balloon: Node, live: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for id: Variant in live:
		var entry: Variant = live[id]
		var actor: Variant = (entry as Dictionary).get("actor") if entry is Dictionary else null
		if not is_instance_valid(actor) or not actor is Node3D: continue
		var held: bool = actor.get("_held") == true
		if held: _held[actor] = true
		elif _held.has(actor):
			_held.erase(actor)
			_released[actor] = now
		if not held and (not _released.has(actor) or now - int(_released[actor]) > CARRY_GRACE * 1000.0): continue
		if _aboard(balloon, actor) or not bool(balloon.call("contains", (actor as Node3D).global_position)): continue
		if not _anon_aboard(balloon): continue
		var saved: Dictionary = balloon.get("saved_passengers")
		_invited[str(id)] = [balloon, now + int(CARRY_GRACE * 1000.0)]
		if not saved.has(str(id)):
			var local: Vector3 = (balloon as Node3D).to_local((actor as Node3D).global_position)
			saved[str(id)] = [local.x, local.y, local.z]
			print("[balloon_boarding] %s set down in the basket: riding along" % str(id))


## A follower whose walk to the ramp ended too far out: up the ramp she goes.
func _stopped_short(balloon: Node) -> void:
	var boarding: Dictionary = balloon.get("_boarding")
	for id: Variant in boarding.keys():
		var row: Variant = boarding[id]
		if not row is Dictionary or str((row as Dictionary).get("stage", "")) != "walk": continue
		var actor: Variant = (row as Dictionary).get("actor")
		if not is_instance_valid(actor) or not actor is Node3D: continue
		if float((row as Dictionary).get("stuck", 0.0)) < STUCK: continue
		if (actor as Node3D).global_position.distance_to((balloon as Node3D).global_position) > REACH: continue
		if not _helped.has(str(id)):
			_helped[str(id)] = true
			print("[balloon_boarding] %s stopped %.1f m from the basket: helping her up the ramp" % [str(id), (actor as Node3D).global_position.distance_to((balloon as Node3D).global_position)])
		balloon.call("_climb", str(id), row)


## An expected rider who did not end up aboard (taken out again, or never settled) is forgotten,
## so the balloon does not seat her later from its saved list.
func _expire() -> void:
	var now := Time.get_ticks_msec()
	for id: String in _invited.keys():
		var row: Array = _invited[id]
		if now < int(row[1]): continue
		_invited.erase(id)
		var balloon: Variant = row[0]
		# Seated, the balloon has taken her off its saved list already.
		if is_instance_valid(balloon): (balloon.get("saved_passengers") as Dictionary).erase(id)
	for actor: Variant in _released.keys():
		if not is_instance_valid(actor) or now - int(_released[actor]) > CARRY_GRACE * 1000.0: _released.erase(actor)
	for actor: Variant in _held.keys():
		if not is_instance_valid(actor): _held.erase(actor)


## Switched off mid-game: forget the riders this mod put on a balloon's saved list but who are
## not seated yet, so the balloon does not seat them later.
func _exit_tree() -> void:
	for id: String in _invited.keys():
		var balloon: Variant = _invited[id][0]
		if is_instance_valid(balloon) and balloon.get("saved_passengers") is Dictionary:
			(balloon.get("saved_passengers") as Dictionary).erase(id)
	_invited.clear()
	_released.clear()
	_held.clear()
	_helped.clear()
