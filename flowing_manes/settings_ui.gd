extends RefCounted
## Settings > More > "Flowing Manes": the mod's own page in the settings sidebar, just under
## Updates, built with the settings page's own pieces (tab button, row cards, pill segments,
## sliders, notes) so it looks like the game's. Every change applies at once and is saved per
## player (main.gd set_setting).
## The game's tabs are a fixed list, so the page lives inside the Updates tab's list: showing it
## shows the Updates tab with only these rows visible and the title changed. Stick/VR focus then
## walks these rows like any tab's. The page's internals are read with get()/has_method(); if a
## game update changes them the page is simply not added and the mod keeps its saved settings.

const STYLE := preload("res://world/ui/menu_style.gd")
const ICON := preload("res://world/ui/menu_icon.gd")
const HOST_TAB := "Updates"
const TITLE := "Flowing Manes"
const PRESETS := [["subtle", "Subtle"], ["show", "Show-like"], ["dramatic", "Dramatic"]]
const ON_OFF := [[false, "Off"], [true, "On"]]
## key, label, caption, min, max, step (shown as percent)
const SLIDERS := [
	["motion", "Wave size", "How far the manes and tails swing", 0.0, 2.0, 0.05],
	["speed", "Wave speed", "", 0.5, 1.5, 0.05],
	["sparkle", "Sparkles and stars", "Celestia's sparkles, Luna's drifting stars", 0.0, 2.0, 0.05],
	["glow", "Luna's glowing edge", "The see-through lavender rim", 0.0, 1.5, 0.05],
]

var host: Node
## page -> {root, button, showing, pills: {key: HBoxContainer}, sliders: {key: [HSlider, Label]}}
var _built: Dictionary = {}


func _init(owner: Node) -> void:
	host = owner


## Mods.on_node: a settings page appeared. It is often set up after it enters the tree, so the
## page is added once its sidebar and tab lists exist (and again if the page rebuilds them).
func attach(page: Node) -> void:
	if not page is Control: return
	var patch := _patch.bind(page)
	if not (page as Control).visibility_changed.is_connected(patch): (page as Control).visibility_changed.connect(patch)
	if not (page as Control).resized.is_connected(patch): (page as Control).resized.connect(patch)
	page.tree_exiting.connect(func() -> void: _built.erase(page), CONNECT_ONE_SHOT)
	patch.call_deferred()


func detach_all() -> void:
	for page: Variant in _built.keys():
		if is_instance_valid(page) and bool(_built[page].get("showing")): _leave(page)
		var row: Dictionary = _built[page]
		for key: String in ["root", "button"]:
			if is_instance_valid(row.get(key)): (row[key] as Node).queue_free()
		if is_instance_valid(page):
			var order: Variant = page.get("_tab_order")
			if order is Array and row.get("button") in order: (order as Array).erase(row.button)
	_built.clear()


func _host_index(page: Node) -> int:
	if not is_instance_valid(page) or not page.has_method("_tab_index") or not page.has_method("_show_tab"): return -1
	if page.get("_lists") == null or page.get("_tabs") == null or page.get("_tab_title") == null: return -1
	var index: int = page.call("_tab_index", HOST_TAB)
	var lists: Array = page.get("_lists"); var tabs: Array = page.get("_tabs")
	if index < 0 or index >= lists.size() or index >= tabs.size() or not tabs[index] is Button: return -1
	return index


func _patch(page: Node) -> void:
	var index := _host_index(page)
	if index < 0: return
	if not (page.has_method("_button") and page.get("_row_idle") != null and page.get("font_size") != null): return
	var list: VBoxContainer = (page.get("_lists") as Array)[index]
	var row: Dictionary = _built.get(page, {})
	# A relayout empties the tab lists: the rows are built again, the sidebar button stays.
	if is_instance_valid(row.get("root")) and (row.root as Node).get_parent() == list: return
	var showing := bool(row.get("showing", false))
	var built := _build(page, list)
	built.button = row.get("button") if is_instance_valid(row.get("button")) else _add_button(page, index)
	built.showing = false
	_built[page] = built
	(built.root as Control).visible = false
	if showing: _enter(page)
	_refresh(page)
	_redraw(page)


