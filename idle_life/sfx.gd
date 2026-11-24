extends RefCounted
## Idle Life's hoof sounds and the royal stamp's camera shake (dev 2026-11-24).
## Sounds (placeholders, sounds/*.ogg, made from the game's own footsteps): any pony's angry
## stamp, Celestia's and Luna's deeper stamp with a thump and rumble, and light taps for the
## tippy-taps; grass or stone, from what the game says she is standing on
## (ground_contact_audio.gd material()). The shake: desktop and VR.

const CONTACT := "res://world/audio/ground_contact_audio.gd"
const DIR := "res://mods/idle_life/sounds/"
## Materials the game calls hard: these get the stone sounds, anything else the grass ones.
const HARD := ["stone", "wood", "ice", "cobble", "brick", "tile", "metal", "marble", "cloud"]
## How loud (dB) each kind plays, and how far it carries (metres to half volume). Set from the
## first render with sound (2026-11-24): the royal stamp clipped at 4 m (its long reach adds about 5 dB close up) and the taps were faint.
const LOUD := {"stamp": -2.0, "stamp_royal": -7.5, "tap": 0.0}
const UNIT := {"stamp": 4.0, "stamp_royal": 7.0, "tap": 2.5}
## The royal stamp's shake: full within SHAKE_NEAR metres of her, none past SHAKE_FAR.
const SHAKE_NEAR := 4.0
const SHAKE_FAR := 12.0
const SHAKE_SECONDS := 0.35
const SHAKE_METRES := 0.036   # 0.03 + 20% (dev 2026-11-24)

static var _streams: Dictionary = {}
static var LAB_DEBUG := false


## Plays `kind` ("stamp", "stamp_royal" or "tap") at `at`, where `pony` stands.
static func play(pony: Node3D, kind: String, at: Vector3) -> void:
	if not is_instance_valid(pony) or not pony.is_inside_tree() or not at.is_finite(): return
	var ground := "grass"
	var contact: Variant = load(CONTACT) if ResourceLoader.exists(CONTACT) else null
	if contact != null:
		var material := str(contact.call("material", pony, at, pony.get_tree().get_first_node_in_group("weather")))
		if material.is_empty(): return   # in the air: nothing to stamp on
		for hard: String in HARD:
			if material.contains(hard): ground = "stone"
	var name := "%s_%s" % [kind, ground]
	if kind == "tap": name += "_%d" % (randi() % 3 + 1)
	var stream := _stream(name)
	if LAB_DEBUG: print("SFX ", name, " loaded=", stream != null, " at=", at.snapped(Vector3.ONE * 0.01))
	if stream == null: return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.volume_db = float(LOUD.get(kind, 0.0))
	player.unit_size = float(UNIT.get(kind, 3.0))
	player.max_distance = 40.0
	player.pitch_scale = randf_range(0.95, 1.05)
	(pony.get_parent() if pony.get_parent() != null else pony).add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


## Imported in a pack; read straight from the .ogg when run from source before an import.
static func _stream(name: String) -> AudioStream:
	if _streams.has(name): return _streams[name]
	var path := DIR + name + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path): stream = load(path) as AudioStream
	elif FileAccess.file_exists(path): stream = AudioStreamOggVorbis.load_from_file(path)
	_streams[name] = stream
	return stream


## A short shake of your view, stronger the nearer you are to `at`. Desktop: the camera's own
## offsets. VR (dev 2026-11-24: wanted there too): your XR origin nudged and put back, as the
## game's own knockdown moves it (player_knockdown.gd).
static func shake(tree: SceneTree, at: Vector3) -> void:
	if tree == null: return
	var camera := tree.root.get_camera_3d()
	if camera == null: return
	if LAB_DEBUG: print("SFX shake from ", camera.global_position.distance_to(at))
	var near := 1.0 - clampf((camera.global_position.distance_to(at) - SHAKE_NEAR) / (SHAKE_FAR - SHAKE_NEAR), 0.0, 1.0)
	if near <= 0.0: return
	var old := camera.get_node_or_null("IdleLifeShake")
	if old != null: old.queue_free()
	var shaker := Shaker.new()
	shaker.name = "IdleLifeShake"
	shaker.strength = near
	if camera is XRCamera3D:
		shaker.origin = camera.get_parent() as XROrigin3D
		if shaker.origin == null: return
	camera.add_child(shaker)


## Jitters, for SHAKE_SECONDS and fading out: on desktop its camera's h/v offsets (the game never
## sets them), put back after; in VR the XR origin, by how much it moved it last frame, so
## whatever else moves the origin keeps its own moves.
class Shaker extends Node:
	var strength := 1.0
	var origin: XROrigin3D
	var _time := 0.0
	var _h := 0.0
	var _v := 0.0
	var _moved := Vector3.ZERO

	func _ready() -> void:
		var camera := get_parent() as Camera3D
		_h = camera.h_offset
		_v = camera.v_offset

	func _process(delta: float) -> void:
		var camera := get_parent() as Camera3D
		if camera == null: queue_free(); return
		_time += delta
		var left := 1.0 - _time / SHAKE_SECONDS
		if left <= 0.0:
			_settle(camera)
			queue_free()
			return
		var amount := SHAKE_METRES * strength * left * left
		var x := amount * sin(_time * 71.0) * 0.6
		var y := amount * sin(_time * 53.0 + 1.3)
		if is_instance_valid(origin):
			var b := camera.global_basis.orthonormalized()
			var want := b.x * x + b.y * y
			origin.global_position += want - _moved
			_moved = want
		else:
			camera.h_offset = _h + x
			camera.v_offset = _v + y

	func _settle(camera: Camera3D) -> void:
		if is_instance_valid(origin):
			origin.global_position -= _moved
			_moved = Vector3.ZERO
		elif camera != null:
			camera.h_offset = _h
			camera.v_offset = _v

	func _exit_tree() -> void:
		if _time < SHAKE_SECONDS: _settle(get_parent() as Camera3D)
