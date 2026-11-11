extends Node3D
## Fishing: the Angler's Log. A book lying on the pier beside the rod rack until you own one;
## look at it and press E to take it. Holding it, left click opens the book: a page per fish (a
## turning picture, best size, how many, the first one's day, time and water; a silhouette and
## a hint for ones not caught yet) and a page of odds and ends. A/D, the arrow keys or the mouse
## wheel turn pages; click, E or Esc closes it. VR (untested): the trigger on the hand holding
## it shows the current page floating above it and turns to the next.
const ID := "food:fishing-log"
const TABLE := preload("res://mods/fishing/catch_table.gd")
const MODEL := preload("res://mods/fishing/fish_model.gd")
const FONT := preload("res://world/ui/fonts/PonyvilleMedium.ttf")
var dock: Node3D
var inventory: Node
var state_source: Callable
var _prop: Node3D
var _prop_body: StaticBody3D
var _ui: CanvasLayer
var _page := 0
var _pic_world: SubViewport
var _pic_root: Node3D
var _pic_fish: Node3D
var _labels: Dictionary = {}
var _float_page: Label3D
var _vr_trigger: Dictionary = {}
var _locked := false

func setup(d: Node3D, inv: Node, source: Callable) -> void:
	dock = d; inventory = inv; state_source = source
	add_to_group("interaction_hint_sources")
	# On the deck by the end of the rod rack.
	global_transform = dock.global_transform * Transform3D(Basis(Vector3.UP, .35), Vector3(.45, .02, 1.6))
	_prop = (load("res://mods/fishing/models/log.scn") as PackedScene).instantiate(); add_child(_prop)
	_prop_body = StaticBody3D.new(); _prop_body.collision_layer = 1; _prop_body.collision_mask = 0
	var cs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(.2, .05, .26); cs.shape = box; cs.position.y = .02
	_prop_body.add_child(cs); add_child(_prop_body); _prop_body.set_meta("fishing_log", self)
	_float_page = Label3D.new(); _float_page.font = FONT; _float_page.font_size = 40; _float_page.pixel_size = .0009
	_float_page.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _float_page.outline_size = 10; _float_page.outline_modulate = Color("3a2616")
	_float_page.visible = false; _float_page.top_level = true; add_child(_float_page)

func _owned() -> bool:
	if not is_instance_valid(inventory): return false
	var inv: Variant = inventory.get("inventory")
	if inv == null: return false
	for slot: Variant in inv.get("slots"):
		if slot is Dictionary and str((slot as Dictionary).get("id", "")) == ID: return true
	for loan: Variant in (inv.get("loans") as Dictionary).values():
		if loan is Dictionary and str(loan.get("id", "")) == ID: return true
	return false

var _check_in := 0.0
func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = .5
		var show := not _owned()
		_prop.visible = show; _prop_body.collision_layer = 1 if show else 0
	_vr_page()
	if is_open() and held_side() != "desktop": close()

# ---------------------------------------------------------------- taking it

func _look_hit() -> Dictionary:
	if not is_instance_valid(inventory) or not _prop.visible: return {}
	var cam: Camera3D = inventory.get("camera")
	if not is_instance_valid(cam): return {}
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 2.6, 1)
	var body: Variant = inventory.get("player_body")
	if body is CollisionObject3D: q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	return hit if not hit.is_empty() and hit.collider == _prop_body else {}

func interaction_hint() -> Dictionary:
	if not is_instance_valid(inventory) or not bool(inventory.get("_desktop")): return {}
	var hit := _look_hit()
	if hit.is_empty(): return {}
	return {"target": _prop_body, "text": "[E] Take the Angler's Log" if not inventory.hand_busy("desktop") else "Angler's Log · hands full", "point": hit.position, "collider": _prop_body}

## Desktop E on the book: into your hand. Returns whether it took the key.
func desktop_take() -> bool:
	if _look_hit().is_empty() or inventory.hand_busy("desktop"): return false
	var body: RigidBody3D = inventory.spawn_owned_drop(ID, global_transform * Transform3D(Basis(), Vector3(0, .08, 0)))
	if body == null: print("[fishing] log: couldn't make the Angler's Log (briefcase full?)"); return false
	_prop.visible = false; _prop_body.collision_layer = 0; _check_in = 1.0
	if inventory.has_method("_take_pick"):
		inventory.call("_take_pick", "desktop", {"target": body, "kind": "", "pointed": true, "point": body.global_position}, inventory.camera.global_transform)
	preload("res://mods/fishing/sounds.gd").play_ui(self, "jingle", -10.0)
	return true

