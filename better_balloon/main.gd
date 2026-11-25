extends Node
## Better Balloon: desktop flying for the hot-air balloon (world/vehicles/balloon/), from outside,
## without changing the game's files.
##
## Holding the Helm (E / LMB on it, as before):
##   W/S forward and back (the balloon's front is its gate side, -Z), A/D sideways,
##   Q/E turn the balloon (TURN_RATE, eased), Space/Ctrl rise and descend (the game's own keys),
##   the mouse looks around freely instead of steering. LMB or Esc lets go.
##
## Nobody at the Helm, the balloon airborne with Anon aboard and the gate shut: a gentle breeze
## (about DRIFT_SPEED, its direction slowly wandering) and a slight lazy turn. The Lift and Vent
## ropes still rise and descend as normal. Landed, gate open or an empty basket: no drift (an empty
## basket still settles down by the game's own rule).
##
## How: the game's helm script (controls.gd, physics priority -90) still reads Space/Ctrl and the
## ropes; this node runs after it (-85) and before the balloon moves (-80), and only rewrites the
## balloon's `steering` and turns it. While the desktop Helm is held, the helm script's _input is
## switched off (it would turn mouse motion into steering and let go on Q/E); this node handles
## the mouse, Q/E, LMB and Esc instead, and switches it back on the moment the Helm is let go.
##
## Only the balloon's and player's own functions and fields are used, each checked first: if a game
## update changes them, the mod does nothing.

## Degrees per second at full turn, and how fast the turn rate itself changes (deg/s²).
const TURN_RATE := 30.0
const TURN_EASE := 60.0
## Breeze speed in m/s (the balloon's steering is scaled by 5.5 m/s in balloon.gd).
const DRIFT_SPEED := 0.5
const SHIP_SPEED := 5.5
## Slight lazy turn while drifting, deg/s at most.
const DRIFT_TURN := 1.5
## -1.0: W flies toward the gate side (-Z). Set to 1.0 to flip front and back.
const FORWARD := -1.0

const CRATES := preload("res://mods/better_balloon/crates.gd")
var _fitted: Array[Node3D] = []

## Seconds the drift stays off after the basket last touched ground or cloud.
const SETTLE := 1.5
## Anon pushed further than this from where he took the Helm is put back (and it is logged).
const PIN_LOG := 0.05

var _controls_input_off: Node = null   # the helm script whose _input this mod switched off
var _turn_speed: Dictionary = {}        # balloon -> current turn rate (rad/s)
var _touched: Dictionary = {}           # balloon -> msec it last rested on something
var _wind_seed := randf() * 1000.0
var _logged := false
var _pin_balloon: Node3D = null         # balloon whose Helm Anon holds on desktop
var _pin_local := Vector3.INF           # where he stood, in the balloon's frame
var _pin_logged := false
var _feet_balloon: Node3D = null        # balloon carrying Anon's feet, and its pose last frame
var _feet_last := Transform3D.IDENTITY


class Late extends Node:
	var run: Callable
	func _physics_process(_delta: float) -> void: run.call()


func _ready() -> void:
	process_physics_priority = -85
	process_priority = -100  # feet carried before AnonBody's _process plans its steps
	add_to_group("interaction_hint_sources")
	var late := Late.new()
	late.name = "AfterPlayer"
	late.process_physics_priority = 100  # after the balloon (-80) and the player (0) have moved
	late.run = _keep_at_helm
	add_child(late)
	# Balloon Boarding's fixes (carried-in passengers stay, followers who stop short are helped in).
	var boarding: Node = preload("res://mods/better_balloon/boarding.gd").new()
	boarding.name = "Boarding"
	add_child(boarding)
	# Passengers looking out over the rim (test key 6 for now).
	var leans: Node = preload("res://mods/better_balloon/leans.gd").new()
	leans.name = "Leans"
	add_child(leans)
	# Anon leaning out over the rim (hold Ctrl at a wall).
	var lean_over: Node = preload("res://mods/better_balloon/lean_over.gd").new()
	lean_over.name = "LeanOver"
	add_child(lean_over)


