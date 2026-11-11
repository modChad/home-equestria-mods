extends Node
## Briefcase Rescue: on every launch, before the title screen, removes items the game no longer
## knows (left behind by an uninstalled mod) from briefcases and world saves.
##
## The game rejects a whole briefcase or save when one item id is unknown
## (world/inventory/inventory_store.gd valid_document, world/game_saves.gd valid) and renames
## the file to `<file>.corrupt-<time>`. This mod:
##   1. strips unknown items from every briefcase.json / save .json (and their .previous copies);
##   2. when the current file is missing, unusable or (briefcase) empty, restores the newest
##      `.corrupt-*` copy that becomes valid once unknown items are removed, then renames that
##      copy to `.rescued-*` so it is never restored twice.
## A file is only written when the game's own validator accepts the cleaned result. Every file
## changed is first copied to `<file>.rescue-backup-<time>`. Nothing outside user:// is touched.

const CATALOG := preload("res://world/inventory/item_catalog.gd")
const INVENTORY := preload("res://world/inventory/inventory_store.gd")
const SAVES := preload("res://world/game_saves.gd")
const SAVE_FILE := preload("res://world/save_file.gd")
const WORLDS := "user://worlds"
const LEGACY_CASE := "user://inventory/briefcase.json"
const CASE_BYTES := 1 << 20
const NOTICE := "Corrupted items removed."

var _removed: int = 0
var _stamp: String = ""

func _ready() -> void:
	_stamp = SAVE_FILE.stamp()
	_rescue_case(LEGACY_CASE)
	if DirAccess.dir_exists_absolute(WORLDS):
		for world: String in DirAccess.get_directories_at(WORLDS):
			var root := WORLDS.path_join(world)
			_rescue_case(root.path_join("inventory/briefcase.json"))
			_rescue_saves(root.path_join("saves"), world)
			_rescue_saves(root.path_join("saves/archive"), world)
	if _removed > 0:
		print("[briefcase_rescue] removed %d unknown item(s)" % _removed)
		_notify.call_deferred()


# --- items -------------------------------------------------------------------------------

static func _known(id: Variant) -> bool:
	return id is String and (CATALOG.has(id) or id == "house-key")

## Removes unknown slots and loans from an inventory document in place. Returns the ids removed.
static func _strip(inv: Variant) -> Array[String]:
	var gone: Array[String] = []
	if not inv is Dictionary: return gone
	var slots: Variant = inv.get("slots")
	if slots is Array:
		for i in slots.size():
			var slot: Variant = slots[i]
			if slot is Dictionary and not slot.is_empty() and not _known(slot.get("id")):
				gone.append(str(slot.get("id")))
				slots[i] = {}
	var loans: Variant = inv.get("checked_out")
	if loans is Dictionary:
		for token: Variant in loans.keys():
			var loan: Variant = loans[token]
			if loan is Dictionary and not _known(loan.get("id")):
				gone.append(str(loan.get("id")))
				loans.erase(token)
	return gone

static func _case_empty(doc: Dictionary) -> bool:
	for slot: Variant in doc.slots:
		if slot is Dictionary and not slot.is_empty(): return false
	return doc.checked_out.is_empty()


# --- briefcases --------------------------------------------------------------------------

func _rescue_case(path: String) -> void:
	for file: String in [path, path + ".previous"]:
		var doc: Variant = SAVE_FILE.parse(file, CASE_BYTES)
		if not doc is Dictionary or doc.get("version") != 1: continue
		var gone := _strip(doc)
		if gone.is_empty(): continue
		if INVENTORY.valid_document(doc): _replace(file, doc, gone)
		else: push_warning("[briefcase_rescue] %s still invalid after removing %s; left unchanged" % [file, gone])
	var current: Variant = SAVE_FILE.parse(path, CASE_BYTES)
	var current_ok: bool = current is Dictionary and INVENTORY.valid_document(current)
	if current is Dictionary and current.get("version") is float and current.version > 1: return
	if current_ok and not _case_empty(current): return
	for kept: String in _corrupt_copies(path):
		var old: Variant = SAVE_FILE.parse(kept, CASE_BYTES)
		if not old is Dictionary or old.get("version") != 1: continue
		var gone := _strip(old)
		if gone.is_empty() or not INVENTORY.valid_document(old): continue
		if current_ok:
			# Bits earned since the case was set aside are kept on top of the old balance.
			old.bits = mini(INVENTORY.MAX_BITS, int(old.get("bits", 0)) + int(current.get("bits", 0)))
		_replace(path, old, gone)
		_retire(kept)
		print("[briefcase_rescue] restored %s from %s" % [path, kept.get_file()])
		return


