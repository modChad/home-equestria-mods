extends SkeletonModifier3D
## Kissing: keeps her face off his eyes. Runs after every kiss pose writer (the game's kiss pose,
## reach.gd at Hoers size, rear.gd), whose lip fits pull her mouth to his without the game's own
## eye clearance, so at bigger sizes her snout and skull went through the camera (the inside of her
## head filled the view). Each tick: if his eyes are inside her skull (affection_pose.gd's skull
## point and radius) plus SKULL_ROOM, or her nose tip is within NOSE_ROOM of them, her neck turns
## her head back out along the line from his eyes, a few passes of CCD on neck2 and neck1.

const SKULL_ROOM := 0.11 # Metres past her skull's radius.
const NOSE_ROOM := 0.08
const MUZZLE_ROOM := 0.07 # Metres past her muzzle's surface.
const NOSE_RADIUS := 0.35 # Her muzzle at the nose, as a share of her skull's radius.
const PASSES := 6
## She tilts her head this far to one side through a kiss, turning about her lips (which stay on
## his): head-on, her long muzzle put her forehead on his eyes at every size below Hoers.
const TILT_DEGREES := 25.0
const TILT_IN := 0.6 # Seconds to tilt fully.
var _tilt := 0.0
var _side := 1.0
var _last_ms := -100000

var mare: Node3D
var affection: Node
var eye := Vector3.INF # His eyes (world), from main.gd. Built-in `active` is switched by main.gd.
var pushed := 0.0
var clearance := INF # Lab: skull surface to eye after the guard (m). # How far her head was pushed out this tick (metres), for the lab.

var _neck: Array[int] = []
var _head := -1


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null: return
	for name: String in ["pony_neck2", "pony_neck1"]:
		if sk.find_bone(name) >= 0: _neck.append(sk.find_bone(name))
	_head = sk.find_bone("pony_head")


func _process_modification() -> void:
	pushed = 0.0
	var sk := get_skeleton()
	if not active or sk == null or _head < 0 or _neck.is_empty() or not eye.is_finite() or not is_instance_valid(affection): return
	var pose: Variant = affection.get("pose")
	if pose == null: return
	var scale := maxf(sk.global_basis.get_scale().x, 0.0001)
	var at_eye: Vector3 = sk.global_transform.affine_inverse() * eye
	var skull_in: Vector3 = pose.get("skull_in_head")
	var nose_in: Vector3 = pose.get("nose_in_head")
	var radius := float(pose.get("skull_radius")) / scale
	_tilt_head(sk, pose, at_eye)
	var points := [[skull_in, radius + SKULL_ROOM / scale], [nose_in, NOSE_ROOM / scale]]
	# Her muzzle between them, narrowing toward the nose: the bridge of her nose had sat on his eyes.
	if skull_in != Vector3.ZERO and nose_in != Vector3.ZERO:
		for t: float in [0.3, 0.55, 0.8]:
			points.append([skull_in.lerp(nose_in, t), lerpf(radius, radius * NOSE_RADIUS, t) + MUZZLE_ROOM / scale])
	clearance = ((sk.get_bone_global_pose(_head) * skull_in).distance_to(at_eye) - radius) * scale
	for _pass in PASSES:
		var worst := 0.0
		var point_in := Vector3.ZERO
		var room := 0.0
		for p: Array in points:
			if (p[0] as Vector3) == Vector3.ZERO: continue
			var at: Vector3 = sk.get_bone_global_pose(_head) * (p[0] as Vector3)
			var short := float(p[1]) - at.distance_to(at_eye)
			if short > worst:
				worst = short
				point_in = p[0]
				room = p[1]
		clearance = worst * scale
		if worst <= 0.0001: return
		var now: Vector3 = sk.get_bone_global_pose(_head) * point_in
		var away := now - at_eye
		if away.length() < 0.0001: away = Vector3.UP
		var goal := at_eye + away.normalized() * room
		pushed += worst * scale
		for bone in _neck:
			_aim(sk, bone, sk.get_bone_global_pose(_head) * point_in, goal)


## Turn `bone` so `from_point` (a point it carries) moves toward `goal`.
func _aim(sk: Skeleton3D, bone: int, from_point: Vector3, goal: Vector3) -> void:
	var at := sk.get_bone_global_pose(bone).origin
	var from := from_point - at
	var to := goal - at
	var axis := from.cross(to)
	if from.length() < 0.001 or to.length() < 0.001 or axis.length() < 0.000001: return
	var turn := Quaternion(axis.normalized(), from.angle_to(to))
	var parent := sk.get_bone_parent(bone)
	var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var now := sk.get_bone_global_pose(bone).basis.orthonormalized()
	sk.set_bone_pose_rotation(bone, (above.inverse() * (Basis(turn) * now)).get_rotation_quaternion())


## Her head turned about her lips, about the level line toward his eyes; a new kiss (the guard
## idle a moment) tilts from straight, to a side picked at random.
func _tilt_head(sk: Skeleton3D, pose: Variant, at_eye: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ms > 300:
		_tilt = 0.0
		_side = -1.0 if randf() < 0.5 else 1.0
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	_tilt = move_toward(_tilt, 1.0, dt / TILT_IN)
	var mouth_in: Variant = pose.get("mouth_in_head")
	var parent := sk.get_bone_parent(_head)
	if not mouth_in is Vector3 or parent < 0: return
	var head := sk.get_bone_global_pose(_head)
	var pivot: Vector3 = head * (mouth_in as Vector3)
	var toward := at_eye - pivot
	toward.y = 0.0
	if toward.length() < 0.001: return
	var turn := Basis(toward.normalized(), deg_to_rad(TILT_DEGREES) * smoothstep(0.0, 1.0, _tilt) * _side)
	var tilted := Transform3D(turn * head.basis, pivot + turn * (head.origin - pivot))
	var local := sk.get_bone_global_pose(parent).affine_inverse() * tilted
	sk.set_bone_pose_rotation(_head, local.basis.get_rotation_quaternion())
	sk.set_bone_pose_position(_head, local.origin)