## Group talk in the balloon (group_talk.gd): swapped in for the conversation director's helper,
## checked every couple of seconds (a new world has a new director).
const GROUP_TALK := preload("res://mods/better_balloon/group_talk.gd")
var _director: Node = null
var _director_old: RefCounted = null
var _director_look := 0.0


func _swap_group_talk(delta: float) -> void:
	if is_instance_valid(_director) and _director.get("_group_turns") is RefCounted and (_director.get("_group_turns") as RefCounted).get_script() == GROUP_TALK: return
	_director_look -= delta
	if _director_look > 0.0: return
	_director_look = 2.0
	var game: Variant = Mods.get("game")
	if not is_instance_valid(game): return
	var node: Variant = (game as Node).get("director")
	if not is_instance_valid(node) or not (node as Node).has_method("_group_candidates"): return
	var old: Variant = node.get("_group_turns")
	if not old is RefCounted or (old as RefCounted).get_script() == GROUP_TALK: return
	var mine: RefCounted = GROUP_TALK.new(node)
	for key: String in ["_ambient_roll_wait", "_heard_serial", "invalid_why", "dropped_why"]:
		if key in old: mine.set(key, old.get(key))
	node.set("_group_turns", mine)
	_director = node
	_director_old = old
	print("[better_balloon] group talk in the balloon on")


func _physics_process(delta: float) -> void:
	_swap_group_talk(delta)
	for balloon: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if not _usable(balloon): continue
		_fit_out(balloon as Node3D)
		var hands: Node = balloon.get("hands")
		var desktop_helm := _desktop_helm(hands)
		_switch_controls_input(hands, desktop_helm)
		if not _anon_aboard(balloon):
			_turn_speed[balloon] = 0.0
			continue
		var flying_ok: bool = balloon.get("gate_open") == false and not _gate_moving(balloon)
		var now := Time.get_ticks_msec()
		if balloon.get("landed") == true or (balloon.has_method("_support") and not (balloon.call("_support") as Dictionary).is_empty()):
			_touched[balloon] = now
		var settled: bool = now - int(_touched.get(balloon, -100000)) < int(SETTLE * 1000.0)
		var turn_target := 0.0
		if desktop_helm and _typing():
			balloon.set("steering", Vector2.ZERO) # typing a message: letters, not steering
		elif desktop_helm:
			var move := Vector2.ZERO
			if _key(KEY_D): move.x += 1.0
			if _key(KEY_A): move.x -= 1.0
			if _key(KEY_W): move.y += FORWARD
			if _key(KEY_S): move.y -= FORWARD
			balloon.set("steering", move.limit_length(1.0))
			if _key(KEY_Q): turn_target += deg_to_rad(TURN_RATE)
			if _key(KEY_E): turn_target -= deg_to_rad(TURN_RATE)
			if not _logged:
				_logged = true
				print("[better_balloon] at the Helm: WASD move, Q/E turn")
		elif _helm_held(hands):
			pass  # VR: the game's own helm grip steers.
		elif flying_ok and not settled:
			var t := Time.get_ticks_msec() * 0.001 + _wind_seed
			# Breeze direction wanders: two slow waves whose periods share no factor.
			var heading := sin(t / 97.0) * 2.6 + sin(t / 41.0) * 0.9
			var gust := 1.0 + 0.25 * sin(t / 23.0)
			var wind := Vector3(sin(heading), 0.0, cos(heading)) * DRIFT_SPEED * gust
			var local: Vector3 = (balloon as Node3D).global_basis.inverse() * wind
			balloon.set("steering", Vector2(local.x, local.z) / SHIP_SPEED)
			turn_target = deg_to_rad(DRIFT_TURN) * sin(t / 53.0)
		if not flying_ok: turn_target = 0.0
		var speed: float = move_toward(float(_turn_speed.get(balloon, 0.0)), turn_target, deg_to_rad(TURN_EASE) * delta)
		_turn_speed[balloon] = speed
		if absf(speed) > 0.0001: _turn(balloon as Node3D, speed * delta)
	for balloon: Variant in _turn_speed.keys():
		if not is_instance_valid(balloon): _turn_speed.erase(balloon)
	for balloon: Variant in _touched.keys():
		if not is_instance_valid(balloon): _touched.erase(balloon)


