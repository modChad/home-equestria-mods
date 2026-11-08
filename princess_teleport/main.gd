extends Node
## Princess Teleport: Celestia, Luna and Twilight teleport instead of walking a long way.
##
## Their AI already sends them places with go_to and lead tags. When one of them accepts such a
## trip (or a fly_to) to a place more than FAR metres away, with Anon within TOGETHER metres of
## her, and Anon has agreed to it (see _consented: he asked her to teleport them, or said yes when
## she offered) or he is in danger (see _in_danger: a timberwolf close by, or the Everfree after
## dark), she lights her horn and, after a moment, the two of them vanish in a flash and reappear
## at the place: Anon first, then her beside him once the ground there is ready to walk on (the
## debug console's own "bring that pony here", which finds her a safe spot and moves her
## navigation and residence along with her). The trip then finishes the last few steps as usual.
## A trip without Anon beside her, or that he didn't agree to, is walked as before.
##
## Their prompts learn it from a lore entry each (merge/world/ai/context_seeds.json): ask, and
## she uses the trip tag she already knows. Everything else is the game's own: nothing is
## patched, and the mod only reads the action system and moves ponies with the game's functions.

const TELEPORTERS := ["celestia", "luna", "twilight_sparkle"]
const FAR := 150.0
const TOGETHER := 8.0
## Seconds her horn glows before the flash.
const CHARGE := 1.4
## Longest wait for the ground at the far end to be ready.
const READY_WAIT := 45.0
const TRIPS := ["go_to", "lead", "fly_to"]
## His agreement only counts for this long after he said it, so an old request in her history
## can't teleport him later.
const CONSENT_FOR := 90.0
## A timberwolf this close to Anon is danger.
const WOLF_NEAR := 45.0
const HABITAT := preload("res://world/life/everfree_habitat.gd")

## Asking to be teleported. Words, not just "take me": a plain "take me home" is walked.
const ASK := "\\b(teleport\\w*|tele-?port\\w*|zap|poof|blink|beam|warp|magic\\s+(us|me)|use\\s+(your\\s+)?magic|with\\s+(your\\s+)?magic)\\b"
## "Don't teleport", "no magic", "I'd rather walk": no.
const REFUSE := "\\b(don'?t|do\\s+not|never|no|not|without|rather\\s+not|no\\s+need\\s+to)\\W+(\\w+\\W+){0,3}?(teleport\\w*|zap|poof|blink|beam|warp|magic)\\b|\\b(rather|prefer\\w*|let'?s|we\\s+can|i'?ll)\\s+(to\\s+)?walk"
## Asking, not refusing: "why don't you teleport us?", "can't you just zap us home?".
const ASKING_NOT := "\\b(why\\s+(don'?t|not)(\\s+you|\\s+we)?|can'?t\\s+you|couldn'?t\\s+you|won'?t\\s+you|wouldn'?t\\s+you|isn'?t\\s+it\\s+faster\\s+to)\\b"
## Saying yes to her offer.
const YES := "^\\W*(yes|yeah|yep|yup|sure|ok|okay|alright|all\\s+right|please|do\\s+it|go\\s+ahead|let'?s(\\s+do\\s+it|\\s+go)?|i'?d\\s+(like|love)\\s+that|sounds\\s+good|absolutely|of\\s+course)\\b"
## A yes that's really a no.
const BUT_NO := "\\b(no|not|nope|don'?t|rather\\s+walk|walk)\\b"
## Her line offering it.
const OFFER := "\\b(teleport\\w*|tele-?port\\w*|blink|poof|zap|warp)\\b|\\bmagic\\s+(us|you)\\b"

var _hooked: Dictionary = {}     # executor -> id
var _busy := false
var _scan := 0.0
var _heard: Array = []           # [{text, at}] Anon's recent lines, newest last
var _listening: Object = null    # the director whose transcript we follow
var _rx := {}


