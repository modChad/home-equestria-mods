extends Node
## Teleport: two commands for the game's debug console (world/debug/command_console.gd), typed
## at the ` console or on Settings > Debug's command line.
##   places [filter]         every place the game knows by name (the same list ponies are sent
##                           around by, world/navigation/place_directory.gd), numbered, nearest
##                           first, with the world's regions after.
##   tp <number>             to a place from the last list
##   tp <place name>         to a place by name ("tp sugarcube corner", "tp balloon")
##   tp <pony name>          next to a pony in the world ("tp celestia")
##   tp <x> <y> <z>          to a point
## The console's own commands are untouched: the mod answers only these two and adds them to
## "help". It hooks the console's input line and Settings > Debug's command runner; if a game
## update changes the console, the mod stays out of the way and the console works as before.

const CONSOLE := "res://world/debug/command_console.gd"
const PLACES := preload("res://world/navigation/place_directory.gd")
const CATALOGUE := preload("res://world/population/pony_population_config.gd")
const HELP := "places [word] — list places to teleport to, nearest first (word: only those matching)\ntp <number | place | pony | x y z> — teleport there (e.g. tp 3, tp sugarcube corner, tp luna)"
## Shown in one go before the list is cut short.
const LIST_MAX := 60

var _consoles: Dictionary = {}   # console -> [proxy, our submit callable]
var _last: Array = []            # the last "places" list: [{label, id}]


func _ready() -> void:
	Mods.on_node(CONSOLE, _attach)


func _exit_tree() -> void:
	for console: Variant in _consoles.keys(): _detach(console)


func _attach(console: Node) -> void:
	if _consoles.has(console): return
	# The console builds its input line in setup(), just after it enters the tree.
	for i in 120:
		if not is_instance_valid(console) or not console.is_inside_tree(): return
		if console.get("field") is LineEdit: break
		await get_tree().process_frame
	var field: Variant = console.get("field")
	if not field is LineEdit or not console.has_method("execute") or not console.has_method("_write") or not console.has_method("_place"): return
	var own := Callable(console, "_submit")
	if not (field as LineEdit).text_submitted.is_connected(own): return
	(field as LineEdit).text_submitted.disconnect(own)
	var ours := _submit.bind(console)
	(field as LineEdit).text_submitted.connect(ours)
	var proxy := Proxy.new()
	proxy.mod = self; proxy.console = console; proxy.name = "TeleportConsole"
	add_child(proxy)
	_consoles[console] = [proxy, ours]
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.get("debug_console") == console: settings.set("debug_console", proxy)
	console.tree_exiting.connect(_detach.bind(console), CONNECT_ONE_SHOT)
	print("[teleport] console ready: tp and places added")


func _detach(console: Variant) -> void:
	var row: Array = _consoles.get(console, [null, Callable()])
	_consoles.erase(console)
	var proxy: Variant = row[0]
	var settings := get_node_or_null("/root/Settings")
	if settings != null and proxy != null and settings.get("debug_console") == proxy:
		settings.set("debug_console", console if is_instance_valid(console) and (console as Node).is_inside_tree() and not (console as Node).is_queued_for_deletion() else null)
	if is_instance_valid(console):
		var field: Variant = console.get("field")
		if field is LineEdit and (row[1] as Callable).is_valid() and (field as LineEdit).text_submitted.is_connected(row[1]):
			(field as LineEdit).text_submitted.disconnect(row[1])
			(field as LineEdit).text_submitted.connect(Callable(console, "_submit"))
	if is_instance_valid(proxy): (proxy as Node).queue_free()


## The console's input line: the same as its own handler, through execute() below.
func _submit(line: String, console: Node) -> void:
	if not is_instance_valid(console): return
	var field: LineEdit = console.get("field")
	field.clear()
	if console.get("_busy") == true: console.call("_write", "A spawn is still loading."); return
	var text := line.strip_edges()
	if text.is_empty(): return
	console.call("_write", "> " + text)
	var reply := str(await execute(console, text))
	if not is_instance_valid(console) or not console.is_inside_tree(): return
	if not reply.is_empty(): console.call("_write", reply)
	if console.get("visible") == true: field.grab_focus()


func execute(console: Node, text: String) -> String:
	var parts := text.strip_edges().split(" ", false)
	var command := parts[0].to_lower() if not parts.is_empty() else ""
	var rest := text.strip_edges().substr(command.length()).strip_edges()
	match command:
		"places", "locations": return _places(console, rest)
		"tp", "teleport": return _teleport(console, rest)
		"help": return str(await console.call("execute", text)) + "\n" + HELP
	return str(await console.call("execute", text))


# ---------------------------------------------------------------- places

func _here(console: Node) -> Vector3:
	var body: Variant = console.get("player_body")
	return (body as Node3D).global_position if is_instance_valid(body) and body is Node3D else Vector3.ZERO


