extends Node
## What the ponies know about Pin the Tail on the Pony.
## - A live note in the "Situation" block of every pony near the poster when she speaks
##   (director_prompts.gd asks every node in "pony_prompt_notes" for prompt_note(id)): what the game
##   is, the scoreboard, the last few pins, who is blindfolded right now and whether they are getting
##   warmer or colder, and the [pin_the_tail] tag that lets her have a go herself.
## - A memory for every pony who saw a pin (world_context.record), so she can tease about it later.
## The lore entry for the words "pin the tail", "blindfold" and so on is merge/world/ai/context_seeds.json.

## main.gd.
var game: Node

## Ponies this close to the poster get the note (the shop floor and its doorway).
const NOTE_RANGE := 14.0
## Ponies this close to a pin see it and remember it.
const WITNESS_RANGE := 10.0
## How long a pin stays "just now" in the note, seconds.
const RECENT_SECONDS := 600.0
const RECENT_KEEP := 4
## Warmer/colder looks at how far the blindfolded one is from the poster now and this long ago.
const TREND_SECONDS := 2.5
const TREND_METRES := 0.25

## [{who, where, at (seconds)}], newest last.
var _recent: Array = []
## Seeker key ("player" or a pony id) -> [[time, distance], ...] over the last few seconds.
var _tracks: Dictionary = {}
var _sample := 0.0


func _ready() -> void:
	add_to_group("pony_prompt_notes")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The name ponies call the player (AI settings "player_name"), else "Anon".
func player_name() -> String:
	var director: Node = get_tree().get_first_node_in_group("conversation_director") if is_inside_tree() else null
	var config: Variant = director.get("config") if director != null else null
	if config is ConfigFile:
		var named := str((config as ConfigFile).get_value("player_name", "Anon")).strip_edges()
		if named != "": return named
	return "Anon"


func pony_name(id: String) -> String:
	var actor := pony(id)
	var identity: Variant = actor.get("identity") if actor != null else null
	if identity is Resource and str(identity.get("display_name")) != "": return str(identity.get("display_name"))
	return id.replace("_", " ").capitalize()


## The loaded body of the pony with this id, or null.
func pony(id: String) -> Node3D:
	if id == "" or not is_inside_tree(): return null
	for actor: Node in get_tree().get_nodes_in_group("ai_characters"):
		var identity: Variant = actor.get("identity")
		if identity is Resource and str(identity.get("id")) == id and actor is Node3D and is_instance_valid(actor):
			return actor as Node3D
	return null


# ------------------------------------------------------------------ warmer and colder

## Everyone blindfolded right now: {key: {name, at, forward}}. Key "player" or a pony's id.
func seekers() -> Dictionary:
	var out := {}
	if bool(game.call("player_blind")):
		var view: Dictionary = game.call("player_view")
		if not view.is_empty(): out["player"] = {"name": player_name(), "at": view.at, "forward": view.forward}
	var players: Node = game.get("pony_game")
	if is_instance_valid(players):
		for id: String in players.call("blind_ids"):
			var actor := pony(id)
			if actor != null: out[id] = {"name": pony_name(id), "at": actor.global_position, "forward": -actor.global_basis.z}
	return out


func _physics_process(delta: float) -> void:
	_sample -= delta
	if _sample > 0.0: return
	_sample = 0.5
	var poster: Node3D = game.call("poster")
	var now := _now()
	var found := seekers()
	for key: String in _tracks.keys():
		if not found.has(key): _tracks.erase(key)
	if poster == null: return
	for key: String in found:
		var track: Array = _tracks.get(key, [])
		track.append([now, _flat(found[key].at, poster.global_position)])
		while track.size() > 0 and now - float(track[0][0]) > TREND_SECONDS * 2.0: track.pop_front()
		_tracks[key] = track


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## "about 3 m from the poster, facing away from it, getting colder".
func _seeker_line(key: String, seeker: Dictionary, poster: Node3D) -> String:
	var gap := _flat(seeker.at, poster.global_position)
	var distance := "right at the wall by the poster" if gap < 1.0 else ("a few steps from the poster" if gap < 2.5 else "across the room from the poster")
	var toward: Vector3 = poster.global_position - (seeker.at as Vector3)
	toward.y = 0.0
	var forward: Vector3 = seeker.forward
	forward.y = 0.0
	var facing := ""
	if toward.length() > 0.2 and forward.length() > 0.01:
		var angle := rad_to_deg(forward.angle_to(toward))
		facing = "facing it" if angle < 35.0 else ("facing away from it" if angle > 120.0 else "turned partly away from it")
	var trend := ""
	var track: Array = _tracks.get(key, [])
	if track.size() >= 2:
		var now := _now()
		var then: Array = track[0]
		for row: Array in track:
			if now - float(row[0]) <= TREND_SECONDS: break
			then = row
		var change := gap - float(then[1])
		trend = "getting warmer" if change < -TREND_METRES else ("getting colder" if change > TREND_METRES else "not getting any warmer or colder")
	var parts: PackedStringArray = [distance]
	if facing != "": parts.append(facing)
	if trend != "": parts.append(trend)
	return ", ".join(parts)


