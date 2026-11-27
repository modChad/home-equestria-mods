extends RefCounted
## Settings → Mods, Installed view: search, sort, filter chips, a restart notice, a conflict
## notice, and one A–Z list of every mod (no "your mods first": mods that come with the game wear
## an "Included" badge and have their own filter) with All on / All off, in compact rows that open
## for details. `page` is the settings page (ext/settings_page.gd); its helpers and
## mm_* state are reached by name.

const STYLE := preload("res://world/ui/menu_style.gd")
const LOADER := preload("res://world/modding/mod_loader.gd")
const BROWSE := preload("res://mods/modchads_modmanager/menu/browse.gd")
const PROBLEMS := preload("res://mods/modchads_modmanager/menu/problems.gd")
const RELOAD := preload("res://mods/modchads_modmanager/menu/reload.gd")
const FILTERS := [["all", "All"], ["on", "On"], ["off", "Off"], ["restart", "Needs restart"], ["settings", "Has settings"],
	["included", "Included"], ["yours", "Added by you"]]
const SORTS := ["A–Z", "On first", "Author"]
const MOST_FILES := 200


## The whole tab, built again from nothing (also when switching between Installed and Browse).
static func build(page, list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child); child.queue_free()
	var fs: int = page.font_size
	page.mm_rebuild = func() -> void:
		if is_instance_valid(list): build(page, list); page.refresh(); page._redraw()
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); list.add_child(tabs)
	var views: Array = [["installed", "Installed"], ["browse", "Browse online"]]
	# The Problems tab only while there is one (or while it is open, so it can say "none left").
	var problems := PROBLEMS.collect().size()
	if problems > 0 or page.mm_view == "problems": views.append(["problems", "Problems %d" % problems if problems > 0 else "Problems"])
	for view: Array in views:
		var b: Button = page._button(tabs, str(view[1]), func() -> void:
			if page.mm_view != view[0]:
				page.mm_view = str(view[0]); build(page, list)
			page.refresh(); page._redraw())
		b.theme_type_variation = "Tab"; b.toggle_mode = true
		b.set_pressed_no_signal(page.mm_view == view[0])
		b.add_theme_font_size_override("font_size", fs - 2)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	RELOAD.build(page, tabs)
	page._note(list, "Mods can run code on your computer. Only install mods from people you trust. Most mods switch on and off at once; the rest apply the next time the game starts.")
	# Not "Open mods folder": Mod Reloader would add its own reload row under that exact text, and
	# the tab bar's Reload control replaces it.
	var open: Button = page._button(list, "Open the mods folder", page._open_mods_folder)
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if page.mm_view == "browse":
		page.mm_browse = BROWSE.new(page, list)
		return
	if page.mm_view == "problems":
		page.mm_browse = null
		PROBLEMS.build(page, list)
		return
	page.mm_browse = null
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 8); list.add_child(bar)
	var field := LineEdit.new(); field.placeholder_text = "Search by name, author or description…"
	field.text = page.mm_query; field.clear_button_enabled = true; field.max_length = 80
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL; field.add_theme_font_size_override("font_size", fs - 1)
	field.focus_entered.connect(page._redraw); bar.add_child(field)
	field.text_changed.connect(func(text: String) -> void:
		page.mm_query = text; fill(page); page._redraw())
	var sort := OptionButton.new()
	for s: String in SORTS: sort.add_item(s)
	sort.selected = int(page.mm_sort); sort.add_theme_font_size_override("font_size", fs - 3)
	sort.tooltip_text = "Sort"; bar.add_child(sort)
	sort.item_selected.connect(func(i: int) -> void:
		page.mm_sort = i; fill(page); page._redraw())
	var chips := HFlowContainer.new(); chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6); list.add_child(chips)
	page.mm_chips = chips
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_child(body)
	page.mm_body = body
	fill(page)


