extends SceneTree
## Saves the brush models the game's item visual loads. Run from the project root:
##   godot --headless --xr-mode off --path . --script res://mods/grooming/tools/make_models.gd
## Prints each model's bounds centre: main.gd BRISTLE is the bristle point minus that centre.
const BUILDER := preload("res://mods/grooming/items/brush_item.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for kind: String in ["mane", "coat"]:
		var root: Node3D = BUILDER.build(kind)
		var packed := PackedScene.new()
		packed.pack(root)
		var path := "res://mods/grooming/models/%s_brush.scn" % kind
		print(path, " ", ResourceSaver.save(packed, path), " centre ", _bounds(root).get_center())
		root.free()
	quit()

func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