func _physics_process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0: return
	_scan = 1.0
	_listen()
	var actions := _actions()
	if actions == null: return
	var executors: Variant = actions.get("executors")
	if not executors is Dictionary: return
	for id: Variant in executors:
		var executor: Variant = executors[id]
		if str(id) not in TELEPORTERS or not is_instance_valid(executor) or _hooked.has(executor): continue
		if not executor.has_signal("outcome"): continue
		executor.outcome.connect(_on_outcome.bind(executor))
		_hooked[executor] = str(id)
	for executor: Variant in _hooked.keys():
		if not is_instance_valid(executor): _hooked.erase(executor)


func _exit_tree() -> void:
	for executor: Variant in _hooked.keys():
		if is_instance_valid(executor) and executor.outcome.is_connected(_on_outcome): executor.outcome.disconnect(_on_outcome)
	_hooked.clear()
	if is_instance_valid(_listening) and _listening.transcript.is_connected(_on_transcript): _listening.transcript.disconnect(_on_transcript)
	_listening = null


## Follows what Anon says, so a teleport needs his say-so.
func _listen() -> void:
	var game: Node = Mods.game
	var director: Variant = game.get("director") if is_instance_valid(game) else null
	if director == _listening: return
	if is_instance_valid(_listening) and _listening.transcript.is_connected(_on_transcript): _listening.transcript.disconnect(_on_transcript)
	_listening = null; _heard.clear()
	if director is Object and is_instance_valid(director) and (director as Object).has_signal("transcript"):
		director.transcript.connect(_on_transcript)
		_listening = director


func _on_transcript(text: String) -> void:
	_heard.append({"text": text.strip_edges(), "at": _now()})
	if _heard.size() > 8: _heard.pop_front()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _regex(pattern: String) -> RegEx:
	if not _rx.has(pattern):
		var rx := RegEx.new(); rx.compile("(?i)" + pattern); _rx[pattern] = rx
	return _rx[pattern]


## Did Anon agree to this teleport? His last line to her, said in the last CONSENT_FOR seconds,
## either asks for one, or says yes right after she offered one.
func _consented(id: String) -> bool:
	var game: Node = Mods.game
	var director: Variant = game.get("director") if is_instance_valid(game) else null
	if director == null or not is_instance_valid(director): return false
	var characters: Variant = director.get("characters")
	if not characters is Dictionary or not (characters as Dictionary).has(id): return false
	var history: Variant = (characters[id] as Dictionary).get("history")
	if not history is Array: return false
	var asked := -1
	for i in range((history as Array).size() - 1, -1, -1):
		if str(history[i].get("role", "")) == "user": asked = i; break
	if asked < 0: return false
	var line := str(history[asked].get("content", ""))
	if not _recent(line): return false
	var offer := ""
	for i in range(asked - 1, -1, -1):
		if str(history[i].get("role", "")) == "assistant": offer = str(history[i].get("content", "")); break
	return agrees(_last_line(line), offer)


## His newest line as he said it (the game puts notes such as how long it's been before it).
func _last_line(content: String) -> String:
	for i in range(_heard.size() - 1, -1, -1):
		var said := str(_heard[i].text)
		if not said.is_empty() and content.ends_with(said): return said
	return content


func _recent(content: String) -> bool:
	for i in range(_heard.size() - 1, -1, -1):
		var said := str(_heard[i].text)
		if not said.is_empty() and content.ends_with(said): return _now() - float(_heard[i].at) <= CONSENT_FOR
	return false


## The words alone: does "line" agree to a teleport, given her line "offer" just before it?
func agrees(line: String, offer: String) -> bool:
	if _regex(REFUSE).search(_regex(ASKING_NOT).sub(line, "", true)) != null: return false
	if _regex(ASK).search(line) != null: return true
	return _regex(OFFER).search(offer) != null and _regex(YES).search(line) != null and _regex(BUT_NO).search(line) == null


