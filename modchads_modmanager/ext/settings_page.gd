extends "res://world/ui/settings_page.gd"
## modChads modManager 1.1.0: replaces only the Settings → Mods tab (_build_mods). The game's own
## helpers are reused (_button, _note, _mod_notes, _one_scenario_switch, _mod_updates,
## _open_mods_folder) and every colour comes from world/ui/menu_style.gd, so it looks like the
## rest of the page. The tab bar carries its own Reload control (menu/reload.gd, with main.gd for
## loading back into a save), which replaces the retired Mod Reloader. The folder button is called
## "Open the mods folder" so an old copy of Mod Reloader, which anchors its row on the exact text
## "Open mods folder", adds nothing here.

const MM_INSTALLED := preload("res://mods/modchads_modmanager/menu/installed.gd")

## "installed" or "browse".
var mm_view := "installed"
var mm_query := ""
var mm_filter := "all"
var mm_sort := 0
## pack file -> true while its details are open; "<file>|files" while its file list is open.
var mm_open: Dictionary = {}
var mm_list: VBoxContainer
var mm_body: VBoxContainer
var mm_chips: Control
var mm_browse: RefCounted
## Builds the whole Mods tab again (set by installed.gd build()).
var mm_rebuild := Callable()


func _build_mods(list: VBoxContainer) -> void:
	mm_list = list
	MM_INSTALLED.build(self, list)
