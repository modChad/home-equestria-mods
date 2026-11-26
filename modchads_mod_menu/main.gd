extends Node
## modChad's Mod Menu: the part that runs at startup. Mod Reloader (modChad) is merged in here:
## when Reload game is set to load a save, menu/reload.gd autosaves, writes a one-shot resume note
## and restarts the game; on this launch the title runs as normal (XR, data, setup) and, once it
## is ready, the chosen save is staged with game_saves.stage() and entered like the title's own
## Load game (_pick_entry). --skip-title / --world-id can't be used: player builds strip them.
## A note Mod Reloader left behind (its own data folder) is honoured too, once, if Mod Reloader is
## not running to take it.

const SAVES := preload("res://world/game_saves.gd")
const CATALOGUE := preload("res://world/saves/save_catalogue.gd")
const TITLE := "res://world/ui/title_screen.gd"
const ID := "modchads_mod_menu"
const NOTE := "resume.cfg"
const NOTE_MAX_AGE := 600.0       # seconds: an older note (a failed relaunch) is ignored
const TITLE_WAIT := 180.0         # seconds the title may take to become ready
const FAIL := "Couldn't load that save after reloading. Pick it from Load game."

var _pending := {}                # {path, world_id} from a resume note, until used


static func note_path() -> String:
	return Mods.data_folder(ID).path_join(NOTE)


func _ready() -> void:
	_read_note(note_path())
	if _pending.is_empty() and not Mods.is_active("mod_reloader"):
		_read_note(Mods.data_folder("mod_reloader").path_join(NOTE))
	Mods.on_node(TITLE, _on_title)


func _read_note(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var file := ConfigFile.new()
	var ok := file.load(path) == OK
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))  # one shot, whatever happens
	if not ok: return
	var age := Time.get_unix_time_from_system() - float(file.get_value("resume", "time", 0.0))
	if age < 0.0 or age > NOTE_MAX_AGE:
		print("[%s] ignoring an old resume note (%d s)" % [ID, int(age)]); return
	_pending = {"path": str(file.get_value("resume", "path", "")), "world_id": str(file.get_value("resume", "world_id", ""))}
	print("[%s] resuming %s" % [ID, _pending.path if not str(_pending.path).is_empty() else "the last save"])


func _on_title(title: Node) -> void:
	if _pending.is_empty() or title.get("overlay_host") != null: return
	var want := _pending
	_pending = {}
	var waited := 0.0
	while is_instance_valid(title) and not bool(title.get("ready_for_entry")) and waited < TITLE_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_instance_valid(title): return
	if not bool(title.get("ready_for_entry")) or bool(title.get("entering")):
		_fail(title, "title not ready after %d s" % int(waited)); return
	var entry := _find_entry(want)
	if entry.is_empty():
		_fail(title, "no save found"); return
	if not SAVES.stage(entry):
		_fail(title, "save would not stage: %s" % SAVES.last_problem); return
	title.set("_staged", true)
	if title.has_method("_trip_of"): title.set("_destination", title.call("_trip_of", entry))
	title.call("enter_game")


## The save the note names (matched by path), else the newest save of all.
static func _find_entry(want: Dictionary) -> Dictionary:
	var entries := SAVES.catalogue()
	var path := str(want.get("path", ""))
	if not path.is_empty():
		for entry: Dictionary in entries:
			if str(entry.get("path", "")) == path: return entry
		return {}
	return CATALOGUE.newest(entries)


func _fail(title: Node, why: String) -> void:
	push_warning("[%s] could not resume: %s" % [ID, why])
	var status: Variant = title.get("status")
	if status is Label: (status as Label).text = FAIL
	var dialog := AcceptDialog.new()
	dialog.title = "modChad's Mod Menu"
	dialog.dialog_text = FAIL
	dialog.exclusive = false
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
