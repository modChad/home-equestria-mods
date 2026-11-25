extends Node
## Better Balloon: Anon leans out over the rim (desktop). Standing in the basket within REACH of a
## wall and facing it, not at the Helm, holding Ctrl leans his view out past the rim and down, so he
## can see below; letting go brings it back. Only the camera goes out: his body stays standing behind
## the wall (AnonBody's desktop_body_forward is pulled back by as much), so nothing clips through it.
## Ctrl is also crouch: while leaning, the view is held at a bent-over height instead.

const CRATES := preload("res://mods/better_balloon/crates.gd")
const REACH := 0.75 # Metres from his feet to a wall's inner face.
const FACING := 0.45 # How squarely he must face it (dot of his view with the way out).
const OUT_PAST := 0.30 # His eyes this far past the wall's inner face (the rail's outer edge is 0.19).
const MAX_FORWARD := 1.0 # Never further ahead of him than this.
const BENT_EYE := 0.78 # Eye height while leaning, as a share of his standing eye height.
const EASE_SECONDS := 0.25

var _amount := 0.0
var _body: Node3D
var _camera: Camera3D
var _avatar: Node
var _avatar_forward := 0.0
var _forward := 0.0 # metres ahead of him, last tick


func _ready() -> void:
	process_physics_priority = 100 # after desktop_player.gd has placed the camera this tick


func _physics_process(delta: float) -> void:
	var want := _wanted()
	_amount = move_toward(_amount, 1.0 if want.size() > 0 else 0.0, delta / EASE_SECONDS)
	if want.size() > 0: _forward = want.forward
	if _amount <= 0.0:
		_release()
		return
	var eased := smoothstep(0.0, 1.0, _amount)
	var ahead := _forward * eased
	_camera.position.x = 0.0
	_camera.position.z = -ahead
	var stand: float = float(_body.get("_stand_eye")) if _body.get("_stand_eye") != null else _camera.position.y
	_camera.position.y = lerpf(_camera.position.y, stand * BENT_EYE, eased)
	if is_instance_valid(_avatar): _avatar.set("desktop_body_forward", _avatar_forward - ahead)


## When he may lean, {"forward": metres his eyes go ahead of him}; else {}.
func _wanted() -> Dictionary:
	if not Input.is_physical_key_pressed(KEY_CTRL): return {}
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return {}
	for node: Node in get_tree().get_nodes_in_group("hot_air_balloons"):
		if not node is Node3D or not node.has_method("holds_player"): continue
		var player: Variant = node.get("_player")
		if not is_instance_valid(player) or not bool(node.call("holds_player", player)): continue
		var body := player as Node3D
		if body.get("headset_view") == true or body.get("controls_locked") == true or is_instance_valid(body.get("form_driver")): return {}
		var camera: Variant = body.get("camera")
		if not camera is Camera3D: return {}
		var hands: Variant = node.get("hands")
		if is_instance_valid(hands) and hands.get("held") is Dictionary and not (hands.get("held") as Dictionary).is_empty(): return {}
		var balloon := node as Node3D
		var feet := balloon.to_local(body.global_position)
		var look := balloon.global_basis.inverse() * -(camera as Camera3D).global_basis.z
		look.y = 0.0
		if look.length() < 0.1: return {}
		look = look.normalized()
		for spot: Dictionary in _walls(feet):
			var out: Vector3 = spot.out
			var gap: float = spot.gap
			if gap > REACH or look.dot(out) < FACING: continue
			_take(body, camera as Camera3D)
			# His eyes out past the wall along where he's looking.
			var forward := clampf((gap + OUT_PAST) / maxf(look.dot(out), 0.3), 0.0, MAX_FORWARD)
			return {"forward": forward}
	return {}


## The basket's four walls from `feet` (balloon-local): the way out and how far away each is.
func _walls(feet: Vector3) -> Array:
	return [
		{"out": Vector3.LEFT, "gap": feet.x + CRATES.SIDE_FACE},
		{"out": Vector3.RIGHT, "gap": CRATES.SIDE_FACE - feet.x},
		{"out": Vector3.FORWARD, "gap": feet.z - CRATES.FRONT_FACE},
		{"out": Vector3.BACK, "gap": BACK_FACE - feet.z},
	]
const BACK_FACE := 1.267 # The back wall's inner face (z).


func _take(body: Node3D, camera: Camera3D) -> void:
	if _body == body: return
	_release()
	_body = body
	_camera = camera
	_avatar = body.find_child("AnonBody", true, false)
	_avatar_forward = float(_avatar.get("desktop_body_forward")) if is_instance_valid(_avatar) and _avatar.get("desktop_body_forward") != null else 0.0


func _release() -> void:
	if is_instance_valid(_camera):
		_camera.position.x = 0.0
		_camera.position.z = 0.0
	if is_instance_valid(_avatar): _avatar.set("desktop_body_forward", _avatar_forward)
	_body = null
	_camera = null
	_avatar = null
	_amount = 0.0


func _exit_tree() -> void:
	_release()
