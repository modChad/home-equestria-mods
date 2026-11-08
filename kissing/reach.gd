extends SkeletonModifier3D
## Kissing: a tall pony's reach down to Anon (Hoers size and up), run right after the game's kiss
## pose (world/relationships/affection_pose.gd).
##
## At Hoers size a pony's lips sit about a metre above a 6 ft Anon's, and the game's kiss pose
## lowers her head only a little (tuned for Canon): her lips stop short. This finishes the reach
## the way a horse lowers herself to someone: first her front comes down, her back pitching down
## from the hips (spine1 -> spine3, up to BOW_MAX) while her forelegs fold, knees forward, under
## her shoulders; then CCD passes over her neck and head bring her lips the rest of the way. Each
## front hoof stays on the ground where it stood (the terrain modifier planted it), under its
## shoulder, keeping its angle. Every bone stays inside the rig's joint limits
## (pony_joint_limits.gd, as every pose writer does). It eases in and out over EASE seconds.

const EASE := 0.6
const PASSES := 12
const NECK_STEP := deg_to_rad(5.0) # Most a neck bone turns per pass.
const HEAD_STEP := deg_to_rad(5.0)
const BOW_MAX := deg_to_rad(14.0) # The whole back's pitch, shared down the spine.
const BOW_STEP := deg_to_rad(1.0)

var mare: Node3D
var affection: Node
var want := false # Set by main.gd while it drives a kiss with her.
var weight := 0.0
var debug := "" # Read by the lab (tools/_kiss_lab).
var debug_bow := 0.0
var _neck: Array[int] = []
var _back: Array[int] = []
var _legs: Array = [] # [hoof, [hand, wrist, lowerArm, upperArm, shoulder]] per side
var _head := -1
var _touched: Array[int] = []
## Each front hoof from its shoulder joint (upperArm) at rest, skeleton space.
var _rest_hoof: Array[Vector3] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null: return
	_neck = _find(sk, ["pony_neck2", "pony_neck1", "pony_head"])
	_back = _find(sk, ["pony_spine3", "pony_spine2", "pony_spine1"])
	_head = sk.find_bone("pony_head")
	for side: String in ["L", "R"]:
		var hoof := sk.find_bone("pony_finger_" + side)
		var chain := _find(sk, ["pony_hand_" + side, "pony_wrist_" + side, "pony_lowerArm_" + side, "pony_upperArm_" + side, "pony_shoulder_" + side])
		if hoof >= 0 and chain.size() == 5:
			_legs.append([hoof, chain])
			_rest_hoof.append(sk.get_bone_global_rest(hoof).origin - sk.get_bone_global_rest(chain[3]).origin)
	_touched = _neck + _back
	for leg: Array in _legs:
		_touched.append(leg[0])
		_touched.append_array(leg[1])


func _find(sk: Skeleton3D, names: Array) -> Array[int]:
	var out: Array[int] = []
	for name: String in names:
		var bone := sk.find_bone(name)
		if bone >= 0: out.append(bone)
	return out


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _head < 0 or _back.size() < 3 or not is_instance_valid(affection): return
	var live: bool = want and str(affection.get("kind")) == "kiss"
	weight = move_toward(weight, 1.0 if live else 0.0, get_process_delta_time() / EASE)
	if weight <= 0.0: return
	var pose: Variant = affection.get("pose")
	var target: Variant = affection.get("target")
	if pose == null or not target is Vector3 or not (target as Vector3).is_finite(): return
	var in_head: Vector3 = pose.get("mouth_in_head")
	var goal: Vector3 = sk.global_transform.affine_inverse() * (target as Vector3)
	var limits: Variant = mare.get("joint_limits") if is_instance_valid(mare) else null
	var before: Dictionary = {}
	for bone in _touched: before[bone] = sk.get_bone_pose_rotation(bone)
	# Where each front hoof stands now (planted by the terrain modifier), to keep it there.
	var planted: Array[Transform3D] = []
	for leg: Array in _legs: planted.append(sk.get_bone_global_pose(leg[0]))
	# Her front lowers first; her neck and head bring her lips the rest of the way.
	_lower_front(sk, goal, in_head, limits)
	var bow := 0.0
	for bone in _back: bow += rad_to_deg((before[bone] as Quaternion).angle_to(sk.get_bone_pose_rotation(bone)))
	debug_bow = bow
	for _pass in PASSES:
		for bone in _neck: _ccd(sk, bone, goal, in_head, HEAD_STEP if bone == _head else NECK_STEP, limits)
	# Her forelegs fold under her lowered shoulders, knees forward.
	var ahead := _neck_base(sk) - sk.get_bone_global_pose(_back[2]).origin
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.001 else Vector3.FORWARD
	for i in _legs.size():
		var hoof: int = _legs[i][0]
		var chain: Array = _legs[i][1]
		# Each front hoof under its shoulder as at rest (the bow carries the shoulder a little
		# forward), on the ground where it stood.
		var spot := planted[i].origin
		var under: Vector3 = sk.get_bone_global_pose(chain[3]).origin + _rest_hoof[i]
		spot.x = under.x
		spot.z = under.z
		_fold(sk, chain[3], chain[1], hoof, spot, ahead, limits)
		_set_global_basis(sk, hoof, planted[i].basis, limits)
	if weight < 1.0:
		for bone: int in before:
			sk.set_bone_pose_rotation(bone, (before[bone] as Quaternion).slerp(sk.get_bone_pose_rotation(bone), weight))


