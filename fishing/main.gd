extends Node
## Fishing: makes the river pier's fishing readable and adds five species.
## Each pier rod (world/minigames/fishing/fishing_rod.gd) gets the mod's line (line.gd: aimed
## casts, nibbles, a longer bite, species by habitat) and a feedback node (feedback.gd: float,
## splashes, ripples, rod bend, desktop prompts, VR haptics). The game's rod, hands and
## companions keep driving it. Switched off, every rod gets its own line and float back.
const LINE := preload("res://mods/fishing/line.gd")
const FEEDBACK := preload("res://mods/fishing/feedback.gd")
const HUD := preload("res://mods/fishing/hud.gd")
const CATCH_TABLE := preload("res://mods/fishing/catch_table.gd")
var hud: CanvasLayer
var _rods: Dictionary = {}   # rod -> {old_line, line, feedback}
var _watch: Node             # at the end of the root, so its _input runs before the game's
var _busy: Dictionary = {}   # rod -> true while a keep/release animation plays
var _vr_trigger: Dictionary = {}

func _ready() -> void:
	hud = HUD.new(); hud.name = "FishingHud"; add_child(hud)
	Mods.on_node(_is_pier_rod, _adopt)
	_watch = Node.new(); _watch.name = "FishingInput"
	var script := GDScript.new()
	script.source_code = "extends Node\nvar mod: Node\nfunc _input(e: InputEvent) -> void:\n\tif is_instance_valid(mod): mod.on_input(e)\nfunc _physics_process(_d: float) -> void:\n\tif is_instance_valid(mod): mod.on_physics()\n"
	script.reload(); _watch.set_script(script); _watch.set("mod", self)
	get_tree().root.add_child.call_deferred(_watch)

## The pier's rods: children of RiverDock with a line and a cast().
func _is_pier_rod(node: Node) -> bool:
	return node is Node3D and node.get_parent() != null and String(node.get_parent().name) == "RiverDock" \
		and node.has_method("cast") and node.get("line") != null

func _adopt(rod: Node) -> void:
	if _rods.has(rod) or not rod.is_node_ready(): 
		if not rod.is_node_ready(): rod.ready.connect(_adopt.bind(rod), CONNECT_ONE_SHOT)
		return
	var old: RefCounted = rod.line
	var line: RefCounted = LINE.new()
	line.rod = rod; line.rng.randomize(); line.reset(rod.tip())
	line.caught.connect(_caught.bind(rod))
	line.dropped.connect(_dropped.bind(rod))
	rod.line = line
	var fb: Node3D = FEEDBACK.new(); fb.name = "FishingFeedback"
	rod.add_child(fb)
	fb.setup(rod, line, hud, _hands_for(rod))
	_rods[rod] = {"old_line": old, "line": line, "feedback": fb}
	rod.tree_exiting.connect(func() -> void: _rods.erase(rod), CONNECT_ONE_SHOT)

func _hands_for(rod: Node) -> Node:
	var runtime: Node = rod.get_parent().get_parent()
	return runtime.get("hands") if runtime != null and runtime.get("hands") != null else null

## A pony companion's catch goes the game's way (its river fish beside the bucket). The player's
## hangs on the line with a card: keep it (into the bucket) or release it.
func _caught(at: Vector3, rod: Node) -> void:
	if not is_instance_valid(rod): return
	var line: RefCounted = rod.line
	if str(rod.holder) != "player" or line.fish.is_empty():
		if rod.has_method("_landed"): rod.call("_landed", at)
		return
	var fish: Dictionary = line.fish.duplicate()
	line.land(fish)
	var note := _best_note(fish)
	var fb: Node = _rods[rod].feedback
	if note != "": preload("res://mods/fishing/sounds.gd").play_ui(self, "jingle_best" if note.contains("best") else "jingle", -6.0)
	if _desktop(rod): hud.card(fish.name, fish.length, note)
	else: fb.show_card3d("%s  %d cm%s\nTrigger: keep  ·  other trigger: release" % [fish.name, roundi(fish.length * 100.0), ("\n" + note) if note != "" else ""])

func _best_note(fish: Dictionary) -> String:
	var bests: Dictionary = _bests()
	var best: float = float(bests.get(fish.id, 0.0))
	if best <= 0.0: return "First %s!" % str(fish.name).to_lower()
	if fish.length > best: return "New personal best!"
	return ""

func _bests() -> Dictionary:
	var st: Dictionary = Mods.state("fishing") if Mods.has_method("state") else {}
	if not st.get("best") is Dictionary: st["best"] = {}
	return st.best

func _record(fish: Dictionary, kept: bool) -> void:
	var st: Dictionary = Mods.state("fishing") if Mods.has_method("state") else {}
	var bests := _bests()
	if fish.length > float(bests.get(fish.id, 0.0)): bests[fish.id] = snappedf(fish.length, .001)
	if not st.get("count") is Dictionary: st["count"] = {}
	st.count[fish.id] = int(st.count.get(fish.id, 0)) + 1
	if not kept: st["released"] = int(st.get("released", 0)) + 1
	if Mods.has_method("save_changed"): Mods.save_changed()

