extends SceneTree
## Optimare (modChad): reduces chosen meshes in the game's own models with Godot's simplifier
## (meshoptimizer via ImporterMesh.generate_lods, the nearest step to each target) and writes them
## under STAGE at the game path each one replaces (an imported .glb's .godot/imported scene).
## Index-only: every vertex is kept, so anything keyed to vertex indices still lines up.
## Run from the project root:
##   godot --headless --xr-mode off --path . --script res://mods/optimare/tools/reduce.gd
## then tools/pack.gd. Prints one row per mesh to res://build/optimare/report.tsv.
const STAGE := "res://build/optimare/stage/"
## model -> {mesh node name: fraction of its triangles to keep}
const TARGETS := {
	"res://world/characters/princesses/celestia_body.glb": {
		"Celestia vn_celestia_shoes_tia_smd": 0.25, "wing folded_L": 0.5, "wing folded_R": 0.5,
		"Celestia vn_celestia_crown_tia_smd": 0.5, "Celestia vn_celestia_collar_tia_smd": 0.5},
	"res://world/characters/princesses/luna_body.glb": {
		"wing folded_L": 0.5, "wing folded_R": 0.5, "Luna luna_Crown_smd": 0.5, "Luna luna_Collar_smd": 0.5},
	"res://world/characters/princesses/celestia_wings.glb": {"wing open_L": 0.5, "wing open_R": 0.5},
	"res://world/characters/princesses/luna_wings.glb": {"wing open_L_001": 0.5, "wing open_R_001": 0.5},
}
var rows := []

func _init() -> void:
	for model: String in TARGETS:
		var cfg := ConfigFile.new(); cfg.load(model + ".import")
		var ps := load(model) as PackedScene
		var root := ps.instantiate()
		var changed := false
		for name: String in TARGETS[model]:
			var mi := root.find_child(name, true, false) as MeshInstance3D
			if mi == null or not mi.mesh is ArrayMesh: print("MISSING ", model, " ", name); continue
			if _reduce(mi.mesh, TARGETS[model][name], false, model + " " + name): changed = true
		root.free()
		if changed: _save(ps, str(cfg.get_value("remap", "path")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/optimare"))
	var out := FileAccess.open("res://build/optimare/report.tsv", FileAccess.WRITE)
	for r in rows: out.store_line("\t".join(r))
	print("DONE ", rows.size())
	quit()

func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return t

func _save(res: Resource, game_path: String) -> void:
	var dst := STAGE + game_path.trim_prefix("res://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	var err := ResourceSaver.save(res, dst, ResourceSaver.FLAG_COMPRESS)
	if err != OK: print("SAVE_FAIL ", dst, " ", err)

## Rebuilds every surface of `m` in place at about `ratio` of its triangles (closest simplifier step).
func _reduce(m: ArrayMesh, ratio: float, compact: bool, label: String) -> bool:
	var surfaces := []
	var before := 0; var after := 0; var vb := 0; var va := 0
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		if m.get_blend_shape_count() > 0: print("SKIP blendshapes ", label); return false
		var fmt := m.surface_get_format(s)
		var flags := fmt & (((1 << 22) - 1) << 13)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var want := int(idx.size() * ratio)
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, "", flags)
		im.generate_lods(25.0, 60.0, [])
		var base := im.get_surface_arrays(0)
		var best := -1; var bd := 1 << 30
		for l in im.get_surface_lod_count(0):
			var n := im.get_surface_lod_indices(0, l).size()
			if n < idx.size() * 0.9 and absi(n - want) < bd: bd = absi(n - want); best = l
		var main_idx: PackedInt32Array = idx if best < 0 else im.get_surface_lod_indices(0, best)
		var lods := {}
		if best >= 0:
			for l in range(best + 1, im.get_surface_lod_count(0)): lods[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
		var vcount := (base[0] as PackedVector3Array).size()
		if vcount != (arrays[0] as PackedVector3Array).size(): print("VERTS_CHANGED ", label)
		if compact and best >= 0:
			var remap := PackedInt32Array(); remap.resize(vcount); remap.fill(-1)
			var order := PackedInt32Array()
			for list: PackedInt32Array in [main_idx] + lods.values():
				for v in list:
					if remap[v] < 0: remap[v] = order.size(); order.append(v)
			for slot in base.size():
				var a: Variant = base[slot]
				if a == null or slot == Mesh.ARRAY_INDEX or a.size() == 0 or a.size() % vcount != 0: continue
				var per: int = a.size() / vcount
				var o: Variant = a.duplicate(); o.resize(order.size() * per)
				for i in order.size():
					for c in per: o[i * per + c] = a[order[i] * per + c]
				base[slot] = o
			var fix := func(list: PackedInt32Array) -> PackedInt32Array:
				var rr := PackedInt32Array(); rr.resize(list.size())
				for i in list.size(): rr[i] = remap[list[i]]
				return rr
			main_idx = fix.call(main_idx)
			for k: Variant in lods.keys(): lods[k] = fix.call(lods[k])
		base[Mesh.ARRAY_INDEX] = main_idx
		surfaces.append({"arrays": base, "lods": lods, "flags": flags, "mat": m.surface_get_material(s), "name": m.surface_get_name(s)})
		before += idx.size() / 3; after += main_idx.size() / 3
		vb += (arrays[0] as PackedVector3Array).size(); va += (base[0] as PackedVector3Array).size()
	if after >= before: return false
	m.clear_surfaces()
	for s: Dictionary in surfaces:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s.arrays, [], s.lods, s.flags)
		var i := m.get_surface_count() - 1
		m.surface_set_material(i, s.mat); m.surface_set_name(i, s.name)
	rows.append([label, str(before), str(after), str(vb), str(va)])
	return true