## Pitch her back straight down about her side axis (no twist), shared over spine1 (at the hips),
## spine2 and spine3, a step at a time while her lips are still above his, up to BOW_MAX.
func _lower_front(sk: Skeleton3D, goal: Vector3, in_head: Vector3, limits: Variant) -> void:
	var hips := sk.get_bone_global_pose(_back[2]).origin
	var forward := _neck_base(sk) - hips
	forward.y = 0.0
	if forward.length() < 0.001: return
	var side := forward.normalized().cross(Vector3.UP).normalized()
	var bowed := 0.0
	while bowed < BOW_MAX:
		var lips := sk.get_bone_global_pose(_head) * in_head
		if lips.y <= goal.y: break
		var moved := false
		for bone: int in [_back[2], _back[1], _back[0]]:
			var was := sk.get_bone_pose_rotation(bone)
			_turn(sk, bone, Quaternion(side, -BOW_STEP / 3.0), limits)
			if not was.is_equal_approx(sk.get_bone_pose_rotation(bone)): moved = true
		if not moved: break
		bowed += BOW_STEP


func _neck_base(sk: Skeleton3D) -> Vector3:
	return sk.get_bone_global_pose(_neck[1] if _neck.size() > 1 else _head).origin


## Two-bone fold of a foreleg: `upper` (upperArm, at the shoulder joint) carries the leg down to the
## knee (`knee`, pony_wrist, the elbow between them kept as posed); the knee joint then points the
## cannon and pastern at the hoof's spot. The knee goes toward `pole` (forward). Out of reach, the
## leg just straightens toward the spot.
func _fold(sk: Skeleton3D, upper: int, knee: int, hoof: int, spot: Vector3, pole: Vector3, limits: Variant) -> void:
	var top := sk.get_bone_global_pose(upper).origin
	var mid := sk.get_bone_global_pose(knee).origin
	var end := sk.get_bone_global_pose(hoof).origin
	var a := top.distance_to(mid)
	var b := mid.distance_to(end)
	var to_spot := spot - top
	if to_spot.length() < 0.001: return
	var c := clampf(to_spot.length(), absf(a - b) + 0.001, a + b - 0.001)
	debug = "leg reach=%.3f a+b=%.3f shoulder-over-hoof=%.3f" % [to_spot.length(), a + b, Vector2(to_spot.x, to_spot.z).length()]
	var line := to_spot.normalized()
	var side := line.cross(pole)
	if side.length() < 0.001: return
	side = side.normalized()
	# Angle at the shoulder between the line to the hoof and the shoulder-to-knee segment.
	var angle := acos(clampf((a * a + c * c - b * b) / (2.0 * a * c), -1.0, 1.0))
	var knee_at := top + line.rotated(side, -angle) * a
	# rotated(side, -angle) should swing the line toward `pole`; if not, the other way.
	if (knee_at - top).dot(pole) < line.dot(pole) * a: knee_at = top + line.rotated(side, angle) * a
	_aim(sk, upper, mid - top, knee_at - top, limits)
	mid = sk.get_bone_global_pose(knee).origin
	end = sk.get_bone_global_pose(hoof).origin
	_aim(sk, knee, end - mid, spot - mid, limits)


## Turn `bone` so the direction `from` points along `to`.
func _aim(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3, limits: Variant) -> void:
	var axis := from.cross(to)
	if from.length() < 0.001 or to.length() < 0.001 or axis.length() < 0.000001: return
	_turn(sk, bone, Quaternion(axis.normalized(), from.angle_to(to)), limits)


## One CCD step: turn `bone` so her lips move toward `goal`, at most `step`.
func _ccd(sk: Skeleton3D, bone: int, goal: Vector3, in_head: Vector3, step: float, limits: Variant) -> void:
	var lips := sk.get_bone_global_pose(_head) * in_head
	var at := sk.get_bone_global_pose(bone).origin
	var from := lips - at
	var to := goal - at
	var axis := from.cross(to)
	if from.length() < 0.001 or to.length() < 0.001 or axis.length() < 0.000001: return
	_turn(sk, bone, Quaternion(axis.normalized(), minf(from.angle_to(to), step)), limits)


## Turn `bone` by `turn` (skeleton space, about its own origin), then keep it in its joint limits.
func _turn(sk: Skeleton3D, bone: int, turn: Quaternion, limits: Variant) -> void:
	var now := sk.get_bone_global_pose(bone).basis.orthonormalized()
	_set_global_basis(sk, bone, Basis(turn) * now, limits)


func _set_global_basis(sk: Skeleton3D, bone: int, basis: Basis, limits: Variant) -> void:
	var parent := sk.get_bone_parent(bone)
	var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var local := above.inverse() * basis.orthonormalized()
	if limits != null and (limits as Object).has_method("constrain"): local = limits.constrain(bone, local)
	sk.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
