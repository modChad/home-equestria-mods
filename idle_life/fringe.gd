extends RefCounted
## Her fringe (forelock): the mane hair over her forehead, found from the mane mesh at rest (the
## devkit "<prefix>DevkitMane" on ordinary ponies, the body model's mane on the princesses), and
## the stroke the magic brush draws down it.
##
## The stroke runs from beside her horn's base down over her forehead to her brow, on one side,
## following the outside of her fringe: each point along it is pushed out from the middle of her
## skull to just past the furthest fringe hair in that direction. It is worked out once and held
## in her head model's "mHead" frame (the bone her hair follows), so it moves with her head.
##
## find() -> {side, size, strokes: {side: [stroke points, top to brow]}, points}, plus for the
## princesses clear: {side: [how much further out each stroke point must ride, metres]}.; spot() gives
## where a stroke point is now (the princesses' are held by their hair bones: see _swoop()).
## (side: +1 / -1 the way her fringe sweeps, 0 when it falls evenly; points: the fringe hair
## sampled, in her face frame, for the lab). Empty when she has too little fringe to brush.

## Fewer sampled fringe points than this: no fringe worth brushing.
const MIN_POINTS := 12
## Fringe leaning less than this far to one side (metres, at size 1) counts as even.
const EVEN := 0.012
## Points along the stroke.
const STEPS := 9
## A fringe hair counts toward the stroke's height at a point when it lies within this angle of
## it, seen from the middle of her skull.
const CONE_DEG := 14.0
## How far beyond the furthest hair (metres at size 1) the stroke runs: the brush on the hair.
const ABOVE := 0.004
## How far back over her head the fringe reaches (0 her forehead .. 1 the middle of her head),
## and how wide (times her brows' half-width).
static var LAB_FRONT := 0.5
static var LAB_WIDTH := 1.3
## How far in front of her forehead (metres at size 1) hair still counts as fringe.
static var LAB_AHEAD := 0.08
static var LAB_DEBUG := false
## The princesses' swoop (metres at size 1): x how far below her eyes and y how far to either side
## its hair is looked for, z how far below her eyes its end may be, w how far round each step
## the hair furthest out is looked for.
static var LAB_SWOOP := Vector4(0.18, 0.3, 0.14, 0.05)
## Clearing the swoop's hair (metres at size 1): x the brush's half-width, y the gap left.
static var LAB_CLEAR := Vector2(0.035, 0.008)
## Where the stroke starts, beside her horn: out to the side and up from her forehead bone
## (metres at size 1).
static var LAB_TOP := Vector2(0.035, 0.04)
## Where it ends: up from her brow (metres at size 1).
static var LAB_BROW := 0.012

## Her pose reader's name under her skeleton (main.gd adds it).
const READER := "IdleLifePoseReader"
const BONES := ["mHead", "mEyeLeft", "mEyeRight", "mFaceEar1Left", "mFaceEar1Right", "mFaceForeheadCenter",
	"mFaceEyebrowCenterLeft", "mFaceEyebrowCenterRight", "mFaceEyebrowOuterLeft", "mFaceEyebrowOuterRight"]


static func find(pony: Node3D) -> Dictionary:
	var head_node: Variant = pony.get("head")
	var hk: Skeleton3D = head_node.get("skeleton") if head_node != null else null
	if hk == null: return {}
	var world := {}
	for b: String in BONES:
		var i := hk.find_bone(b)
		if i < 0: return {}
		world[b] = hk.global_transform * hk.get_bone_global_pose(i).origin
	# Everything in her face's own frame (she may be looking aside): x toward her right eye, y up
	# her face, -z out of it, from the middle of her skull.
	var right := (Vector3(world.mEyeRight) - Vector3(world.mEyeLeft)).normalized()
	var ahead: Vector3 = (Vector3(world.mEyeLeft) + world.mEyeRight - world.mFaceEar1Left - world.mFaceEar1Right) * 0.5
	ahead = (ahead - right * ahead.dot(right)).normalized()
	if right.is_zero_approx() or ahead.is_zero_approx(): return {}
	var face_basis := Basis(right, (-ahead).cross(right), -ahead)
	var face := Transform3D(face_basis, (Vector3(world.mEyeLeft) + world.mEyeRight + world.mFaceEar1Left + world.mFaceEar1Right) / 4.0)
	var inv := face.affine_inverse()
	var at := {}   # bone -> face frame
	for b: String in BONES: at[b] = inv * Vector3(world[b])
	var to_head := head_frame(pony).affine_inverse() * face
	var centre: Vector3 = (Vector3(at.mEyeLeft) + at.mEyeRight + at.mFaceEar1Left + at.mFaceEar1Right) / 4.0
	var forehead: Vector3 = at.mFaceForeheadCenter
	var eye_y := (float(at.mEyeLeft.y) + float(at.mEyeRight.y)) * 0.5
	var size := (Vector3(at.mEyeLeft) - Vector3(at.mEyeRight)).length() / 0.14
	var width := maxf(absf(float(at.mFaceEyebrowOuterLeft.x)), absf(float(at.mFaceEyebrowOuterRight.x))) * LAB_WIDTH
	if pony.scene_file_path.contains("/princesses/"): return _swoop(pony, inv, at, centre, size, eye_y, to_head)
	var front_z := lerpf(forehead.z, float(at.mHead.z), LAB_FRONT)
	var points := _hair(pony, inv, eye_y, Vector2(forehead.z - LAB_AHEAD * size, front_z), width)
	if LAB_DEBUG: print("FRINGE points=", points.size(), " eye_y=", eye_y, " forehead=", forehead, " size=", size)
	if points.size() < MIN_POINTS: return {}
	var lean := 0.0
	for p in points: lean += p.x
	lean /= points.size()
	var side := signf(lean) if absf(lean) >= EVEN * size else 0.0
	var out := {"side": side, "size": size, "strokes": {}, "points": points}
	var cone := cos(deg_to_rad(CONE_DEG))
	for s: float in ([side] if side != 0.0 else [1.0, -1.0]):
		# Her "Left" bones lie on her -x side.
		var brow: Vector3 = at.mFaceEyebrowCenterRight if s > 0.0 else at.mFaceEyebrowCenterLeft
		var top := forehead + Vector3(s * LAB_TOP.x, LAB_TOP.y, 0.0) * size
		var low := brow + Vector3.UP * LAB_BROW * size
		var path: Array[Vector3] = []
		var hits := 0
		for k in STEPS:
			var on := top.lerp(low, float(k) / (STEPS - 1))
			var dir := (on - centre).normalized()
			var reach := (on - centre).length()
			for p in points:
				var to := p - centre
				var d := to.length()
				if d > reach and to.dot(dir) > cone * d: reach = d; hits += 1
			path.append(to_head * (centre + dir * (reach + ABOVE * size)))
		if LAB_DEBUG: print("FRINGE side ", s, " hits=", hits)
		if hits == 0: continue
		out.strokes[s] = path
	if (out.strokes as Dictionary).is_empty(): return {}
	return out