## The sidebar button, right under Updates.
func _add_button(page: Node, index: int) -> Button:
	var updates: Button = (page.get("_tabs") as Array)[index]
	var side := updates.get_parent()
	var button: Button = page.call("_button", side, TITLE, _enter.bind(page))
	button.theme_type_variation = updates.theme_type_variation; button.toggle_mode = true
	button.alignment = updates.alignment; button.clip_text = true
	button.custom_minimum_size = updates.custom_minimum_size
	button.add_theme_font_size_override("font_size", int(page.get("font_size")) - 2)
	if page.has_method("_icon_texture"): button.icon = page.call("_icon_texture", "sparkle")
	button.expand_icon = false
	button.set_meta("icon_kind", "sparkle"); button.set_meta("no_sparkle", true)
	side.move_child(button, updates.get_index() + 1)
	var order: Variant = page.get("_tab_order")
	if order is Array:
		var at := (order as Array).find(updates)
		(order as Array).insert(at + 1 if at >= 0 else (order as Array).size(), button)
	# Any of the game's tabs leaves this page.
	for tab: Variant in page.get("_tabs"):
		if tab is Button: (tab as Button).pressed.connect(func() -> void: if bool(_built.get(page, {}).get("showing")): _leave(page))
	return button


## Shows the page: the Updates tab, with only these rows and its own title and lit button.
func _enter(page: Node) -> void:
	var row: Dictionary = _built.get(page, {})
	var index := _host_index(page)
	if row.is_empty() or index < 0: return
	page.call("_show_tab", index)
	var list: VBoxContainer = (page.get("_lists") as Array)[index]
	for child: Node in list.get_children():
		if child == row.root or not child is CanvasItem: continue
		if (child as CanvasItem).visible: child.set_meta("fm_hid", true); (child as CanvasItem).visible = false
	(row.root as Control).visible = true
	row.showing = true
	((page.get("_tabs") as Array)[index] as Button).set_pressed_no_signal(false)
	(row.button as Button).set_pressed_no_signal(true)
	(page.get("_tab_title") as Label).text = TITLE
	var icon: Variant = page.get("_tab_icon")
	if icon != null: icon.set("kind", "sparkle")
	_refresh(page)
	_redraw(page)


## Back to the game's own tabs: the Updates rows return, these hide.
func _leave(page: Node) -> void:
	var row: Dictionary = _built.get(page, {})
	if row.is_empty(): return
	row.showing = false
	if is_instance_valid(row.get("button")): (row.button as Button).set_pressed_no_signal(false)
	if not is_instance_valid(row.get("root")): return
	(row.root as Control).visible = false
	for child: Node in (row.root as Node).get_parent().get_children():
		if child.has_meta("fm_hid"): child.remove_meta("fm_hid"); (child as CanvasItem).visible = true
	_redraw(page)


func _build(page: Node, list: VBoxContainer) -> Dictionary:
	var fs: int = page.get("font_size")
	var root := VBoxContainer.new()
	root.name = "FlowingManesSettings"
	root.add_theme_constant_override("separation", 6)
	list.add_child(root)
	var built := {"root": root, "pills": {}, "sliders": {}}
	_pills(page, root, built, "celestia", "Princess Celestia", "Flowing mane and tail, twinkling sparkles", ON_OFF)
	_pills(page, root, built, "luna", "Princess Luna", "Flowing mane and tail, drifting stars, glowing edge", ON_OFF)
	_pills(page, root, built, "emotions", "React to emotions", "Hair moves with how they feel", ON_OFF)
	_pills(page, root, built, "celestia_colour", "Celestia's mood colours", "Brighter when happy, duller when sad, Daybreaker flame when angry", ON_OFF)
	_pills(page, root, built, "daybreaker", "Daybreaker flame", "Celestia's mane catches fire when she's angry, even with emotions or her mood colours off", ON_OFF)
	_pills(page, root, built, "luna_colour", "Luna's mood colours", "Brighter when happy, duller when sad, Nightmare Moon night when angry", ON_OFF)
	_pills(page, root, built, "preset", "Look", "How strongly the hair flows", PRESETS)
	for slider: Array in SLIDERS: _slider(page, root, built, slider)
	var reset: Button = page.call("_button", root, "Reset Flowing Manes to defaults", _reset.bind(page))
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.icon = ICON.texture("sparkle", fs)
	if page.has_method("_note"): page.call("_note", root, "Changes show at once. Saved for you on this computer, for every world.")
	return built


## A row card like the game's: name (and a faint caption) on the left, the control on the right.
func _card(page: Node, parent: Control, title: String, caption: String) -> HBoxContainer:
	var fs: int = page.get("font_size")
	var idle: StyleBox = page.get("_row_idle")
	var hover: StyleBox = page.get("_row_hover")
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", idle)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", hover if hover != null else idle); _redraw(page))
	card.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", idle); _redraw(page))
	parent.add_child(card)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 12); card.add_child(line)
	var texts := VBoxContainer.new(); texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER; texts.add_theme_constant_override("separation", 1); line.add_child(texts)
	var name_label := STYLE.label(title, "", fs); name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; texts.add_child(name_label)
	if not caption.is_empty(): texts.add_child(STYLE.label(caption, "Faint", fs - 5))
	return line


