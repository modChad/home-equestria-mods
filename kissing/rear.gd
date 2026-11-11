extends SkeletonModifier3D
## Kissing: she rises into his arms (Kissing 1.2.0). In a deep kiss with a partner, a pony below
## Hoers size rears up on her hind legs, forelegs folded, then rests them over his shoulders and
## kneads, her neck bending down to keep their lips together. Runs right after the game's kiss
## pose (affection_pose.gd), whose own supported rear is switched off meanwhile (main.gd).
##
## The motion is keyframed in Blender on the game's own rig (renders/kissing/blender_rear/
## rear_v2.blend) and exported to rear_anim.json: per frame, each bone's turn from its rest in
## skeleton space. Here it's played on her skeleton: the rise (frames 0..risen), the reach over his
## shoulders (..draped), then the kneading loop (loop_from..loop_to) for as long as the kiss lasts;
## when it ends the rise plays backwards and she drops back onto her forehooves.
## Fitted to the moment by code on top:
## - the rise is scaled to her size so her shoulders come up just under his (Canon: the full 55°);
## - her hind hooves stay where they stood (CCD on each hind leg);
## - her forehooves are brought onto his shoulders (CCD, once she's reached over them);
## - her neck brings her lips to his (CCD).
## The dev allows his joint limits to be bypassed when testing new animations: the keyframes and
## fits here don't go through the rig's limits.

const AFFECTION_POSE := preload("res://world/relationships/affection_pose.gd")
const ANIM_PATH := "res://mods/kissing/rear_anim.json"
const BLEND_SECONDS := 0.25 # In from her own pose, and back out to it.
const LAND_SPEED := 1.5 # The rise played backwards this much faster.
const UNDER_SHOULDERS := 0.16 # Her shoulder joints this far (metres at Canon) under his.
const FORE_REACH := 0.62 # His shoulders this share of her foreleg's length in front of hers.
const CHEST_DROP := 0.12 # Chest mode: hooves this far (m) under his shoulder points,
const CHEST_REACH := 0.85 # never higher than this share of her foreleg above her shoulders,
const CHEST_FRONT := 0.12 # and this far (m) toward her, on the front of his chest.
const MIN_PITCH := deg_to_rad(12.0)
const PASSES := 10
const STEP := deg_to_rad(8.0)

static var _anim: Dictionary = {}

var mare: Node3D
var affection: Node
var want := false # Set by main.gd while she's up.
var weight := 0.0
var frame := 0.0 # Playhead (animation frames).
var landing := false
var angle := 0.0 # The rise now (radians), for main.gd and the lab.
var step_need := INF # How far she should step toward him before rising (metres, + toward).
var on_chest := false
var chest_mode := false # Canon (main.gd): he stays upright and her forehooves rest on his chest.
var eye_for_shoulders := INF # World height main.gd bends him to.
var eye := Vector3.INF # His eyes and facing (world), from main.gd.
var face := Basis.IDENTITY
var debug := ""

var _bones: Array[int] = [] # Animated bones, parents first.
var _tracks: Array = [] # Per animated bone: Array of Quaternion per frame.
var _hips := -1
var _flanks: Array[int] = []
var _hind: Array = [] # [flank, tip]
var _fore: Array = [] # [shoulder, upperArm, lowerArm, tip]
var _neck: Array[int] = []
var _head := -1
var _plants: Array[Vector3] = []
var _leg_length := 0.3
var _anim_pitch := deg_to_rad(55.0)


static func _load() -> Dictionary:
	if _anim.is_empty() and FileAccess.file_exists(ANIM_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANIM_PATH))
		if parsed is Dictionary: _anim = parsed
	return _anim