## The princesses' fringe is the swoop of mane over one side of the face: the stroke runs from
## beside the horn out along the swoop's outside. Its points after the first are hair points,
## each held by the bone it is skinned to ([skeleton, bone, place in the bone's frame]), so the
## stroke follows the swoop as it flows.
static func _swoop(pony: Node3D, inv: Transform3D, at: Dictionary, centre: Vector3, size: float, eye_y: float, to_head: Transform3D) -> Dictionary:
	var forehead: Vector3 = at.mFaceForeheadCenter
	var points: Array[Vector3] = []
	var holds: Array = []
	_sample(pony, inv, points, holds)
	# Hair in front of her face's middle and above her chin.
	var front: Array[int] = []
	for i in points.size():
		var p := points[i]
		if p.z < centre.z + 0.05 * size and p.y > eye_y - LAB_SWOOP.x * size and absf(p.x) < LAB_SWOOP.y * size: front.append(i)
	if LAB_DEBUG: print("SWOOP all=", points.size(), " front=", front.size(), " centre=", centre, " eye_y=", eye_y, " size=", size)
	if front.size() < MIN_POINTS: return {}
	var lean := 0.0
	for i in front: lean += points[i].x
	lean /= front.size()
	var side := signf(lean) if absf(lean) >= EVEN * size else 1.0
	var start := forehead + Vector3(side * LAB_TOP.x * 1.4, LAB_TOP.y * 1.6, 0.0) * size
	# The swoop's end: the hair standing out furthest on her side, at about the height of her eyes
	# down to her cheek.
	var end := -1
	for i in front:
		var p := points[i]
		if p.y < eye_y - LAB_SWOOP.z * size or p.y > eye_y + 0.03 * size or p.z > centre.z + 0.05 * size: continue
		if end < 0 or p.x * side > points[end].x * side: end = i
	if end < 0: return {}
	if LAB_DEBUG: print("SWOOP side=", side, " start=", start, " end=", points[end])
	# Each step along the way: the hair furthest out from her skull near that point.
	var path: Array = [to_head * start]
	var placed: Array[Vector3] = [start]
	var reach := LAB_SWOOP.w * size
	for k in range(1, STEPS):
		var want := start.lerp(points[end], float(k) / (STEPS - 1))
		var best := -1
		var out := -1.0
		for i in front:
			if points[i].distance_to(want) > reach: continue
			var d := points[i].distance_to(centre)
			if d > out: out = d; best = i
		if best >= 0: path.append(holds[best]); placed.append(points[best])
		else: path.append(to_head * want); placed.append(want)
	# Her mane is thick: how far each stroke point must stand further out (from the middle of her
	# skull) to clear all of it, the brush's width either side.
	var clear: Array[float] = []
	var width := LAB_CLEAR.x * size
	for p in placed:
		var n := (p - centre).normalized()
		var most := 0.0
		for q in points:
			var to := q - p
			var along := to.dot(n)
			if along <= most: continue
			if (to - n * along).length() < width: most = along
		clear.append(most + LAB_CLEAR.y * size)
	return {"side": side, "size": size, "strokes": {side: path}, "clear": {side: clear}, "points": front.map(func(i: int) -> Vector3: return points[i])}


