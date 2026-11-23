extends SceneTree
## Packs Lighter Hair: mods/hair_lite/mod.json + a mod.built.json marker + every reduced file
## staged by reduce_hair.gd under res://build/hair_lite/stage/, each at the game path it replaces.
## (mods/build_packs.sh can't build this mod: it only packs files inside the mod's own folder.)
##   godot --headless --xr-mode off --path <project> --script res://mods/hair_lite/tools/pack.gd -- <out.pck>
const STAGE := "res://build/hair_lite/stage/"
const MOD := "res://mods/hair_lite/"

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOD + "mod.json"))
	var stamp := ProjectSettings.globalize_path("user://mod_build_hair_lite.json")
	var f := FileAccess.open(stamp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "hair_lite", "version": str(manifest.version), "game_version": str(ProjectSettings.get_setting("application/config/version", "")), "godot": Engine.get_version_info().string}, "\t"))
	f.close()
	var files := {MOD + "mod.json": ProjectSettings.globalize_path(MOD + "mod.json"), MOD + "mod.built.json": stamp}
	_walk(STAGE, files)
	var packer := PCKPacker.new()
	if packer.pck_start(out) != OK: printerr("MOD_BUILD_FAILED cannot write ", out); quit(1); return
	var paths := files.keys(); paths.sort()
	for p: String in paths:
		if packer.add_file(p, files[p]) != OK: printerr("MOD_BUILD_FAILED ", p); quit(1); return
	packer.flush()
	print("MOD_BUILT ", out, " (", paths.size(), " files)")
	quit()

func _walk(dir: String, files: Dictionary) -> void:
	for d in DirAccess.get_directories_at(dir): _walk(dir + d + "/", files)
	for name in DirAccess.get_files_at(dir):
		files["res://" + (dir + name).trim_prefix(STAGE)] = ProjectSettings.globalize_path(dir + name)
