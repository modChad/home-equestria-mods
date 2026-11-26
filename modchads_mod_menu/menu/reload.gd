extends RefCounted
## The Reload control at the right of the Mods tab bar: restarts the game so mod changes apply.
## By default it goes back to the main menu (title screen). The list under it can instead load
## straight into your last save or a chosen one: a one-shot resume note that main.gd reads on the
## next launch (this replaces the retired Mod Reloader). Either way the open world is autosaved
## first (the save a window close makes, game_saves.gd save_before_quit), and the button needs a
## second press. The relaunch: same exe / AppImage and arguments, with --xr-mode set to this
## copy's mode so Desktop/VR isn't asked again.

const STYLE := preload("res://world/ui/menu_style.gd")
const LOADER := preload("res://world/modding/mod_loader.gd")
const SAVES := preload("res://world/game_saves.gd")
const CATALOGUE := preload("res://world/saves/save_catalogue.gd")
const ARM_SECONDS := 5.0
const MAX_SAVES := 20
const ENTRY := preload("res://mods/modchads_mod_menu/main.gd")

## Which entry of the list is chosen (kept while the page is open).
static var choice := 0
static var _armed_at := -100.0


static func restart_needed() -> bool:
	for row: Dictionary in LOADER.pack_rows():
		if bool(row.get("switchable", true)) and LOADER.switched_on(str(row.file)) != bool(row.enabled): return true
	return false


## Adds the button and the list under it to `bar` (the tab bar's HBox).
static func build(page, bar: HBoxContainer) -> void:
	var fs: int = page.font_size
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(spacer)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 4); bar.add_child(stack)
	var targets: Array = [["menu", "", "", "To the main menu"], ["save", "", "", "Into my last save"]]
	var entries := SAVES.catalogue()
	for i in mini(entries.size(), MAX_SAVES):
		targets.append(["save", str(entries[i].get("path", "")), str(entries[i].get("world_id", "")), "Into: " + CATALOGUE.title_text(entries[i])])
	choice = clampi(choice, 0, targets.size() - 1)
	var armed := Time.get_ticks_msec() / 1000.0 - _armed_at < ARM_SECONDS
	var needed := restart_needed()
	var button: Button = page._button(stack, "Press again to reload" if armed else "Reload game", func() -> void: _press(page, targets))
	button.add_theme_font_size_override("font_size", fs - 3)
	button.custom_minimum_size = Vector2(fs * 9, fs * 1.8)
	if needed or armed: button.theme_type_variation = "Primary"
	button.tooltip_text = "Restart the game so mod changes apply" + (" (changes are waiting)" if needed else "")
	var picker := OptionButton.new(); picker.add_theme_font_size_override("font_size", fs - 5)
	for t: Array in targets: picker.add_item(str(t[3]))
	picker.selected = choice; picker.tooltip_text = "Where the game goes after reloading"
	picker.custom_minimum_size = Vector2(fs * 9, 0); picker.clip_text = true
	picker.item_selected.connect(func(i: int) -> void: choice = i)
	stack.add_child(picker)


static func _press(page, targets: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var target: Array = targets[clampi(choice, 0, targets.size() - 1)]
	if now - _armed_at >= ARM_SECONDS:
		_armed_at = now
		Settings.message = "Press Reload again to save and restart the game %s." % ("at the main menu" if target[0] == "menu" else "into " + ("your last save" if str(target[1]).is_empty() else "that save"))
		page.mm_rebuild.call()
		var tree: SceneTree = page.get_tree()
		if tree != null:
			await tree.create_timer(ARM_SECONDS + 0.1).timeout
			if is_instance_valid(page): page.mm_rebuild.call()
		return
	_armed_at = -100.0
	_relaunch(page, target[0] == "save", str(target[1]), str(target[2]))


## Autosaves, leaves a resume note when going into a save (main.gd picks it up), starts a fresh
## copy of the game and quits. Without a note the new copy stops at the title screen.
static func _relaunch(page, into_save: bool, path: String, world_id: String) -> void:
	var game: Node = Mods.game
	if is_instance_valid(game):
		var saves := game.get_node_or_null("GameSaves")
		if saves != null and saves.has_method("save_before_quit") and not saves.call("save_before_quit"):
			push_warning("[modchads_mod_menu] the autosave before reloading did not write")
	var note_file := ProjectSettings.globalize_path(ENTRY.note_path())
	if into_save:
		var note := ConfigFile.new()
		note.set_value("resume", "path", path)
		note.set_value("resume", "world_id", world_id)
		note.set_value("resume", "time", Time.get_unix_time_from_system())
		DirAccess.make_dir_recursive_absolute(note_file.get_base_dir())
		if note.save(ENTRY.note_path()) != OK:
			Settings.message = "Could not prepare the reload. Nothing was changed."; page.refresh(); return
	var args := PackedStringArray()
	var raw := OS.get_cmdline_args()
	var i := 0
	while i < raw.size():
		if raw[i] == "--xr-mode": i += 2; continue
		args.append(raw[i]); i += 1
	var xr := XRServer.primary_interface
	args.append_array(["--xr-mode", "on" if xr != null and xr.is_initialized() else "off"])
	var user := preload("res://world/dev_tools.gd").user_args()
	if not user.is_empty() and not args.has("--"):
		args.append("--"); args.append_array(user)
	var image := OS.get_environment("APPIMAGE")
	var exe := image if not image.is_empty() else OS.get_executable_path()
	print("[modchads_mod_menu] reloading %s: %s %s" % ["into a save" if into_save else "to the main menu", exe, " ".join(args)])
	if OS.create_process(exe, args) < 0:
		if into_save: DirAccess.remove_absolute(note_file)
		Settings.message = "Could not start the game again. Close it and start it yourself."; page.refresh(); return
	page.get_tree().quit()
