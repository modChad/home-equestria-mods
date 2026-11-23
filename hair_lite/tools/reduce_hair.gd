extends SceneTree
## Lighter Hair 1.0.0 (modChad). Run from the project root:
##   godot --headless --xr-mode off --path . --script res://mods/hair_lite/tools/reduce_hair.gd -- <absolute path to tools/hair_list.txt>
## then tools/pack.gd. hair_list.txt: every hair scene the identities name (anon_stallion_dash_hair is unused).
## Reduces every pony hair (mane/tail) mesh with Godot's simplifier and writes the results under
## STAGE, mirroring the game path each one replaces. Tails keep every vertex (tail contacts and
## anchors index them); manes drop unused vertices. Prints one TSV row per mesh changed.
const STAGE := "res://build/hair_lite/stage/"
var done := {}   # mesh instance id -> true
var rows := []

func _init() -> void:
	var list := FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]).split("\n", false)
	for path in list:
		if path.ends_with(".glb"):
			var cfg := ConfigFile.new(); cfg.load(path + ".import")
			_scene(path, str(cfg.get_value("remap", "path")))
		else: _scene(path, path)
	for dir in ["res://world/characters/background/support/", "res://world/characters/hybrid_mare/tail_anchors/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".res"): _anchor(dir + f)
	var out := FileAccess.open("res://build/hair_lite/report.tsv", FileAccess.WRITE)
	for r in rows: out.store_line("\t".join(r))
	print("DONE ", rows.size())
	quit()

func _group(path: String) -> String:
	if "/mane6/" in path or "dash_devkit_hair" in path: return "mane6"
	if "/player_pony/" in path: return "anon"
	return "background"

## Target fraction for one mesh, or 0 to leave it.
func _ratio(group: String, lod1: bool, tris: int) -> float:
	match group:
		"mane6": return 0.5 if lod1 else 0.25
		"anon": return 0.0 if lod1 else 0.34
		_: return 0.0 if lod1 or tris <= 6000 else 0.5
	return 0.0

func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return t

func _scene(src: String, game_path: String) -> void:
	var ps := load(src) as PackedScene
	var root := ps.instantiate()
	var changed := false
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if not ("Mane" in nm or "Tail" in nm) or not mi.mesh is ArrayMesh: continue
		if done.has(mi.mesh.get_instance_id()): continue
		done[mi.mesh.get_instance_id()] = true
		var r := _ratio(_group(src), nm.ends_with("LOD1"), _tris(mi.mesh))
		if r > 0.0 and _reduce(mi.mesh, r, "Mane" in nm and not "Tail" in nm, src + " " + nm): changed = true
	root.free()
	if changed: _save(ps, game_path)

func _anchor(path: String) -> void:
	var m := load(path) as ArrayMesh
	if m == null or not m.has_meta("anchor_version"): return
	var f := path.get_file().get_basename()
	var lod1 := f.ends_with("LOD1")
	var group := "mane6" if "/tail_anchors/" in path else "background"
	var r := _ratio(group, lod1, _tris(m))
	if r > 0.0 and _reduce(m, r, false, path): _save(m, path)

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
