extends "res://mods/anonfilly/main.gd"
## modChad patch 1.0.0 for Anonfilly (NPC) 1.0.0. The pack itself is unchanged: this extends its
## main.gd (mod.json "patches" and "extends", world/modding/mod_loader.gd) and loads only with
## exactly 1.0.0.
## Her hair (anon_filly_hair.scn, a copy of the player's) is 25,760 triangles, heavy for a
## background filly on Quest 3. This pack carries the same scene reduced with Godot's own
## simplifier (meshoptimizer): mane 23,744 -> 7,936 and tail 2,016 -> 1,280 triangles, unused
## vertices dropped, plus coarser LODs Godot picks by distance. Nodes, skeleton, skin weights, UVs
## and materials are untouched. Her identity is pointed at it before anything spawns her; the
## resource is held here so every later load of anon_filly.tres gets the same edited copy.

const PATCH_HAIR := "res://mods/anonfilly_patch/anon_filly_hair.scn"
const PATCH_IDENTITY := "res://mods/anonfilly/anon_filly.tres"
var _patch_identity: Resource


func _ready() -> void:
	_patch_identity = load(PATCH_IDENTITY)
	if _patch_identity != null and ResourceLoader.exists(PATCH_HAIR):
		_patch_identity.set("hair_scene", PATCH_HAIR)
	else:
		push_warning("[anonfilly_patch] could not swap in the lighter hair; she keeps the original")
	super()
