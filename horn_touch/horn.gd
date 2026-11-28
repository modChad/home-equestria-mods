extends RefCounted
## Horn Touch helpers: who the mod may touch at all, and where her horn is.
const PLAYER_FORM := preload("res://world/life/player_form.gd")
const BONDS := preload("res://world/relationships/player_bonds.gd")
const HULL_REGION := "head_Unicorn Horn" # pony_touch_body.gd role of the horn's fitted hull.


## Hard block: only grown unicorns and alicorns, never fillies or colts, never a young player,
## and only ponies the relationship system itself counts as adults.
static func eligible(pony: Node) -> bool:
	if not is_instance_valid(pony) or not pony.is_inside_tree(): return false
	var identity: Resource = pony.get("identity")
	if identity == null or not identity.has_horn() or bool(identity.get("filly")): return false
	if young_player(pony): return false
	var bonds: Object = bonds_of(pony)
	if bonds != null:
		var adults: Variant = bonds.get("adults")
		if adults is Dictionary and not bool((adults as Dictionary).get(pony_id(pony), false)): return false
	return true


static func young_player(node: Node) -> bool:
	return node.is_inside_tree() and PLAYER_FORM.is_young(PLAYER_FORM.active(node.get_tree()))


static func alicorn(pony: Node) -> bool:
	var identity: Resource = pony.get("identity")
	return identity != null and identity.has_horn() and identity.has_wings()


static func pony_id(pony: Node) -> String:
	return str(pony.get_meta("relationship_id", ""))


static func runtime_of(pony: Node) -> Object:
	return pony.get_meta("relationship_runtime") if pony.has_meta("relationship_runtime") else null


static func bonds_of(pony: Node) -> Object:
	var runtime: Object = runtime_of(pony)
	return runtime.get("bonds") if runtime != null else null


## Her stage with Anon as an index into player_bonds STAGES (acquaintance 0 .. married 5).
static func stage(pony: Node) -> int:
	var bonds: Object = bonds_of(pony)
	var id := pony_id(pony)
	if bonds == null or id.is_empty(): return 0
	var record: Dictionary = bonds.record_for(id)
	return maxi(0, BONDS.STAGES.find(str(record.get("stage", "acquaintance"))))


## Angry at him right now (pony_impressions mood): even a close friend won't have it.
static func angry(pony: Node) -> bool:
	var bonds: Object = bonds_of(pony)
	var context: Variant = bonds.get("context") if bonds != null else null
	if not context is Object or not is_instance_valid(context): return false
	var impressions: Variant = (context as Object).get("impressions")
	if not impressions is Object or not is_instance_valid(impressions): return false
	return str((impressions as Object).profile(pony_id(pony)).get("mood", "neutral")) == "angry"


## Her horn's base and tip in world space, [] when she has none or it isn't built yet.
## Princesses wear a horn fitted into their body export (princess_hybrid.gd hides the head's own
## "Unicorn Horn", and pony_touch_body fits no hull to theirs): that one is measured here, the same
## way the horn magic (unicorn_magic.gd _measure_horn) measures the head horn it uses otherwise.
static func segment(pony: Node) -> Array:
	var fitted: Dictionary = _fitted(pony)
	if not fitted.is_empty():
		if fitted.has("node"):
			var node: Node3D = fitted.node
			if is_instance_valid(node): return [node.global_transform * Vector3(fitted.base), node.global_transform * Vector3(fitted.tip)]
			return []
		var sk: Skeleton3D = fitted.skeleton
		if is_instance_valid(sk):
			var world: Transform3D = sk.global_transform * sk.get_bone_global_pose(int(fitted.bone))
			return [world * Vector3(fitted.base), world * Vector3(fitted.tip)]
	var magic: Node = pony.get("magic")
	if not is_instance_valid(magic) or not magic.has_method("_build") or not magic.call("_build"): return []
	var skeleton: Skeleton3D = magic.get("_skeleton")
	var bone: int = int(magic.get("_bone"))
	if not is_instance_valid(skeleton) or bone < 0: return []
	var bone_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return [bone_world * Vector3(magic.get("_base_local")), bone_world * Vector3(magic.get("_tip_local"))]


## True when her visible horn is a fitted one with no touch hull (Celestia, Luna).
static func fitted(pony: Node) -> bool:
	return not _fitted(pony).is_empty()


