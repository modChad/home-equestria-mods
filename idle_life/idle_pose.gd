extends SkeletonModifier3D
## One idle playing on a pony: additive turns on her body skeleton, layered after locomotion and
## her other modifiers (added as the skeleton's last child). Every turn is a rotation about her
## own right (pitch), up (yaw) or forward (roll) axis, then held inside the rig's joint limits
## (pony_joint_limits.gd), so nothing bends further than the game allows. Bones are never moved
## or scaled. The motion itself is idles.gd; `fade` (0..1, eased by main.gd) scales all of it.

const IDLES := preload("res://mods/idle_life/idles.gd")

var mare: Node3D
var idle := ""
var side := 1.0
var time := 0.0
var fade := 1.0

var _bones: Dictionary = {}
var _bound: Skeleton3D


func _bone(sk: Skeleton3D, name: String) -> int:
	if sk != _bound:
		_bound = sk
		_bones.clear()
	if not _bones.has(name): _bones[name] = sk.find_bone(name)
	return _bones[name]


func _process_modification_with_delta(_delta: float) -> void:
	if fade <= 0.001 or not is_instance_valid(mare): return
	var sk := get_skeleton()
	if sk == null: return
	var basis := mare.global_basis.orthonormalized()
	var axes := {"pitch": basis.x, "yaw": basis.y, "roll": -basis.z}
	var limits: Variant = mare.get("joint_limits")
	_limited = limits != null and limits.has_method("constrain") and limits.get("joints") is Dictionary
	_limits = limits if _limited else null
	var plant := idle in IDLES.PLANTED
	var ground := {}
	if plant:
		for sole: String in HIND_SOLES + FRONT_SOLES: ground[sole] = _at(sk, sole)
	for turn: Array in IDLES.turns(idle, time, side):
		var bone := _bone(sk, str(turn[0]))
		if bone < 0: continue
		var trim := tip_trim if plant and str(turn[0]) in IDLES.TIP_BONES and turn[1] == "pitch" else 1.0
		_turn(sk, bone, Vector3(axes[turn[1]]), deg_to_rad(float(turn[2])) * fade * trim)
	if idle == "preen": _bring_wing(sk, IDLES.wing_amount(time) * fade)
	var lift := IDLES.wing_lift(idle, time)
	if lift.x > 0.001:
		for s: String in ["_L", "_R"]: _set_wing(sk, s, IDLES.WING_ANGLE + lift.y, lift.x * fade)
	if idle == "preen" and LAB_MEASURE: _measure_reach(sk)
	if plant:
		_plant(sk, ground, Vector3(axes.pitch))
		# A foreleg that cannot reach far enough forward within its limits leaves its hoof below
		# the ground: tip her a little less next time, and back toward the full tip when it fits.
		var sunk := 0.0
		for sole: String in FRONT_SOLES: sunk = maxf(sunk, Vector3(ground[sole]).y - _at(sk, sole).y)
		var step := get_physics_process_delta_time() if get_physics_process_delta_time() > 0.0 else 1.0 / 60.0
		if sunk > 0.004: tip_trim = maxf(tip_trim - step * (1.5 + sunk * 30.0), 0.15)
		elif sunk < 0.001: tip_trim = minf(tip_trim + step * 0.25, 1.0)


const HIND_SOLES := ["pony_hoof_L_end", "pony_hoof_R_end"]
const FRONT_SOLES := ["pony_finger_L_end", "pony_finger_R_end"]
## Joints that bring a forehoof down to the ground, tried in turn.
const FRONT_JOINTS := {"pony_finger_L_end": ["pony_shoulder_L", "pony_upperArm_L"], "pony_finger_R_end": ["pony_shoulder_R", "pony_upperArm_R"]}
var _limited := false
const WING_POINTS := ["pony_WingBaseF", "pony_FeatherBaseF", "pony_FeatherBaseF_001", "pony_FeatherTipF", "pony_WingBaseR", "pony_FeatherBaseM", "pony_FeatherBaseM_001", "pony_FeatherTipM"]
## Of the wing's length, how far out along it her muzzle meets it (0 root .. 1 tip).
const MEET := 0.55


