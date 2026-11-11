extends Node
## Idle Life Debug: an `idle` command for the game's debug console (the ` console and
## Settings > Debug's command line), to play any Idle Life idle straight away.
##   idle list                 every idle's name
##   idle <name>               plays it on the pony you're looking at
##   idle <name> <pony>        plays it on that pony ("idle shoe celestia")
##   idle run_all [pony]       plays every idle on her in turn, 2 s apart
##   idle stop [pony]          stops the idle playing on her (and a run_all)
## Idles started here play to their end: nothing interrupts them.
##
## It joins the console after any other mod that hooks it (Teleport does, for tp and places):
## a few frames after the console's input line appears it takes over whatever handles the line
## now and passes on every command that isn't `idle`, and likewise for Settings > Debug.

const CONSOLE := "res://world/debug/command_console.gd"
const IDLE_LIFE := "res://mods/idle_life/main.gd"
const IDLES := "res://mods/idle_life/idles.gd"
const HELP := "idle list | idle <name> [pony] | idle run_all [pony] | idle stop [pony] — play an Idle Life idle on the pony you're looking at (or a named one)"
## Frames to wait after the console's input line appears, so other mods hook it first.
const AFTER := 8
## How far, and how far off the middle of the view, a pony counts as the one you're looking at.
const LOOK_RANGE := 25.0
const LOOK_ANGLE := 12.0
## Seconds between idles in `idle run_all`.
const RUN_GAP := 2.0

var _runs: Dictionary = {}     # pony -> run number (a run stops when its number is gone or replaced)
var _run_count := 0

var _hooked: Dictionary = {}   # console -> {"field", "before", "ours", "proxy", "settings_before"}


func _ready() -> void:
	Mods.on_node(CONSOLE, _attach)


func _exit_tree() -> void:
	for console: Variant in _hooked.keys(): _detach(console)


func _attach(console: Node) -> void:
	if _hooked.has(console): return
	for i in 240:
		if not is_instance_valid(console) or not console.is_inside_tree(): return
		if console.get("field") is LineEdit: break
		await get_tree().process_frame
	for i in AFTER: await get_tree().process_frame
	if not is_instance_valid(console) or _hooked.has(console): return
	var field: Variant = console.get("field")
	if not field is LineEdit or not console.has_method("_write"): return
	# Whatever answers the line now (the console itself, or a mod that hooked it before us).
	var before: Array[Callable] = []
	for c: Dictionary in (field as LineEdit).text_submitted.get_connections():
		before.append(c.callable)
	if before.is_empty(): return
	for c: Callable in before: (field as LineEdit).text_submitted.disconnect(c)
	var ours := _submit.bind(console)
	(field as LineEdit).text_submitted.connect(ours)
	var row := {"field": field, "before": before, "ours": ours}
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		var was: Variant = settings.get("debug_console")
		if was != null:
			var proxy := Proxy.new()
			proxy.mod = self; proxy.console = console; proxy.before = was; proxy.name = "IdleLifeDebugConsole"
			add_child(proxy)
			settings.set("debug_console", proxy)
			row.proxy = proxy
			row.settings_before = was
	_hooked[console] = row
	console.tree_exiting.connect(_detach.bind(console), CONNECT_ONE_SHOT)
	print("[idle_life_debug] console ready: idle added")


func _detach(console: Variant) -> void:
	var row: Dictionary = _hooked.get(console, {})
	_hooked.erase(console)
	if row.is_empty(): return
	var field: Variant = row.get("field")
	if is_instance_valid(field) and (field as LineEdit).text_submitted.is_connected(row.ours):
		(field as LineEdit).text_submitted.disconnect(row.ours)
		for c: Callable in row.before:
			if c.is_valid() and not (field as LineEdit).text_submitted.is_connected(c): (field as LineEdit).text_submitted.connect(c)
	var settings := get_node_or_null("/root/Settings")
	if settings != null and row.has("proxy") and settings.get("debug_console") == row.proxy:
		var back: Variant = row.get("settings_before")
		settings.set("debug_console", back if is_instance_valid(back) else null)
	if is_instance_valid(row.get("proxy")): (row.proxy as Node).queue_free()


## The console's line: `idle …` answered here, anything else handed on unchanged.
func _submit(line: String, console: Node) -> void:
	var row: Dictionary = _hooked.get(console, {})
	if not _ours(line):
		for c: Callable in row.get("before", []):
			if c.is_valid(): c.call(line)
		return
	if not is_instance_valid(console): return
	var field: LineEdit = console.get("field")
	field.clear()
	console.call("_write", "> " + line.strip_edges())
	var reply: String = await run(console, line)
	if not reply.is_empty(): console.call("_write", reply)
	if console.get("visible") == true: field.grab_focus()


func _ours(line: String) -> bool:
	var word := line.strip_edges().get_slice(" ", 0).to_lower()
	return word == "idle" or word == "help"


