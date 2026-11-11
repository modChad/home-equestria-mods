extends RefCounted
## Fishing: ponies notice catches. Notable ones (a first, a personal best, a rare fish, a big one,
## junk) are written to the game's witnessed-events memory for ponies within 10 m, so the AI can
## bring them up later. A pony fishing with you (or one close by, for notable catches) says a
## short line over her head, no AI call (world/ai/overhead_dialogue.gd, as the courier does).
## Her own catches she announces too.
const OVERHEAD := preload("res://world/ai/overhead_dialogue.gd")
const WITNESS_RANGE := 10.0
const NEAR_RANGE := 6.0
const RECORD_GAP := 45.0
var host: Node   # main.gd
var _last_record := -1000000
var _speech: Dictionary = {}   # pony -> speech node

const JUNK_TEXT := {"hat": "an old sun hat", "can": "a rusty tin can", "horseshoe": "a lost horseshoe", "weed": "a clump of pond weed", "stick": "a stick"}
const LINES := {
	"rare": ["Whoa, is that a %s?!", "No way, a %s! I've never seen one!", "A %s! You lucky thing!"],
	"best": ["Now THAT's a fish!", "Look at the size of it!", "Ooh, that's a big one!"],
	"first": ["Your first %s! Nice!", "Ooh, a %s!"],
	"fish": ["Nice catch!", "Ooh, a %s!", "Good one!"],
	"hat": ["Ooh, a hat! It's got ear holes and everything.", "Maybe it'll fit once it dries out!"],
	"can": ["A tin can? Keep at it!", "That's... not a fish."],
	"horseshoe": ["Somepony's going to be glad to see that again!", "A horseshoe! Lucky!"],
	"weed": ["Mmm, pond weed. Very... green.", "Ha! Not quite a fish."],
	"stick": ["A stick! Riveting.", "Fetch!"],
	"mine": ["Got one!", "Ha! A %s!", "Look, a %s!"],
	"mine_junk": ["Oh. Just %s.", "Hmph, %s."],
}

func player_caught(rod: Node3D, fish: Dictionary, note: String) -> void:
	var junk: bool = fish.get("junk", false)
	var rare: bool = fish.get("rare", false)
	var best := note.contains("best"); var first := note.contains("First")
	var big: bool = float(fish.get("size_t", 0.0)) > .7
	var notable := junk or rare or best or first or big
	if notable: _remember(rod, _text_for("Anon", fish, best, first, "his"), rare or best)
	# Who speaks: a pony fishing with you, else (for notable ones) a pony close by, half the time.
	var pony := _companion(rod)
	if pony == null and notable and randf() < .5: pony = _nearest(rod.global_position, NEAR_RANGE)
	if pony == null: return
	var pool := "fish"
	if junk: pool = str(fish.id)
	elif rare: pool = "rare"
	elif best or big: pool = "best"
	elif first: pool = "first"
	elif randf() > .35: return
	_say(pony, _line(pool, str(fish.name).to_lower()))

func pony_caught(rod: Node3D, fish: Dictionary) -> void:
	var pony := _actor_for(rod)
	if pony == null: return
	var name := _name_of(pony)
	if fish.get("junk", false):
		_say(pony, _line("mine_junk", JUNK_TEXT.get(str(fish.id), "junk")))
		return
	_say(pony, _line("mine", str(fish.name).to_lower()))
	if fish.get("rare", false) or float(fish.get("size_t", 0.0)) > .7:
		_remember(rod, "%s caught a %d cm %s at the fishing pier%s." % [name, roundi(float(fish.length) * 100.0), str(fish.name).to_lower(),
			", a rare one" if fish.get("rare", false) else ""], true)

func _text_for(who: String, fish: Dictionary, best: bool, first: bool, his: String) -> String:
	if fish.get("junk", false):
		return "%s fished %s out of the water at the fishing pier." % [who, JUNK_TEXT.get(str(fish.id), "some junk")]
	var tail := ""
	if fish.get("rare", false): tail = ", a rare one"
	elif best: tail = ", %s biggest yet" % his
	elif first: tail = ", %s first" % his
	return "%s caught a %d cm %s at the fishing pier%s." % [who, roundi(float(fish.length) * 100.0), str(fish.name).to_lower(), tail]

func _line(pool: String, word: String) -> String:
	var options: Array = LINES.get(pool, LINES.fish)
	var line: String = options[randi() % options.size()]
	return line % word if line.contains("%s") else line

# ---------------------------------------------------------------- memory

func _remember(rod: Node3D, text: String, always := false) -> void:
	var game: Variant = Mods.get("game")
	if not is_instance_valid(game): return
	var now := Time.get_ticks_msec()
	if not always and now - _last_record < int(RECORD_GAP * 1000.0): return
	var memory: Variant = game.get("world_context"); var director: Variant = game.get("director")
	if memory == null or director == null or not memory.has_method("record"): return
	var cast: Variant = director.get("characters")
	if not cast is Dictionary: return
	var witnesses := ["player"]
	for key: Variant in cast:
		var node: Variant = (cast[key] as Dictionary).get("node")
		if node is Node3D and is_instance_valid(node) and (node as Node3D).global_position.distance_to(rod.global_position) <= WITNESS_RANGE:
			witnesses.append(str(key))
	if witnesses.size() <= 1: return
	if not str(memory.call("record", "fishing", text, witnesses, ["player"])).is_empty(): _last_record = now

# ---------------------------------------------------------------- who's there

func _companion(rod: Node3D) -> Node3D:
	var companions: Variant = rod.get_parent().get_parent().get("companions")
	if companions == null: return null
	for lease: Variant in companions.get("leases"):
		var actor: Variant = (lease as Dictionary).get("actor")
		if actor is Node3D and is_instance_valid(actor): return actor
	return null

func _actor_for(rod: Node3D) -> Node3D:
	var companions: Variant = rod.get_parent().get_parent().get("companions")
	if companions == null or not companions.has_method("actor_for_rod"): return null
	var actor: Variant = companions.actor_for_rod(rod)
	return actor if actor is Node3D and is_instance_valid(actor) else null

func _nearest(at: Vector3, within: float) -> Node3D:
	var game: Variant = Mods.get("game")
	if not is_instance_valid(game) or game.get("director") == null: return null
	var cast: Variant = game.director.get("characters")
	if not cast is Dictionary: return null
	var best: Node3D = null; var dist := within
	for key: Variant in cast:
		var node: Variant = (cast[key] as Dictionary).get("node")
		if node is Node3D and is_instance_valid(node):
			var d := (node as Node3D).global_position.distance_to(at)
			if d < dist: best = node; dist = d
	return best

func _name_of(pony: Node) -> String:
	var identity: Variant = pony.get("identity")
	return str((identity as Resource).get("display_name")) if identity is Resource else "A pony"

## Her words over her head for a few seconds (no AI call).
func _say(pony: Node3D, text: String) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree(): return
	if pony.has_method("is_speaking") and pony.is_speaking(): return  # don't talk over the AI
	var old: Variant = _speech.get(pony)
	if is_instance_valid(old): (old as Node).queue_free()
	var speech: Node3D = OVERHEAD.new()
	speech.call("set_fallback_labels", null, null, _name_of(pony))
	speech.set("text", text); speech.set("caption_full", text)
	host.add_child(speech)
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	speech.call("show_for", pony, cam)
	_speech[pony] = speech
	host.get_tree().create_timer(4.5).timeout.connect(func() -> void: if is_instance_valid(speech): speech.queue_free())