## What one pack row shows and how it can be filtered.
static func _facts(page, row: Dictionary, tabs: Dictionary) -> Dictionary:
	var name := str(row.title); var version := str(row.version); var author := str(row.author)
	var lines := PackedStringArray()
	for mod: Dictionary in LOADER.mods:
		if mod.file != row.file: continue
		if not str(mod.description).is_empty(): lines.append(str(mod.description))
	var file := str(row.file)
	var switchable := bool(row.get("switchable", true))
	var on := LOADER.switched_on(file)
	var problem := not str(row.get("reason", "")).is_empty() or bool(row.get("held", false)) or not str(row.get("error", "")).is_empty()
	var key := _key(name)
	return {"row": row, "file": file, "name": name, "version": version, "author": author,
		"description": "\n".join(lines), "on": on, "switchable": switchable,
		"restart": switchable and on != bool(row.enabled), "problem": problem,
		"old": LOADER.is_old(row) and not bool(row.get("held", false)),
		"settings": tabs.get(key) if tabs.has(key) else null,
		"search": " ".join(PackedStringArray([name, author, version, "\n".join(lines), file])).to_lower()}


## Lower-case letters and digits only, for matching names.
static func _key(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"): out += c
	return out


## Sidebar buttons other mods added (Flowing Manes' own page and the like), by name key.
static func _settings_tabs(page) -> Dictionary:
	var game_tabs := {}
	for tab: Array in Settings.TABS: game_tabs[str(tab[0])] = true
	var out := {}
	var order: Variant = page.get("_tab_order")
	if not order is Array: return out
	for b: Variant in order:
		if b is Button and is_instance_valid(b) and not game_tabs.has((b as Button).text):
			out[_key((b as Button).text)] = b
	return out


## The rows, notices and sections, built again after any change.
static func fill(page) -> void:
	var body: VBoxContainer = page.mm_body
	if body == null or not is_instance_valid(body): return
	for child in body.get_children():
		body.remove_child(child); child.queue_free()
	var tabs := _settings_tabs(page)
	var all: Array = []
	for row: Dictionary in LOADER.pack_rows():
		if str(row.patch_of).is_empty(): all.append(_facts(page, row, tabs))
	_fill_chips(page, all)
	var restart := all.filter(func(f: Dictionary) -> bool: return f.restart)
	if not restart.is_empty():
		var names := PackedStringArray(restart.map(func(f: Dictionary) -> String: return "%s (%s)" % [f.name, "on" if f.on else "off"]))
		_card(page, body, "%d %s after a restart: %s." % [restart.size(), "change applies" if restart.size() == 1 else "changes apply", ", ".join(names)], STYLE.SKY)
	var problems := PROBLEMS.collect()
	if not problems.is_empty():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(STYLE.CORAL, 0.08), Color(STYLE.CORAL, 0.3), 1, 14, 14, 10)))
		body.add_child(card)
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); card.add_child(line)
		var label := STYLE.label("%d %s with your mods." % [problems.size(), "problem" if problems.size() == 1 else "problems"], "", int(page.font_size) - 3)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; line.add_child(label)
		var go: Button = page._button(line, "See what's wrong", func() -> void:
			page.mm_view = "problems"; build(page, page.mm_list); page.refresh(); page._redraw())
		go.theme_type_variation = "Danger"; go.add_theme_font_size_override("font_size", int(page.font_size) - 4)
	var shown_rows := all.filter(func(f: Dictionary) -> bool: return _passes(page, f))
	shown_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(int(page.mm_sort), a, b))
	_heading(page, body, "Installed mods", "%d" % all.size() + (", %d shown" % shown_rows.size() if shown_rows.size() != all.size() else ""), shown_rows)
	var shipped := all.filter(func(f: Dictionary) -> bool: return bool(f.row.bundled)).map(func(f: Dictionary) -> Dictionary: return f.row)
	if not shipped.is_empty(): page._mod_updates(body, shipped)
	if all.is_empty():
		page._note(body, "No mods yet. Put .pck mods in the mods folder, then restart the game, or find some under Browse online.")
	elif shown_rows.is_empty():
		_faint(page, body, "None match.")
	for f: Dictionary in shown_rows: _row(page, body, f)