# ------------------------------------------------------------------ the prompt note

func prompt_note(id: String) -> String:
	var poster: Node3D = game.call("poster")
	var actor := pony(id)
	if poster == null or actor == null or actor.global_position.distance_to(poster.global_position) > NOTE_RANGE: return ""
	var lines: PackedStringArray = []
	lines.append("- Pin the Tail on the Pony: a party-game poster hangs on Sugarcube Corner's west wall (a cartoon mint pony missing her tail, a gold X on her rump), with a basket of yarn tails and a chalk scoreboard. Whoever plays is blindfolded, spun around, and tries to pin a tail on the X.")
	var state: Dictionary = Mods.state("pin_the_tail")
	var best: int = int(state.get("best_cm", -1))
	if best >= 0:
		var by: String = str(state.get("best_by", ""))
		lines.append("  Scoreboard: best shot %d cm from the X%s, %d games played." % [best, " by " + by if by != "" else "", int(state.get("plays", 0))])
	var now := _now()
	var recent: PackedStringArray = []
	for row: Dictionary in _recent:
		if now - float(row.at) <= RECENT_SECONDS:
			recent.append("%s pinned it %s (%s ago)" % [row.who, row.where, _ago(now - float(row.at))])
	if not recent.is_empty(): lines.append("  Recent pins: " + "; ".join(recent) + ".")
	var found := seekers()
	for key: String in found:
		if key == id:
			lines.append("  You are blindfolded right now, feeling your way toward the poster. You cannot see anything.")
			continue
		lines.append("  Right now %s is blindfolded and hunting for the poster: %s." % [found[key].name, _seeker_line(key, found[key], poster)])
	if not found.is_empty() and not found.has(id):
		lines.append("  You may call out warmer or colder in your own way: honest, teasing, or playfully misleading, whatever suits you. Never give exact directions or distances.")
	var players: Node = game.get("pony_game")
	var busy: bool = not found.is_empty() or (is_instance_valid(players) and str(players.call("player_name")) != "")
	if not busy and not found.has(id):
		lines.append("  To have a go yourself, put [pin_the_tail] in your reply: you walk over, get blindfolded and spun, and try to pin the tail. You can also invite whoever you are with to play.")
	if not recent.is_empty():
		lines.append("  When a tail lands somewhere silly, it is fair game to tease whoever pinned it, kindly and in your own way.")
	return "\n".join(lines)


func _ago(seconds: float) -> String:
	if seconds < 60.0: return "moments"
	var minutes := roundi(seconds / 60.0)
	return "a minute" if minutes <= 1 else "%d minutes" % minutes


# ------------------------------------------------------------------ memories

## A tail was pinned (main.gd place_tail): every pony nearby who saw it remembers.
func pinned(who_id: String, who_name: String, result: Dictionary) -> void:
	var where: String = str(result.get("where", ""))
	_recent.append({"who": who_name, "where": where, "at": _now()})
	while _recent.size() > RECENT_KEEP: _recent.pop_front()
	var poster: Node3D = game.call("poster")
	var context: Variant = Mods.game.get("world_context") if Mods.game != null else null
	if poster == null or not context is Node or not is_instance_valid(context): return
	var witnesses: Array = []
	for actor: Node in get_tree().get_nodes_in_group("ai_characters"):
		if not actor is Node3D or bool(actor.get("sleeping")): continue
		if (actor as Node3D).global_position.distance_to(poster.global_position) > WITNESS_RANGE: continue
		var identity: Variant = actor.get("identity")
		var id: String = str(identity.get("id")) if identity is Resource else ""
		if id != "" and id != who_id: witnesses.append(id)
	if who_id != "player" and who_id != "": witnesses.append(who_id)
	if witnesses.is_empty(): return
	var text := "%s played Pin the Tail on the Pony in Sugarcube Corner and, blindfolded, pinned the tail %s." % [who_name, where]
	var subjects: Array = [who_id] if who_id != "" else []
	(context as Node).call("record", "pin_the_tail", text, witnesses, subjects, "", "sugarcube_corner")
