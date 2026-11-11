extends Node
## Item Spawn: one command for the game's debug console (world/debug/command_console.gd), typed
## at the ` console or on Settings > Debug's command line.
##   is list [word]          every item the game can list (world/inventory/item_tags.gd
##                                  enumerable()), id and name; a word keeps only matching ones
##   is add <item> [count]   puts the item straight into the briefcase (inventory_store.gd
##                                  grant()), count 1 by default; no match lists the 5 closest
## A full briefcase stops the spawn and says how many fitted: an owned item on the ground still
## needs a briefcase slot (briefcase_drops.gd spawn_owned_drop), so nothing can go there instead.
## The console's own commands, and other mods' (Teleport), are untouched: this wraps whatever
## handles the input line and Settings > Debug's command runner, answers only is, and
## passes everything else on. If a game update changes the console, the mod stays out of the way.

const CONSOLE := "res://world/debug/command_console.gd"
const CATALOG := preload("res://world/inventory/item_catalog.gd")
const TAGS := preload("res://world/inventory/item_tags.gd")
const HELP := "is list [word] — list every item (word: only those matching)\nis add <item> [count] — put an item in the briefcase (e.g. is add apple 5)"
const COMMAND := "is"
const MAX_COUNT := 999
const CLOSEST := 5
## Frames to wait after the console's input line exists, so a mod that needs the console's own
## handler (Teleport) attaches first and this one wraps it.
const SETTLE_FRAMES := 3

var _consoles: Dictionary = {}   # console -> [proxy, our callable, the callable we replaced]


func _ready() -> void:
	Mods.on_node(CONSOLE, _attach)


func _exit_tree() -> void:
	for console: Variant in _consoles.keys(): _detach(console)


func _attach(console: Node) -> void:
	if _consoles.has(console): return
	for i in 120:
		if not is_instance_valid(console) or not console.is_inside_tree(): return
		if console.get("field") is LineEdit: break
		await get_tree().process_frame
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
		if not is_instance_valid(console) or not console.is_inside_tree(): return
	if _consoles.has(console): return
	var field: Variant = console.get("field")
	if not field is LineEdit or not console.has_method("execute") or not console.has_method("_write"): return
	# The one handler on the input line: the console's _submit, or a mod's wrapper of it.
	var handlers: Array = (field as LineEdit).text_submitted.get_connections()
	if handlers.size() != 1: return
	var previous: Callable = handlers[0].callable
	(field as LineEdit).text_submitted.disconnect(previous)
	var ours := _submit.bind(console, previous)
	(field as LineEdit).text_submitted.connect(ours)
	var settings := get_node_or_null("/root/Settings")
	var runner: Variant = settings.get("debug_console") if settings != null else null
	var proxy := Proxy.new()
	proxy.mod = self; proxy.console = console; proxy.inner = runner if is_instance_valid(runner) else console
	proxy.name = "ItemSpawnConsole"
	add_child(proxy)
	_consoles[console] = [proxy, ours, previous]
	if settings != null and is_instance_valid(runner): settings.set("debug_console", proxy)
	console.tree_exiting.connect(_detach.bind(console), CONNECT_ONE_SHOT)
	print("[item_spawn] console ready: is added")


func _detach(console: Variant) -> void:
	var row: Array = _consoles.get(console, [null, Callable(), Callable()])
	_consoles.erase(console)
	var proxy: Variant = row[0]
	var settings := get_node_or_null("/root/Settings")
	if settings != null and proxy != null and settings.get("debug_console") == proxy:
		var inner: Variant = (proxy as Node).get("inner") if is_instance_valid(proxy) else null
		settings.set("debug_console", inner if is_instance_valid(inner) and (inner as Node).is_inside_tree() and not (inner as Node).is_queued_for_deletion() else null)
	if is_instance_valid(console):
		var field: Variant = console.get("field")
		if field is LineEdit and (row[1] as Callable).is_valid() and (field as LineEdit).text_submitted.is_connected(row[1]):
			(field as LineEdit).text_submitted.disconnect(row[1])
			if (row[2] as Callable).is_valid(): (field as LineEdit).text_submitted.connect(row[2])
	if is_instance_valid(proxy): (proxy as Node).queue_free()


## The console's input line: is here, anything else to the handler we replaced; "help"
## goes there too, then our lines follow it.
func _submit(line: String, console: Node, previous: Callable) -> void:
	if not is_instance_valid(console): return
	var text := line.strip_edges()
	var command := text.get_slice(" ", 0).to_lower()
	if command != COMMAND:
		if previous.is_valid(): await previous.call(line)
		if command == "help" and is_instance_valid(console) and console.is_inside_tree(): console.call("_write", HELP)
		return
	var field: LineEdit = console.get("field")
	field.clear()
	if console.get("_busy") == true: console.call("_write", "A spawn is still loading."); return
	console.call("_write", "> " + text)
	var reply := run(console, text.substr(command.length()).strip_edges())
	if not reply.is_empty(): console.call("_write", reply)
	if console.get("visible") == true: field.grab_focus()