# --- world saves -------------------------------------------------------------------------

func _rescue_saves(dir: String, world: String) -> void:
	if not DirAccess.dir_exists_absolute(dir): return
	var mains: Dictionary = {}
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".json") or name.ends_with(".json.previous"):
			_clean_save(dir.path_join(name), world)
		var at := name.find(".json.corrupt-")
		if at > 0: mains[dir.path_join(name.substr(0, at + 5))] = true
	for main: String in mains:
		_restore_save(main, world)

func _clean_save(file: String, world: String) -> void:
	var doc: Variant = SAVE_FILE.parse(file, SAVES.MAX_BYTES)
	if not doc is Dictionary or not doc.get("inventory") is Dictionary: return
	var gone := _strip(doc.inventory)
	if gone.is_empty(): return
	if _save_ok(doc, world): _replace(file, doc, gone)
	else: push_warning("[briefcase_rescue] %s still invalid after removing %s; left unchanged" % [file, gone])

func _restore_save(main: String, world: String) -> void:
	var current: Variant = SAVE_FILE.parse(main, SAVES.MAX_BYTES)
	if current is Dictionary:
		if SAVES.prepare(current.duplicate(true), world).verdict == SAVE_FILE.NEWER: return
		if not current.get("empty", false) and _save_ok(current, world): return
	for kept: String in _corrupt_copies(main):
		var old: Variant = SAVE_FILE.parse(kept, SAVES.MAX_BYTES)
		if not old is Dictionary or not old.get("inventory") is Dictionary: continue
		var gone := _strip(old.inventory)
		if gone.is_empty() or not _save_ok(old, world): continue
		_replace(main, old, gone)
		_retire(kept)
		print("[briefcase_rescue] restored %s from %s" % [main, kept.get_file()])
		return

static func _save_ok(doc: Dictionary, world: String) -> bool:
	return SAVES.prepare(doc.duplicate(true), world).verdict == ""


# --- files -------------------------------------------------------------------------------

## `<path>.corrupt-*` copies, newest first (the name carries the time).
static func _corrupt_copies(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir): return result
	var prefix := path.get_file() + ".corrupt-"
	for name: String in DirAccess.get_files_at(dir):
		if name.begins_with(prefix) and not name.contains(".rescue-"): result.append(dir.path_join(name))
	result.sort()
	result.reverse()
	return result

## Back up `path` (if present), then write `doc` over it via a temporary file.
func _replace(path: String, doc: Dictionary, gone: Array[String]) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		var backup := absolute + ".rescue-backup-" + _stamp
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(absolute, backup) != OK:
			push_warning("[briefcase_rescue] could not back up %s; left unchanged" % path)
			return
	var tmp := absolute + ".rescue-tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("[briefcase_rescue] could not write %s" % path)
		return
	file.store_string(JSON.stringify(doc, "\t", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(tmp, absolute) != OK:
		push_warning("[briefcase_rescue] could not write %s" % path)
		return
	_removed += gone.size()
	print("[briefcase_rescue] %s: removed %s" % [path, ", ".join(gone)])

## A restored `.corrupt-*` copy is renamed so it is not restored again; it is never deleted.
static func _retire(kept: String) -> void:
	var absolute := ProjectSettings.globalize_path(kept)
	DirAccess.rename_absolute(absolute, absolute.replace(".corrupt-", ".rescued-"))


# --- notice ------------------------------------------------------------------------------

func _notify() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Briefcase Rescue"
	dialog.dialog_text = NOTICE
	dialog.exclusive = false
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