func held_side() -> String:
	if not is_instance_valid(inventory): return ""
	for side: String in (inventory.get("held") as Dictionary).keys():
		var item: Variant = inventory.held[side]
		if is_instance_valid(item) and str((item as Node).get_meta("item_id", "")) == ID: return side
	return ""

# ---------------------------------------------------------------- the book

func is_open() -> bool: return is_instance_valid(_ui) and _ui.visible

## Desktop input while the log is held or open (main.gd routes it here first).
func on_input(event: InputEvent) -> bool:
	if is_open():
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_A, KEY_LEFT: turn(-1); return true
				KEY_D, KEY_RIGHT: turn(1); return true
				KEY_E, KEY_ESCAPE, KEY_Q: close(); return true
				KEY_W, KEY_S: return true
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP: turn(-1)
				MOUSE_BUTTON_WHEEL_DOWN: turn(1)
				_: close()
			return true
		return false
	if held_side() == "desktop" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		open(); return true
	return false

func open() -> void:
	if not is_instance_valid(_ui): _build_ui()
	_ui.visible = true; _show_page()
	# Walking reads the keys directly, so A/D would move you while you turn pages: hold still.
	var body: Variant = inventory.get("player_body") if is_instance_valid(inventory) else null
	if is_instance_valid(body) and "controls_locked" in body and not body.controls_locked:
		body.controls_locked = true; _locked = true
	preload("res://world/audio/interaction_sounds.gd").play_at(self, "page")

func close() -> void:
	if is_instance_valid(_ui): _ui.visible = false
	_unlock()
	preload("res://world/audio/interaction_sounds.gd").play_at(self, "cover")

func _unlock() -> void:
	if not _locked: return
	_locked = false
	var body: Variant = inventory.get("player_body") if is_instance_valid(inventory) else null
	if is_instance_valid(body) and "controls_locked" in body: body.controls_locked = false

func _exit_tree() -> void:
	_unlock()

func turn(step: int) -> void:
	_page = wrapi(_page + step, 0, _pages().size()); _show_page()
	preload("res://world/audio/interaction_sounds.gd").play_at(self, "page")

func _pages() -> Array: return TABLE.fish_ids() + ["_junk"]

func _st() -> Dictionary: return state_source.call()

func _build_ui() -> void:
	_ui = CanvasLayer.new(); _ui.layer = 7; add_child(_ui)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, .35); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; _ui.add_child(dim)
	var centre := CenterContainer.new(); centre.set_anchors_preset(Control.PRESET_FULL_RECT); centre.mouse_filter = Control.MOUSE_FILTER_IGNORE; _ui.add_child(centre)
	var book := PanelContainer.new(); book.custom_minimum_size = Vector2(980, 600)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("f3e8cc"); sb.border_color = Color("2f5b5e"); sb.set_border_width_all(14)
	sb.set_corner_radius_all(18); sb.content_margin_left = 30; sb.content_margin_right = 30; sb.content_margin_top = 22; sb.content_margin_bottom = 18
	book.add_theme_stylebox_override("panel", sb); centre.add_child(book)
	var rows := VBoxContainer.new(); book.add_child(rows)
	var spread := HBoxContainer.new(); spread.size_flags_vertical = Control.SIZE_EXPAND_FILL; spread.add_theme_constant_override("separation", 28); rows.add_child(spread)
	# Left page: the picture.
	var svc := SubViewportContainer.new(); svc.custom_minimum_size = Vector2(440, 470); svc.stretch = true; spread.add_child(svc)
	_pic_world = SubViewport.new(); _pic_world.own_world_3d = true; _pic_world.transparent_bg = true; _pic_world.msaa_3d = Viewport.MSAA_4X; svc.add_child(_pic_world)
	_pic_root = Node3D.new(); _pic_world.add_child(_pic_root)
	var cam := Camera3D.new(); cam.fov = 30; cam.position = Vector3(0, .08, 1.5); _pic_world.add_child(cam); cam.look_at(Vector3.ZERO)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); _pic_world.add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, .97, .9); e.ambient_light_energy = .7; env.environment = e; _pic_world.add_child(env)
	var divider := ColorRect.new(); divider.color = Color("c9b78f"); divider.custom_minimum_size = Vector2(3, 0); spread.add_child(divider)
	# Right page: words.
	var words := VBoxContainer.new(); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; words.add_theme_constant_override("separation", 10); spread.add_child(words)
	for key in ["title", "sub", "best", "count", "first", "hint"]:
		var l := Label.new(); l.add_theme_font_override("font", FONT); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", {"title": 46, "sub": 22}.get(key, 26))
		l.add_theme_color_override("font_color", Color("4a2c18") if key != "sub" else Color("8a6a40"))
		words.add_child(l); _labels[key] = l
	var foot := Label.new(); foot.add_theme_font_override("font", FONT); foot.add_theme_font_size_override("font_size", 20)
	foot.add_theme_color_override("font_color", Color("7a6040")); foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; rows.add_child(foot); _labels["foot"] = foot