## Runs an `idle` command (or adds this mod's line to `help`); "" when it isn't ours.
func run(console: Node, line: String) -> String:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty(): return ""
	if parts[0].to_lower() == "help":
		var theirs := ""
		var row: Dictionary = _hooked.get(console, {})
		var before: Variant = row.get("settings_before")
		if before != null and is_instance_valid(before) and before.has_method("execute"): theirs = str(await before.call("execute", line))
		return (theirs + "\n" if not theirs.is_empty() else "") + HELP
	var mod := _idle_life()
	if mod == null: return "Idle Life isn't running (install and switch on Idle Life)."
	var names: Array = (load(IDLES) as Script).get_script_constant_map().get("LENGTH", {}).keys()
	if parts.size() < 2 or parts[1].to_lower() == "list":
		return "Idles: " + ", ".join(names) + "\n" + HELP
	var what := parts[1].to_lower()
	var who := " ".join(parts.slice(2)).strip_edges()
	var pony := _pony(console, who) if not who.is_empty() else _looked_at()
	if pony == null:
		return ("No pony called \"%s\" in the world." % who) if not who.is_empty() else "No pony in front of you: look at one, or name her (idle %s celestia)." % what
	var name := _name(pony)
	if what == "stop":
		var was_running := _runs.has(pony)
		_runs.erase(pony)
		var rows: Dictionary = mod.get("_rows")
		if not rows.has(pony): return ("Stopped %s's run_all." % name) if was_running else "%s isn't doing an idle." % name
		mod.call("_finish", pony)
		return "Stopped %s's idle%s." % [name, " and her run_all" if was_running else ""]
	# Any other idle command for her ends a run_all she's in.
	_runs.erase(pony)
	if what == "run_all":
		_run_count += 1
		_runs[pony] = _run_count
		_run_all(console, mod, pony, names, _run_count)
		return "%s: playing all %d idles, %d s apart (idle stop to end)." % [name, names.size(), int(RUN_GAP)]
	if not what in names: return "No idle called \"%s\". Idles: %s" % [what, ", ".join(names)]
	var rows: Dictionary = mod.get("_rows")
	if rows.has(pony): mod.call("_finish", pony)
	if bool(mod.call("play", pony, what, 0.0, true)): return "%s: %s." % [name, what]
	return "%s can't do %s here (it may need wings, a horn, to be a princess, or room to take off)." % [name, what]


## Plays every idle on `pony` in turn, RUN_GAP seconds after each ends. Idles she can't do at all
## (wings, a horn, a princess, room to take off) are reported and skipped.
func _run_all(console: Node, mod: Node, pony: Node3D, names: Array, run: int) -> void:
	var name := _name(pony)
	var skipped: Array = []
	for i in names.size():
		if not _running(pony, run, mod): return
		var what: String = names[i]
		var rows: Dictionary = mod.get("_rows")
		if rows.has(pony): mod.call("_finish", pony)
		if bool(mod.call("play", pony, what, 0.0, true)):
			_say(console, "%s: %s (%d/%d)." % [name, what, i + 1, names.size()])
			while _running(pony, run, mod) and (mod.get("_rows") as Dictionary).has(pony):
				await get_tree().process_frame
		else:
			skipped.append(what)
			_say(console, "%s can't do %s, skipped (%d/%d)." % [name, what, i + 1, names.size()])
			continue
		if i < names.size() - 1:
			await get_tree().create_timer(RUN_GAP).timeout
	if not _running(pony, run, mod): return
	_runs.erase(pony)
	_say(console, "%s: run_all done%s." % [name, (", skipped " + ", ".join(skipped)) if not skipped.is_empty() else ""])


func _running(pony: Variant, run: int, mod: Node) -> bool:
	if not is_instance_valid(pony) or not is_instance_valid(mod): _runs.erase(pony); return false
	return int(_runs.get(pony, -1)) == run


func _say(console: Node, text: String) -> void:
	if is_instance_valid(console) and console.has_method("_write"): console.call("_write", text)
	print("[idle_life_debug] ", text)


func _idle_life() -> Node:
	for n: Node in get_tree().root.find_children("*", "Node", true, false):
		var s: Variant = n.get_script()
		if s is Script and str((s as Script).resource_path) == IDLE_LIFE: return n
	return null


func _ponies() -> Array:
	var game: Variant = Mods.game
	var mares: Variant = game.get("mares") if is_instance_valid(game) else null
	return mares if mares is Array else []


## A pony by name, through the console's own name matching.
func _pony(console: Node, who: String) -> Node3D:
	var id := str(console.call("resolve_pony", who)) if console.has_method("resolve_pony") else who.to_lower()
	for actor: Variant in _ponies():
		if is_instance_valid(actor) and actor is Node3D and actor.get("identity") != null and str(actor.identity.id) == id: return actor
	return null


## The pony nearest the middle of your view, within LOOK_ANGLE degrees and LOOK_RANGE metres.
func _looked_at() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return null
	var eye := cam.global_position
	var ahead := -cam.global_basis.z.normalized()
	var best: Node3D = null
	var best_angle := LOOK_ANGLE
	for actor: Variant in _ponies():
		if not is_instance_valid(actor) or not actor is Node3D: continue
		var to := (actor as Node3D).global_position + Vector3.UP * 0.6 - eye
		if to.length() > LOOK_RANGE: continue
		var angle := rad_to_deg(ahead.angle_to(to))
		if angle < best_angle: best_angle = angle; best = actor
	return best


func _name(pony: Node) -> String:
	var identity: Variant = pony.get("identity")
	return str(identity.get("display_name")) if identity != null else str(pony.name)


## Settings > Debug's command line runs commands through Settings.debug_console: this stands in
## there, answering `idle` and handing everything else to whatever stood there before.
class Proxy extends Node:
	var mod: Node
	var console: Node
	var before: Variant
	func _get(property: StringName) -> Variant:
		if is_instance_valid(before) and property != &"script": return before.get(property)
		return null
	func execute(text: String) -> String:
		if not is_instance_valid(console): return "Open a world first: commands act on it."
		if mod.call("_ours", text):
			var reply: String = await mod.call("run", console, text)
			return reply
		return str(await before.call("execute", text)) if is_instance_valid(before) and before.has_method("execute") else ""
