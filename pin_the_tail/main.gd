extends Node
## Pin the Tail on the Pony: a party poster on the west wall of Sugarcube Corner's shop floor,
## above the chocolate wainscot beside the cafe table.
##
## Desktop: aim at the poster (or the tail basket) and press E. The blindfold goes on and you are
## spun around. Walk back, aim, and press E again to pin the tail wherever you are pointing.
## VR: touch the poster or basket and pull the trigger. Turn around a few times yourself, then touch
## the wall and pull the trigger to pin. (No forced spin in VR: it makes people sick.)
##
## Tails pinned on the poster stay there and are saved with the world; the best shot is chalked on
## the card beside it. Tails pinned anywhere else stay put until you leave the world.

const ID := "pin_the_tail"
const ART := preload("res://mods/pin_the_tail/art.gd")
const KNOWLEDGE := preload("res://mods/pin_the_tail/knowledge.gd")
const PONY_GAME := preload("res://mods/pin_the_tail/pony_game.gd")
## The tag a pony puts in her reply to have a go ([pin_the_tail], forgiving spellings).
const TAG_PATTERN := "(?i)\\[\\s*(?:play[ _-]*)?pin[ _-]*the[ _-]*tail(?:[ _-]*on[ _-]*the[ _-]*pony)?\\s*\\]"
const SFX := preload("res://world/audio/interaction_sounds.gd")
const INTERIOR := "res://world/buildings/sugarcube/bakery_interior.gd"
const FONT_PATH := "res://world/ui/fonts/PonyvilleMedium.ttf"

## Shop floor height and west wall face in BakeryRoom metres (bakery_room.gd FLOOR, LEFT + half
## the wall's 0.18 m thickness). Move POSTER_AT to hang it somewhere else.
const FLOOR := 0.90
const POSTER_AT := Vector3(-6.295, FLOOR + 1.45, 0.6)
## Facing +x, into the room, off the west wall.
const POSTER_YAW := PI * 0.5

const DESK_REACH := 2.2
const TOUCH_RADIUS := 0.06
const SPIN_SECONDS := 1.6
const MAX_POSTER_PINS := 10
const MAX_LOOSE_PINS := 12
## Wander this far from the poster blindfolded and the game is called off.
const GIVE_UP_DISTANCE := 10.0
## Goods for sale this close to the poster cannot be bought while blindfolded.
const GOODS_RADIUS := 25.0
const DIALOGUE := "res://world/ai/overhead_dialogue.gd"
## Enter-to-type chat field. It sits on a low screen layer; blindfolded, it is lifted over the cloth.
const CHAT := "res://world/ui/chat_box.gd"
const BLINDFOLD_LAYER := 120
## Ponies speaking this close are heard through the blindfold.
const HEARING := 20.0
## The chalkboard beside the poster, metres.
const CARD_SIZE := Vector3(0.50, 0.42, 0.02)
## Almost black, with a hint of the blindfold's purple cloth.
const BLINDFOLD_COLOUR := Color(0.035, 0.012, 0.035)

var _root: Node3D
var _poster: StaticBody3D
var _score_label: Label3D
var _poster_pins: Array = []
var _loose_pins: Array = []
var _font: Font

var _blind := false
var _blindfold: Node
var _spin: Tween
var _locked_by_us := false
var _trigger: Dictionary = {"left": true, "right": true}
## Goods held off sale while blindfolded: [item, the game's own "being bought" meta we set].
var _held_goods: Array = []
var _goods_check := 0.0
## Every pony's speech line (overhead_dialogue.gd), and where the blindfold shows them.
var _dialogues: Array = []
var _subs_box: VBoxContainer
var _subs_3d: Label3D
var _subs_check := 0.0
var _subs_shown := ""
## chat box (CanvasLayer) -> its own layer, while lifted over the blindfold.
var _chats: Array = []
var _lifted: Dictionary = {}
## What ponies know about the game (knowledge.gd) and ponies having a go (pony_game.gd).
var knowledge: Node
var pony_game: Node
var _tag: RegEx
## The conversation director's language-model client, whose reply callback we look through.
var _llm: Node
var _llm_check := 0.0


func _ready() -> void:
	add_to_group("interaction_hint_sources")
	add_to_group("pin_the_tail_mod")
	_tag = RegEx.create_from_string(TAG_PATTERN)
	knowledge = KNOWLEDGE.new()
	knowledge.name = "PonyKnowledge"
	knowledge.set("game", self)
	add_child(knowledge)
	pony_game = PONY_GAME.new()
	pony_game.name = "PonyPlayers"
	pony_game.set("game", self)
	add_child(pony_game)
	if ResourceLoader.exists(FONT_PATH): _font = load(FONT_PATH) as Font
	Mods.on_node(INTERIOR, _on_interior)
	Mods.on_node(DIALOGUE, _on_dialogue)
	Mods.on_node(CHAT, _on_chat)
	Mods.world_ready.connect(_on_world_ready)
	Mods.world_closed.connect(_on_world_closed)


# ------------------------------------------------------------------ building the corner