func _pills(page: Node, parent: Control, built: Dictionary, key: String, title: String, caption: String, options: Array) -> void:
	var fs: int = page.get("font_size")
	var line := _card(page, parent, title, caption)
	var track := PanelContainer.new(); track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", STYLE.rounded(STYLE.box(Color(0.05, 0.02, 0.09, 0.4), Color(1, 1, 1, 0.1), 1, 99, 4, 4)))
	line.add_child(track)
	var pills := HBoxContainer.new(); pills.add_theme_constant_override("separation", 4); track.add_child(pills)
	for option: Array in options:
		var pill: Button = page.call("_button", pills, str(option[1]), _choose.bind(page, key, option[0]))
		pill.theme_type_variation = "Segment"; pill.toggle_mode = true
		pill.custom_minimum_size = Vector2(0, fs * 1.75)
		pill.add_theme_font_size_override("font_size", fs - 3)
		pill.set_meta("value", option[0])
	built.pills[key] = pills


func _slider(page: Node, parent: Control, built: Dictionary, spec: Array) -> void:
	var fs: int = page.get("font_size")
	var key := str(spec[0])
	var line := _card(page, parent, str(spec[1]), str(spec[2]))
	var box := HBoxContainer.new(); box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER; line.add_child(box)
	var slider := HSlider.new(); slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.scrollable = false; slider.focus_mode = Control.FOCUS_ALL
	slider.min_value = float(spec[3]); slider.max_value = float(spec[4]); slider.step = float(spec[5])
	var room: float = float(page.get("_room")) if page.get("_room") != null else fs * 14.0
	var value := Label.new(); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", STYLE.BOLD); value.add_theme_font_size_override("font_size", fs - 1)
	var widest := STYLE.BOLD.get_string_size("200%", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1).x
	value.custom_minimum_size.x = widest + 4.0
	slider.custom_minimum_size = Vector2(clampf(room - widest - 14.0, fs * 7.0, fs * 14.0), fs * 1.6)
	slider.value_changed.connect(func(at: float) -> void:
		value.text = "%d%%" % roundi(at * 100.0)
		host.set_setting(key, snappedf(at, 0.01)))
	slider.mouse_entered.connect(_redraw.bind(page)); slider.mouse_exited.connect(_redraw.bind(page))
	slider.focus_entered.connect(_redraw.bind(page))
	box.add_child(slider); box.add_child(value)
	built.sliders[key] = [slider, value]


func _choose(page: Node, key: String, value: Variant) -> void:
	host.set_setting(key, value)
	_refresh(page)
	_redraw(page)


func _reset(page: Node) -> void:
	var defaults: Dictionary = host.call("defaults")
	for key: String in defaults: host.set_setting(key, defaults[key])
	_refresh(page)
	_redraw(page)


## Shows the saved values: the lit pill, each slider's position and percent; Luna's glow row
## greys out while Luna is off.
func _refresh(page: Node) -> void:
	var built: Dictionary = _built.get(page, {})
	if built.is_empty(): return
	for key: String in built.pills:
		for pill: Node in (built.pills[key] as Node).get_children():
			(pill as Button).set_pressed_no_signal(pill.get_meta("value") == host.config.get(key))
	for key: String in built.sliders:
		var pair: Array = built.sliders[key]
		(pair[0] as HSlider).set_value_no_signal(float(host.config.get(key, 1.0)))
		(pair[1] as Label).text = "%d%%" % roundi(float(host.config.get(key, 1.0)) * 100.0)
	var glow: Array = built.sliders.get("glow", [])
	if not glow.is_empty():
		var card := (glow[0] as Node).get_parent().get_parent().get_parent() as Control
		if card != null: card.modulate.a = 1.0 if bool(host.config.get("luna", true)) else 0.45
	var day: Node = built.pills.get("daybreaker")
	if day != null:
		var day_row := day.get_parent().get_parent().get_parent() as Control
		if day_row != null: day_row.modulate.a = 1.0 if bool(host.config.get("celestia", true)) else 0.45
	# A princess's colour row greys out while she is off or emotions are off.
	for id: String in ["celestia", "luna"]:
		var pills: Node = built.pills.get(id + "_colour")
		if pills == null: continue
		var row := pills.get_parent().get_parent().get_parent() as Control
		var live := bool(host.config.get(id, true)) and bool(host.config.get("emotions", true))
		if row != null: row.modulate.a = 1.0 if live else 0.45


func _redraw(page: Node) -> void:
	if is_instance_valid(page) and page.has_method("_redraw"): page.call("_redraw")
