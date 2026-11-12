extends Node
## Horn Glow (modChad): one per UnicornMagic (main.gd), named "HornGlow". Watches the game's horn
## magic and draws its glow around the horn: a shell copy of the horn mesh skinned to the same
## skeleton, grown along its normals by a share of the horn's length plus its own thickness, with a
## rounded flickering top (glow.gdshader). The round disc of the game's horn aura is hidden (its
## sparkles stay; main.gd makes it silent), and a gentle hum follows the glow. No game script is
## replaced: taking over unicorn_magic.gd broke the game's other scripts in exported builds.
const GLOW_SHADER := preload("res://mods/horn_glow/glow.gdshader")
const HUM := preload("res://world/characters/magic/aura/magic_sustain.res")
const SHELL_GAP := 0.03  # Share of the horn's length, everywhere.
const SHELL_WIDEN := 0.9 # Plus this share of the horn's own thickness there (so it tapers with it).
const SHELL_FLAME := 0.25 # Share of the horn's length past the tip.
const HUM_PEAK := 0.12    # Linear volume at full glow.
var magic: Node
var _glow_horn: MeshInstance3D
var _generic: MeshInstance3D
var _shell: MeshInstance3D
var _shell_material: ShaderMaterial
var _hum: AudioStreamPlayer3D
var _length := 0.0
var _outside := 0.0


## Other mods (Kissing's slow build-up) light the glow to `level` (0-1) for this frame; call it
## every frame while it should show. It eases off on its own once they stop.
func glow_from_outside(level: float) -> void:
	_outside = clampf(level, 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_instance_valid(magic): return
	var aura: Variant = magic.get("_aura")
	if aura is Node3D and is_instance_valid(aura):
		var disc: Variant = (aura as Node).get("_disc")
		if disc is Node3D: (disc as Node3D).visible = false
	var intensity := float(magic.get("intensity"))
	var eased := intensity * intensity * (3.0 - 2.0 * intensity)
	_glow(maxf(eased, _outside))
	_outside = move_toward(_outside, 0.0, delta * 2.0)


func _glow(eased: float) -> void:
	if eased <= 0.0:
		if is_instance_valid(_shell): _shell.visible = false
		if is_instance_valid(_hum) and _hum.playing: _hum.stop()
		return
	if not is_instance_valid(_shell) and not _make_shell(): return
	_shell.visible = true
	var layer: Variant = magic.get("_visual_layer")
	if layer is int: _shell.layers = layer
	_shell_material.set_shader_parameter("strength", eased)
	if not _hum.playing: _hum.play()
	_hum.volume_db = linear_to_db(maxf(HUM_PEAK * eased, 0.0001))
	var anchor: Variant = magic.get("_anchor")
	_hum.global_position = (anchor as Node3D).global_position if anchor is Node3D and is_instance_valid(anchor) else _shell.global_position


func _make_shell() -> bool:
	var horn: Variant = magic.get("_horn")
	if not horn is MeshInstance3D or not is_instance_valid(horn): return false
	_generic = horn
	_glow_horn = _own_horn(_generic)
	if _glow_horn.mesh == null or _glow_horn.skin == null: return false
	var skeleton := _glow_horn.get_node_or_null(_glow_horn.skeleton) as Skeleton3D
	if skeleton == null and _glow_horn.get_parent() is Skeleton3D: skeleton = _glow_horn.get_parent()
	if skeleton == null: return false
	var baked := _baked(_glow_horn.mesh)
	var length := maxf(_length, 0.0001)
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = GLOW_SHADER
	_shell_material.render_priority = 90
	var colour: Color = magic.call("vivid", magic.get("color")) if magic.has_method("vivid") else magic.get("color")
	_shell_material.set_shader_parameter("glow_color", colour)
	_shell_material.set_shader_parameter("own_horn", _glow_horn != _generic)
	_shell_material.set_shader_parameter("gap", length * SHELL_GAP)
	_shell_material.set_shader_parameter("widen", length * SHELL_WIDEN)
	_shell_material.set_shader_parameter("flame", length * SHELL_FLAME)
	_shell = MeshInstance3D.new()
	_shell.name = "HornGlowShell"
	_shell.mesh = baked
	_shell.skin = _glow_horn.skin
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.extra_cull_margin = length
	_glow_horn.get_parent().add_child(_shell)
	_shell.transform = _glow_horn.transform
	_shell.skeleton = _shell.get_path_to(skeleton)
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "HornGlowHum"
	_hum.stream = HUM
	_hum.unit_size = 4.0
	_hum.volume_db = -80.0
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("route"): settings.route(_hum, "SFX")
	_hum.finished.connect(func() -> void: if is_instance_valid(_shell) and _shell.visible: _hum.play())
	add_child(_hum)
	return true


func _exit_tree() -> void:
	if is_instance_valid(_shell): _shell.queue_free()


## Every surface of the horn mesh (the generic horn's base and its swirl, which give Rarity's
## glow its rippled shape), each vertex with its share of the way from base to tip in its colour's
## red and its distance from the horn's axis (per horn length) in green.
func _baked(mesh: Mesh) -> ArrayMesh:
	var all := PackedVector3Array()
	for surface in mesh.get_surface_count():
		all.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var ends := _ends(all)
	var base: Vector3 = ends[0]
	var axis: Vector3 = ends[1] - base
	var span := maxf(axis.length_squared(), 0.0000001)
	_length = sqrt(span)
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			var t := clampf((verts[i] - base).dot(axis) / span, 0.0, 1.0)
			colors[i] = Color(t, (verts[i] - (base + axis * t)).length() / _length, 0.0)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags: int = mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays, [], {}, flags)
	return out


## Base (the mean of the lowest fifth) and tip (the vertex farthest from it).
static func _ends(verts: PackedVector3Array) -> Array:
	var low := INF
	var high := -INF
	for v in verts:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	var cut := low + (high - low) * 0.2
	var base := Vector3.ZERO
	var count := 0
	for v in verts:
		if v.y <= cut:
			base += v
			count += 1
	base /= maxf(count, 1)
	var tip := base
	for v in verts:
		if v.distance_squared_to(base) > tip.distance_squared_to(base): tip = v
	return [base, tip]


static func _own_horn(horn: MeshInstance3D) -> MeshInstance3D:
	if not is_instance_valid(horn): return horn
	var root: Node = horn
	while root.get_parent() != null and not root.has_method("listen_point"): root = root.get_parent()
	if not root.has_method("listen_point"): return horn
	var best := horn
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == horn or mesh.mesh == null or mesh.skin == null or not "horn" in mesh.name.to_lower(): continue
		if mesh.mesh.get_aabb().size.length() > best.mesh.get_aabb().size.length(): best = mesh
	return best
