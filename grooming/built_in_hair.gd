extends RefCounted
## Ponies whose mane, tail and wings are part of the body model (the princesses,
## world/characters/princesses/<id>_body.glb) rather than the separate devkit hair and feathered
## wings ordinary ponies wear. The game's touch body only fits hulls to devkit hair, and the spa's
## stray feathers only pin onto per-feather wing bones, so for these ponies the mod brings its own:
##   - hair_hit(): the mane and tail as a cloud of points (sampled from their meshes, each held in
##     its main bone's frame so it follows her), hit-tested along a ray.
##   - scatter_feathers(): stray feathers pinned onto her open wings where they are drawn.
## Ordinary ponies never reach either: the game's own hulls and feathers are used for them.

const FEATHERS := preload("res://world/minigames/spa/spa_feathers.gd")
## Points kept per hair mesh (sampled evenly).
const MAX_POINTS := 900
## How close a ray must pass to a hair point to touch it (metres, at body scale 1).
const RADIUS := 0.045
const CROOKED_DEG := Vector2(28.0, 48.0)
## An ordinary pony's open wing, root to tip (metres at body scale 1): stray feathers are sized for it.
const ORDINARY_WING := 0.45

## pony -> {"has_hulls": bool, "points": [[skeleton bone, local Vector3, "mane"|"tail"], ...]}
var _cache: Dictionary = {}


## True when the game's touch body already has mane and tail hulls for her.
func _has_hulls(pony: Node, touch: Node) -> bool:
	var entries: Variant = touch.get("_entries")
	if not entries is Array or (entries as Array).is_empty(): return true   # not fitted yet: wait
	for e: Variant in entries:
		if e is Dictionary and str((e as Dictionary).get("region", "")) in ["mane", "tail"]: return true
	return false


func _row(pony: Node3D) -> Dictionary:
	if _cache.has(pony): return _cache[pony]
	var row := {"points": []}
	var model: Node = pony.get("_model")
	var skeleton: Skeleton3D = pony.get("skeleton")
	if model != null and skeleton != null:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var lower := String(mi.name).to_lower()
			var part := "tail" if "tail" in lower else ("mane" if "mane" in lower else "")
			if part.is_empty() or mi.mesh == null or mi.skin == null: continue
			(row.points as Array).append_array(_sample(mi, skeleton, part))
	_cache[pony] = row
	pony.tree_exiting.connect(func() -> void: _cache.erase(pony), CONNECT_ONE_SHOT)
	return row


## Mesh vertices, each as its main bone plus its place in that bone's rest frame.
static func _sample(mi: MeshInstance3D, skeleton: Skeleton3D, part: String) -> Array:
	var out := []
	var skin := mi.skin
	var total := 0
	for surface in mi.mesh.get_surface_count(): total += mi.mesh.surface_get_array_len(surface)
	var every := maxi(1, total / MAX_POINTS)
	for surface in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var vb: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var vw: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if verts.is_empty() or vb.size() < verts.size(): continue
		var per := vb.size() / verts.size()
		for v in range(0, verts.size(), every):
			var main := -1
			var weight := 0.0
			for k in per:
				if vw[v * per + k] > weight: weight = vw[v * per + k]; main = vb[v * per + k]
			if main < 0 or main >= skin.get_bind_count(): continue
			var bone := skin.get_bind_bone(main)
			if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(main))
			if bone < 0: continue
			out.append([bone, skin.get_bind_pose(main) * verts[v], part])
	return out


## The mane or tail point nearest along the ray from `from` to `to`, within reach of it.
## {target, point, normal, region, visible_pick} or {}.
func hair_hit(pony: Node3D, from: Vector3, to: Vector3, radius_scale: float = 1.0) -> Dictionary:
	var touch: Node = pony.get("touch_body")
	if touch != null and _has_hulls(pony, touch): return {}
	var row := _row(pony)
	if (row.points as Array).is_empty(): return {}
	var skeleton: Skeleton3D = pony.get("skeleton")
	var size := float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0
	var radius := RADIUS * size * radius_scale
	var ray := to - from
	var length := ray.length()
	if length < 0.0001: return {}
	var dir := ray / length
	var frames := {}
	var best := {}
	var best_along := INF
	for p: Array in row.points:
		var bone: int = p[0]
		if not frames.has(bone): frames[bone] = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var at: Vector3 = (frames[bone] as Transform3D) * Vector3(p[1])
		var along := (at - from).dot(dir)
		if along < 0.0 or along > length or along >= best_along: continue
		if (from + dir * along).distance_to(at) > radius: continue
		best_along = along
		best = {"target": pony, "point": at, "normal": -dir, "region": p[2], "visible_pick": true}
	return best