## The rod was reset with a fish still held (put back with E/Q, or let go): keep it.
func _dropped(fish: Dictionary, rod: Node) -> void:
	if _busy.has(rod): return  # keep/release already under way; its own callback finishes it
	hud.clear_card()
	_record(fish, true)
	_put_in_bucket(rod, fish)

func _put_in_bucket(rod: Node, fish: Dictionary) -> void:
	var dock: Node = rod.get_parent()
	var into: Vector3 = dock.landing_point() if dock.has_method("landing_point") else rod.global_position
	var inv: Node = _inventory(rod)
	var id := "food:fish-" + str(fish.id)
	var body: Node = inv.spawn_owned_drop(id, Transform3D(Basis(Vector3.UP, randf() * TAU), into)) if is_instance_valid(inv) and inv.has_method("spawn_owned_drop") else null
	if body == null and is_instance_valid(inv): print("[fishing] couldn't place ", id, " in the bucket (too many loose items?)")
	if is_instance_valid(body): preload("res://world/audio/interaction_sounds.gd").play_at(body, "prop_fish_land")

func keep(rod: Node) -> void:
	if _busy.has(rod) or str(rod.line.state) != "landed": return
	var fish: Dictionary = rod.line.fish.duplicate()
	var dock: Node = rod.get_parent()
	var into: Vector3 = dock.landing_point() if dock.has_method("landing_point") else rod.global_position
	_busy[rod] = true; hud.clear_card()
	_record(fish, true)
	rod.line.fish = {}  # handed over: a reset now won't count as dropping it
	_rods[rod].feedback.fly_fish(into, .55, false, func() -> void:
		_busy.erase(rod)
		_put_in_bucket(rod, fish)
		if str(rod.line.state) == "landed": rod.line.reset(rod.tip()))

func release(rod: Node) -> void:
	if _busy.has(rod) or str(rod.line.state) != "landed": return
	var fish: Dictionary = rod.line.fish.duplicate()
	var dock: Node = rod.get_parent()
	var out: Vector3 = rod.tip() + (dock.water_direction() if dock.has_method("water_direction") else -rod.global_basis.z) * 2.5
	out.y = rod.line.water_y
	_busy[rod] = true; hud.clear_card()
	_record(fish, false)
	rod.line.fish = {}
	_rods[rod].feedback.fly_fish(out, .7, true, func() -> void:
		_busy.erase(rod)
		if str(rod.line.state) == "landed": rod.line.reset(rod.tip()))

## Desktop: left click keeps, right click releases, while a catch hangs on the player's rod.
## Taking the rod back to the rack (E/Q) keeps it.
func on_input(event: InputEvent) -> void:
	var rod := _landed_rod()
	if rod == null or not _desktop(rod): return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: keep(rod); get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT: release(rod); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E, KEY_Q]:
		keep(rod)

## VR (untested): the rod hand's trigger keeps, the other hand's trigger releases.
func on_physics() -> void:
	# The game scene is added after mods load; keep this watcher last so it hears input first.
	if is_instance_valid(_watch) and _watch.get_index() != get_tree().root.get_child_count() - 1:
		get_tree().root.move_child(_watch, -1)
	for rod: Node in _rods:
		if not is_instance_valid(rod): continue
		# The rod went back to the rack (or the hand let go) with a fish still on: keep it.
		if str(rod.line.state) == "landed" and str(rod.holder) != "player" and not _busy.has(rod): keep(rod)
	var rod := _landed_rod()
	if rod == null or _desktop(rod): return
	var hands := _hands_for(rod); var inv := _inventory(rod)
	if not is_instance_valid(hands) or not is_instance_valid(inv): return
	var side := str(hands.get("side")); var other := "left" if side == "right" else "right"
	for s: String in [side, other]:
		var down := float(inv.hand_sample(s).get("trigger", 0.0)) > .6
		if down and not _vr_trigger.get(s, true):
			if s == side: keep(rod)
			else: release(rod)
		_vr_trigger[s] = down

func _landed_rod() -> Node:
	for rod: Node in _rods:
		if is_instance_valid(rod) and str(rod.line.state) == "landed" and not _busy.has(rod): return rod
	return null

func _desktop(rod: Node) -> bool:
	var hands := _hands_for(rod)
	return not is_instance_valid(hands) or str(hands.get("side")) in ["desktop", ""]

func _inventory(rod: Node) -> Node:
	var hands := _hands_for(rod)
	return hands.get("inventory") if is_instance_valid(hands) else null

func _exit_tree() -> void:
	if is_instance_valid(_watch): _watch.queue_free()
	for rod: Node in _rods.keys():
		if not is_instance_valid(rod): continue
		var entry: Dictionary = _rods[rod]
		if is_instance_valid(entry.feedback): entry.feedback.restore(); entry.feedback.queue_free()
		var old: RefCounted = entry.old_line
		old.reset(rod.tip()); rod.line = old
	_rods.clear()