## Every sampled mane hair point (face frame), with what holds it.
static func _sample(pony: Node3D, inv: Transform3D, points: Array[Vector3], holds: Array) -> void:
	var hair_sk: Variant = pony.get("hair_skeleton")
	var sk: Skeleton3D = pony.get("skeleton")
	for node: Node in pony.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var lower := String(mi.name).to_lower()
		if not "mane" in lower or "lod" in lower or mi.mesh == null or mi.skin == null: continue
		var bones: Skeleton3D = hair_sk if hair_sk is Skeleton3D and (hair_sk as Skeleton3D).is_ancestor_of(mi) else sk
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vb: Variant = arrays[Mesh.ARRAY_BONES]
			var vw: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if vb == null or vw == null or (vb as PackedInt32Array).size() < verts.size(): continue
			var per := (vb as PackedInt32Array).size() / verts.size()
			for v in range(0, verts.size(), 2):
				var main := 0
				var weight := -1.0
				for k in per:
					if vw[v * per + k] > weight: weight = vw[v * per + k]; main = vb[v * per + k]
				if main >= mi.skin.get_bind_count(): continue
				var b := mi.skin.get_bind_bone(main)
				if b < 0: b = bones.find_bone(mi.skin.get_bind_name(main))
				if b < 0: continue
				var local := mi.skin.get_bind_pose(main) * verts[v]
				points.append(inv * (bones.global_transform * pose(bones, b) * local))
				holds.append([bones, b, local])


## A stroke point now (world): held by a hair bone ([skeleton, bone, place]) or fixed in her
## "mHead" frame (Vector3).
static func spot(pony: Node3D, entry: Variant) -> Vector3:
	if entry is Vector3: return head_frame(pony) * Vector3(entry)
	var hold: Array = entry
	var bones: Skeleton3D = hold[0]
	if not is_instance_valid(bones): return head_frame(pony).origin
	return bones.global_transform * pose(bones, int(hold[1])) * Vector3(hold[2])


## A bone's global pose as drawn: from her pose reader (pose_reader.gd) when she has one, else
## the skeleton's own (before its modifiers).
static func pose(bones: Skeleton3D, bone: int) -> Transform3D:
	var reader := bones.get_node_or_null(READER)
	if reader != null:
		var poses: Array = reader.get("poses")
		if bone < poses.size(): return poses[bone]
	return bones.get_bone_global_pose(bone)


## Mane hair over her forehead (face frame): above her eyes, in the front part of her head (not
## hanging out far in front of it, as a princess' flowing mane may), no wider than her brows.
static func _hair(pony: Node3D, inv: Transform3D, eye_y: float, span_z: Vector2, width: float) -> Array[Vector3]:
	var hair_sk: Variant = pony.get("hair_skeleton")
	var sk: Skeleton3D = pony.get("skeleton")
	var points: Array[Vector3] = []
	for node: Node in pony.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var lower := String(mi.name).to_lower()
		if not "mane" in lower or "lod" in lower or mi.mesh == null or mi.skin == null: continue
		var bones: Skeleton3D = hair_sk if hair_sk is Skeleton3D and (hair_sk as Skeleton3D).is_ancestor_of(mi) else sk
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vb: Variant = arrays[Mesh.ARRAY_BONES]
			var vw: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if vb == null or vw == null or (vb as PackedInt32Array).size() < verts.size(): continue
			var per := (vb as PackedInt32Array).size() / verts.size()
			for v in range(0, verts.size(), 2):
				var main := 0
				var weight := -1.0
				for k in per:
					if vw[v * per + k] > weight: weight = vw[v * per + k]; main = vb[v * per + k]
				if main >= mi.skin.get_bind_count(): continue
				var b := mi.skin.get_bind_bone(main)
				if b < 0: b = bones.find_bone(mi.skin.get_bind_name(main))
				if b < 0: continue
				var p := inv * (bones.global_transform * bones.get_bone_global_pose(b) * mi.skin.get_bind_pose(main) * verts[v])
				if p.y < eye_y or p.z < span_z.x or p.z > span_z.y or absf(p.x) > width: continue
				points.append(p)
	return points


## Her head model's "mHead" frame now (the stroke's frame).
static func head_frame(pony: Node3D) -> Transform3D:
	var head_node: Variant = pony.get("head")
	var hk: Skeleton3D = head_node.get("skeleton") if head_node != null else null
	var i := hk.find_bone("mHead") if hk != null else -1
	return hk.global_transform * hk.get_bone_global_pose(i) if i >= 0 else pony.global_transform


## The middle of her skull now (between her eyes and her ears).
static func centre(pony: Node3D) -> Vector3:
	var head_node: Variant = pony.get("head")
	var hk: Skeleton3D = head_node.get("skeleton") if head_node != null else null
	if hk == null: return pony.global_position
	var sum := Vector3.ZERO
	for b in ["mEyeLeft", "mEyeRight", "mFaceEar1Left", "mFaceEar1Right"]:
		var i := hk.find_bone(b)
		if i < 0: return pony.global_position
		sum += hk.global_transform * hk.get_bone_global_pose(i).origin
	return sum / 4.0
