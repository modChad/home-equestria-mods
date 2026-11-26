extends "res://world/ui/settings_page.gd"
## modChad's Mod Menu 1.0.0: replaces only the Settings → Mods tab (_build_mods). The game's own
## helpers are reused (_button, _note, _mod_notes, _one_scenario_switch, _mod_updates,
## _open_mods_folder) and every colour comes from world/ui/menu_style.gd, so it looks like the
## rest of the page. The "Open mods folder" button stays a direct child of the tab's list, where
## Mod Reloader anchors its "Reload from last save" row.

const MM_INSTALLED := preload("res://mods/modchads_mod_menu/menu/installed.gd")

## "installed" or "browse".
var mm_view := "installed"
var mm_query := ""
var mm_filter := "all"
var mm_sort := 0
## pack file -> true while its details are open; "<file>|files" while its file list is open.
var mm_open: Dictionary = {}
var mm_list: VBoxContainer
var mm_body: VBoxContainer
var mm_chips: HBoxContainer
var mm_browse: RefCounted


func _build_mods(list: VBoxContainer) -> void:
	mm_list = list
	MM_INSTALLED.build(self, list)