## While Anon holds the Helm on desktop his own controls are locked, so he should not move in the
## basket at all; anything that pushed him this tick is undone (sideways only: the floor and steps
## keep his height).
func _keep_at_helm() -> void:
	var balloon: Node3D = null
	for node: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if _usable(node) and _controls_input_off == node.get("hands") and _anon_aboard(node): balloon = node as Node3D
	if balloon == null:
		_pin_balloon = null; _pin_local = Vector3.INF; _pin_logged = false
		return
	var body: Variant = balloon.get("_player")
	if not body is Node3D: return
	var local := balloon.to_local((body as Node3D).global_position)
	if balloon != _pin_balloon or not _pin_local.is_finite():
		_pin_balloon = balloon; _pin_local = local
		return
	var pushed := Vector2(local.x - _pin_local.x, local.z - _pin_local.z).length()
	if pushed <= 0.001: return
	if pushed > PIN_LOG and not _pin_logged:
		_pin_logged = true
		print("[better_balloon] Anon was pushed %.2f m at the Helm: put back" % pushed)
	(body as Node3D).global_position = balloon.to_global(Vector3(_pin_local.x, local.y, _pin_local.z))


## Anon's desktop body plants its feet in the world and steps when his hips move away from them
## (player/anon_body.gd), so a moving basket made him walk on the spot, with footstep sounds.
## Before the body plans its steps each frame, his planted feet move with the balloon.
func _process(_delta: float) -> void:
	var balloon: Node3D = null
	for node: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if _usable(node) and _anon_aboard(node): balloon = node as Node3D
	if balloon == null:
		_feet_balloon = null
		return
	var now := balloon.global_transform
	if balloon != _feet_balloon:
		_feet_balloon = balloon; _feet_last = now
		return
	if now == _feet_last: return
	var motion := now * _feet_last.affine_inverse()
	_feet_last = now
	_carry_panels(balloon, motion)
	var avatar := _anon_body(balloon)
	if avatar == null: return
	var feet: Variant = avatar.get("_feet")
	if not feet is Array: return
	var turn := motion.basis.get_euler().y
	for foot: Variant in feet:
		if not foot is Dictionary: continue
		for key: String in ["planted", "from", "to"]:
			var p: Variant = (foot as Dictionary).get(key)
			if p is Vector3 and (p as Vector3).is_finite(): foot[key] = motion * (p as Vector3)
		if (foot as Dictionary).get("yaw") is float: foot.yaw = float(foot.yaw) + turn
	var last_hip: Variant = avatar.get("_last_hip")
	if last_hip is Vector3 and (last_hip as Vector3).is_finite(): avatar.set("_last_hip", motion * (last_hip as Vector3))


## The briefcase, a pony's profile card, the clothing customizer and the Tab menu open as panels placed in the
## world in front of Anon; in a moving basket they stayed behind. While open (and not in his hand),
## they ride with the balloon, as he does.
func _carry_panels(balloon: Node3D, motion: Transform3D) -> void:
	var inventory: Variant = balloon.get("inventory")
	if not is_instance_valid(inventory): return
	var panels: Array[Node3D] = []
	var case: Variant = inventory.get("case")
	if case is Node3D and (case as Node3D).visible and str(inventory.get("holding_case")) == "" and inventory.get("_moving_case") != true:
		panels.append(case)
	var inspector: Variant = inventory.get("inspector")
	if is_instance_valid(inspector) and inspector.get("active") == true:
		var card: Variant = inspector.get("panel")
		if card is Node3D and (card as Node3D).visible: panels.append(card)
	var customizer: Variant = inventory.get("customizer")
	if customizer is Node3D and customizer.get("opened") == true: panels.append(customizer)
	# The Tab menu (briefcase, clothes and pony buttons): the desktop wrist strip.
	var wrist: Variant = inventory.get("wrist")
	if wrist is Node3D and inventory.get("_desktop_wrist") == true and (wrist as Node3D).visible: panels.append(wrist)
	var map: Variant = inventory.get("map_menu")
	if map is Node3D and (map as Node3D).is_visible_in_tree() and inventory.has_method("_map_open") and bool(inventory.call("_map_open")): panels.append(map)
	for panel: Node3D in panels: panel.global_transform = motion * panel.global_transform