func _ready() -> void:
	var sk := get_skeleton()
	var anim := _load()
	if sk == null or anim.is_empty(): return
	var bones: Dictionary = anim.get("bones", {})
	# Parents first: the export lists them in hierarchy order.
	for name: String in bones:
		var bone := sk.find_bone(name)
		if bone < 0: continue
		var track: Array[Quaternion] = []
		for q: Array in bones[name]: track.append(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
		_bones.append(bone)
		_tracks.append(track)
	var pitches: Array = anim.get("pitch_degrees", [])
	if not pitches.is_empty(): _anim_pitch = deg_to_rad(maxf(1.0, float(pitches.max())))
	_hips = sk.find_bone("pony_hips")
	_head = sk.find_bone("pony_head")
	for name: String in ["pony_neck2", "pony_neck1", "pony_head"]:
		if sk.find_bone(name) >= 0: _neck.append(sk.find_bone(name))
	for side: String in ["L", "R"]:
		var flank := sk.find_bone("pony_flank_" + side)
		var tip := sk.find_bone("pony_hoof_%s_end" % side)
		if flank >= 0 and tip >= 0:
			_flanks.append(flank)
			_hind.append([flank, tip])
		var chain := [sk.find_bone("pony_shoulder_" + side), sk.find_bone("pony_upperArm_" + side), sk.find_bone("pony_lowerArm_" + side), sk.find_bone("pony_finger_%s_end" % side)]
		if not chain.has(-1): _fore.append(chain)
	if _fore.size() == 2:
		_leg_length = sk.get_bone_global_rest(_fore[0][1]).origin.distance_to(sk.get_bone_global_rest(_fore[0][3]).origin)


func ready_to_use() -> bool:
	return not _bones.is_empty() and _hips >= 0 and _flanks.size() == 2 and _hind.size() == 2 and _fore.size() == 2 and _head >= 0


func _mark(name: String, fallback: float) -> float:
	return float((_anim.get("marks", {}) as Dictionary).get(name, fallback))


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or not ready_to_use() or not is_instance_valid(affection) or not eye.is_finite(): return
	var live: bool = want and str(affection.get("kind")) == "kiss"
	var fps := float(_anim.get("fps", 24))
	var last := float(_anim.get("frames", 1)) - 1.0
	# The playhead: up and over his shoulders, then the kneading loop; backwards to land.
	if live:
		landing = false
		weight = move_toward(weight, 1.0, delta / BLEND_SECONDS)
		frame += delta * fps
		var loop_from := _mark("loop_from", last)
		var loop_to := _mark("loop_to", last)
		if frame > loop_to: frame = loop_from + fmod(frame - loop_from, maxf(loop_to - loop_from, 1.0))
	elif weight > 0.0:
		if not landing:
			landing = true
			frame = minf(frame, _mark("draped", last))
		frame = maxf(0.0, frame - delta * fps * LAND_SPEED)
		if frame <= 0.0: weight = move_toward(weight, 0.0, delta / BLEND_SECONDS)
	var to_sk := sk.global_transform.affine_inverse()
	var scale := maxf(sk.global_basis.get_scale().x, 0.0001)
	var hinge := (sk.get_bone_global_pose(_flanks[0]).origin + sk.get_bone_global_pose(_flanks[1]).origin) * 0.5
	var forward := _neck_base(sk) - sk.get_bone_global_pose(_hips).origin
	forward.y = 0.0
	if forward.length() < 0.001: return
	forward = forward.normalized()
	var axis := forward.cross(Vector3.UP).normalized()
	var settings: Dictionary = AFFECTION_POSE.kiss_settings()
	var shoulders := AFFECTION_POSE.shoulder_points(eye, face, settings)
	var his: Vector3 = to_sk * ((shoulders[0] + shoulders[1]) * 0.5)
	var upper := (sk.get_bone_global_pose(_fore[0][1]).origin + sk.get_bone_global_pose(_fore[1][1]).origin) * 0.5
	# How far she rises: her shoulders just under his, never past the keyframed rise.
	var size: float = float(mare.get("body_scale")) if mare.get("body_scale") != null else 1.0
	var under := UNDER_SHOULDERS * size / scale
	var full := clampf(_solve(hinge, upper, axis, his.y - under), MIN_PITCH, _anim_pitch)
	var raised := hinge + Basis(axis, full) * (upper - hinge)
	on_chest = raised.y < his.y - under - 0.1 * _leg_length
	step_need = ((his - raised).dot(forward) - FORE_REACH * _leg_length) * scale
	var top := hinge + Basis(axis, _anim_pitch) * (upper - hinge)
	eye_for_shoulders = (sk.global_transform * top).y + under * scale + float(settings.get("hoof_drop", 0.19))
	if weight <= 0.0:
		angle = 0.0
		frame = 0.0
		_plants.clear()
		return
	# Her hind hooves where they stand, before anything turns.
	if _plants.is_empty():
		for leg: Array in _hind: _plants.append(sk.global_transform * sk.get_bone_global_pose(leg[1]).origin)
	# The keyframes, the rise scaled to fit (pony_hips' turn), each bone from its rest.
	var k := floori(frame)
	var t := frame - float(k)
	var k2 := mini(k + 1, int(last))
	var fit := full / _anim_pitch
	var blend := smoothstep(0.0, 1.0, weight)
	for i in _bones.size():
		var bone: int = _bones[i]
		var track: Array = _tracks[i]
		var a: Quaternion = track[mini(k, track.size() - 1)]
		var b: Quaternion = track[mini(k2, track.size() - 1)]
		var turn := a.slerp(b, t)
		if bone == _hips: turn = Quaternion.IDENTITY.slerp(turn, fit)
		var want_global := Basis(turn) * sk.get_bone_global_rest(bone).basis.orthonormalized()
		var parent := sk.get_bone_parent(bone)
		var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var local := (above.inverse() * want_global).get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(local, blend))
	angle = full * clampf(frame / _mark("risen", 34.0), 0.0, 1.0)
	# Hind hooves back onto their spots.
	for i in _hind.size():
		_limb(sk, _hind[i][1], _hind[i][0], to_sk * _plants[i], 24)
	# Forehooves onto his shoulders (her left to his right) once she's reached over them.
	var reach := smoothstep(_mark("risen", 34.0), _mark("draped", 56.0), frame) * blend
	if reach > 0.0 and (chest_mode or not on_chest):
		var risen_shoulders := sk.global_transform * (hinge + Basis(axis, angle) * (upper - hinge))
		for side in 2:
			var leg: Array = _fore[side]
			var tip := sk.get_bone_global_pose(leg[3]).origin
			var spot: Vector3 = shoulders[1 - side]
			if chest_mode:
				# On his chest: below his shoulder, where her leg reaches, on the front of him.
				var fwd_world := (sk.global_basis * forward).normalized()
				spot.y = minf(spot.y - CHEST_DROP, risen_shoulders.y + CHEST_REACH * _leg_length * scale)
				spot -= fwd_world * CHEST_FRONT
			var goal: Vector3 = tip.lerp(to_sk * spot, reach)
			for _pass in PASSES:
				for bone: int in [leg[2], leg[1], leg[0]]:
					_aim(sk, bone, sk.get_bone_global_pose(leg[3]).origin, goal, STEP)
	# Her lips to his.
	var target: Variant = affection.get("target")
	var pose: Variant = affection.get("pose")
	if target is Vector3 and pose != null:
		var in_head: Vector3 = pose.get("mouth_in_head")
		var lips_goal: Vector3 = to_sk * (target as Vector3)
		for _pass in PASSES:
			for bone in _neck:
				_aim(sk, bone, sk.get_bone_global_pose(_head) * in_head, lips_goal, deg_to_rad(5.0) * blend)
	debug = "frame=%.1f fit=%.0f%% raised=%.2f his=%.2f chest=%s" % [frame, fit * 100.0, (sk.global_transform * raised).y, (sk.global_transform * his).y, on_chest]