func _on_interior(interior: Node) -> void:
	# The bakery merges its still meshes a frame after it is ready; build after that.
	_build.call_deferred(interior, 0)


func _build(interior: Node, tries: int) -> void:
	if not is_instance_valid(interior) or not interior.is_inside_tree(): return
	if is_instance_valid(_root) and _root.is_inside_tree(): return
	var site := interior.get_parent()
	var room := site.get_node_or_null("BakeryRoom") as Node3D if site != null else null
	if room == null:
		if tries < 30: get_tree().process_frame.connect(_build.bind(interior, tries + 1), CONNECT_ONE_SHOT)
		return
	# A sibling of the room in the room's own frame (metres), so the bakery's mesh merge never
	# swallows these nodes and switching the mod off can free them all.
	_root = Node3D.new()
	_root.name = "PinTheTailCorner"
	_root.transform = room.transform
	site.add_child(_root)

	_poster = StaticBody3D.new()
	_poster.name = "PinTailPoster"
	_poster.set_meta(ID, "poster")
	_poster.position = POSTER_AT
	_poster.rotation.y = POSTER_YAW
	_root.add_child(_poster)
	var size := ART.POSTER_SIZE
	_collision(_poster, Vector3(size.x, size.y, 0.03), Vector3(0, 0, 0.0))
	var quad := QuadMesh.new()
	quad.size = size
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = ART.poster_texture()
	paper.roughness = 0.95
	quad.material = paper
	var face := MeshInstance3D.new()
	face.name = "PosterFace"
	face.mesh = quad
	face.position.z = 0.016
	_poster.add_child(face)
	var frame := ART.material("8c573b")
	for side: Array in [[Vector3(size.x + 0.10, 0.05, 0.035), Vector3(0, size.y * 0.5 + 0.025, 0.012)],
			[Vector3(size.x + 0.10, 0.05, 0.035), Vector3(0, -size.y * 0.5 - 0.025, 0.012)],
			[Vector3(0.05, size.y, 0.035), Vector3(size.x * 0.5 + 0.025, 0, 0.012)],
			[Vector3(0.05, size.y, 0.035), Vector3(-size.x * 0.5 - 0.025, 0, 0.012)]]:
		_box(_poster, side[0], side[1], frame)

	var title := _label("Pin the Tail on the Pony", 72, Color("d979aa"))
	title.position = Vector3(0, size.y * 0.5 + 0.16, 0.02)
	_poster.add_child(title)

	# The tail basket, on the viewer's left of the poster.
	var basket := StaticBody3D.new()
	basket.name = "TailBasket"
	basket.set_meta(ID, "basket")
	basket.position = Vector3(-size.x * 0.5 - 0.30, -0.25, 0.08)
	_poster.add_child(basket)
	_collision(basket, Vector3(0.28, 0.20, 0.16), Vector3.ZERO)
	_box(basket, Vector3(0.28, 0.20, 0.16), Vector3.ZERO, ART.material("e590be"))
	_box(basket, Vector3(0.30, 0.03, 0.18), Vector3(0, 0.10, 0), ART.material("f3d998"))
	for i in 3:
		var spare := ART.make_tail(100 + i)
		spare.position = Vector3(-0.08 + i * 0.08, 0.06, 0.0)
		spare.rotation = Vector3(-0.4, 0, PI + (float(i) - 1.0) * 0.25)
		basket.add_child(spare)
	var hook := _box(_poster, Vector3(0.03, 0.10, 0.06), Vector3(-size.x * 0.5 - 0.30, -0.10, 0.03), ART.material("8c573b"))
	hook.name = "BasketHook"

	# The score card, on the viewer's right.
	var card := Node3D.new()
	card.name = "ScoreCard"
	card.position = Vector3(size.x * 0.5 + 0.36, 0.12, 0.0)
	_poster.add_child(card)
	_box(card, CARD_SIZE, Vector3(0, 0, 0.01), ART.material("3d3540"))
	_box(card, CARD_SIZE + Vector3(0.04, 0.04, -0.005), Vector3(0, 0, 0.004), ART.material("8c573b"))
	_score_label = _label("", 30, Color("f4e9d2"))
	_score_label.position = Vector3(0, 0, 0.022)
	_score_label.outline_size = 0
	# Wrap inside the board, with a small chalk margin either side.
	_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_label.width = (CARD_SIZE.x - 0.06) / _score_label.pixel_size
	_score_label.line_spacing = -4.0
	card.add_child(_score_label)

	# The reset button, under the score card.
	var button := StaticBody3D.new()
	button.name = "ResetButton"
	button.set_meta(ID, "reset")
	button.position = Vector3(card.position.x, card.position.y - CARD_SIZE.y * 0.5 - 0.12, 0.0)
	_poster.add_child(button)
	_collision(button, Vector3(0.12, 0.12, 0.08), Vector3(0, 0, 0.03))
	var plate := _box(button, Vector3(0.14, 0.14, 0.02), Vector3(0, 0, 0.01), ART.material("8c573b"))
	plate.name = "Plate"
	var knob := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.045; cap.bottom_radius = 0.05; cap.height = 0.035
	knob.mesh = cap
	knob.material_override = ART.material("e0564c")
	knob.rotation.x = PI * 0.5
	knob.position = Vector3(0, 0, 0.035)
	knob.name = "Knob"
	button.add_child(knob)
	var caption := _label("Reset", 30, Color("f4e9d2"))
	caption.outline_modulate = Color("3d3540")
	caption.outline_size = 8
	caption.position = Vector3(0, -0.11, 0.02)
	button.add_child(caption)

	for mesh: GeometryInstance3D in _root.find_children("*", "GeometryInstance3D", true, false):
		if mesh.visibility_range_end <= 0.0: mesh.visibility_range_end = 60.0   # tails keep their own
	if Mods.game != null: _restore()
	_refresh_score()
	print("[%s] poster hung in Sugarcube Corner" % ID)