## Cached on her: {} for an ordinary head horn, else {skeleton, bone, base, tip}.
static func _fitted(pony: Node) -> Dictionary:
	if pony.has_meta("horn_touch_fitted"): return pony.get_meta("horn_touch_fitted")
	var found := {}
	if pony.get("_model") == null: return found # Not built yet: look again later.
	# Anywhere on her but the OpenPony head (whose own "Unicorn Horn" the princesses hide).
	var head: Variant = pony.get("head")
	for mi: MeshInstance3D in pony.find_children("*", "MeshInstance3D", true, false):
		if not "horn" in String(mi.name).to_lower() or String(mi.name) == "Unicorn Horn": continue
		if head is Node and ((head as Node) == mi or (head as Node).is_ancestor_of(mi)): continue
		found = _measure(mi)
		if not found.is_empty(): break
	pony.set_meta("horn_touch_fitted", found)
	return found


static func _measure(horn: MeshInstance3D) -> Dictionary:
	if horn.mesh == null: return {}
	var arrays := horn.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ends := _ends(horn.mesh.get_aabb(), verts)
	# Not skinned (a rigid prop on a bone attachment): its own transform carries it.
	if horn.skin == null: return {"node": horn, "base": ends[0], "tip": ends[1]}
	var skeleton := horn.get_node_or_null(horn.skeleton) as Skeleton3D
	if skeleton == null: return {"node": horn, "base": ends[0], "tip": ends[1]}
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones.is_empty(): return {}
	var totals := {}
	for i in bones.size(): totals[bones[i]] = float(totals.get(bones[i], 0.0)) + weights[i]
	var bind := 0
	for b: int in totals:
		if float(totals[b]) > float(totals.get(bind, -1.0)): bind = b
	var bone := horn.skin.get_bind_bone(bind)
	if bone < 0: bone = skeleton.find_bone(horn.skin.get_bind_name(bind))
	if bone < 0: return {}
	var to_bone := horn.skin.get_bind_pose(bind)
	return {"skeleton": skeleton, "bone": bone, "base": to_bone * Vector3(ends[0]), "tip": to_bone * Vector3(ends[1])}


## Base: the middle of the lowest fifth; tip: the vertex furthest from it.
static func _ends(aabb: AABB, verts: PackedVector3Array) -> Array:
	var cut := aabb.position.y + aabb.size.y * 0.2
	var base := Vector3.ZERO
	var count := 0
	for v in verts:
		if v.y <= cut: base += v; count += 1
	base /= maxf(count, 1)
	var tip := base
	for v in verts:
		if v.distance_squared_to(base) > tip.distance_squared_to(base): tip = v
	return [base, tip]


## A click ray against her horn: {point, normal, distance (along the ray)} or {}. The point is on
## the horn's surface facing him, kept between 15% and 85% of its length so the hand rests on the
## horn itself, never floating past its tip or sinking into her forelock.
const SURFACE := 0.012 # Rough horn radius at mid length, metres at Canon size.
static func pick(pony: Node, from: Vector3, to: Vector3, radius: float) -> Dictionary:
	var seg := segment(pony)
	if seg.is_empty(): return {}
	var base: Vector3 = seg[0]
	var tip: Vector3 = seg[1]
	var closest := Geometry3D.get_closest_points_between_segments(from, to, base, tip)
	var on_ray: Vector3 = closest[0]
	var size := float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0
	if on_ray.distance_to(closest[1]) > radius * size: return {}
	var axis := (tip - base)
	var t := clampf((Vector3(closest[1]) - base).dot(axis) / maxf(axis.length_squared(), 1e-6), .15, .85)
	var hit := at(pony, t, from)
	hit.distance = from.distance_to(on_ray)
	return hit


## The spot `t` (0 base .. 1 tip) along her horn, on the side facing `eye`: {point, normal, t},
## or {} without a horn. A held hand follows this as her head moves.
static func at(pony: Node, t: float, eye: Vector3) -> Dictionary:
	var seg := segment(pony)
	if seg.is_empty(): return {}
	var base: Vector3 = seg[0]
	var axis: Vector3 = Vector3(seg[1]) - base
	var size := float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0
	var on_horn := base + axis * clampf(t, .15, .85)
	# Out from the horn toward his eye, square to the horn.
	var dir := axis.normalized()
	var out := eye - on_horn
	out -= dir * out.dot(dir)
	var normal := out.normalized() if out.length() > 1e-4 else Vector3.UP
	return {"point": on_horn + normal * SURFACE * size, "normal": normal, "t": clampf(t, .15, .85)}


## Distance from `point` to the horn segment, INF when there is no horn.
static func distance(pony: Node, point: Vector3) -> float:
	var seg := segment(pony)
	if seg.is_empty(): return INF
	return point.distance_to(Geometry3D.get_closest_point_to_segment(point, seg[0], seg[1]))


static func color(pony: Node) -> Color:
	var magic: Node = pony.get("magic")
	var c: Color = magic.get("color") if is_instance_valid(magic) else Color(0.92, 0.26, 0.55)
	return UnicornMagic.vivid(c)
