extends RefCounted
## Settings → Mods, Browse online: the listings at mods.pones.top (read-only GET of /api/mods, as
## its AGENTS.md describes), newest first, with newer versions of mods you have at the top.
## content_filter.gd's hard block (sexual content involving fillies, foals, colts or any young
## character) has no setting: it is applied before a listing is kept, again before it is drawn and
## again before any download. Other adult listings follow the "Adult listings" switch (hidden by
## default, saved in the mod's data folder). Listings the site's security check red-flagged are
## dropped too. Fetched when
## the tab opens (at most every CACHE_SECONDS) or on Refresh, never polled. Install downloads a
## .pck over HTTPS into the mods folder after a second press, checks it is a Godot pack, and the
## game loads it at the next start. Anything else (a .zip, no download) opens the listing's page.

const STYLE := preload("res://world/ui/menu_style.gd")
const LOADER := preload("res://world/modding/mod_loader.gd")
const FILTER := preload("res://mods/modchads_mod_menu/menu/content_filter.gd")
const INDEX := "https://mods.pones.top"
const AGENT := "modChads-Mod-Menu/1.0.0 (Home: Equestria)"
const CACHE_SECONDS := 600.0
const PAGE_SIZE := 30
const MOST_BYTES := 400 * 1024 * 1024
const ARM_SECONDS := 5.0
const MODES := [["newest", "Newest"], ["mine", "Updates for my mods"], ["new", "Not installed"], ["checked", "Security check passed"], ["rated", "Highest rated"]]
const REVIEW := {"no_findings": ["Security check: no findings", "mint"], "findings": ["Security check: findings", "peach"],
	"incomplete": ["Security check: incomplete", "butter"], "not_reviewed": ["Not checked yet", "faint"],
	"stale": ["Security check: out of date", "butter"], "mixed": ["Security check: downloads differ", "peach"]}

## Kept between visits to the tab (blocked listings are never stored).
static var cache: Array = []
static var cache_at := -1.0
static var hidden_filter := 0
static var hidden_flag := 0
## Adult listings hidden in the last fill (the hard block's count is hidden_filter).
static var hidden_nsfw := 0
## The player's "Adult listings" choice. It never reaches the hard block.
static var show_nsfw := false
static var _settings_read := false
const SETTINGS_ID := "modchads_mod_menu"
static var last_error := ""
## listing id -> "Downloading…", "Installed: restart to load", "Failed: …"
static var installing: Dictionary = {}

var page
var list: VBoxContainer
var body: VBoxContainer
var chips: HFlowContainer
var query := ""
var mode := "newest"
var shown := PAGE_SIZE
var loading := false
var _armed: Dictionary = {}   # listing id -> ticks msec of the first Install press


func _init(settings_page, tab_list: VBoxContainer) -> void:
	page = settings_page; list = tab_list
	_read_settings()
	var fs: int = page.font_size
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 8); list.add_child(bar)
	var field := LineEdit.new(); field.placeholder_text = "Search mods.pones.top…"; field.clear_button_enabled = true
	field.max_length = 80; field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", fs - 1); field.focus_entered.connect(page._redraw); bar.add_child(field)
	field.text_changed.connect(func(text: String) -> void: query = text; shown = PAGE_SIZE; fill())
	var refresh: Button = page._button(bar, "Refresh", func() -> void: fetch())
	refresh.add_theme_font_size_override("font_size", fs - 3)
	chips = HFlowContainer.new(); chips.add_theme_constant_override("h_separation", 6); chips.add_theme_constant_override("v_separation", 6)
	list.add_child(chips)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_child(body)
	if cache_at < 0.0 or _now() - cache_at > CACHE_SECONDS: fetch()
	else: fill()


static func _settings_path() -> String:
	return Mods.data_folder(SETTINGS_ID).path_join("settings.cfg")


static func _read_settings() -> void:
	if _settings_read: return
	_settings_read = true
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path()) == OK: show_nsfw = cfg.get_value("browse", "show_nsfw", false) == true


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_settings_path())
	cfg.set_value("browse", "show_nsfw", show_nsfw)
	DirAccess.make_dir_recursive_absolute(_settings_path().get_base_dir())
	cfg.save(_settings_path())


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _alive() -> bool:
	return is_instance_valid(body) and body.is_inside_tree()