func run(console: Node, rest: String) -> String:
	var sub := rest.get_slice(" ", 0).to_lower()
	var argument := rest.substr(sub.length()).strip_edges()
	match sub:
		"list": return _list(argument)
		"add": return _add(console, argument)
	return HELP


# ---------------------------------------------------------------- list

func _ids() -> Array[String]:
	if not TAGS.bound(): TAGS.bind_catalog(CATALOG)
	return TAGS.enumerable()


func _name(id: String) -> String:
	return str(CATALOG.definition(id).get("name", id))


func _list(filter: String) -> String:
	var word := filter.to_lower()
	var lines := PackedStringArray()
	for id: String in _ids():
		var name := _name(id)
		if not word.is_empty() and not id.to_lower().contains(word) and not name.to_lower().contains(word): continue
		lines.append("%s  —  %s" % [id, name])
	if lines.is_empty(): return "No items match \"%s\"." % filter
	lines.sort()
	lines.insert(0, "1 item:" if lines.size() == 1 else "%d items:" % lines.size())
	lines.append("is add <id or name> [count] to spawn one.")
	return "\n".join(lines)


# ---------------------------------------------------------------- add

func _add(console: Node, argument: String) -> String:
	if argument.is_empty(): return "Usage: is add <item> [count]. Type is list for the items."
	# A last word that is a number is the count: "is add apple pie 3".
	var count := 1
	var words := argument.split(" ", false)
	if words.size() > 1 and words[words.size() - 1].is_valid_int():
		count = int(words[words.size() - 1])
		words.remove_at(words.size() - 1)
		if count < 1 or count > MAX_COUNT: return "Count runs from 1 to %d." % MAX_COUNT
	var wanted := " ".join(words)
	var id := _resolve(wanted)
	if id.is_empty(): return _closest(wanted)
	var game: Variant = console.get("game")
	var briefcase: Variant = game.get("inventory") if is_instance_valid(game) else null
	var store: Variant = briefcase.get("inventory") if is_instance_valid(briefcase) else null
	if store == null or not (store as Object).has_method("grant"): return "Inventory is not ready."
	var stack := maxi(1, CATALOG.stack(id))
	var added := 0
	while added < count:
		# grant() fills one stack or one empty slot per call; a smaller amount may still fit a stack.
		var chunk := mini(count - added, stack)
		while chunk > 0 and int(store.call("grant", id, chunk)) < 0: chunk -= 1
		if chunk <= 0: break
		added += chunk
	var label := _name(id)
	if added == count: return "Added %d × %s to the briefcase." % [count, label]
	var why := "the briefcase can't be changed right now" if store.get("writable") == false else "no room in the briefcase"
	return "Added %d of %d × %s: %s." % [added, count, label, why]


## The item's id: an exact id (books, letters and paintings too) or exact name, also with a plural
## folded ("apples" -> apple), else the game's own name matching (part of a name, tag word).
func _resolve(text: String) -> String:
	if text.is_empty(): return ""
	if CATALOG.has(text): return CATALOG.canonical(text)
	var lower := text.to_lower()
	var forms: Array[String] = [lower]
	for suffix: String in ["es", "s"]:
		if lower.length() > suffix.length() + 2 and lower.ends_with(suffix): forms.append(lower.left(lower.length() - suffix.length()))
	var ids := _ids()
	for form: String in forms:
		if CATALOG.has(form): return CATALOG.canonical(form)
		for id: String in ids:
			if _name(id).to_lower() == form: return id
	return CATALOG.match_name(text, ids)


func _closest(text: String) -> String:
	var lower := text.to_lower()
	var scored: Array = []
	for id: String in _ids():
		var name := _name(id).to_lower()
		var score := maxf(lower.similarity(id.to_lower()), lower.similarity(name))
		if name.contains(lower) or id.contains(lower): score += 0.5
		scored.append([score, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lines := PackedStringArray(["No item called \"%s\". Closest matches:" % text])
	# One line per name: colours of one wear kind share a name.
	var shown := {}
	for row: Array in scored:
		if shown.size() >= CLOSEST: break
		var name := _name(row[1])
		if shown.has(name): continue
		shown[name] = true
		lines.append("  %s  —  %s" % [row[1], name])
	return "\n".join(lines)


## Settings > Debug runs commands through Settings.debug_console: this stands in for whatever was
## there (the console, or another mod's stand-in), answers is and passes the rest on.
class Proxy extends Node:
	var mod: Node
	var console: Node
	var inner: Node
	func _get(property: StringName) -> Variant:
		if property == &"_busy" and is_instance_valid(console): return console.get("_busy")
		return null
	func execute(text: String) -> String:
		if not is_instance_valid(console): return "Open a world first: commands act on it."
		var command := text.strip_edges().get_slice(" ", 0).to_lower()
		if command == COMMAND: return str(mod.call("run", console, text.strip_edges().substr(command.length()).strip_edges()))
		var target: Node = inner if is_instance_valid(inner) else console
		var reply := str(await target.call("execute", text))
		return reply + "\n" + HELP if command == "help" else reply
