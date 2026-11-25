extends SkeletonModifier3D
## Better Balloon: a passenger looks out over the basket's rim. Kept last on her skeleton, idle
## (weight 0) until main.gd (or the lab) sets `want`.
##
## The pose is keyed on the game's mare rig at Canon size (rim_anim.json, made by
## renders/better_balloon/blender/rim_pose.py): a small dip, a rise of 62° about her hips with the
## hips sinking back, forelegs tucked and then resting on the wall under a rim 0.80 m above her
## hooves (a Canon pony on a step crate), then a slow breathing loop. Per frame: each bone's turn
## from its rest in skeleton space, plus the hips' shift.
## Fitted here: the whole pose is scaled down for a pony the rim stands lower against (her
## shoulders just under the rim), her hind hooves stay where they stood and her forehooves go onto
## the wall (CCD), and her head turns to look about: slowly left and right, now and then down.
## A big pony the rim stands at or below the shoulders of doesn't rear: she stands, leans her neck
## out over the rim and looks about.
## The caller places her (step_need, slide()) and says where the wall is (wall_point, wall_out).

const ANIM_PATH := "res://mods/better_balloon/rim_anim.json"
const BLEND_SECONDS := 0.3
const LAND_SPEED := 1.3 # The rise played backwards this much faster.
const SHOULDER_UNDER_RIM := 0.0 # Metres: her shoulder joints this far under the rim once risen.
const MIN_FIT := 0.15 # Less of the rise than this: she stands and leans instead.
const CHEST_AHEAD_STAND := 0.35 # Her chest this share of her hips-to-shoulders length ahead of
const CHEST_AHEAD_UP := 0.71 # her shoulders, standing and fully up (the keyed pose's back curl).
const HOOF_UNDER_RIM := 0.07 # Metres: forehooves this far under the rim top,
const HOOF_INSET := 0.025 # this far in front of the wall face,
const HOOF_SPREAD := 1.1 # and this share of her shoulders' width apart.
const RAIL_TOP := 0.07 # Metres: the rim rail's top over the wall top (basket.gd),
const KNEE_ABOVE := 0.025 # her knees this far over it,
const KNEE_OVER := 0.09 # and this far past the wall face, over the rail.
const HOOF_OUT := 0.21 # Metres: her hooves hang this far past the wall face, clear of rail and wall.
const LOOK_YAW := deg_to_rad(28.0) # Looking about: this far left and right,
const LOOK_DOWN := deg_to_rad(15.0) # and now and then this far down.
const STAND_LEAN := deg_to_rad(14.0) # Standing: her neck leans out over the rim up to this much,
const STAND_LIFT := deg_to_rad(18.0) # or lifts up to this much when her head is low,
const STAND_CLEAR := 0.16 # aiming her head bone this far (metres) over the rim.
const DOWN_CLEAR := 0.22 # Looking down only with her head this far (metres) over the rim.
const PASSES := 10
const STEP := deg_to_rad(8.0)

static var _anim: Dictionary = {}

var mare: Node3D
var want := false
var wall_point := Vector3.INF # World: the inner wall face at the rim top, in front of her.
var wall_out := Vector3.ZERO # World: horizontal, out of the basket.
var weight := 0.0
var frame := 0.0
var rearing := true # Latched while a lean plays.
var fit := 1.0 # Share of the keyed rise she uses (latched with rearing).
var step_need := 0.0 # World metres she should still move toward the wall (+).
var look_time := 0.0
var debug := ""
var hoof_miss := 0.0 # Metres between her forehooves and their spots on the wall (lab).

