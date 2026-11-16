extends Node
## Mod Reloader: a "Reload from last save" button on Settings → Mods, shown only when a mod
## change waits for the next launch (a pack whose saved switch differs from what is loaded).
##
## Pressed: autosaves (the same save a window close makes, game_saves.gd save_before_quit),
## writes a one-shot resume note, starts a fresh copy of the game the way launch_config.gd
## restart_in_vr does (same exe / AppImage and args, plus --xr-mode so Desktop/VR isn't asked
## again) and quits. On the next launch the title runs as normal (XR, data, setup); once it is
## ready the chosen save is staged with game_saves.stage() and entered like the title's own
## Load game (_pick_entry). --skip-title / --world-id can't be used: player builds strip them.

const LOADER := preload("res://world/modding/mod_loader.gd")
const SAVES := preload("res://world/game_saves.gd")
const CATALOGUE := preload("res://world/saves/save_catalogue.gd")
const TITLE := "res://world/ui/title_screen.gd"
const PAGE := "res://world/ui/settings_page.gd"
const ROW := "ModReloaderRow"
const NOTE := "resume.cfg"
const NOTE_MAX_AGE := 600.0       # seconds: an older note (a failed relaunch) is ignored
const TITLE_WAIT := 180.0         # seconds the title may take to become ready
const FAIL := "modChad fucked it. Sorry."
const MAX_SAVES := 20

var _pending := {}                # {path, world_id} from a resume note, until used
var _pages: Array[WeakRef] = []
var _tick := 0.0


func _ready() -> void:
	_read_note()
	Mods.on_node(TITLE, _on_title)
	Mods.on_node(PAGE, func(page: Node) -> void: _pages.append(weakref(page)))


func _note_path() -> String:
	return Mods.data_folder("mod_reloader").path_join(NOTE)


# --- next launch: back into the save ----------------------------------------------------

func _read_note() -> void:
	var path := _note_path()
	if not FileAccess.file_exists(path): return
	var file := ConfigFile.new()
	var ok := file.load(path) == OK
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))  # one shot, whatever happens
	if not ok: return
	var age := Time.get_unix_time_from_system() - float(file.get_value("resume", "time", 0.0))
	if age < 0.0 or age > NOTE_MAX_AGE:
		print("[mod_reloader] ignoring an old resume note (%d s)" % int(age)); return
	_pending = {"path": str(file.get_value("resume", "path", "")), "world_id": str(file.get_value("resume", "world_id", ""))}
	print("[mod_reloader] resuming %s" % (_pending.path if not _pending.path.is_empty() else "the last save"))


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
	push_warning("[mod_reloader] could not resume: " + why)
	var status: Variant = title.get("status")
	if status is Label: (status as Label).text = FAIL
	var dialog := AcceptDialog.new()
	dialog.title = "Mod Reloader"
	dialog.dialog_text = FAIL
	dialog.exclusive = false
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


# --- Settings → Mods: the button --------------------------------------------------------

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.3: return
	_tick = 0.0
	_pages = _pages.filter(func(ref: WeakRef) -> bool: return is_instance_valid(ref.get_ref()))
	if _pages.is_empty(): return
	var needed := restart_needed()
	for ref: WeakRef in _pages:
		var page := ref.get_ref() as Control
		if page == null or not page.is_visible_in_tree(): continue
		var anchor := _mods_anchor(page)
		if anchor == null: continue
		var list := anchor.get_parent()
		var row := list.get_node_or_null(ROW) as Control
		if row == null:
			if not needed: continue
			row = _build_row(page, list)
			list.move_child(row, anchor.get_index() + 1)
		row.visible = needed


## True when any pack's saved On/Off differs from what this launch loaded: the same test the
## Mods page uses for "Restart the game to apply mod changes." (settings_page.gd _mod_row).
static func restart_needed() -> bool:
	for row: Dictionary in LOADER.pack_rows():
		if not bool(row.get("switchable", true)): continue
		if LOADER.switched_on(str(row.file)) != bool(row.enabled): return true
	return false


## The Mods tab's "Open mods folder" button: the row goes right under it.
static func _mods_anchor(page: Node) -> Button:
	for node: Node in page.find_children("*", "Button", true, false):
		if (node as Button).text == "Open mods folder": return node as Button
	return null


func _build_row(page: Node, list: Node) -> Control:
	var size := int(page.get("font_size")) if page.get("font_size") is int else 20
	var row := HBoxContainer.new()
	row.name = ROW
	row.add_theme_constant_override("separation", 6)
	list.add_child(row)
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", size - 4)
	picker.tooltip_text = "Which save to load after the restart"
	picker.add_item("Last save")
	picker.set_item_metadata(0, "")
	var entries := SAVES.catalogue()
	for i in mini(entries.size(), MAX_SAVES):
		picker.add_item(CATALOGUE.title_text(entries[i]))
		picker.set_item_metadata(picker.item_count - 1, str(entries[i].get("path", "")) + "\n" + str(entries[i].get("world_id", "")))
	var press := func() -> void:
		var meta := str(picker.get_item_metadata(picker.selected)).split("\n")
		reload(meta[0] if meta.size() > 0 else "", meta[1] if meta.size() > 1 else "")
	var button: Button
	if page.has_method("_button"):
		button = page.call("_button", row, "Reload from last save", press)  # the page's own style
	else:
		button = Button.new(); button.text = "Reload from last save"; button.pressed.connect(press); row.add_child(button)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	picker.item_selected.connect(func(index: int) -> void:
		button.text = "Reload from last save" if index == 0 else "Reload this save")
	return row


## Saves, leaves a resume note, starts a fresh copy of the game and quits. `path` empty = the
## newest save after this one is written.
func reload(path: String, world_id: String) -> void:
	var game := Mods.game
	if is_instance_valid(game):
		var saves := game.get_node_or_null("GameSaves")
		if saves != null and saves.has_method("save_before_quit") and not saves.call("save_before_quit"):
			push_warning("[mod_reloader] the autosave before restarting did not write; using the newest save on disk")
	var note := ConfigFile.new()
	note.set_value("resume", "path", path)
	note.set_value("resume", "world_id", world_id)
	note.set_value("resume", "time", Time.get_unix_time_from_system())
	if note.save(_note_path()) != OK:
		Settings.message = FAIL; return
	var args := PackedStringArray()
	var raw := OS.get_cmdline_args()
	var i := 0
	while i < raw.size():
		if raw[i] == "--xr-mode": i += 2; continue  # replaced below with this copy's mode
		args.append(raw[i]); i += 1
	var xr := XRServer.primary_interface
	args.append_array(["--xr-mode", "on" if xr != null and xr.is_initialized() else "off"])
	var user := preload("res://world/dev_tools.gd").user_args()
	if not user.is_empty():
		args.append("--"); args.append_array(user)
	var image := OS.get_environment("APPIMAGE")
	var exe := image if not image.is_empty() else OS.get_executable_path()
	print("[mod_reloader] restarting: %s %s" % [exe, " ".join(args)])
	if OS.create_process(exe, args) < 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_note_path()))
		Settings.message = FAIL; return
	get_tree().quit()