func fetch() -> void:
	if loading or not _alive(): return
	loading = true; last_error = ""
	fill()
	var http := HTTPRequest.new(); http.timeout = 20.0; http.body_size_limit = 16 * 1024 * 1024
	page.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
		http.queue_free(); _on_index(result, code, bytes))
	var err := http.request(INDEX + "/api/mods", ["Accept: application/json", "User-Agent: " + AGENT])
	if err != OK:
		http.queue_free(); _failed("Could not start the request (error %d)." % err)


func _failed(why: String) -> void:
	loading = false; last_error = why
	if _alive(): fill()


func _on_index(result: int, code: int, bytes: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS: _failed("Could not reach mods.pones.top (%s)." % _result_text(result)); return
	if code == 429: _failed("mods.pones.top asked to wait a little. Try Refresh again later."); return
	if code != 200: _failed("mods.pones.top answered %d." % code); return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Array: _failed("mods.pones.top sent something this menu does not understand."); return
	var kept: Array = []
	hidden_filter = 0; hidden_flag = 0
	for item: Variant in data:
		if FILTER.hard_blocked(item): hidden_filter += 1; continue
		var review: Variant = (item as Dictionary).get("security_review", {})
		if review is Dictionary and str((review as Dictionary).get("state", "")) == "red_flag": hidden_flag += 1; continue
		kept.append(item)
	cache = kept; cache_at = _now(); loading = false
	if _alive(): fill()


static func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE: return "no internet or the address can't be found"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR: return "could not connect"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "secure connection failed"
		HTTPRequest.RESULT_TIMEOUT: return "timed out"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "the file is too big"
	return "error %d" % result


## Name keys of every installed mod -> its version (mods that are off count too).
static func _installed() -> Dictionary:
	var out := {}
	for row: Dictionary in LOADER.pack_rows():
		out[_key(str(row.title))] = str(row.version)
		var declared: Dictionary = row.get("declared", {}) if row.get("declared") is Dictionary else {}
		for id: Variant in declared:
			var info: Variant = declared[id]
			if info is Dictionary: out[_key(str((info as Dictionary).get("name", "")))] = str((info as Dictionary).get("version", ""))
	for mod: Dictionary in LOADER.mods: out[_key(str(mod.name))] = str(mod.version)
	out.erase("")
	return out


static func _key(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"): out += c
	return out


## "new", "newer" (you have an older one) or "have"; with the version you have.
static func _status(item: Dictionary, installed: Dictionary) -> Array:
	var names: Array = [str(item.get("name", ""))]
	var aliases: Variant = item.get("search_aliases", [])
	if aliases is Array: names.append_array(aliases)
	for n: Variant in names:
		var k := _key(str(n))
		if installed.has(k):
			var mine := str(installed[k])
			return ["newer" if LOADER.version_older(mine, str(item.get("version", ""))) else "have", mine]
	return ["new", ""]


func fill() -> void:
	if not _alive(): return
	for child in body.get_children():
		body.remove_child(child); child.queue_free()
	var fs: int = page.font_size
	_fill_chips()
	if loading:
		page._note(body, "Loading the listings from mods.pones.top…")
		page._redraw(); return
	if not last_error.is_empty():
		page._note(body, last_error)
		var retry: Button = page._button(body, "Try again", func() -> void: fetch())
		retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_footer(); page._redraw(); return
	page._note(body, "Listings from mods.pones.top, posted by players. Install downloads the mod's .pck into your mods folder after a second press; it loads the next time the game starts.")
	var installed := _installed()
	var q := query.strip_edges().to_lower()
	var newer: Array = []; var rest: Array = []
	hidden_nsfw = 0
	for item: Dictionary in cache:
		# The hard block again, whatever is in the cache; then the player's adult-listings choice.
		if FILTER.hard_blocked(item): continue
		if FILTER.is_nsfw(item) and not show_nsfw:
			hidden_nsfw += 1; continue
		if not q.is_empty():
			var text := " ".join(PackedStringArray([str(item.get("name", "")), str(item.get("short_description", "")), str(item.get("author", "")), str(item.get("search_aliases", ""))])).to_lower()
			var ok := true
			for word in q.split(" ", false):
				if not text.contains(word): ok = false; break
			if not ok: continue
		var status := _status(item, installed)
		if mode == "mine" and status[0] != "newer": continue
		if mode == "new" and status[0] != "new": continue
		if mode == "checked":
			var review: Variant = item.get("security_review", {})
			if not (review is Dictionary and str((review as Dictionary).get("state", "")) == "no_findings"): continue
		if status[0] == "newer" and mode != "rated": newer.append([item, status])
		else: rest.append([item, status])
	if mode == "rated":
		rest.sort_custom(func(a: Array, b: Array) -> bool: return float((a[0] as Dictionary).get("rating", 0)) > float((b[0] as Dictionary).get("rating", 0)))
	if not newer.is_empty():
		_heading("Newer versions of your mods", "%d found" % newer.size())
		for pair: Array in newer: _listing(pair[0], pair[1])
	if mode != "mine":
		_heading("Highest rated" if mode == "rated" else "Listings", "%d" % rest.size())
		if rest.is_empty(): body.add_child(STYLE.label("None match.", "Faint", maxi(12, fs - 4)))
		for i in mini(shown, rest.size()): _listing(rest[i][0], rest[i][1])
		if rest.size() > shown:
			var more: Button = page._button(body, "Show more (%d left)" % (rest.size() - shown), func() -> void: shown += PAGE_SIZE; fill())
			more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif newer.is_empty():
		body.add_child(STYLE.label("Every mod you have that is listed there is up to date.", "Faint", maxi(12, fs - 4)))
	_footer()
	page._redraw()


func _fill_chips() -> void:
	for child in chips.get_children():
		chips.remove_child(child); child.queue_free()
	var fs: int = page.font_size
	for entry: Array in MODES:
		var id := str(entry[0])
		var chip: Button = page._button(chips, str(entry[1]), func() -> void: mode = id; shown = PAGE_SIZE; fill())
		chip.theme_type_variation = "Chip"; chip.toggle_mode = true; chip.set_pressed_no_signal(mode == id)
		chip.custom_minimum_size = Vector2(0, fs * 1.6); chip.add_theme_font_size_override("font_size", fs - 4)


func _heading(text: String, detail: String) -> void:
	var fs: int = page.font_size
	var space := Control.new(); space.custom_minimum_size.y = fs * 0.5; body.add_child(space)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); body.add_child(line)
	var title := STYLE.label(text, "Heading", fs + 4); title.size_flags_vertical = Control.SIZE_SHRINK_END; line.add_child(title)
	var sub := STYLE.label(detail, "Faint", maxi(12, fs - 5)); sub.size_flags_vertical = Control.SIZE_SHRINK_END; line.add_child(sub)


## The first download that is a .pck over HTTPS, or {}.
static func _pck(item: Dictionary) -> Dictionary:
	var downloads: Variant = item.get("downloads", [])
	if downloads is Array:
		for d: Variant in downloads:
			if not d is Dictionary: continue
			var name := str((d as Dictionary).get("filename", "")).get_file()
			var url := str((d as Dictionary).get("url", ""))
			if name.to_lower().ends_with(".pck") and url.begins_with("https://"): return {"filename": name, "url": url}
	return {}


func _listing(item: Dictionary, status: Array) -> void:
	var fs: int = page.font_size
	var id := str(item.get("id", ""))
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", page._row_idle); body.add_child(card)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); card.add_child(line)
	var texts := VBoxContainer.new(); texts.add_theme_constant_override("separation", 3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(texts)
	var title := RichTextLabel.new(); title.bbcode_enabled = true; title.fit_content = true; title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("normal_font_size", fs - 2); title.add_theme_font_size_override("bold_font_size", fs - 2)
	var meta := PackedStringArray()
	if not str(item.get("version", "")).is_empty(): meta.append(str(item.get("version", "")))
	if not str(item.get("author", "")).is_empty(): meta.append(str(item.get("author", "")))
	title.text = "[b]%s[/b]  [color=#%s]%s[/color]" % [_bb(str(item.get("name", ""))), STYLE.MUTED.to_html(false), _bb(" · ".join(meta))]
	texts.add_child(title)
	var short := str(item.get("short_description", "")).strip_edges()
	if short.length() > 220: short = short.substr(0, 217) + "…"
	if not short.is_empty():
		var desc := STYLE.label(short, "Muted", fs - 4); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; texts.add_child(desc)
	var badges := HFlowContainer.new(); badges.add_theme_constant_override("h_separation", 6); texts.add_child(badges)
	var review: Variant = item.get("security_review", {})
	var state := str((review as Dictionary).get("state", "not_reviewed")) if review is Dictionary else "not_reviewed"
	var r: Array = REVIEW.get(state, ["Security check: %s" % state, "faint"])
	_badge(badges, str(r[0]), _colour(str(r[1])))
	if str(item.get("approval", "")) == "current": _badge(badges, "Approved", STYLE.MINT)
	match str(status[0]):
		"have": _badge(badges, "Installed (%s)" % status[1] if not str(status[1]).is_empty() else "Installed", STYLE.SKY)
		"newer": _badge(badges, "You have %s" % status[1], STYLE.MINT)
	var made_for := str(item.get("game_version", ""))
	if not made_for.is_empty() and made_for != LOADER.game_version(): _badge(badges, "Made for game %s" % made_for, STYLE.FAINT)
	var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 6); side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(side)
	var progress := str(installing.get(id, ""))
	var pck := _pck(item)
	if not progress.is_empty():
		var note := STYLE.label(progress, "Muted", fs - 4); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = fs * 7; side.add_child(note)
	elif not pck.is_empty() and status[0] != "have":
		var armed := _now() - float(_armed.get(id, -100.0)) < ARM_SECONDS
		var caption := ("Press again" if armed else ("Update" if status[0] == "newer" else "Install"))
		var install: Button = page._button(side, caption, func() -> void: _press_install(item, pck))
		if status[0] == "newer" or armed: install.theme_type_variation = "Primary"
		install.add_theme_font_size_override("font_size", fs - 3)
	var open: Button = page._button(side, "Open page", func() -> void: _open_page(id))
	open.theme_type_variation = "Ghost"; open.add_theme_font_size_override("font_size", fs - 4)


func _press_install(item: Dictionary, pck: Dictionary) -> void:
	if FILTER.hard_blocked(item): return
	var id := str(item.get("id", ""))
	if _now() - float(_armed.get(id, -100.0)) >= ARM_SECONDS:
		_armed[id] = _now()
		Settings.message = "Press again to download %s from %s into your mods folder." % [str(item.get("name", "")), str(pck.url).get_slice("/", 2)]
		fill(); page.refresh()
		var tree: SceneTree = page.get_tree()
		if tree != null:
			await tree.create_timer(ARM_SECONDS + 0.1).timeout
			if _alive(): fill()
		return
	_armed.erase(id)
	_download(item, pck)


## The folder the game reads mods from: beside the game on desktop, else user://mods (the same
## choice as settings_page.gd _open_mods_folder()).
static func _mods_dir() -> String:
	if OS.has_feature("template") and not OS.has_feature("android"):
		var beside := OS.get_executable_path().get_base_dir().path_join("mods")
		if DirAccess.make_dir_recursive_absolute(beside) == OK: return beside
	var folder := ProjectSettings.globalize_path(LOADER.USER_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


func _download(item: Dictionary, pck: Dictionary) -> void:
	var id := str(item.get("id", ""))
	var name := str(pck.filename).get_file().validate_filename()
	if not name.to_lower().ends_with(".pck") or FILTER.hard_blocked(item): return
	if FILTER.is_nsfw(item) and not show_nsfw: return
	var folder := _mods_dir()
	var part := folder.path_join(name + ".part")
	var final := folder.path_join(name)
	var http := HTTPRequest.new(); http.download_file = part; http.timeout = 180.0
	http.body_size_limit = MOST_BYTES; http.max_redirects = 5
	page.add_child(http)
	installing[id] = "Downloading…"; fill()
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		http.queue_free(); _downloaded(item, part, final, result, code))
	var err := http.request(str(pck.url), ["User-Agent: " + AGENT])
	if err != OK:
		http.queue_free(); installing[id] = "Failed: could not start the download."; fill()


func _downloaded(item: Dictionary, part: String, final: String, result: int, code: int) -> void:
	var id := str(item.get("id", ""))
	var why := ""
	if result != HTTPRequest.RESULT_SUCCESS: why = _result_text(result)
	elif code != 200: why = "the server answered %d" % code
	else:
		var f := FileAccess.open(part, FileAccess.READ)
		var magic := f.get_buffer(4).get_string_from_ascii() if f != null else ""
		if f != null: f.close()
		if magic != "GDPC": why = "the file is not a Godot mod pack"
	if not why.is_empty():
		DirAccess.remove_absolute(part)
		installing[id] = "Failed: %s." % why
		Settings.message = "Could not install %s: %s." % [str(item.get("name", "")), why]
	else:
		if FileAccess.file_exists(final): DirAccess.remove_absolute(final)
		if DirAccess.rename_absolute(part, final) != OK:
			DirAccess.remove_absolute(part)
			installing[id] = "Failed: could not save it in the mods folder."
		else:
			installing[id] = "Installed: restart to load"
			Settings.message = "Installed %s (%s). Restart the game to load it." % [str(item.get("name", "")), final.get_file()]
	if _alive(): fill(); page.refresh()


func _open_page(id: String) -> void:
	var url := INDEX + "/mod/" + id.uri_encode()
	Settings.message = ("Opened " if OS.shell_open(url) == OK else "Open this page in a browser: ") + url
	page.refresh(); page._redraw()


func _footer() -> void:
	var fs: int = page.font_size
	var adult := PanelContainer.new()
	adult.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(STYLE.LILAC, 0.08), Color(STYLE.LILAC, 0.3), 1, 14, 14, 10)))
	body.add_child(adult)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); adult.add_child(line)
	var text := ("Adult listings (18+): shown." if show_nsfw else "Adult listings (18+): hidden.") + (" Hidden: %d." % hidden_nsfw if hidden_nsfw > 0 and not show_nsfw else "")
	var label := STYLE.label(text, "", fs - 4); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; line.add_child(label)
	var flip: Button = page._button(line, "Hide them" if show_nsfw else "Show them", func() -> void:
		show_nsfw = not show_nsfw; _save_settings(); shown = PAGE_SIZE; fill())
	flip.add_theme_font_size_override("font_size", fs - 4); flip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if hidden_flag > 0:
		_card("Hidden: %d %s that the site's security check red-flagged. Red-flagged listings are never offered here." % [hidden_flag, "listing" if hidden_flag == 1 else "listings"], STYLE.CORAL)
	_card("Never shown, whatever the settings: sexual content involving fillies, foals, colts or any other young character. This block has no switch and can't be installed around from this menu." + (" Hidden: %d." % hidden_filter if hidden_filter > 0 else ""), STYLE.FAINT)


func _card(text: String, color: Color) -> void:
	var fs: int = page.font_size
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(color, 0.08), Color(color, 0.3), 1, 14, 14, 10)))
	body.add_child(card)
	var label := STYLE.label(text, "", fs - 4); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_child(label)


func _badge(parent: Control, text: String, color: Color) -> void:
	var fs: int = page.font_size
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(color, 0.14), Color(color, 0.45), 1, 99, 8, 1)))
	var label := Label.new(); label.text = text
	label.add_theme_font_size_override("font_size", maxi(11, fs - 8)); label.add_theme_color_override("font_color", color)
	chip.add_child(label); parent.add_child(chip)


static func _colour(name: String) -> Color:
	match name:
		"mint": return STYLE.MINT
		"peach": return STYLE.PEACH
		"butter": return STYLE.BUTTER
		"coral": return STYLE.CORAL
	return STYLE.FAINT


static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")