var _bones: Array[int] = []
var _tracks: Array = []
var _shift: Array[Vector3] = []
var _hips := -1
var _hind: Array = [] # [flank, tip]
var _fore: Array = [] # [shoulder, upperArm, lowerArm, wrist (knee), tip]
var _neck: Array[int] = []
var _head := -1
var _plants: Array[Vector3] = [] # Her hind hooves' spots, in her own frame (the basket moves).
var _anim_pitch := deg_to_rad(62.0)
var _rim_above := 0.8
var _wall_from_hips := 0.5


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
	for name: String in bones: # Parents first.
		var bone := sk.find_bone(name)
		if bone < 0: continue
		var track: Array[Quaternion] = []
		for q: Array in bones[name]: track.append(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
		_bones.append(bone)
		_tracks.append(track)
	for v: Array in anim.get("hips_offset", []): _shift.append(Vector3(float(v[0]), float(v[1]), float(v[2])))
	var pitches: Array = anim.get("pitch_degrees", [])
	if not pitches.is_empty(): _anim_pitch = deg_to_rad(maxf(1.0, float(pitches.max())))
	_rim_above = float(anim.get("rim_above_hooves", 0.8))
	_wall_from_hips = float(anim.get("wall_from_hips", 0.5))
	_hips = sk.find_bone("pony_hips")
	_head = sk.find_bone("pony_head")
	for name: String in ["pony_neck1", "pony_neck2", "pony_head"]:
		if sk.find_bone(name) >= 0: _neck.append(sk.find_bone(name))
	for side: String in ["L", "R"]:
		var flank := sk.find_bone("pony_flank_" + side)
		var tip := sk.find_bone("pony_hoof_%s_end" % side)
		if flank >= 0 and tip >= 0: _hind.append([flank, tip])
		var chain := [sk.find_bone("pony_shoulder_" + side), sk.find_bone("pony_upperArm_" + side), sk.find_bone("pony_lowerArm_" + side), sk.find_bone("pony_wrist_" + side), sk.find_bone("pony_finger_%s_end" % side)]
		if not chain.has(-1): _fore.append(chain)


func ready_to_use() -> bool:
	return not _bones.is_empty() and _hips >= 0 and _hind.size() == 2 and _fore.size() == 2 and _head >= 0 and _neck.size() == 3


func _mark(name: String, fallback: float) -> float:
	return float((_anim.get("marks", {}) as Dictionary).get(name, fallback))


## Moves her by `by` (world), her planted hind hooves with her.
func slide(by: Vector3) -> void:
	if not is_instance_valid(mare): return
	mare.global_position += by
	for i in _plants.size(): _plants[i] -= mare.global_basis.inverse() * by


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or not ready_to_use() or not is_instance_valid(mare) or not wall_point.is_finite() or wall_out.length() < 0.5: return
	var fps := float(_anim.get("fps", 24))
	var risen := _mark("risen", 34.0)
	var loop_from := _mark("loop_from", 40.0)
	var loop_to := _mark("loop_to", float(_anim.get("frames", 120)) - 1.0)
	var to_sk := sk.global_transform.affine_inverse()
	var scale := maxf(sk.global_basis.get_scale().x, 0.0001)
	var hips_pos := sk.get_bone_global_pose(_hips).origin
	var forward := sk.get_bone_global_pose(_neck[0]).origin - hips_pos
	forward.y = 0.0
	if forward.length() < 0.001: return
	forward = forward.normalized()
	var side_axis := forward.cross(Vector3.UP).normalized() # turning about it by + lifts the nose
	var rim: Vector3 = to_sk * wall_point
	var out: Vector3 = to_sk.basis * wall_out
	out.y = 0.0
	out = out.normalized()
	var along := out.cross(Vector3.UP).normalized()
	# How much of the keyed rise she needs: the turn about her hips that brings her own shoulders
	# just under the rim (each rig is built differently), against the keyed 62°.
	var upper := (sk.get_bone_global_pose(_fore[0][1]).origin + sk.get_bone_global_pose(_fore[1][1]).origin) * 0.5
	var reach_len := (upper - hips_pos).length()
	var needed := _solve(hips_pos, upper, side_axis, rim.y - SHOULDER_UNDER_RIM / scale) / _anim_pitch
	if weight <= 0.0:
		fit = needed
		rearing = fit >= MIN_FIT
	var use := fit if rearing else 0.0
	# Where she stands: her chest (ahead of her shoulders, more so as her back curls up) at the wall.
	var raised := hips_pos + Basis(side_axis, use * _anim_pitch) * (upper - hips_pos)
	var wall_from_hips := (raised - hips_pos).dot(forward) + lerpf(CHEST_AHEAD_STAND, CHEST_AHEAD_UP, use) * reach_len
	step_need = ((rim - hips_pos).dot(out) - wall_from_hips) * scale
	# Her head over the rim (skeleton units): standing ponies lift their neck to clear it, and a
	# pony only just peeking over doesn't look down behind the wall.
	var clearance := sk.get_bone_global_pose(_head).origin.y - rim.y
	# The playhead: up to "risen", on into the breathing loop; to land, the keyed getting-down
	# (from up there), or the rise backwards (still on the way up).
	var down_from := _mark("down_from", -1.0)
	var down_to := _mark("down_to", -1.0)
	if want:
		weight = move_toward(weight, 1.0, delta / BLEND_SECONDS)
		if rearing:
			if frame >= down_from and down_from > 0.0: frame = loop_from # wanted again while getting down
			frame += delta * fps
			if frame > loop_to: frame = loop_from + fmod(frame - loop_from, maxf(loop_to - loop_from, 1.0))
		else: frame = risen
		look_time += delta
	elif weight > 0.0:
		if rearing and down_from > 0.0 and frame >= _mark("settled", 46.0):
			if frame < down_from: frame = down_from
			frame = minf(frame + delta * fps, down_to)
			if frame >= down_to: weight = move_toward(weight, 0.0, delta / BLEND_SECONDS)
		else:
			if rearing: frame = maxf(0.0, minf(frame, risen) - delta * fps * LAND_SPEED)
			else: frame = 0.0
			if frame <= risen * 0.3: weight = move_toward(weight, 0.0, delta / BLEND_SECONDS)
	if weight <= 0.0:
		frame = 0.0
		_plants.clear()
		debug = "idle rear=%s fit=%.0f%% step=%.2f" % [rearing, needed * 100.0, step_need]
		return
	if _plants.is_empty():
		for leg: Array in _hind: _plants.append(mare.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(leg[1]).origin))
	var blend := smoothstep(0.0, 1.0, weight)
	var up_share := clampf(frame / maxf(risen, 1.0), 0.0, 1.0) if rearing else 1.0
	if rearing:
		# The keyframes, each bone's turn from its rest scaled by the fit; the hips' shift too.
		var k := floori(frame)
		var t := frame - float(k)
		for i in _bones.size():
			var bone: int = _bones[i]
			var track: Array = _tracks[i]
			var a: Quaternion = track[mini(k, track.size() - 1)]
			var b: Quaternion = track[mini(k + 1, track.size() - 1)]
			var turn := Quaternion.IDENTITY.slerp(a.slerp(b, t), use)
			var want_global := Basis(turn) * sk.get_bone_global_rest(bone).basis.orthonormalized()
			var parent := sk.get_bone_parent(bone)
			var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
			var local := (above.inverse() * want_global).get_rotation_quaternion()
			sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(local, blend))
		if not _shift.is_empty():
			var shift: Vector3 = _shift[mini(k, _shift.size() - 1)].lerp(_shift[mini(k + 1, _shift.size() - 1)], t) * use * blend
			var parent := sk.get_bone_parent(_hips)
			var above := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
			sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + above.inverse() * shift)
		for i in _hind.size(): _limb(sk, _hind[i][1], _hind[i][0], to_sk * (mare.global_transform * _plants[i]), 24)
		# Forelegs over the rim, the left first: knees on the rail just past the wall face, lower legs
		# hanging outside, clear of the rail and wall; off again first thing when she gets down.
		var width := sk.get_bone_global_pose(_fore[0][1]).origin.distance_to(sk.get_bone_global_pose(_fore[1][1]).origin) * HOOF_SPREAD
		var centre := rim + along * (sk.get_bone_global_pose(_neck[0]).origin - rim).dot(along)
		centre += Vector3.UP * ((RAIL_TOP + KNEE_ABOVE) / scale) + out * (KNEE_OVER / scale)
		hoof_miss = 0.0
		for n in _fore.size():
			var reach := _reach(frame, n) * blend
			if reach <= 0.0: continue
			var leg: Array = _fore[n]
			var tip := sk.get_bone_global_pose(leg[4]).origin
			var knee := sk.get_bone_global_pose(leg[3]).origin
			var side := signf((tip - centre).dot(along))
			if side == 0.0: side = 1.0 if n == 0 else -1.0
			var lower_len := tip.distance_to(knee)
			var knee_spot := centre + along * side * width * 0.5
			var reach_out := (HOOF_OUT - KNEE_OVER) / scale
			var hoof_spot := knee_spot + out * reach_out + Vector3.DOWN * sqrt(maxf(lower_len * lower_len - reach_out * reach_out, 0.0)) * 0.97
			var hoof: Vector3 = tip.lerp(hoof_spot, reach)
			_foreleg(sk, leg, knee.lerp(knee_spot, reach), hoof, forward)
			hoof_miss = maxf(hoof_miss, sk.get_bone_global_pose(leg[4]).origin.distance_to(hoof) * scale)
	else:
		# Standing: her neck leans out over the rim, or lifts her head to clear it.
		var lift := clampf((STAND_CLEAR / scale - clearance) / (0.1 / scale), -1.0, 1.0)
		var pitch := STAND_LIFT * lift if lift > 0.0 else STAND_LEAN * lift
		_turn(sk, _neck[0], Quaternion(side_axis, pitch * blend))
	# Looking about: a head turn, split between the upper neck and the head.
	var sway := sin(look_time * 0.45) * 0.6 + sin(look_time * 0.17 + 1.3) * 0.4
	# About every 45 s, for a few seconds, the first time about 12 s in.
	var over := sk.get_bone_global_pose(_head).origin.y - rim.y # her head over the rim, as posed now
	var down := smoothstep(0.8, 0.97, sin(look_time * 0.14 - 0.11)) * clampf(over * scale / DOWN_CLEAR, 0.0, 1.0)
	var look := blend * smoothstep(0.5, 1.0, up_share)
	if look > 0.0:
		for bone: int in [_neck[1], _head]:
			_turn(sk, bone, Quaternion(Vector3.UP, sway * LOOK_YAW * 0.5 * look) * Quaternion(side_axis, -down * LOOK_DOWN * 0.5 * look))
	debug = "frame=%.0f rear=%s fit=%.0f%% step=%.2f look=%.2f down=%.2f miss=%.2f" % [frame, rearing, use * 100.0, step_need, sway, down, hoof_miss]


