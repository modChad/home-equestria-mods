extends SceneTree
## Saves the brush models the game's item visual loads. Run from the project root:
##   godot --headless --xr-mode off --path . --script res://mods/grooming/tools/make_models.gd
## The brushes are modelled in Blender (renders/grooming_brushes_v1.0.3.blend) and exported with
## baked textures to SRC as <kind>_brush.glb: grip at the origin, head toward -Z, bristles toward -Y.
## Every mesh goes under a "container_brush" node so the game treats it as a container part (never
## eaten, never hidden). Prints each model's bounds centre and the BRISTLE value for main.gd
## (the bristle point minus that centre) and the size for definitions.json "size_m".
const SRC := "res://renders/grooming_brushes_v1.0.3/"
## Lowest bristle tip, under the middle of the head, in the brush frame.
const BRISTLE_POINT := {"mane": Vector3(0, -0.035, -0.165), "coat": Vector3(0, -0.0395, -0.06)}
const TEXTURE_SIZE := 512

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for kind: String in ["mane", "coat"]:
		var root := _build(kind)
		if root == null: continue
		var packed := PackedScene.new()
		packed.pack(root)
		var path := "res://mods/grooming/models/%s_brush.scn" % kind
		var box := _bounds(root)
		print(path, " ", ResourceSaver.save(packed, path), " centre ", box.get_center(), " size ", box.size,
			" BRISTLE ", BRISTLE_POINT[kind] - box.get_center())
		root.free()
	quit()

func _build(kind: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC + "%s_brush.glb" % kind), state)
	if err != OK:
		push_error("cannot read %s_brush.glb: %s" % [kind, err]); return null
	var scene := doc.generate_scene(state) as Node3D
	var root := Node3D.new()
	root.name = "ManeBrush" if kind == "mane" else "CoatBrush"
	var parts := Node3D.new()
	parts.name = "container_brush"
	root.add_child(parts)
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := MeshInstance3D.new()
		mi.name = kind + "_brush_mesh"
		var mesh := source.mesh.duplicate() as Mesh
		var baked := mesh.surface_get_material(0)
		# The glTF material carries the full-size texture: keep only the compressed copy.
		for i in mesh.get_surface_count(): mesh.surface_set_material(i, null)
		mi.mesh = mesh
		mi.transform = _global(source, scene)
		mi.material_override = _material(baked)
		parts.add_child(mi)
		mi.owner = root
	parts.owner = root
	scene.free()
	return root

## Transform of `node` relative to the scene root (the scene is not in the tree).
func _global(node: Node3D, top: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p != null and p != top:
		if p is Node3D: t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

## Plain material with the baked albedo, stored compressed inside the .scn.
func _material(source: Material) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	var tex: Texture2D = (source as BaseMaterial3D).albedo_texture if source is BaseMaterial3D else null
	if tex != null:
		var img := tex.get_image()
		if img.is_compressed(): img.decompress()
		img.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		var packed := PortableCompressedTexture2D.new()
		# Outside the editor Godot drops the compressed data once uploaded: keep it so it saves.
		packed.keep_compressed_buffer = true
		packed.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.9)
		m.albedo_texture = packed
	return m

func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