## The preened wing swung about its root (wing roots carry no joint limits) so the part of it
## MEET of the way out comes to her muzzle, wherever her head went: lying or sitting, any size
## of pony, either side. `amount` eases it there and back.
func _bring_wing(sk: Skeleton3D, amount: float) -> void:
	if amount <= 0.001: return
	var s := "_R" if side > 0.0 else "_L"
	var root_bone := _bone(sk, "pony_WingBase" + s)
	if root_bone < 0: return
	var root := sk.get_bone_global_pose(root_bone).origin
	var mouth := _at(sk, "MOUNT_MOUTH")
	if not mouth.is_finite(): return
	# The wing point nearest MEET of its reach.
	var points: Array[Vector3] = []
	var span := 0.0
	for n: String in WING_POINTS:
		var p := _at(sk, n + s)
		if p.is_finite(): points.append(p); span = maxf(span, p.distance_to(root))
	if points.is_empty(): return
	var want := span * MEET
	var point := points[0]
	for p in points:
		if absf(p.distance_to(root) - want) < absf(point.distance_to(root) - want): point = p
	var from := (point - root).normalized()
	var to := (mouth - root).normalized()
	if from.is_zero_approx() or to.is_zero_approx() or from.dot(to) > 0.99999: return
	var turn := Quaternion(from, to)
	var angle := turn.get_angle() * amount
	var axis := turn.get_axis()
	_turn(sk, root_bone, (sk.global_basis.orthonormalized() * axis).normalized(), angle)

## A wing swung about her heading, so seen from in front or behind its drawn tip stands `degrees`
## above level, eased there by `amount`.
func _set_wing(sk: Skeleton3D, s: String, degrees: float, amount: float) -> void:
	var root_bone := _bone(sk, "pony_WingBase" + s)
	if root_bone < 0: return
	var root := sk.get_bone_global_pose(root_bone).origin
	var tip := _wing_tip(sk, s, root)
	if not tip.is_finite(): return
	if tip == root: return
	# Skeleton frame throughout. Seen from in front of or behind her (along her heading, level),
	# against the ground's level, as she is looked at.
	var to_sk := sk.global_basis.orthonormalized().inverse()
	var spine := (to_sk * mare.global_basis.z).normalized()
	var up := (to_sk * Vector3.UP).normalized()
	up = (up - spine * up.dot(spine)).normalized()
	var across := up.cross(spine).normalized()
	var dir := tip - root
	dir -= spine * dir.dot(spine)
	# Her own side of the wing: whichever way across her it reaches.
	var out := across if dir.dot(across) >= 0.0 else -across
	if dir.length() < 0.0001: return
	var now := rad_to_deg(atan2(dir.dot(up), dir.dot(out)))
	# Turning about the spine carries `out` toward spine × out: raising when that points up.
	var raise := 1.0 if spine.cross(out).dot(up) > 0.0 else -1.0
	var turn := deg_to_rad(degrees - now) * amount * raise
	_turn(sk, root_bone, (sk.global_basis.orthonormalized() * spine).normalized(), turn)
	if LAB_MEASURE and Engine.get_physics_frames() % 30 == 0:
		var d2 := _wing_tip(sk, s, root) - sk.get_bone_global_pose(root_bone).origin
		d2 -= spine * d2.dot(spine)
		print("WING %s now=%.1f after=%.1f want=%.1f turn=%.1f idx=%d/%d" % [s, now, rad_to_deg(atan2(d2.dot(up), d2.dot(out))), degrees, rad_to_deg(turn), get_index(), sk.get_child_count()])


## Each open wing's drawn tip: its mesh vertex furthest from the wing root, as [bone, place in the
## bone's frame] (by the vertex's main bone), found once. The wing's feathers sweep up past its
## bones, so the bones alone read the wing as lower than it is drawn.
var _tips := {}


func _wing_tip(sk: Skeleton3D, s: String, root: Vector3) -> Vector3:
	if not _tips.has(s):
		_tips[s] = []
		var flight: Variant = mare.get("flight")
		var wings: Variant = flight.get("wings") if flight != null else null
		if wings != null:
			var best := -1.0
			for mi: MeshInstance3D in wings.get("meshes"):
				if not is_instance_valid(mi) or mi.mesh == null or mi.skin == null or not String(mi.name).ends_with(s): continue
				var arr := mi.mesh.surface_get_arrays(0)
				var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var vb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var vw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				if vv.is_empty() or vb.size() < vv.size(): continue
				var per := vb.size() / vv.size()
				for k in range(0, vv.size(), 2):
					var main := 0
					var w := -1.0
					for j in per:
						if vw[k * per + j] > w: w = vw[k * per + j]; main = vb[k * per + j]
					var bone := mi.skin.get_bind_bone(main)
					if bone < 0: continue
					var local := mi.skin.get_bind_pose(main) * vv[k]
					var d := (sk.get_bone_global_pose(bone) * local).distance_to(root)
					if d > best: best = d; _tips[s] = [bone, local]
	var tip: Array = _tips[s]
	if tip.is_empty(): return Vector3.INF
	return sk.get_bone_global_pose(int(tip[0])) * Vector3(tip[1])


## Lab: muzzle-to-wing distance measured each pass.
static var LAB_MEASURE := false
var reach := INF