## How far foreleg `n` (0 left, 1 right) has gone from tucked onto the rail at `at` (frames), as
## keyed: the left lands first, and leaves first when she gets down.
func _reach(at: float, n: int) -> float:
	var down_from := _mark("down_from", -1.0)
	if down_from > 0.0 and at >= down_from: return 1.0 - smoothstep(down_from + 2.0 * n, down_from + 2.0 * n + 7.0, at)
	var start := 26.0 + 5.0 * n
	return smoothstep(start, start + 10.0, at)


## A foreleg over the rim as a pony's goes: the knee (pony_wrist) at `knee_goal`, the lower leg
## hanging from it to `hoof`, and the elbow bending back toward her tail (two-joint solve in the
## leg's plane).
func _foreleg(sk: Skeleton3D, leg: Array, knee_goal: Vector3, hoof: Vector3, forward: Vector3) -> void:
	var shoulder := sk.get_bone_global_pose(leg[1]).origin
	var elbow := sk.get_bone_global_pose(leg[2]).origin
	var knee := sk.get_bone_global_pose(leg[3]).origin
	var upper_len := elbow.distance_to(shoulder)
	var fore_len := knee.distance_to(elbow)
	var to_knee := knee_goal - shoulder
	var span := clampf(to_knee.length(), absf(upper_len - fore_len) + 0.001, upper_len + fore_len - 0.001)
	var dir := to_knee.normalized()
	# The elbow on the side of her tail (and a little down) from the shoulder-to-knee line.
	var pole := -forward - Vector3.UP * 0.3
	pole = (pole - dir * pole.dot(dir)).normalized()
	var along_line := (upper_len * upper_len - fore_len * fore_len + span * span) / (2.0 * span)
	var elbow_goal := shoulder + dir * along_line + pole * sqrt(maxf(upper_len * upper_len - along_line * along_line, 0.0))
	_aim(sk, leg[1], elbow, elbow_goal, PI)
	_aim(sk, leg[2], sk.get_bone_global_pose(leg[3]).origin, shoulder + dir * span, PI)
	_aim(sk, leg[3], sk.get_bone_global_pose(leg[4]).origin, hoof, PI)


