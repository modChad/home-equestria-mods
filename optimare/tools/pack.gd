extends SceneTree
## Packs Optimare: mods/optimare/mod.json + a mod.built.json marker + every reduced file
## staged by reduce.gd under res://build/optimare/stage/, each at the game path it replaces.
## (mods/build_packs.sh can't build this mod: it only packs files inside the mod's own folder.)
##   godot --headless --xr-mode off --path <project> --script res://mods/optimare/tools/pack.gd -- <out.pck>
const STAGE := "res://build/optimare/stage/"
const MOD := "res://mods/optimare/"

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOD + "mod.json"))
	var stamp := ProjectSettings.globalize_path("user://mod_build_optimare.json")
	var f := FileAccess.open(stamp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "optimare", "version": str(manifest.version), "game_version": str(ProjectSettings.get_setting("application/config/version", "")), "godot": Engine.get_version_info().string}, "\t"))
	f.close()
	var files := {MOD + "mod.json": ProjectSettings.globalize_path(MOD + "mod.json"), MOD + "mod.built.json": stamp}
	_walk(STAGE, files)
	if files.size() <= 2: printerr("MOD_BUILD_FAILED nothing staged in ", STAGE); quit(1); return
	var packer := PCKPacker.new()
	if packer.pck_start(out) != OK: printerr("MOD_BUILD_FAILED cannot write ", out); quit(1); return
	var paths := files.keys(); paths.sort()
	for p: String in paths:
		if packer.add_file(p, files[p]) != OK: printerr("MOD_BUILD_FAILED ", p); quit(1); return
	packer.flush()
	print("MOD_BUILT ", out, " (", paths.size(), " files)")
	quit()

func _walk(dir: String, files: Dictionary) -> void:
	# include_hidden: the imported scenes live under .godot/imported/
	var d := DirAccess.open(dir)
	d.include_hidden = true
	for sub in d.get_directories(): _walk(dir + sub + "/", files)
	for name in d.get_files():
		files["res://" + (dir + name).trim_prefix(STAGE)] = ProjectSettings.globalize_path(dir + name)
