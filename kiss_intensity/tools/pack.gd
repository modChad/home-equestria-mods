extends SceneTree
## Packs Kiss intensity (0.7.2 and later): mods/kiss_intensity/mod.json (devanon's, with only the version and
## the Kissing pin changed) + a mod.built.json marker + devanon's 0.7.1 files exactly as he shipped
## them, staged by tools/stage.sh in build/kiss_intensity/stage/. The two .glb models go in raw, not
## imported: kiss_model.gd reads them with GLTFDocument.append_from_buffer.
##   godot --headless --xr-mode off --path <project> --script res://mods/kiss_intensity/tools/pack.gd -- <out.pck>
const MOD := "res://mods/kiss_intensity/"

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var stage := ProjectSettings.globalize_path("res://build/kiss_intensity/stage/")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOD + "mod.json"))
	var stamp := ProjectSettings.globalize_path("user://mod_build_kiss_intensity.json")
	var f := FileAccess.open(stamp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "kiss_intensity", "version": str(manifest.version), "game_version": str(ProjectSettings.get_setting("application/config/version", "")), "godot": Engine.get_version_info().string}, "\t"))
	f.close()
	var files := {MOD + "mod.json": ProjectSettings.globalize_path(MOD + "mod.json"), MOD + "mod.built.json": stamp}
	_walk(stage, "", files)
	if files.size() <= 2: printerr("MOD_BUILD_FAILED nothing staged in ", stage, " (run tools/stage.sh)"); quit(1); return
	var packer := PCKPacker.new()
	if packer.pck_start(out) != OK: printerr("MOD_BUILD_FAILED cannot write ", out); quit(1); return
	var paths := files.keys(); paths.sort()
	for p: String in paths:
		if packer.add_file(p, files[p]) != OK: printerr("MOD_BUILD_FAILED ", p); quit(1); return
	packer.flush()
	print("MOD_BUILT ", out, " (", paths.size(), " files)")
	quit()

func _walk(abs_dir: String, rel: String, files: Dictionary) -> void:
	var d := DirAccess.open(abs_dir)
	d.include_hidden = true
	for sub in d.get_directories(): _walk(abs_dir.path_join(sub), rel + sub + "/", files)
	for name in d.get_files():
		if name == ".gdignore" or name == "mod.json" and rel == "": continue
		files[MOD + rel + name] = abs_dir.path_join(name)