func _show_page() -> void:
	var pages := _pages(); var id: String = pages[_page]
	var st := _st()
	var counts: Dictionary = st.get("count", {}) if st.get("count") is Dictionary else {}
	var bests: Dictionary = st.get("best", {}) if st.get("best") is Dictionary else {}
	var firsts: Dictionary = st.get("first", {}) if st.get("first") is Dictionary else {}
	_labels.foot.text = "Angler's Log  ·  page %d of %d  ·  [A]/[D] or wheel to turn  ·  click to close" % [_page + 1, pages.size()]
	for k in ["title", "sub", "best", "count", "first", "hint"]: _labels[k].text = ""
	if is_instance_valid(_pic_fish): _pic_fish.queue_free()
	if id == "_junk":
		_labels.title.text = "Odds & ends"
		var junk: Dictionary = st.get("junk", {}) if st.get("junk") is Dictionary else {}
		var lines: PackedStringArray = []
		for jid: String in TABLE.junk():
			var n := int(junk.get(jid, 0))
			lines.append(("%s  ×%d" % [TABLE.name_of(jid), n]) if n > 0 else "?????")
		_labels.best.text = "\n".join(lines)
		_labels.hint.text = "Things that bit when a fish didn't."
		_pic_fish = (load("res://mods/fishing/models/hat.scn") as PackedScene).instantiate(); _pic_root.add_child(_pic_fish)
		_pic_fish.scale = Vector3.ONE * 1.6
		return
	var caught := int(counts.get(id, 0)) > 0
	var is_rare := TABLE.rare().has(id)
	var row: Dictionary = TABLE.rare()[id] if is_rare else TABLE.species()[id]
	_labels.title.text = TABLE.name_of(id) if caught or not is_rare else "???"
	_labels.sub.text = "Rare" if is_rare else ""
	if caught:
		_labels.best.text = "Best:  %d cm" % roundi(float(bests.get(id, 0.0)) * 100.0)
		_labels.count.text = "Caught:  %d" % int(counts.get(id, 0))
		var f: Dictionary = firsts.get(id, {})
		if not f.is_empty():
			var h := float(f.get("hour", 12.0))
			_labels.first.text = "First:  day %d, %02d:%02d, in the %s" % [int(f.get("day", 0)) + 1, int(h), int(fmod(h, 1.0) * 60.0), str(f.get("water", "water"))]
	else:
		_labels.best.text = "Not caught yet."
	_labels.hint.text = str(row.get("hint", ""))
	var spec: Dictionary = (MODEL as Script).get_script_constant_map().get(id.to_upper(), MODEL.TROUT)
	_pic_fish = MODEL.build(spec); _pic_root.add_child(_pic_fish)
	_pic_fish.scale = Vector3.ONE * (.75 / float(spec.length))
	if not caught:
		# A silhouette: every part flat dark ink.
		var ink := StandardMaterial3D.new(); ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; ink.albedo_color = Color("3b3026")
		for mi in _pic_fish.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = ink

func _physics_process(delta: float) -> void:
	if is_instance_valid(_pic_fish) and is_open(): _pic_fish.rotation.y += delta * .6

## VR (untested): the trigger on the hand holding the log shows the page above it and turns on.
func _vr_page() -> void:
	var side := held_side()
	if side == "" or side == "desktop":
		_float_page.visible = false; return
	var sample: Dictionary = inventory.hand_sample(side)
	var down := float(sample.get("trigger", 0.0)) > .6
	if down and not _vr_trigger.get(side, true):
		if _float_page.visible: _page = wrapi(_page + 1, 0, _pages().size())
		_float_page.visible = true
	_vr_trigger[side] = down
	if _float_page.visible:
		var item: Node3D = inventory.held[side]
		_float_page.global_position = item.global_position + Vector3.UP * .22
		_float_page.text = _page_text()

func _page_text() -> String:
	var id: String = _pages()[_page]
	var st := _st()
	if id == "_junk": return "Odds & ends"
	var n := int((st.get("count", {}) as Dictionary).get(id, 0)) if st.get("count") is Dictionary else 0
	var best := float((st.get("best", {}) as Dictionary).get(id, 0.0)) if st.get("best") is Dictionary else 0.0
	return "%s\n%s" % [TABLE.name_of(id) if n > 0 else "???", ("Best %d cm · %d caught" % [roundi(best * 100.0), n]) if n > 0 else "Not caught yet"]