## Pins `count` stray feathers across her open wings, where the wings are drawn: the game's own
## touch hulls follow her wings' held-open pose, so rays cast down onto them find the upper surface.
## Spots 30-68% of the way from the wing root to its tip (the solid part of the wing: the hulls run
## a little past the feather tips), spread apart, half on each wing. Each feather is held by a
## small node under her skeleton (the wings stay still while she is preened).
## Empty while the hulls for her open wings are still being fitted: call again a moment later.
static func scatter_feathers(pony: Node3D, count: int, rng: RandomNumberGenerator) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var touch: Node = pony.get("touch_body")
	if touch == null or not touch.has_method("desktop_offer"): return out
	# Wake the hulls, and wait for the ones fitted to her open wings (her folded wings' hulls lie
	# along her sides).
	touch.desktop_offer(pony.global_position + Vector3.UP * 3.0, pony.global_position)
	var installed: Variant = touch.get("_installed_key")
	if installed is String and not (installed as String).ends_with("open"): return out
	var size := float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0
	var frame := pony.global_transform.orthonormalized()
	var skeleton: Skeleton3D = pony.get("skeleton") as Skeleton3D
	if skeleton == null: return out
	# Rays onto her wings from above and from each side, over a grid as wide as a princess'
	# wingspan; held open, a wing may stand nearly upright, so its outer face counts as well as
	# its top. Kept: hits on a wing whose surface faces the ray.
	var spots := {"_L": [], "_R": []}
	var step := 0.07 * size
	var rays: Array = []
	var a := -2.2 * size
	while a <= 2.2 * size:
		var z := -1.4 * size
		while z <= 1.4 * size:
			rays.append([Vector3(a, 3.6 * size, z), Vector3(a, 0.2 * size, z)])
			if a >= 0.2 * size:   # a: height here
				rays.append([Vector3(2.6 * size, a, z), Vector3(0.0, a, z)])
				rays.append([Vector3(-2.6 * size, a, z), Vector3(0.0, a, z)])
			z += step
		a += step
	for ray: Array in rays:
		var from: Vector3 = frame * Vector3(ray[0])
		var to: Vector3 = frame * Vector3(ray[1])
		var hit: Dictionary = touch.desktop_offer(from, to)
		if hit.is_empty() or str(hit.get("region", "")) != "wing": continue
		if Vector3(hit.normal).dot((from - to).normalized()) < 0.3: continue
		var local := frame.affine_inverse() * Vector3(hit.point)
		(spots["_L" if local.x > 0.0 else "_R"] as Array).append({"at": Vector3(hit.point), "local": local, "normal": Vector3(hit.normal).normalized()})
	var coat := FEATHERS.coat_of(pony)
	var sides := ["_L", "_R"]
	var placed: Array[Vector3] = []
	for n in count:
		var list: Array = spots[sides[n % 2]]
		if list.size() < 8: continue
		# The open wing is the upper part of what the rays met (lower down is her side), and its
		# root the part of that nearest her middle.
		var low := INF
		var high := -INF
		for s: Dictionary in list: low = minf(low, (s.local as Vector3).y); high = maxf(high, (s.local as Vector3).y)
		var wing: Array = list.filter(func(s: Dictionary) -> bool: return (s.local as Vector3).y >= lerpf(low, high, 0.45))
		var root := Vector3.INF
		var root_gap := INF
		for s: Dictionary in wing:
			if absf((s.local as Vector3).x) < root_gap: root_gap = absf((s.local as Vector3).x); root = s.at
		list = wing
		var reach := 0.0
		for s: Dictionary in list: reach = maxf(reach, (s.at as Vector3).distance_to(root))
		var pick := {}
		for attempt in 60:
			var s: Dictionary = list[rng.randi_range(0, list.size() - 1)]
			var d := (s.at as Vector3).distance_to(root)
			if d < reach * 0.3 or d > reach * 0.68: continue
			var apart := true
			for other in placed:
				if other.distance_to(s.at) < reach * 0.14: apart = false; break
			if apart: pick = s; break
		if pick.is_empty(): continue
		var feather := FEATHERS.load_prop(FEATHERS.FEATHER)
		if feather == null: break
		placed.append(pick.at)
		var up: Vector3 = pick.normal
		var along := ((pick.at as Vector3) - root)
		along = (along - up * along.dot(up)).normalized()
		var crooked := deg_to_rad(rng.randf_range(CROOKED_DEG.x, CROOKED_DEG.y)) * (1.0 if n % 2 == 0 else -1.0)
		var direction := (along.rotated(up, crooked) + up * 0.3).normalized()
		# Her wings are far bigger than an ordinary pony's: the feather grows with them.
		var grow := clampf(reach / (ORDINARY_WING * size), 1.0, 4.0)
		var holder := Node3D.new()
		holder.name = "SpaStrayFeather_%d" % n
		holder.set_meta("spa_mount", true)
		# Under her skeleton, which carries the drawn body (her root can drift from it as she settles).
		skeleton.add_child(holder, true)
		holder.global_transform = Transform3D(Basis.IDENTITY, pick.at + up * 0.01 * size)
		holder.add_child(feather)
		feather.global_transform = Transform3D(Basis.looking_at(direction, up).scaled(Vector3.ONE * size * grow), holder.global_position)
		FEATHERS.tint(feather, coat.lerp(Color.WHITE, 0.08))
		feather.set_meta("spa_feather_bone", "")
		out.append(feather)
	return out