func _measure_reach(sk: Skeleton3D) -> void:
	var mouth := _at(sk, "MOUNT_MOUTH")
	var s := "_R" if side > 0.0 else "_L"
	reach = INF
	for n: String in ["pony_WingBaseF" + s, "pony_FeatherBaseF" + s, "pony_FeatherBaseM" + s, "pony_FeatherBaseM_001" + s, "pony_FeatherBaseF_001" + s, "pony_WingBaseR" + s, "pony_FeatherTipF" + s, "pony_FeatherTipM" + s]:
		var p := _at(sk, n)
		if p.is_finite(): reach = minf(reach, mouth.distance_to(p))
## How much of the stretch's body tip the forelegs can follow (fitted as it plays).
var tip_trim := 1.0
var _limits: Variant


## Rotates `bone` by `angle` about the world `axis`, then holds it inside its joint limits.
func _turn(sk: Skeleton3D, bone: int, axis: Vector3, angle: float, free := false) -> void:
	if absf(angle) < 0.00001: return
	var local_axis := (sk.global_basis.orthonormalized().inverse() * axis).normalized()
	var parent := sk.get_bone_parent(bone)
	var parent_rotation := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var global := parent_rotation * sk.get_bone_pose_rotation(bone)
	var q := (parent_rotation.inverse() * Quaternion(local_axis, angle) * global).normalized()
	if _limited and not free and (_limits.joints as Dictionary).has(bone):
		q = (_limits.constrain(bone, Basis(q)) as Basis).get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, q)


func _at(sk: Skeleton3D, name: String) -> Vector3:
	var bone := _bone(sk, name)
	return sk.get_bone_global_pose(bone).origin if bone >= 0 else Vector3.INF


## Hooves back on the ground: the body moves so the hind hooves are where they stood, then each
## foreleg swings (shoulder, then elbow, within their limits) until its hoof is at ground height.
func _plant(sk: Skeleton3D, ground: Dictionary, pitch_axis: Vector3) -> void:
	var hips := _bone(sk, "pony_hips")
	if hips < 0: return
	var was := Vector3.ZERO
	var now := Vector3.ZERO
	for sole: String in HIND_SOLES:
		if not Vector3(ground[sole]).is_finite(): return
		was += Vector3(ground[sole]); now += _at(sk, sole)
	var shift := (was - now) * 0.5
	var parent := sk.get_bone_parent(hips)
	var to_local := sk.get_bone_global_pose(parent).basis.inverse() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_position(hips, sk.get_bone_pose_position(hips) + to_local * shift)
	var forward := sk.global_basis.orthonormalized().inverse() * -(mare.global_basis.z)
	forward.y = 0.0
	if forward.length() < 0.01: return
	forward = forward.normalized()
	for sole: String in FRONT_SOLES: _reach(sk, sole, Vector3(ground[sole]), forward, pitch_axis)


## One foreleg out straight to the ground: from its shoulder joint, a leg as long as it stands
## (unbent, the standing pose's own small bends kept) meets the ground ahead of the chest where it
## just reaches. The elbow swings first, then the shoulder blade takes whatever the elbow's limit
## leaves, so the hoof slides forward as the chest sinks and comes back as it rises.
func _reach(sk: Skeleton3D, sole: String, standing: Vector3, forward: Vector3, pitch_axis: Vector3) -> void:
	if not standing.is_finite(): return
	var joints: Array = FRONT_JOINTS[sole]
	var arm := _bone(sk, str(joints[1]))
	if arm < 0: return
	var top := sk.get_bone_global_pose(arm).origin
	var reach := (_at(sk, sole) - top).length()
	var height := top.y - standing.y
	var target: Vector3
	if height >= reach:
		target = Vector3(top.x, standing.y, top.z)
	else:
		target = Vector3(top.x, standing.y, top.z) + forward * sqrt(reach * reach - height * height)
	# Keep the hoof's own width apart from her middle.
	var side_axis := forward.cross(Vector3.UP).normalized()
	target += side_axis * (standing - target).dot(side_axis)
	var local_pitch := (sk.global_basis.orthonormalized().inverse() * pitch_axis).normalized()
	for joint_name: Variant in [joints[1], joints[0], joints[1]]:
		var joint := _bone(sk, str(joint_name))
		if joint < 0: continue
		var pivot := sk.get_bone_global_pose(joint).origin
		var now := _at(sk, sole) - pivot
		var want := target - pivot
		# Signed angle between them about her side-to-side axis.
		now -= local_pitch * now.dot(local_pitch)
		want -= local_pitch * want.dot(local_pitch)
		if now.length() < 0.001 or want.length() < 0.001: continue
		var angle := now.signed_angle_to(want, local_pitch)
		if absf(angle) < 0.002: break
		_turn(sk, joint, pitch_axis, angle, idle in IDLES.FREE_REACH)