static func _passes(page, f: Dictionary) -> bool:
	var query := str(page.mm_query).strip_edges().to_lower()
	if not query.is_empty():
		for word in query.split(" ", false):
			if not str(f.search).contains(word): return false
	match str(page.mm_filter):
		"on": return f.on
		"off": return not f.on
		"restart": return f.restart
		"settings": return f.settings != null
		"included": return bool(f.row.bundled)
		"yours": return not bool(f.row.bundled)
	return true


static func _before(sort: int, a: Dictionary, b: Dictionary) -> bool:
	if sort == 1 and a.on != b.on: return a.on
	if sort == 2 and str(a.author).to_lower() != str(b.author).to_lower(): return str(a.author).to_lower() < str(b.author).to_lower()
	return str(a.name).to_lower() < str(b.name).to_lower()


static func _fill_chips(page, all: Array) -> void:
	var chips: Control = page.mm_chips
	if chips == null or not is_instance_valid(chips): return
	for child in chips.get_children():
		chips.remove_child(child); child.queue_free()
	var fs: int = page.font_size
	for entry: Array in FILTERS:
		var id := str(entry[0])
		var count := all.filter(func(f: Dictionary) -> bool:
			match id:
				"on": return f.on
				"off": return not f.on
				"restart": return f.restart
				"settings": return f.settings != null
				"included": return bool(f.row.bundled)
				"yours": return not bool(f.row.bundled)
			return true).size()
		if count == 0 and id != "all" and page.mm_filter != id: continue
		var chip: Button = page._button(chips, "%s %d" % [entry[1], count], func() -> void:
			page.mm_filter = id; fill(page); page._redraw())
		chip.theme_type_variation = "Chip"; chip.toggle_mode = true
		chip.set_pressed_no_signal(page.mm_filter == id)
		chip.custom_minimum_size = Vector2(0, fs * 1.6)
		chip.add_theme_font_size_override("font_size", fs - 4)


## A section title with All on / All off for the rows it shows.
static func _heading(page, body: VBoxContainer, text: String, detail: String, rows: Array) -> void:
	var fs: int = page.font_size
	var space := Control.new(); space.custom_minimum_size.y = fs * 0.5; body.add_child(space)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); body.add_child(line)
	var title := STYLE.label(text, "Heading", fs + 4); title.size_flags_vertical = Control.SIZE_SHRINK_END; line.add_child(title)
	var sub := STYLE.label(detail, "Faint", maxi(12, fs - 5)); sub.size_flags_vertical = Control.SIZE_SHRINK_END
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(sub)
	var switchable := rows.filter(func(f: Dictionary) -> bool: return f.switchable and not LOADER.is_scenario_row(f.row))
	if switchable.is_empty(): return
	for pair: Array in [["All on", true], ["All off", false]]:
		var b: Button = page._button(line, str(pair[0]), func() -> void: _switch_many(page, switchable, bool(pair[1])))
		b.theme_type_variation = "Ghost"; b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(0, fs * 1.6); b.add_theme_font_size_override("font_size", fs - 4)


## Scenario mods are left out: only one may run, and each has its own rules.
static func _switch_many(page, rows: Array, on: bool) -> void:
	var changed := 0
	for f: Dictionary in rows:
		if LOADER.switched_on(str(f.file)) == on: continue
		Mods.switch(str(f.file), on); changed += 1
	Settings.message = ("Switched %d %s %s." % [changed, "mod" if changed == 1 else "mods", "on" if on else "off"]) if changed > 0 else "Nothing to change."
	fill(page); page.refresh(); page._redraw()