func _places(console: Node, filter: String) -> String:
	var here := _here(console)
	var near: Array = []
	var regions: Array = []
	var words := PLACES.name_words(filter)
	for e: Dictionary in PLACES.entries(get_tree()):
		if not words.is_empty():
			var bag := PLACES.name_words(str(e.label) + " " + str(e.get("alt", "")) + " " + str(e.id).get_slice(":", str(e.id).get_slice_count(":") - 1).replace("_", " "))
			var hit := false
			for w: String in words: hit = hit or bag.has(w)
			if not hit: continue
		(regions if str(e.kind).begins_with("region") else near).append(e)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return here.distance_to(a.position) < here.distance_to(b.position))
	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.label) < str(b.label))
	_last.clear()
	var lines := PackedStringArray()
	if near.is_empty() and regions.is_empty(): return "No places match \"%s\"." % filter
	if not near.is_empty():
		lines.append("Places nearby:")
		for e: Dictionary in near.slice(0, LIST_MAX):
			_last.append({"id": e.id, "label": e.label})
			lines.append("%d  %s  (%s, %d m)" % [_last.size(), e.label, _kind(e), roundi(here.distance_to(e.position))])
		if near.size() > LIST_MAX: lines.append("…and %d more: try places <word>." % (near.size() - LIST_MAX))
	if not regions.is_empty():
		lines.append("Regions:")
		for e: Dictionary in regions:
			_last.append({"id": e.id, "label": e.label})
			lines.append("%d  %s  (%d m)" % [_last.size(), e.label, roundi(here.distance_to(e.position))])
	lines.append("tp <number> to go there.")
	return "\n".join(lines)


func _kind(e: Dictionary) -> String:
	var kind := str(e.kind)
	if kind == PLACES.HOUSE_KIND: return "house"
	return "landmark" if kind == "landmark" else kind.get_slice(":", 1).replace("_", " ")


# ---------------------------------------------------------------- teleport

func _teleport(console: Node, what: String) -> String:
	if what.is_empty(): return "tp <number | place | pony | x y z>. Type places for the list."
	# A point.
	var xyz := what.replace(",", " ").split(" ", false)
	if xyz.size() == 3 and xyz[0].is_valid_float() and xyz[1].is_valid_float() and xyz[2].is_valid_float():
		var at := Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		return str(console.call("_place", _ground(at, true), "At %.1f, %.1f, %.1f." % [at.x, at.y, at.z]))
	# A number from the last list.
	if what.is_valid_int():
		var n := int(what)
		if _last.is_empty(): _places(console, "")
		if n < 1 or n > _last.size(): return "No place %d: type places for the list." % n
		return _go_place(console, str(_last[n - 1].id), str(_last[n - 1].label))
	# A pony in the world.
	var pony := _pony(console, what)
	if pony != null:
		var forward := pony.global_basis.z; forward.y = 0.0
		if forward.length_squared() < 0.01: forward = Vector3.FORWARD
		var size := float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0
		var at := pony.global_position + forward.normalized() * 1.6 * size
		var who: String = CATALOGUE.pony_name(str(pony.identity.id))
		return str(console.call("_place", _ground(at, false), "Next to %s." % who))
	# A place by name.
	var entries: Array = PLACES.entries(get_tree())
	var ids: Array = []
	var labels := {}
	for e: Dictionary in entries:
		ids.append(e.id); labels[e.id] = str(e.label) + " " + str(e.get("alt", ""))
	var id := PLACES.match_name(what, ids, labels)
	if id.is_empty(): return "No place or pony called \"%s\". Type places for the list." % what
	for e: Dictionary in entries:
		if e.id == id: return _go_place(console, id, str(e.label))
	return "No place called \"%s\"." % what


func _go_place(console: Node, id: String, label: String) -> String:
	var at: Vector3 = PLACES.resolve(get_tree(), id)
	if not at.is_finite(): return "%s is not loaded right now." % label
	return str(console.call("_place", _ground(at, false), "At %s." % label))


## A pony in the world by name (the console's own name matching), or null.
func _pony(console: Node, name: String) -> Node3D:
	if not console.has_method("resolve_pony"): return null
	var id := str(console.call("resolve_pony", name))
	if id.is_empty(): return null
	var game: Variant = console.get("game")
	var mares: Variant = game.get("mares") if is_instance_valid(game) else null
	if not mares is Array: return null
	for actor: Variant in mares:
		if is_instance_valid(actor) and actor is Node3D and actor.get("identity") != null and str(actor.identity.id) == id: return actor
	return null


## Standing room at a point: the floor under it (a house floor, a bridge, the ground), else the
## terrain, a little above either. `exact` keeps a typed height when nothing is under it.
func _ground(at: Vector3, exact: bool) -> Vector3:
	var world := get_viewport().world_3d
	if world != null:
		# From just above the point: a house's centre is inside it, under its roof.
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at + Vector3.DOWN * 6.0, 1)
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty(): return (hit.position as Vector3) + Vector3.UP * 0.1
	if is_instance_valid(WorldTerrain.instance):
		var h: float = WorldTerrain.instance.height_at(at)
		if is_finite(h) and (not exact or at.y < h): return Vector3(at.x, h + 0.5, at.z)
	return at + Vector3.UP * 0.5


## Settings > Debug runs commands through Settings.debug_console: this stands in for the console
## there, so the command line on that page knows tp and places too.
class Proxy extends Node:
	var mod: Node
	var console: Node
	func _get(property: StringName) -> Variant:
		if property == &"_busy" and is_instance_valid(console): return console.get("_busy")
		return null
	func execute(text: String) -> String:
		if not is_instance_valid(console): return "Open a world first: commands act on it."
		return str(await mod.call("execute", console, text))