## Danger: a timberwolf near Anon or her, or Anon in the Everfree after dark.
func _in_danger(anon: Node3D, actor: Node3D) -> bool:
	var game: Node = Mods.game
	var pack: Node = game.get_node_or_null("Timberwolves") if is_instance_valid(game) else null
	var wolves: Variant = pack.get("wolves") if pack != null else null
	if wolves is Array:
		for wolf: Variant in wolves:
			if not wolf is Node3D or not is_instance_valid(wolf) or not (wolf as Node3D).is_inside_tree(): continue
			var at := (wolf as Node3D).global_position
			if at.distance_to(anon.global_position) < WOLF_NEAR or at.distance_to(actor.global_position) < WOLF_NEAR: return true
	if HABITAT.strength(anon.global_position) > 0.5:
		if pack != null and pack.has_method("dark"): return bool(pack.call("dark", anon.global_position))
		var clock := get_node_or_null("/root/TimeOfDay")
		if clock != null and clock.has_method("daylight") and float(clock.call("daylight")) < 0.3: return true
	return false


func _actions() -> Node:
	var game: Node = Mods.game
	if not is_instance_valid(game): return null
	var director: Variant = game.get("director")
	if director == null or not is_instance_valid(director): return null
	var actions: Variant = director.get("actions")
	return actions if actions is Node and is_instance_valid(actions) else null


func _player_body() -> Node3D:
	var game: Node = Mods.game
	var inventory: Variant = game.get("inventory") if is_instance_valid(game) else null
	var body: Variant = inventory.get("player_body") if inventory != null and is_instance_valid(inventory) else null
	return body if body is Node3D and is_instance_valid(body) else null


## A trip she just took on: far, asked by her AI, with Anon beside her: teleport instead.
func _on_outcome(event: Dictionary, executor: Node) -> void:
	if _busy or str(event.get("status", "")) != "accepted" or str(event.get("type", "")) not in TRIPS: return
	if not is_instance_valid(executor): return
	var movement: Variant = executor.get("movement")
	if not movement is Dictionary or str((movement as Dictionary).get("id", "")) != str(event.get("id", "")): return
	if not bool((movement as Dictionary).get("ai", false)): return
	var actor: Variant = executor.get("actor")
	var navigator: Variant = executor.get("navigator")
	if not actor is Node3D or not is_instance_valid(actor) or navigator == null or not navigator.has_method("command_location"): return
	var place := str((movement as Dictionary).get("location_id", ""))
	if place.is_empty(): return
	var goal: Vector3 = navigator.command_location(place)
	if not goal.is_finite(): return
	var anon := _player_body()
	if anon == null: return
	var distance := (actor as Node3D).global_position.distance_to(goal)
	if distance < FAR or (actor as Node3D).global_position.distance_to(anon.global_position) > TOGETHER: return
	var id := str(_hooked.get(executor, ""))
	var danger := _in_danger(anon, actor as Node3D)
	if not danger and not _consented(id):
		print("[princess_teleport] %s walks to %s: Anon didn't ask to be teleported" % [id, place])
		return
	if danger: print("[princess_teleport] %s: danger, teleporting without asking" % id)
	_teleport(id, executor, actor as Node3D, anon, goal, place)