static func _switch(page, f: Dictionary, on: bool) -> void:
	var file := str(f.file)
	if LOADER.switched_on(file) == on: return
	Mods.switch(file, on)
	var note: String = page._one_scenario_switch(f.row, on) if on else ""
	var applied := true
	for row: Dictionary in LOADER.pack_rows():
		if row.file == file: applied = bool(row.enabled) == on
	if not note.is_empty(): Settings.message = note
	else: Settings.message = ("%s switched %s." % [f.name, "on" if on else "off"]) if applied else "Restart the game to apply mod changes."
	fill(page); page.refresh(); page._redraw()


## One pack: a chevron, its name, version and author with badges, a one-line description, a
## Settings button when it has its own page, and an Off | On switch; details when opened.
static func _row(page, body: VBoxContainer, f: Dictionary) -> void:
	var fs: int = page.font_size
	var file := str(f.file)
	var opened := bool(page.mm_open.get(file, false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", page._row_hover if opened else page._row_idle)
	body.add_child(card)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 6); card.add_child(stack)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); stack.add_child(line)
	var chevron: Button = page._button(line, "▾" if opened else "▸", func() -> void:
		page.mm_open[file] = not opened; fill(page); page._redraw())
	chevron.theme_type_variation = "Ghost"; chevron.custom_minimum_size = Vector2(fs * 1.7, fs * 1.7)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER; chevron.tooltip_text = "Hide details" if opened else "Show details"
	var texts := VBoxContainer.new(); texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(texts)
	var title := RichTextLabel.new(); title.bbcode_enabled = true; title.fit_content = true; title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("normal_font_size", fs - 2); title.add_theme_font_size_override("bold_font_size", fs - 2)
	var meta := PackedStringArray()
	if not str(f.version).is_empty(): meta.append(str(f.version))
	if not str(f.author).is_empty(): meta.append(str(f.author))
	title.text = "[b]%s[/b]  [color=#%s]%s[/color]" % [_bb(str(f.name)), STYLE.MUTED.to_html(false), _bb(" · ".join(meta))]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE; texts.add_child(title)
	var badges := HFlowContainer.new(); badges.add_theme_constant_override("h_separation", 6)
	for b: Array in _badges(f): _badge(page, badges, str(b[0]), b[1])
	if badges.get_child_count() > 0: texts.add_child(badges)
	if not opened and not str(f.description).is_empty():
		var desc := STYLE.label(str(f.description).get_slice("\n", 0), "Faint", maxi(12, fs - 5))
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; desc.clip_text = true
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; texts.add_child(desc)
	if f.settings != null and is_instance_valid(f.settings):
		var tab: Button = f.settings
		var go: Button = page._button(line, "Settings", func() -> void:
			if is_instance_valid(tab): tab.pressed.emit())
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER; go.custom_minimum_size = Vector2(0, fs * 1.6)
		go.add_theme_font_size_override("font_size", fs - 4)
	if f.switchable: _switch_pills(page, line, f)
	if opened: _details(page, stack, f)


static func _badges(f: Dictionary) -> Array:
	var out: Array = []
	var row: Dictionary = f.row
	if bool(row.bundled): out.append(["Included", STYLE.LILAC])
	if f.restart: out.append(["Restart needed", STYLE.BUTTER])
	if f.problem: out.append(["Problem", STYLE.CORAL])
	if f.old: out.append(["Made for game %s" % str(row.game_version), STYLE.PEACH])
	if not (row.get("scenario", {}) as Dictionary).is_empty(): out.append(["Scenario", STYLE.PERIWINKLE])
	if not (row.get("patched_by", []) as Array).is_empty(): out.append(["Includes patch", STYLE.SKY])
	match str(row.get("update", "")):
		"manifest", "author": out.append(["Updated to %s" % str(row.version), STYLE.MINT])
	if not str(row.get("caution", "")).is_empty(): out.append(["Caution", STYLE.PEACH])
	if not (row.overrides as PackedStringArray).is_empty(): out.append(["Replaces %d game %s" % [(row.overrides as PackedStringArray).size(), "file" if (row.overrides as PackedStringArray).size() == 1 else "files"], STYLE.FAINT])
	return out