func _anon_body(balloon: Node3D) -> Node:
	var hands: Variant = balloon.get("hands")
	var avatar: Variant = hands.get("_avatar") if is_instance_valid(hands) else null
	if is_instance_valid(avatar) and (avatar as Node).has_method("set_hand_override") and "_feet" in avatar: return avatar
	return null


## Once per balloon: its rim lowered and its ropes on (crates.gd).
func _fit_out(balloon: Node3D) -> void:
	if balloon.has_meta(CRATES.META) or balloon.get_node_or_null("Gate") == null: return
	CRATES.lower_rim(balloon)
	_fitted.append(balloon)
	print("[better_balloon] basket rim lowered to %.2f m" % (CRATES.RIM_Y - CRATES.FLOOR_Y))


func _usable(balloon: Node) -> bool:
	if not is_instance_valid(balloon) or not balloon is Node3D: return false
	if not balloon.has_method("holds_player"): return false
	for field: String in ["steering", "gate_open", "landed", "hands", "_player"]:
		if not field in balloon: return false
	var hands: Variant = balloon.get("hands")
	return is_instance_valid(hands) and "held" in hands and hands.has_method("release_all") and hands.get("inventory") != null


func _anon_aboard(balloon: Node) -> bool:
	var player: Variant = balloon.get("_player")
	return is_instance_valid(player) and bool(balloon.call("holds_player", player))


func _gate_moving(balloon: Node) -> bool:
	var angle: Variant = balloon.get("_gate_angle")
	return (angle is float) and absf(angle) > 0.01


func _helm_held(hands: Node) -> bool:
	var held: Variant = hands.get("held")
	if not held is Dictionary: return false
	for row: Variant in (held as Dictionary).values():
		if row is Dictionary and is_instance_valid((row as Dictionary).get("node")) and String(((row as Dictionary).node as Node).name) == "Helm": return true
	return false


func _desktop_helm(hands: Node) -> bool:
	var held: Variant = hands.get("held")
	if not held is Dictionary or not (held as Dictionary).has("desktop"): return false
	var row: Variant = (held as Dictionary)["desktop"]
	return row is Dictionary and is_instance_valid((row as Dictionary).get("node")) and String(((row as Dictionary).node as Node).name) == "Helm"


## The helm script's own _input is off only while the desktop Helm is held.
func _switch_controls_input(hands: Node, desktop_helm: bool) -> void:
	if desktop_helm and _controls_input_off == null:
		hands.set_process_input(false)
		_controls_input_off = hands
	elif not desktop_helm and _controls_input_off == hands:
		hands.set_process_input(true)
		_controls_input_off = null
		_unlock_after = hands
	_unlock_left_lock()


## The game's helm script lets go of the Helm when a text field takes the keyboard (the chat box
## counts as a menu) and then leaves Anon's controls locked for that "menu" to unlock, which the
## chat box never does: after sending a message he could not move, open menus or chat again. Once
## the Helm is let go and nothing is being typed, his controls are unlocked, unless something else
## (a menu, another activity) has taken them since.
var _unlock_after: Node = null