func _teleport(id: String, executor: Node, actor: Node3D, anon: Node3D, goal: Vector3, place: String) -> void:
	_busy = true
	print("[princess_teleport] %s teleports Anon and herself to %s (%d m)" % [id, place, roundi(actor.global_position.distance_to(goal))])
	# She stands still and lights her horn; the walk waits.
	executor.set_physics_process(false)
	if actor.has_method("cast_magic"): actor.call("cast_magic", CHARGE + 1.5)
	var color := _color(actor)
	_glow(actor.global_position + Vector3.UP * 0.9, color, CHARGE, 0.9)
	_glow(anon.global_position + Vector3.UP * 0.9, color, CHARGE, 0.9)
	await get_tree().create_timer(CHARGE).timeout
	if not _still(actor, anon): _done(executor); return
	_flash(actor.global_position + Vector3.UP * 0.8, color)
	_flash(anon.global_position + Vector3.UP * 0.9, color)
	# Anon first: the world around the far end loads around him.
	var console := _console()
	if console != null and console.has_method("_place"): console.call("_place", goal + Vector3.UP * 0.3, "")
	elif anon.has_method("teleport"): anon.call("teleport", goal + Vector3.UP * 0.3)
	else: anon.global_position = goal + Vector3.UP * 0.3
	actor.visible = false
	_flash(goal + Vector3.UP * 0.9, color)
	# Then her, beside him, once the ground there can be walked.
	var waited := 0.0
	while waited < READY_WAIT and not _walkable(goal):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if not _still(actor, anon): _done(executor); return
	var reply := ""
	if console != null and console.has_method("execute") and console.get("_busy") != true:
		reply = str(await console.call("execute", "spawn " + id))
	if not is_instance_valid(actor): _done(executor); return
	if not reply.begins_with("Brought"):
		# The console could not place her: beside Anon, on his ground.
		print("[princess_teleport] %s: %s; setting her down beside Anon" % [id, reply if not reply.is_empty() else "no console"])
		var beside := anon.global_position + anon.global_basis.x * 1.4
		if actor.has_method("reset_motion"): actor.call("reset_motion", Transform3D(actor.global_basis, beside))
		else: actor.global_position = beside
	actor.visible = true
	_flash(actor.global_position + Vector3.UP * 0.8, color)
	if actor.has_method("cast_magic"): actor.call("cast_magic", 1.0)
	_done(executor)


func _done(executor: Node) -> void:
	if is_instance_valid(executor): executor.set_physics_process(true)
	_busy = false


func _still(actor: Node3D, anon: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and is_instance_valid(anon) and anon.is_inside_tree() and is_instance_valid(Mods.game)


func _walkable(at: Vector3) -> bool:
	var game: Node = Mods.game
	if not is_instance_valid(game) or not game.has_method("_resident_service"): return true
	var region := str(WorldLayout.nearest(at).get("id", "ponyville"))
	var service: Variant = game.call("_resident_service", region, at)
	return service != null and bool(service.get("ready_for_paths"))


func _console() -> Node:
	var game: Node = Mods.game
	if not is_instance_valid(game): return null
	return game.get_node_or_null("CommandConsole")


func _color(actor: Node3D) -> Color:
	var magic: Variant = actor.get("magic")
	if magic != null and is_instance_valid(magic) and magic.get("color") is Color: return magic.color
	return Color(1.0, 0.85, 0.45)


# ---------------------------------------------------------------- effects

func _sphere(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2.0
	mesh.radial_segments = 24; mesh.rings = 12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color, 0.0)
	mesh.material = mat
	var node := MeshInstance3D.new(); node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = Mods.game if is_instance_valid(Mods.game) else get_tree().current_scene
	parent.add_child(node)
	node.global_position = at
	return node


## A soft glow gathering round them while her horn charges.
func _glow(at: Vector3, color: Color, seconds: float, radius: float) -> void:
	var node := _sphere(at, color, radius)
	var mat: StandardMaterial3D = (node.mesh as SphereMesh).material
	node.scale = Vector3.ONE * 1.4
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector3.ONE * 0.8, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "albedo_color:a", 0.35, seconds)
	tween.chain().tween_callback(node.queue_free)


## The flash: a bright burst that swells and fades, with a light.
func _flash(at: Vector3, color: Color) -> void:
	var node := _sphere(at, color.lerp(Color.WHITE, 0.4), 0.5)
	var mat: StandardMaterial3D = (node.mesh as SphereMesh).material
	mat.albedo_color.a = 0.9
	var light := OmniLight3D.new(); light.light_color = color; light.light_energy = 6.0; light.omni_range = 6.0
	node.add_child(light)
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector3.ONE * 3.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.chain().tween_callback(node.queue_free)