static func _badge(page, parent: Control, text: String, color: Color) -> void:
	var fs: int = page.font_size
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(color, 0.14), Color(color, 0.45), 1, 99, 8, 1)))
	var label := Label.new(); label.text = text
	label.add_theme_font_size_override("font_size", maxi(11, fs - 8)); label.add_theme_color_override("font_color", color)
	chip.add_child(label); parent.add_child(chip)


## Off | On in the page's own segment track (the look of settings_page.gd _segments()).
static func _switch_pills(page, line: HBoxContainer, f: Dictionary) -> void:
	var fs: int = page.font_size
	var track := PanelContainer.new(); track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(0.05, 0.02, 0.09, 0.4), Color(1, 1, 1, 0.1), 1, 99, 4, 4)))
	line.add_child(track)
	var pills := HBoxContainer.new(); pills.add_theme_constant_override("separation", 4); track.add_child(pills)
	for pair: Array in [["Off", false], ["On", true]]:
		var pill: Button = page._button(pills, str(pair[0]), func() -> void: _switch(page, f, bool(pair[1])))
		pill.theme_type_variation = "Segment"; pill.toggle_mode = true
		pill.set_pressed_no_signal(bool(f.on) == bool(pair[1]))
		pill.custom_minimum_size = Vector2(fs * 2.6, fs * 1.6)
		pill.add_theme_font_size_override("font_size", fs - 4)
		pill.tooltip_text = "%s %s" % [f.name, str(pair[0]).to_lower()]


## Full description, the game's notes for the pack (the file list folded away), its file name.
static func _details(page, stack: VBoxContainer, f: Dictionary) -> void:
	var fs: int = page.font_size
	var file := str(f.file)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); stack.add_child(box)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", int(fs * 2.1))
	stack.remove_child(box); margin.add_child(box); stack.add_child(margin)
	if not str(f.description).is_empty():
		var desc := STYLE.label(str(f.description), "", fs - 3); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(desc)
	var notes := PackedStringArray()
	for note: String in str(page._mod_notes(f.row)).split("\n", false):
		if not note.begins_with("Replaces game files:"): notes.append(note)
	if not notes.is_empty():
		var muted := STYLE.label("\n".join(notes), "Muted", fs - 4); muted.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		muted.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(muted)
	var overrides: PackedStringArray = f.row.overrides
	if not overrides.is_empty():
		var key := file + "|files"
		var listing := bool(page.mm_open.get(key, false))
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); box.add_child(line)
		var count := STYLE.label("Replaces %d game %s." % [overrides.size(), "file" if overrides.size() == 1 else "files"], "Muted", fs - 4)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER; line.add_child(count)
		var toggle: Button = page._button(line, "Hide list" if listing else "Show list", func() -> void:
			page.mm_open[key] = not listing; fill(page); page._redraw())
		toggle.theme_type_variation = "Ghost"; toggle.custom_minimum_size = Vector2(0, fs * 1.5)
		toggle.add_theme_font_size_override("font_size", fs - 4)
		if listing:
			var paths := overrides.slice(0, MOST_FILES)
			var text := "\n".join(paths) + ("\n…and %d more" % (overrides.size() - MOST_FILES) if overrides.size() > MOST_FILES else "")
			var files := STYLE.label(text, "Faint", maxi(11, fs - 6)); files.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			files.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(files)
	box.add_child(STYLE.label("File: " + file.get_file(), "Faint", maxi(11, fs - 6)))


static func _card(page, body: VBoxContainer, text: String, color: Color) -> void:
	var fs: int = page.font_size
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(color, 0.08), Color(color, 0.3), 1, 14, 14, 10)))
	body.add_child(card)
	var label := STYLE.label(text, "", fs - 3); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_child(label)


static func _faint(page, body: VBoxContainer, text: String) -> void:
	body.add_child(STYLE.label(text, "Faint", maxi(12, int(page.font_size) - 4)))


static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")