func _unlock_left_lock() -> void:
	if not is_instance_valid(_unlock_after): return
	if _typing(): return
	var hands := _unlock_after
	_unlock_after = null
	var inventory: Variant = hands.get("inventory")
	if not is_instance_valid(inventory): return
	var body: Variant = inventory.get("player_body")
	if not is_instance_valid(body) or body.get("controls_locked") != true: return
	var owner: Variant = inventory.get_meta("desktop_activity_owner") if inventory.has_meta("desktop_activity_owner") else null
	if is_instance_valid(owner) and owner != hands: return
	if hands.has_method("_menu_open") and bool(hands.call("_menu_open")): return
	if hands.get("held") is Dictionary and not (hands.get("held") as Dictionary).is_empty(): return
	body.set("controls_locked", false)
	print("[better_balloon] Helm let go while typing: Anon's controls unlocked again")


func _typing() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)


## Turns the balloon about its own up axis, and Anon with it (the balloon carries him by position
## only). Ponies aboard ride on it as their moving support, which follows turns already.
func _turn(balloon: Node3D, angle: float) -> void:
	var pivot := balloon.global_position
	balloon.rotate_y(angle)
	var player: Variant = balloon.get("_player")
	if is_instance_valid(player) and player is Node3D:
		var body := player as Node3D
		body.global_position = pivot + (body.global_position - pivot).rotated(Vector3.UP, angle)
		body.rotate_y(angle)


func _input(event: InputEvent) -> void:
	var hands := _controls_input_off
	if not is_instance_valid(hands) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventMouseMotion:
		_look(hands, (event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_let_go(hands)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var code := (event as InputEventKey).physical_keycode
		if code == KEY_ESCAPE:
			_let_go(hands)  # not handled: Escape still opens the pause menu, as before
		elif code in [KEY_Q, KEY_E]:
			get_viewport().set_input_as_handled()  # turning; keeps E from interacting


func _let_go(hands: Node) -> void:
	hands.call("release_all")
	hands.set_process_input(true)
	if _controls_input_off == hands: _controls_input_off = null


## Mouse look while at the Helm: the same turn and pitch the player gets on foot (desktop_player.gd),
## which it skips while its controls are locked by the Helm.
func _look(hands: Node, relative: Vector2) -> void:
	var inventory: Variant = hands.get("inventory")
	if not is_instance_valid(inventory): return
	var body: Variant = inventory.get("player_body")
	if not is_instance_valid(body) or not body is Node3D: return
	if body.get("headset_view") == true: return
	var sensitivity: Variant = body.get("mouse_sensitivity")
	var pitch: Variant = body.get("_pitch")
	if not (sensitivity is float) or not (pitch is float): return
	var invert := -1.0 if body.get("invert_y") == true else 1.0
	(body as Node3D).rotate_y(-relative.x * sensitivity)
	var new_pitch := clampf(pitch - relative.y * sensitivity * invert, -1.5, 1.5)
	body.set("_pitch", new_pitch)
	var form: Variant = body.get("form_driver")
	if is_instance_valid(form):
		if (form as Node).has_method("clamp_view"): form.call("clamp_view")
	else:
		var camera: Variant = body.get("camera")
		if is_instance_valid(camera) and camera is Camera3D: (camera as Camera3D).rotation.x = new_pitch


## The hint line under the crosshair while at the Helm (this node sits ahead of the balloon's own
## hint source in tree order, so its text is shown instead).
func interaction_hint() -> Dictionary:
	var hands := _controls_input_off
	if not is_instance_valid(hands): return {}
	var held: Variant = hands.get("held")
	if not held is Dictionary or not (held as Dictionary).has("desktop"): return {}
	var helm: Variant = (held as Dictionary).desktop.get("node")
	if not is_instance_valid(helm): return {}
	return {"target": helm, "point": (helm as Node3D).global_position, "collider": helm,
		"text": "WASD · move | Q/E · turn | Space/Ctrl · rise/descend | LMB/Esc · release"}


## Switched off mid-game: hand the Helm's input back to the game.
func _exit_tree() -> void:
	if is_instance_valid(_controls_input_off):
		_controls_input_off.call("release_all")
		_controls_input_off.set_process_input(true)
	_controls_input_off = null
	_turn_speed.clear()