func _collision(body: CollisionObject3D, box_size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _box(parent: Node3D, box_size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node


func _label(text: String, font_size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0015
	label.modulate = colour
	label.outline_modulate = Color.WHITE
	label.outline_size = 14
	label.double_sided = false
	if _font != null: label.font = _font
	return label


# ------------------------------------------------------------------ saved state

func _on_world_ready(_game: Node) -> void:
	if is_instance_valid(_poster): _restore()
	_refresh_score()


func _on_world_closed(_game: Node) -> void:
	_end_blind()
	if is_instance_valid(pony_game): pony_game.call("stop_all")
	_loose_pins.clear()
	_poster_pins.clear()


func _restore() -> void:
	for pin: Variant in _poster_pins:
		if is_instance_valid(pin): (pin as Node).queue_free()
	_poster_pins.clear()
	var saved: Variant = Mods.state(ID).get("pins", [])
	if not saved is Array: return
	var index := 0
	for entry: Variant in saved:
		if entry is Array and (entry as Array).size() >= 2:
			var tail := ART.make_tail(index * 7919 + 3)
			tail.position = Vector3(float(entry[0]), float(entry[1]), 0.016)
			_poster.add_child(tail)
			_poster_pins.append(tail)
			index += 1


func _refresh_score() -> void:
	if not is_instance_valid(_score_label): return
	var state: Dictionary = Mods.state(ID)
	var best: int = int(state.get("best_cm", -1))
	var last: String = str(state.get("last", ""))
	var plays: int = int(state.get("plays", 0))
	var best_by: String = str(state.get("best_by", ""))
	var shot := "none yet" if best < 0 else ("%d cm" % best + (" (%s)" % best_by if best_by != "" else ""))
	var text := "Best shot: %s\nGames: %d" % [shot, plays]
	if last != "": text += "\nLast: " + last
	_score_label.text = text


# ------------------------------------------------------------------ playing

func _inventory() -> Node:
	var game: Node = Mods.game
	if game == null or not is_instance_valid(game): return null
	var found: Variant = game.get("inventory")
	return found as Node if found is Node and is_instance_valid(found) else null


func _desktop(inventory: Node) -> bool:
	return inventory != null and inventory.get("_desktop") == true


func _camera(inventory: Node) -> Camera3D:
	var found: Variant = inventory.get("camera") if inventory != null else null
	return found as Camera3D if found is Camera3D and is_instance_valid(found) else null


func _player(inventory: Node) -> Node3D:
	var found: Variant = inventory.get("player_body") if inventory != null else null
	return found as Node3D if found is Node3D and is_instance_valid(found) else null


## Bodies a ray or touch must not catch: the player and anything in her hands.
func _skip(inventory: Node) -> Array[RID]:
	var skip: Array[RID] = []
	var body := _player(inventory)
	if body is CollisionObject3D: skip.append((body as CollisionObject3D).get_rid())
	for group: String in ["held", "hands"]:
		var things: Variant = inventory.get(group)
		if not things is Dictionary: continue
		for thing: Variant in (things as Dictionary).values():
			if not is_instance_valid(thing) or not thing is Node: continue
			if thing is CollisionObject3D: skip.append((thing as CollisionObject3D).get_rid())
			for child: Node in (thing as Node).find_children("*", "CollisionObject3D", true, false):
				skip.append((child as CollisionObject3D).get_rid())
	return skip


func _part(collider: Variant) -> String:
	if collider is Node and is_instance_valid(collider) and (collider as Node).has_meta(ID):
		return str((collider as Node).get_meta(ID))
	return ""


func _aimed(inventory: Node) -> Dictionary:
	var camera := _camera(inventory)
	if camera == null or not camera.is_inside_tree(): return {}
	var from := camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * DESK_REACH, 1 | (1 << 17), _skip(inventory))
	return camera.get_world_3d().direct_space_state.intersect_ray(ray)


func _touched(inventory: Node, tip: Vector3) -> Dictionary:
	var camera := _camera(inventory)
	if camera == null or not tip.is_finite(): return {}
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = TOUCH_RADIUS
	query.shape = sphere
	query.transform.origin = tip
	query.collision_mask = 1
	query.exclude = _skip(inventory)
	var info := camera.get_world_3d().direct_space_state.get_rest_info(query)
	if info.is_empty(): return {}
	var collider: Object = instance_from_id(int(info.get("collider_id", 0)))
	return {"collider": collider, "position": info.get("point", tip), "normal": info.get("normal", Vector3.UP)}


func _near_poster(at: Vector3, reach: float) -> bool:
	return is_instance_valid(_poster) and _poster.is_inside_tree() and _poster.global_position.distance_to(at) <= reach


func _input(event: InputEvent) -> void:
	# Blindfolded, E or a left click pins, before anything else can use them. Other clicks do
	# nothing: no grabbing, using or buying blind.
	if not _blind: return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	if not click and not _is_e(event): return
	var inventory := _inventory()
	if not _desktop(inventory) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	get_viewport().set_input_as_handled()
	if click and (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT: return
	if _spin != null and _spin.is_running(): return
	var hit := _aimed(inventory)
	if hit.is_empty():
		_say("Nothing in reach. Walk closer!")
		return
	_pin(hit.collider, hit.position, hit.normal, _camera(inventory))


func _unhandled_input(event: InputEvent) -> void:
	if _blind or not _is_e(event) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var inventory := _inventory()
	if not _desktop(inventory): return
	var hit := _aimed(inventory)
	if hit.is_empty() or _part(hit.collider) == "": return
	get_viewport().set_input_as_handled()
	_use(_part(hit.collider), inventory)


func _is_e(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_E


func _physics_process(delta: float) -> void:
	_watch_replies(delta)
	var inventory := _inventory()
	if inventory == null: return
	var camera := _camera(inventory)
	if _blind and (camera == null or not _near_poster(camera.global_position, GIVE_UP_DISTANCE)):
		_end_blind()
		_record("Gave up")
		return
	if _blind:
		# Restocked goods are held off sale too.
		_goods_check -= delta
		if _goods_check <= 0.0: _hold_goods()
	if _desktop(inventory) or not inventory.has_method("hand_sample"): return
	if camera == null or not _near_poster(camera.global_position, 4.0): return
	for side: String in ["left", "right"]:
		var sample: Dictionary = inventory.call("hand_sample", side)
		var pulled: bool = bool(sample.get("active", false)) and float(sample.get("trigger", 0.0)) > (0.45 if _trigger[side] else 0.75)
		if pulled and not _trigger[side]:
			var tip: Vector3 = sample.get("tip", Vector3.INF)
			var touch := _touched(inventory, tip)
			if _blind:
				if touch.is_empty(): _say("Reach out and touch the wall")
				else: _pin(touch.collider, touch.position, touch.normal, camera)
			elif not touch.is_empty() and _part(touch.collider) != "":
				_use(_part(touch.collider), inventory)
			if inventory.has_method("_haptic"): inventory.call("_haptic", side)
		_trigger[side] = pulled


## The interaction hint under the crosshair (desktop) or beside the hand (VR). Nothing shows while
## blindfolded: an outline would give the poster away.
func interaction_hint() -> Dictionary:
	if _blind or not is_instance_valid(_poster): return {}
	var inventory := _inventory()
	if inventory == null: return {}
	if _desktop(inventory):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return {}
		var hit := _aimed(inventory)
		if hit.is_empty() or _part(hit.collider) == "": return {}
		return {"target": hit.collider, "point": hit.position, "text": "[E] " + _verb(_part(hit.collider))}
	var camera := _camera(inventory)
	if camera == null or not _near_poster(camera.global_position, 4.0): return {}
	for side: String in ["right", "left"]:
		var sample: Dictionary = inventory.call("hand_sample", side)
		if not bool(sample.get("active", false)): continue
		var touch := _touched(inventory, sample.get("tip", Vector3.INF))
		if not touch.is_empty() and _part(touch.collider) != "":
			return {"target": touch.collider, "point": touch.position, "text": "Trigger · " + _verb(_part(touch.collider))}
	return {}


func _verb(part: String) -> String:
	return "Reset scores" if part == "reset" else "Play pin the tail"


func _use(part: String, inventory: Node) -> void:
	if part == "reset": _reset()
	else: _start(inventory)


## The red button: wipes the scores and takes every tail off the poster.
func _reset() -> void:
	var state: Dictionary = Mods.state(ID)
	for key: String in ["best_cm", "best_by", "plays", "last", "pins"]: state.erase(key)
	for pin: Variant in _poster_pins:
		if is_instance_valid(pin): (pin as Node).queue_free()
	_poster_pins.clear()
	if Mods.game != null: Mods.save_changed()
	_refresh_score()
	var button := _poster.get_node_or_null("ResetButton") as Node3D
	if button != null:
		SFX.play_at(button, "prop_select")
		var knob := button.get_node_or_null("Knob") as Node3D
		if knob != null:
			var press := knob.create_tween()
			press.tween_property(knob, "position:z", 0.022, 0.08)
			press.tween_property(knob, "position:z", 0.035, 0.12)
	_say("Scores reset!", _poster.global_position + _poster.global_basis.z * 0.3)


func _start(inventory: Node) -> void:
	var camera := _camera(inventory)
	if camera == null: return
	var turn: String = str(pony_game.call("player_name")) if is_instance_valid(pony_game) else ""
	if turn != "":
		_say("Wait your turn! %s is playing." % turn)
		return
	_blind = true
	_hold_goods()
	_put_on_blindfold(camera, _desktop(inventory))
	_lift_chat()
	SFX.play_at(camera, "prop_blanket")
	var body := _player(inventory)
	if _desktop(inventory) and body != null and body.get("headset_view") != true and "controls_locked" in body:
		_spin_round(body)


func _put_on_blindfold(camera: Camera3D, desktop: bool) -> void:
	if desktop: _blindfold = _screen_blindfold()
	else: _blindfold = _headset_blindfold(camera)


## Desktop: the whole screen goes dark, over the world and the HUD alike.
func _screen_blindfold() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PinTheTailBlindfold"
	layer.layer = BLINDFOLD_LAYER
	var cloth := ColorRect.new()
	cloth.color = Color(BLINDFOLD_COLOUR, 0.995)
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloth.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cloth)
	var note := Label.new()
	note.text = "Blindfolded!\nFind the poster and press E or click to pin the tail"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.offset_top = 260.0
	note.add_theme_color_override("font_color", Color("f3d998"))
	note.add_theme_font_size_override("font_size", 30)
	if _font != null: note.add_theme_font_override("font", _font)
	layer.add_child(note)
	# Ponies' words along the bottom, one line each, in their own subtitle colour.
	_subs_box = VBoxContainer.new()
	_subs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subs_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subs_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subs_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the chat field (chat_box.gd: 104-150 px from the bottom) when it opens.
	_subs_box.offset_bottom = -165.0
	_subs_box.custom_minimum_size = Vector2(900, 0)
	_subs_box.alignment = BoxContainer.ALIGNMENT_END
	layer.add_child(_subs_box)
	add_child(layer)
	return layer


## VR: an opaque cloth sphere around the eyes (screen overlays do not reach the headset).
func _headset_blindfold(camera: Camera3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "PinTheTailBlindfold"
	var cloth := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.flip_faces = true
	cloth.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(BLINDFOLD_COLOUR, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 120
	cloth.material_override = mat
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cloth)
	var note := Label3D.new()
	note.name = "Note"
	note.text = "Blindfolded!\nSpin around three times, then touch the wall\nand pull the trigger to pin the tail"
	note.font_size = 36
	note.pixel_size = 0.00018
	note.position = Vector3(0, -0.035, -0.2)
	note.no_depth_test = true
	note.render_priority = 127
	note.modulate = Color("f3d998")
	note.outline_size = 0
	if _font != null: note.font = _font
	holder.add_child(note)
	_subs_3d = Label3D.new()
	_subs_3d.name = "Speech"
	_subs_3d.font_size = 32
	_subs_3d.pixel_size = 0.00018
	_subs_3d.position = Vector3(0, -0.07, -0.2)
	_subs_3d.no_depth_test = true
	_subs_3d.render_priority = 127
	_subs_3d.outline_size = 8
	_subs_3d.width = 900.0
	_subs_3d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subs_3d.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _font != null: _subs_3d.font = _font
	holder.add_child(_subs_3d)
	camera.add_child(holder)
	return holder


## Desktop: turn the player two to three times on the spot, ending somewhere random.
func _spin_round(body: Node3D) -> void:
	if body.get("controls_locked") != true:
		body.set("controls_locked", true)
		_locked_by_us = true
	var start := body.rotation.y
	var turns := TAU * 2.0 + randf() * TAU
	_spin = create_tween()
	_spin.tween_method(_spin_step.bind(body, start), 0.0, turns, SPIN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spin.finished.connect(_unlock.bind(body))


func _spin_step(turned: float, body: Node3D, start: float) -> void:
	if is_instance_valid(body): body.rotation.y = start + turned


func _unlock(body: Node3D) -> void:
	if _locked_by_us and is_instance_valid(body) and body.get("controls_locked") == true:
		body.set("controls_locked", false)
	_locked_by_us = false


func _end_blind() -> void:
	_blind = false
	if _spin != null and _spin.is_valid(): _spin.kill()
	_spin = null
	_unlock(_player(_inventory()))
	if is_instance_valid(_blindfold): _blindfold.queue_free()
	_blindfold = null
	_subs_box = null
	_subs_3d = null
	_subs_shown = ""
	_lower_chat()
	_release_goods()


## No buying blind: every good for sale nearby wears the game's own "being bought" marker, which
## every way of taking it (desktop E, VR grip, magic hands) already refuses. Goods that had it
## already are left alone; only the ones marked here are cleared afterwards.
func _hold_goods() -> void:
	_goods_check = 0.5
	if not is_instance_valid(_poster) or not _poster.is_inside_tree(): return
	var centre := _poster.global_position
	for pair: Array in [["world_food", "food_claiming"], ["shop_items", "shop_claiming"]]:
		for item: Node in get_tree().get_nodes_in_group(pair[0]):
			if not item is Node3D or (item as Node3D).global_position.distance_to(centre) > GOODS_RADIUS: continue
			if pair[0] == "world_food" and not bool(item.get_meta("food_for_sale", false)): continue
			if bool(item.get_meta(pair[1], false)): continue
			item.set_meta(pair[1], true)
			_held_goods.append([item, pair[1]])


func _release_goods() -> void:
	for entry: Array in _held_goods:
		var item: Variant = entry[0]
		if is_instance_valid(item) and (item as Node).has_meta(entry[1]): (item as Node).remove_meta(entry[1])
	_held_goods.clear()


func _pin(collider: Variant, at: Vector3, normal: Vector3, camera: Camera3D) -> void:
	_end_blind()
	var who: String = str(knowledge.call("player_name")) if is_instance_valid(knowledge) else "Anon"
	var result := place_tail(collider, at, normal, camera.global_basis.y, "player", who)
	if result.is_empty(): return
	var float_at := at + (normal.normalized() * 0.15 if normal.length_squared() > 0.0001 else Vector3.ZERO)
	say(str(result.verdict), float_at)


## A tail pinned by `who_name` (`who_id` "player" or a pony's id) at `at` on `collider`, facing out
## along `normal`. Scores it, saves it, tells the ponies who saw it, and returns
## {on_poster, cm, verdict, where, tail}; {} when there is nowhere to put it.
func place_tail(collider: Variant, at: Vector3, normal: Vector3, up_hint: Vector3, who_id: String, who_name: String) -> Dictionary:
	if not is_instance_valid(_poster): return {}
	var on_poster := _part(collider) == "poster"
	var holder: Node3D = _poster if on_poster else (collider as Node3D if collider is Node3D and is_instance_valid(collider) else _root)
	if holder == null: return {}
	var z := normal.normalized() if normal.length_squared() > 0.0001 else _poster.global_basis.z
	var up := Vector3.UP - z * z.dot(Vector3.UP)
	if up.length_squared() < 0.01: up = up_hint - z * z.dot(up_hint)
	if up.length_squared() < 0.0001: up = Vector3.FORWARD
	up = up.normalized()
	var where := where_pinned(collider, at)
	var tail := ART.make_tail(randi())
	holder.add_child(tail)
	tail.global_transform = Transform3D(Basis(up.cross(z), up, z), at)
	SFX.play_at(tail, "prop_place")
	var result := {"on_poster": on_poster, "cm": -1, "verdict": "", "where": where, "tail": tail}
	if on_poster:
		var local := _poster.to_local(at)
		var cm := roundi(Vector2(local.x, local.y).distance_to(ART.target_local()) * 100.0)
		tail.position.z = 0.016
		tail.basis = Basis.IDENTITY
		_poster_pins.append(tail)
		while _poster_pins.size() > MAX_POSTER_PINS:
			var old: Variant = _poster_pins.pop_front()
			if is_instance_valid(old): (old as Node).queue_free()
		var state: Dictionary = Mods.state(ID)
		var pins: Array = []
		for pin: Variant in _poster_pins:
			if is_instance_valid(pin): pins.append([snappedf((pin as Node3D).position.x, 0.001), snappedf((pin as Node3D).position.y, 0.001)])
		state["pins"] = pins
		var best: int = int(state.get("best_cm", -1))
		if best < 0 or cm < best:
			state["best_cm"] = cm
			state["best_by"] = who_name
		var short := ""
		if cm <= 5: result.verdict = "Bullseye! %d cm" % cm; short = "bullseye"
		elif cm <= 15: result.verdict = "So close! %d cm" % cm; short = "so close"
		elif cm <= 40: result.verdict = "On the pony... %d cm" % cm; short = "on the pony"
		else: result.verdict = "That's not where tails go! %d cm" % cm; short = "way off"
		result.cm = cm
		_record("%s, %s, %d cm" % [who_name, short, cm])
	else:
		_loose_pins.append(tail)
		while _loose_pins.size() > MAX_LOOSE_PINS:
			var old: Variant = _loose_pins.pop_front()
			if is_instance_valid(old): (old as Node).queue_free()
		result.verdict = "Missed the poster entirely!"
		_record("%s, missed!" % who_name)
	if is_instance_valid(knowledge): knowledge.call("pinned", who_id, who_name, result)
	return result


## Where a tail landed, in words a pony can tease about: "15 cm from the X, on the poster pony's
## rump", "on Rarity", "on the wall about 70 cm left of the poster".
func where_pinned(collider: Variant, at: Vector3) -> String:
	if _part(collider) == "poster":
		var local := _poster.to_local(at)
		var cm := roundi(Vector2(local.x, local.y).distance_to(ART.target_local()) * 100.0)
		var px := (local.x / ART.POSTER_SIZE.x + 0.5) * ART.CANVAS.x
		var py := (0.5 - local.y / ART.POSTER_SIZE.y) * ART.CANVAS.y
		var part := "on the empty poster beside the pony"
		if cm <= 5: part = "right on the gold X"
		elif px < 250.0 and py < 200.0: part = "on the poster pony's head"
		elif py > 300.0 and px > 170.0 and px < 410.0: part = "on the poster pony's legs"
		elif Vector2((px - 290.0) / 110.0, (py - 250.0) / 56.0).length() <= 1.0 or Vector2((px - 364.0) / 52.0, (py - 254.0) / 54.0).length() <= 1.0:
			part = "on the poster pony's rump" if px > 330.0 else "on the poster pony's back"
		elif px < 300.0 and py < 230.0: part = "on the poster pony's neck and mane"
		return "%d cm from the X, %s" % [cm, part]
	var pony := pony_of(collider)
	if pony != null:
		var identity: Variant = pony.get("identity")
		var pony_name: String = str(identity.get("display_name")) if identity is Resource else "a pony"
		return "on %s, not the poster" % pony_name
	var local := _poster.to_local(at)
	if absf(local.z) > 0.3 or Vector2(local.x, local.y).length() > 4.0:
		return "nowhere near the poster, somewhere else in Sugarcube Corner"
	var bits: PackedStringArray = []
	var half := ART.POSTER_SIZE * 0.5
	if local.x < -half.x: bits.append("%d cm left of" % roundi((-half.x - local.x) * 100.0))
	elif local.x > half.x: bits.append("%d cm right of" % roundi((local.x - half.x) * 100.0))
	if local.y < -half.y: bits.append("%d cm below" % roundi((-half.y - local.y) * 100.0))
	elif local.y > half.y: bits.append("%d cm above" % roundi((local.y - half.y) * 100.0))
	if bits.is_empty(): return "on the poster's frame"
	return "on the wall, %s the poster" % " and ".join(bits)


## The pony a collider belongs to (her body or one of its parts), or null.
func pony_of(collider: Variant) -> Node3D:
	var node: Node = collider as Node if collider is Node and is_instance_valid(collider) else null
	while node != null:
		if node is Node3D and node.is_in_group("ai_characters"): return node as Node3D
		node = node.get_parent()
	return null


# ------------------------------------------------------------------ used by knowledge.gd and pony_game.gd

## Where the poster hangs, in the shop room's metres.
func poster_at() -> Vector3:
	return POSTER_AT


func poster() -> StaticBody3D:
	return _poster if is_instance_valid(_poster) and _poster.is_inside_tree() else null


func corner() -> Node3D:
	return _root if is_instance_valid(_root) and _root.is_inside_tree() else null


## A point in the shop room's own metres (bakery_room.gd), in the world.
func room_point(local: Vector3) -> Vector3:
	return _root.to_global(local) if corner() != null else Vector3.INF


func player_blind() -> bool:
	return _blind


## The player's eye and look direction, or {} without a camera.
func player_view() -> Dictionary:
	var camera := _camera(_inventory())
	if camera == null or not camera.is_inside_tree(): return {}
	return {"at": camera.global_position, "forward": -camera.global_basis.z}


# ------------------------------------------------------------------ hearing [pin_the_tail]

## A pony's raw reply (tags and all) only exists inside the director's language-model client, on its
## way to the callback it was asked to call (llm_client.gd `_on_done`). While a request is out, that
## callback is wrapped once: the reply comes here first, loses the tag, and goes on unchanged
## otherwise. No game script is replaced or extended. Missing members just mean no tag is heard.
func _watch_replies(delta: float) -> void:
	# 0.4.2: looks every 2 s whether or not it has a client (0.4.1 searched every physics tick while
	# it had none, i.e. with the AI off: devanon's patch 1.0.0, folded in).
	_llm_check -= delta
	if _llm_check <= 0.0:
		_llm_check = 2.0
		var director: Node = get_tree().get_first_node_in_group("conversation_director")
		var found: Variant = director.get("llm") if director != null else null
		_llm = found as Node if found is Node and is_instance_valid(found) else null
	if not is_instance_valid(_llm) or _llm.get("busy") != true: return
	var waiting: Variant = _llm.get("_on_done")
	if not waiting is Callable or not (waiting as Callable).is_valid(): return
	var callback := waiting as Callable
	if callback.get_object() == self: return
	_llm.set("_on_done", _reply_through.bind(callback))


func _reply_through(reply: String, error: String, original: Callable) -> void:
	var text := reply
	if error == "" and _tag != null and _tag.search(reply) != null:
		var director: Node = get_tree().get_first_node_in_group("conversation_director") if is_inside_tree() else null
		var current: Variant = director.get("_current") if director != null else null
		text = heard_reply(reply, original.get_method() == &"_on_group_reply", str(current) if current != null else "")
	if original.is_valid(): original.call(text, error)


## A pony reply with the tag: it starts her turn and is taken out of the reply. A group reply is one
## "speaker: words" line per pony.
func heard_reply(text: String, group_reply: bool, current: String) -> String:
	if _tag == null or _tag.search(text) == null: return text
	if not group_reply:
		if is_instance_valid(pony_game): pony_game.call("request", current)
		return _tag.sub(text, "", true)
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		if _tag.search(line) != null:
			var colon := line.find(":")
			var speaker := line.left(colon).strip_edges().to_lower().replace(" ", "_").replace("*", "") if colon > 0 else current
			if is_instance_valid(pony_game): pony_game.call("request", speaker.trim_prefix("-").strip_edges())
			line = _tag.sub(line, "", true)
		lines.append(line)
	return "\n".join(lines)


func _record(last: String) -> void:
	var state: Dictionary = Mods.state(ID)
	state["plays"] = int(state.get("plays", 0)) + 1
	state["last"] = last
	if Mods.game != null: Mods.save_changed()
	_refresh_score()


func _say(text: String, at: Vector3 = Vector3.INF) -> void:
	say(text, at)


## A word that floats up and fades: at `at`, or just ahead of the player's eyes.
func say(text: String, at: Vector3 = Vector3.INF) -> void:
	var camera := _camera(_inventory())
	if camera == null or not is_instance_valid(_root): return
	var label := _label(text, 56, Color("d979aa"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 127
	label.pixel_size = 0.0012
	_root.add_child(label)
	label.global_position = at if at.is_finite() else camera.global_position - camera.global_basis.z * 0.9
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.25, 2.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 2.2).set_delay(1.0)
	tween.tween_callback(label.queue_free)


# ------------------------------------------------------------------ hearing through the blindfold

func _on_dialogue(dialogue: Node) -> void:
	if not dialogue in _dialogues: _dialogues.append(dialogue)


func _on_chat(chat: Node) -> void:
	if not chat in _chats: _chats.append(chat)


## Blindfolded on desktop, the chat field draws over the cloth so you can see what you type.
func _lift_chat() -> void:
	if not _blindfold is CanvasLayer: return
	for i in range(_chats.size() - 1, -1, -1):
		var chat: Variant = _chats[i]
		if not is_instance_valid(chat) or not chat is CanvasLayer: _chats.remove_at(i); continue
		if _lifted.has(chat): continue
		_lifted[chat] = (chat as CanvasLayer).layer
		(chat as CanvasLayer).layer = BLINDFOLD_LAYER + 1


func _lower_chat() -> void:
	for chat: Variant in _lifted:
		if is_instance_valid(chat) and (chat as CanvasLayer).layer == BLINDFOLD_LAYER + 1:
			(chat as CanvasLayer).layer = int(_lifted[chat])
	_lifted.clear()


func _process(delta: float) -> void:
	if not _blind: return
	_subs_check -= delta
	if _subs_check > 0.0: return
	_subs_check = 0.1
	_lift_chat()
	_show_speech()


## The lines ponies nearby are saying right now, as "Name: words", nearest last.
func _speech() -> Array:
	var camera := _camera(_inventory())
	var lines: Array = []
	for i in range(_dialogues.size() - 1, -1, -1):
		var dialogue: Variant = _dialogues[i]
		if not is_instance_valid(dialogue): _dialogues.remove_at(i); continue
		var node := dialogue as Node
		var shown: String = str(node.get("caption_text"))
		var words: String = (shown if shown.strip_edges() != "" else str(node.get("text"))).strip_edges()
		if words == "": continue
		var link: Variant = node.get("_actor")
		var actor: Variant = (link as WeakRef).get_ref() if link is WeakRef else null
		if not actor is Node3D or not is_instance_valid(actor): continue
		var gap := (actor as Node3D).global_position.distance_to(camera.global_position) if camera != null else 0.0
		if gap > HEARING: continue
		var speaker: String = str(node.get("_fallback_speaker"))
		if speaker == "" or speaker == "<null>":
			var identity: Variant = (actor as Node).get("identity")
			speaker = str(identity.get("display_name")) if identity is Resource else ""
		var colour: Variant = node.get("speaker_color")
		lines.append({"gap": gap, "text": (speaker + ": " if speaker != "" else "") + words,
			"colour": colour if colour is Color else Color.WHITE})
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.gap) > float(b.gap))
	return lines


func _show_speech() -> void:
	var lines := _speech()
	var key := ""
	for line: Dictionary in lines: key += str(line.text) + "\n"
	if key == _subs_shown: return
	_subs_shown = key
	if is_instance_valid(_subs_box):
		for child: Node in _subs_box.get_children(): child.queue_free()
		for line: Dictionary in lines:
			var label := Label.new()
			label.text = str(line.text)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.custom_minimum_size = Vector2(900, 0)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_color_override("font_color", line.colour)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_font_size_override("font_size", 28)
			if _font != null: label.add_theme_font_override("font", _font)
			_subs_box.add_child(label)
	if is_instance_valid(_subs_3d):
		_subs_3d.text = key.strip_edges()
		_subs_3d.modulate = (lines[-1].colour as Color) if lines.size() == 1 else Color.WHITE


# ------------------------------------------------------------------ switched off

func _exit_tree() -> void:
	_end_blind()
	# A reply still on its way must reach the director, not this freed node.
	if is_instance_valid(_llm):
		var waiting: Variant = _llm.get("_on_done")
		if waiting is Callable and (waiting as Callable).get_object() == self:
			var bound: Array = (waiting as Callable).get_bound_arguments()
			if not bound.is_empty() and bound[0] is Callable: _llm.set("_on_done", bound[0])
	if is_instance_valid(pony_game): pony_game.call("stop_all")
	for pin: Variant in _loose_pins:
		if is_instance_valid(pin): (pin as Node).queue_free()
	_loose_pins.clear()
	_poster_pins.clear()
	if is_instance_valid(_root): _root.queue_free()
	_root = null