## The rise (radians about `axis` through `hinge`, nose up) that lifts `point` to `height`.
func _solve(hinge: Vector3, point: Vector3, axis: Vector3, height: float) -> float:
	if point.y >= height: return 0.0
	var high := _anim_pitch
	if (hinge + Basis(axis, high) * (point - hinge)).y < height: return high
	var low := 0.0
	for _i in 14:
		var mid := (low + high) * 0.5
		if (hinge + Basis(axis, mid) * (point - hinge)).y < height: low = mid
		else: high = mid
	return (low + high) * 0.5


## Turns `bone` by `turn` (skeleton space) about its own joint.
func _turn(sk: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var parent := sk.get_bone_parent(bone)
	var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var now := sk.get_bone_global_pose(bone).basis.orthonormalized()
	sk.set_bone_pose_rotation(bone, (above.inverse() * (Basis(turn) * now)).get_rotation_quaternion())


## One CCD step on `bone`: turn it so `from_point` (a point it carries) moves toward `goal`.
func _aim(sk: Skeleton3D, bone: int, from_point: Vector3, goal: Vector3, step: float) -> void:
	var at := sk.get_bone_global_pose(bone).origin
	var from := from_point - at
	var to := goal - at
	var turn_axis := from.cross(to)
	if from.length() < 0.001 or to.length() < 0.001 or turn_axis.length() < 0.000001: return
	_turn(sk, bone, Quaternion(turn_axis.normalized(), minf(from.angle_to(to), step)))


## CCD up a limb from `tip` to `root`.
func _limb(sk: Skeleton3D, tip: int, root: int, goal: Vector3, passes: int) -> void:
	for _pass in passes:
		var bone := sk.get_bone_parent(tip)
		while bone >= 0:
			_aim(sk, bone, sk.get_bone_global_pose(tip).origin, goal, STEP)
			if bone == root: break
			bone = sk.get_bone_parent(bone)
