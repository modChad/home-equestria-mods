extends RefCounted
## The shoe check's shoe. A princess's four shoes are one surface of her body mesh (NearBody), so
## one shoe is taken off by swapping in a copy of that mesh without its triangles (made once per
## mesh and side, then kept), and drawn instead as a mesh of its own, posed exactly as it was on
## her hoof when it came off. Putting it back swaps her own mesh back in.

## The bones a front shoe follows (its vertices' strongest weight), per side.
const FRONT_BONES := ["pony_finger", "pony_hand"]
## The bone the floating shoe is placed from while it is on her hoof.
const HOLD_BONE := "pony_finger"

## mesh instance id + side -> her body mesh without that shoe
static var _without: Dictionary = {}


## Her body mesh (NearBody), or null.
static func body(pony: Node) -> MeshInstance3D:
	var found := pony.find_child("NearBody", true, false)
	return found as MeshInstance3D if found is MeshInstance3D else null


## The surface of her body mesh drawn with her shoes' texture, or -1.
static func shoe_surface(near: MeshInstance3D) -> int:
	if near == null or near.mesh == null: return -1
	for s in near.mesh.get_surface_count():
		var mat := near.get_active_material(s)
		var tex: Variant = null
		if mat is StandardMaterial3D: tex = (mat as StandardMaterial3D).albedo_texture
		elif mat is ShaderMaterial:
			for p: String in ["albedo_texture", "texture_albedo", "albedo", "base_texture"]:
				var v: Variant = (mat as ShaderMaterial).get_shader_parameter(p)
				if v is Texture2D: tex = v
		if tex is Texture2D and str((tex as Texture2D).resource_path).get_file().contains("shoes"): return s
	return -1


## Which of her skin's binds each of `names` (bone names + side) is, as a set of bind indices.
static func _binds(near: MeshInstance3D, sk: Skeleton3D, names: Array) -> Dictionary:
	var out := {}
	var skin := near.skin
	if skin == null: return out
	for i in skin.get_bind_count():
		var n := str(skin.get_bind_name(i))
		if n.is_empty() and skin.get_bind_bone(i) >= 0: n = sk.get_bone_name(skin.get_bind_bone(i))
		if n in names: out[i] = true
	return out


## The triangles (index triples) of the shoe surface whose vertices all mostly follow one of the
## side's front-shoe bones.
static func _shoe_triangles(arrays: Array, binds: Dictionary) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / maxi(verts.size(), 1)
	var mine := PackedByteArray()
	mine.resize(verts.size())
	for v in verts.size():
		var best := -1
		var bw := -1.0
		for k in per:
			if weights[v * per + k] > bw:
				bw = weights[v * per + k]
				best = bones[v * per + k]
		mine[v] = 1 if binds.has(best) else 0
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	var shoe := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		if mine[a] == 1 and mine[b] == 1 and mine[c] == 1: shoe.append_array([a, b, c])
		else: keep.append_array([a, b, c])
	return {"keep": keep, "shoe": shoe}


## Her body mesh without the front shoe on `side` ("_L" / "_R"), made once. Null if her mesh
## has no shoes or isn't indexed.
static func mesh_without(near: MeshInstance3D, sk: Skeleton3D, side: String) -> ArrayMesh:
	var key := "%d%s" % [near.mesh.get_instance_id(), side]
	if _without.has(key): return _without[key]
	var surface := shoe_surface(near)
	if surface < 0 or not near.mesh is ArrayMesh: return null
	var source := near.mesh as ArrayMesh
	var names := []
	for b: String in FRONT_BONES: names.append(b + side)
	var binds := _binds(near, sk, names)
	var made := ArrayMesh.new()
	made.blend_shape_mode = source.blend_shape_mode
	for i in source.get_blend_shape_count(): made.add_blend_shape(source.get_blend_shape_name(i))
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		if s == surface:
			if arrays[Mesh.ARRAY_INDEX] == null: return null
			arrays[Mesh.ARRAY_INDEX] = _shoe_triangles(arrays, binds).keep
		var blends := source.surface_get_blend_shape_arrays(s)
		# Keep the surface's custom-data formats and bone count; let the rest be worked out again.
		var keep_bits: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		for c in 4: keep_bits |= Mesh.ARRAY_FORMAT_CUSTOM_MASK << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + c * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
		var flags := source.surface_get_format(s) & keep_bits
		made.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays, blends, {}, flags)
		made.surface_set_material(s, source.surface_get_material(s))
		made.surface_set_name(s, source.surface_get_name(s))
	_without[key] = made
	return made


## The front shoe on `side` as a mesh of its own, posed as it is on her hoof right now, in the
## space of her HOLD_BONE (so placed at that bone's transform it sits exactly where it was).
static func loose_shoe(near: MeshInstance3D, sk: Skeleton3D, side: String) -> MeshInstance3D:
	var surface := shoe_surface(near)
	var hold := sk.find_bone(HOLD_BONE + side)
	if surface < 0 or hold < 0 or near.skin == null: return null
	var arrays := near.mesh.surface_get_arrays(surface)
	var names := []
	for b: String in FRONT_BONES: names.append(b + side)
	var tris: PackedInt32Array = _shoe_triangles(arrays, _binds(near, sk, names)).shoe
	if tris.is_empty(): return null
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / maxi(verts.size(), 1)
	var skin := near.skin
	# Each bind's skinning transform as she stands now: bone pose * bind pose.
	var skinning := {}
	var to_hold := sk.get_bone_global_pose(hold).affine_inverse()
	var remap := {}
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_i := PackedInt32Array()
	for idx in tris:
		if not remap.has(idx):
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in per:
				var w := weights[idx * per + k]
				if w <= 0.0: continue
				var bind := bones[idx * per + k]
				if not skinning.has(bind):
					var bone := skin.get_bind_bone(bind)
					if bone < 0: bone = sk.find_bone(skin.get_bind_name(bind))
					skinning[bind] = sk.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
				var m: Transform3D = skinning[bind]
				p += (m * verts[idx]) * w
				n += (m.basis * normals[idx]) * w
			remap[idx] = out_v.size()
			out_v.append(to_hold * p)
			out_n.append((to_hold.basis * n).normalized())
			out_uv.append(uvs[idx] if uvs.size() > idx else Vector2.ZERO)
		out_i.append(remap[idx])
	var shoe_arrays := []
	shoe_arrays.resize(Mesh.ARRAY_MAX)
	shoe_arrays[Mesh.ARRAY_VERTEX] = out_v
	shoe_arrays[Mesh.ARRAY_NORMAL] = out_n
	shoe_arrays[Mesh.ARRAY_TEX_UV] = out_uv
	shoe_arrays[Mesh.ARRAY_INDEX] = out_i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shoe_arrays)
	var mi := MeshInstance3D.new()
	mi.name = "IdleLifeShoe"
	mi.mesh = mesh
	mi.material_override = near.get_active_material(surface)
	return mi


## Where HOLD_BONE + side is now, in the world (the loose shoe's transform while on her hoof).
static func on_hoof(sk: Skeleton3D, side: String) -> Transform3D:
	var hold := sk.find_bone(HOLD_BONE + side)
	return sk.global_transform * sk.get_bone_global_pose(hold) if hold >= 0 else sk.global_transform