## The rise (radians about `axis` through `hinge`) that lifts `point` to `height`.
func _solve(hinge: Vector3, point: Vector3, axis: Vector3, height: float) -> float:
	if point.y >= height: return 0.0
	var low := 0.0
	var high := _anim_pitch
	if (hinge + Basis(axis, high) * (point - hinge)).y < height: return high
	for _i in 14:
		var mid := (low + high) * 0.5
		if (hinge + Basis(axis, mid) * (point - hinge)).y < height: low = mid
		else: high = mid
	return (low + high) * 0.5


func _neck_base(sk: Skeleton3D) -> Vector3:
	return sk.get_bone_global_pose(_neck[1] if _neck.size() > 1 else _head).origin


## One CCD step on `bone`: turn it so `from_point` (a point it carries) moves toward `goal`.
func _aim(sk: Skeleton3D, bone: int, from_point: Vector3, goal: Vector3, step: float) -> void:
	var at := sk.get_bone_global_pose(bone).origin
	var from := from_point - at
	var to := goal - at
	var turn_axis := from.cross(to)
	if from.length() < 0.001 or to.length() < 0.001 or turn_axis.length() < 0.000001: return
	var turn := Quaternion(turn_axis.normalized(), minf(from.angle_to(to), step))
	var parent := sk.get_bone_parent(bone)
	var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var now := sk.get_bone_global_pose(bone).basis.orthonormalized()
	sk.set_bone_pose_rotation(bone, (above.inverse() * (Basis(turn) * now)).get_rotation_quaternion())


## CCD up a limb from `tip` to `root`.
func _limb(sk: Skeleton3D, tip: int, root: int, goal: Vector3, passes: int) -> void:
	for _pass in passes:
		var bone := sk.get_bone_parent(tip)
		while bone >= 0:
			_aim(sk, bone, sk.get_bone_global_pose(tip).origin, goal, STEP)
			if bone == root: break
			bone = sk.get_bone_parent(bone)
