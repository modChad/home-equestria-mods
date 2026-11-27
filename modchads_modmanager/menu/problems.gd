extends RefCounted
## Settings → Mods, Problems view: one card per problem, saying what is wrong in plain words, what
## to do about it, and buttons that do it (show the mod in Installed, switch it off, open the mods
## folder). The tab only appears while there is at least one problem.
## When mods.pones.top lists a newer version of the mod, the card offers Update (two presses) if the
## download is a .pck from a trusted host (GitHub) and the site's security check found nothing
## (browse.gd install_check); otherwise it says why and offers the listing's page.
## Problems: a pack that is held back, superseded, waiting for another mod, failed to load or whose
## code does not run (the loader's reason / error / held), an old mod that replaces game files, a
## mod that replaces game scripts that saving and loading depend on, and two mods that are on
## replacing the same game file.

const STYLE := preload("res://world/ui/menu_style.gd")
const LOADER := preload("res://world/modding/mod_loader.gd")
const BROWSE := preload("res://mods/modchads_modmanager/menu/browse.gd")


## Every problem now: [{title, what, todo, kind, file, name, on, switchable}].
static func collect() -> Array:
	var out: Array = []
	var rows := LOADER.pack_rows().filter(func(r: Dictionary) -> bool: return str(r.patch_of).is_empty())
	for row: Dictionary in rows:
		var name := str(row.title)
		var file := str(row.file)
		var on := LOADER.switched_on(file)
		var base := {"file": file, "name": name, "on": on, "switchable": bool(row.get("switchable", true)), "version": str(row.version)}
		var reason := str(row.get("reason", ""))
		var error := str(row.get("error", ""))
		if not str(row.get("superseded_by", "")).is_empty():
			out.append(_merge(base, {"kind": "superseded", "title": "%s: an older copy" % name,
				"what": reason if not reason.is_empty() else "Another copy of this mod is installed, so this one is not loaded.",
				"todo": "Nothing breaks, but the older file can be deleted from the mods folder: %s." % file.get_file()}))
		elif bool(row.get("scenario_held", false)):
			out.append(_merge(base, {"kind": "scenario", "title": "%s: another scenario mod is on" % name,
				"what": "Only one scenario mod runs at a time, so this one is held back." + ("\n" + reason if not reason.is_empty() else ""),
				"todo": "Switch the other scenario mod off if you want this one; the change applies at the next start."}))
		elif not error.is_empty():
			out.append(_merge(base, {"kind": "error", "title": "%s: could not be loaded" % name, "what": error,
				"todo": "The file may be damaged or made for another version of the game. Download it again, or look for an update."}))
		elif bool(row.get("held", false)) and LOADER.is_old(row):
			out.append(_merge(base, {"kind": "held_old", "title": "%s: made for an older game" % name,
				"what": "Made for game %s; this is %s. It replaces game files, so the game keeps it off to protect newer features.%s" % [row.game_version, LOADER.game_version(), "\n" + reason if not reason.is_empty() else ""],
				"todo": "Look for an update made for this game version (Browse online may list one)."}))
		elif not reason.is_empty():
			out.append(_merge(base, {"kind": _kind(reason), "title": "%s: %s" % [name, _short(reason)], "what": reason, "todo": _advice(reason)}))
		elif LOADER.is_old(row) and on:
			out.append(_merge(base, {"kind": "old", "title": "%s: made for an older game" % name,
				"what": "Made for game %s; this is %s. Old mods that replace game files can hide newer features." % [row.game_version, LOADER.game_version()],
				"todo": "If something in the game looks out of date, try switching this mod off, and look for an update."}))
		if (row.ids as Array).has("mod_reloader") and on:
			out.append(_merge(base, {"kind": "retired", "title": "%s: retired" % name,
				"what": "Mod Reloader's job is now part of modChads modManager (the Reload game button and the list under it). With both on, Mod Reloader only adds a second, older reload button elsewhere.",
				"todo": "Switch Mod Reloader off and delete %s from the mods folder." % file.get_file()}))
		var warning := str(row.get("warning", ""))
		if not warning.is_empty() and on:
			out.append(_merge(base, {"kind": "core", "title": "%s: replaces core game scripts" % name, "what": warning,
				"todo": "Keep a backup of your saves, and switch this mod off if new worlds, saving or loading go wrong after a game update."}))
	# Two mods that are on and replace the same game file: only the last one loaded takes effect.
	var owners := {}
	for row: Dictionary in rows:
		if not LOADER.switched_on(str(row.file)): continue
		for path: String in (row.overrides as PackedStringArray):
			if not owners.has(path): owners[path] = []
			(owners[path] as Array).append(str(row.title))
	var groups := {}   # "A, B" -> [files]
	for path: String in owners:
		var who: Array = owners[path]
		if who.size() < 2: continue
		var key := ", ".join(PackedStringArray(who))
		if not groups.has(key): groups[key] = []
		(groups[key] as Array).append(path)
	for key: String in groups:
		var files: Array = groups[key]
		var shown := "\n".join(PackedStringArray(files.slice(0, 8).map(func(p: String) -> String: return p.trim_prefix("res://"))))
		if files.size() > 8: shown += "\n…and %d more" % (files.size() - 8)
		out.append({"kind": "conflict", "title": "Conflict: %s" % key, "file": "", "name": key, "on": true, "switchable": false,
			"what": "These mods replace the same %d game %s, and only the one that loads last takes effect:\n%s" % [files.size(), "file" if files.size() == 1 else "files", shown],
			"todo": "If one of them doesn't seem to work, switch the other off. Some mods are made to replace another (check their pages)."})
	return out


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(); out.merge(b, true); return out


