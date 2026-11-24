extends SceneTree
## Lighter Hair 1.0.1 lab (modChad). After reduce_hair.gd has run on _hat_lab/hat_list.txt, writes
## Applejack's hat before/after as glbs to renders/hair_lite/ for render_hat.py.
const SRC := "res://world/characters/mane6/applejack_devkit_hair.glb"

func _init() -> void:
	var cfg := ConfigFile.new(); cfg.load(SRC + ".import")
	var staged := "res://build/hair_lite/stage/" + str(cfg.get_value("remap", "path")).trim_prefix("res://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders/hair_lite"))
	_export(SRC, "before")
	_export(staged, "after")
	quit()

func _export(path: String, tag: String) -> void:
	var root := (load(path) as PackedScene).instantiate()
	var mi := root.find_child("ApplejackHat", true, false) as MeshInstance3D
	if mi == null: print("NO_HAT ", path); root.free(); return
	var t := 0
	for s in mi.mesh.get_surface_count(): t += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print(tag, " tris ", t)
	var out := Node3D.new(); out.name = "hat_" + tag
	var m := MeshInstance3D.new(); m.name = "hat_" + tag; m.mesh = mi.mesh
	out.add_child(m); m.owner = out
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_scene(out, st)
	print(doc.write_to_filesystem(st, ProjectSettings.globalize_path("res://renders/hair_lite/hat_%s.glb" % tag)))
	out.free(); root.free()