static func _kind(reason: String) -> String:
	var r := reason.to_lower()
	if r.contains("does not run"): return "code"
	if r.contains("needs") or r.contains("requires") or r.contains("waiting") or r.contains("depend"): return "depends"
	return "other"


static func _short(reason: String) -> String:
	match _kind(reason):
		"code": return "its code does not run"
		"depends": return "needs another mod"
	return "held back"


static func _advice(reason: String) -> String:
	match _kind(reason):
		"code": return "Its code failed to start in this version of the game. Look for an update, or switch it off."
		"depends": return "Install or switch on the mod it needs (named above), then restart the game."
	return "Read the note above; switching it off and on again, or restarting the game, may clear it."


static func build(page, list: VBoxContainer) -> void:
	var fs: int = page.font_size
	var found := collect()
	if found.is_empty():
		page._note(list, "No problems found. All your mods loaded as expected.")
		return
	if BROWSE.fetching or BROWSE.cache_at < 0.0:
		page._note(list, "Checking mods.pones.top for updates…")
		BROWSE.ensure_index(page, func() -> void:
			if is_instance_valid(page) and page.mm_view == "problems": page.mm_rebuild.call())
	elif not BROWSE.last_error.is_empty():
		list.add_child(STYLE.label("Couldn't check for updates: " + BROWSE.last_error, "Faint", maxi(12, fs - 5)))
	list.add_child(STYLE.label("%d %s" % [found.size(), "problem" if found.size() == 1 else "problems"], "Faint", maxi(12, fs - 5)))
	for p: Dictionary in found:
		var colour: Color = STYLE.PEACH if str(p.kind) in ["superseded", "old", "core", "retired"] else STYLE.CORAL
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(colour, 0.08), Color(colour, 0.35), 1, 16, 16, 12)))
		list.add_child(card)
		var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 6); card.add_child(stack)
		var title := STYLE.label(str(p.title), "Subheading", fs - 1); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_color_override("font_color", colour); stack.add_child(title)
		var what := STYLE.label(str(p.what), "", fs - 4); what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL; stack.add_child(what)
		var todo := STYLE.label("What to do: " + str(p.todo), "Muted", fs - 4); todo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		todo.size_flags_horizontal = Control.SIZE_EXPAND_FILL; stack.add_child(todo)
		var actions := HFlowContainer.new(); actions.add_theme_constant_override("h_separation", 8); stack.add_child(actions)
		var installed: Script = load("res://mods/modchads_modmanager/menu/installed.gd")
		if not str(p.file).is_empty():
			var show: Button = page._button(actions, "Show in Installed", func() -> void:
				page.mm_view = "installed"; page.mm_query = str(p.name); page.mm_filter = "all"
				installed.build(page, page.mm_list); page.refresh(); page._redraw())
			show.add_theme_font_size_override("font_size", fs - 4)
		var listing: Dictionary = BROWSE.newer_listing(str(p.name), str(p.get("version", ""))) if not str(p.file).is_empty() else {}
		if not listing.is_empty():
			var lid := BROWSE.listing_id(listing)
			var progress := str(BROWSE.installing.get(lid, ""))
			var why := BROWSE.install_check(listing)
			var from := "%s %s by %s" % [str(listing.get("name", "")), str(listing.get("version", "")), str(listing.get("author", "Anonymous"))]
			if not progress.is_empty():
				stack.add_child(STYLE.label("%s: %s" % [from, progress], "Muted", fs - 4))
			elif why.is_empty():
				var is_armed := Time.get_ticks_msec() / 1000.0 - float(BROWSE.armed.get(lid, -100.0)) < BROWSE.ARM_SECONDS
				var update: Button = page._button(actions, "Press again" if is_armed else "Update to %s" % str(listing.get("version", "")), func() -> void:
					BROWSE.press_install(page, listing, func() -> void:
						if is_instance_valid(page) and page.mm_view == "problems": page.mm_rebuild.call()))
				update.theme_type_variation = "Primary"; update.add_theme_font_size_override("font_size", fs - 4)
				update.tooltip_text = from
			else:
				var note := STYLE.label("Newer on mods.pones.top: %s. %s" % [from, why], "Faint", maxi(11, fs - 5))
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stack.add_child(note)
				var page_btn: Button = page._button(actions, "Open its page", func() -> void:
					var url := BROWSE.INDEX + "/mod/" + lid.uri_encode()
					Settings.message = ("Opened " if OS.shell_open(url) == OK else "Open this page in a browser: ") + url
					page.refresh())
				page_btn.theme_type_variation = "Ghost"; page_btn.add_theme_font_size_override("font_size", fs - 4)
		if bool(p.on) and bool(p.switchable) and not str(p.file).is_empty():
			var off: Button = page._button(actions, "Switch it off", func() -> void:
				Mods.switch(str(p.file), false)
				Settings.message = "%s switched off. It may need a restart." % str(p.name)
				page.mm_rebuild.call())
			off.theme_type_variation = "Danger"; off.add_theme_font_size_override("font_size", fs - 4)
		if str(p.kind) in ["superseded", "error", "retired"]:
			var folder: Button = page._button(actions, "Show the mods folder", page._open_mods_folder)
			folder.theme_type_variation = "Ghost"; folder.add_theme_font_size_override("font_size", fs - 4)
		if str(p.kind) in ["held_old", "error", "code"]:
			var look: Button = page._button(actions, "Look for an update", func() -> void:
				page.mm_view = "browse"; installed.build(page, page.mm_list); page.refresh(); page._redraw())
			look.theme_type_variation = "Ghost"; look.add_theme_font_size_override("font_size", fs - 4)
