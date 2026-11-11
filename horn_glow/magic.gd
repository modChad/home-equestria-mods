extends "res://world/characters/magic/unicorn_magic.gd"
## Horn Glow (modChad): the horn's magic as a glow around the horn itself instead of the round
## camera-facing disc. A shell copy of the horn mesh, skinned to the same skeleton (so it moves
## with her head), grown along its normals and drawn out into a flickering flame past the tip.
## The horn's aura still makes its sparkles but is silent and its disc hidden; a gentle sustain
## hum follows the glow instead of the cast sound. Lifted things keep the game's aura.
const GLOW_SHADER := preload("res://mods/horn_glow/glow.gdshader")
const HUM := preload("res://world/characters/magic/aura/magic_sustain.res")
const SHELL_GAP := 0.03  # Share of the horn's length, everywhere.
const SHELL_WIDEN := 0.9 # Plus this share of the horn's own thickness there (so it tapers with it).
const SHELL_FLAME := 0.25 # Share of the horn's length past the tip.
const HUM_PEAK := 0.12    # Linear volume at full glow.
var _shell: MeshInstance3D
var _shell_material: ShaderMaterial
var _hum: AudioStreamPlayer3D
var _glow_horn: MeshInstance3D # The horn the shell copies (see setup).
var _length := 0.0 # Horn base to tip (mesh units).


func _apply() -> void:
	# Our own aura first, made quiet, so the game's _apply keeps it instead of a loud one.
	if intensity > 0.0 and is_instance_valid(_skeleton) and not is_instance_valid(_aura):
		var bone_world := _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)
		var base := bone_world * _base_local
		var tip := bone_world * _tip_local
		_anchor.global_position = (base + tip) * .5
		_aura = MAGIC_AURA.create(_anchor, color, 1.0, maxf(base.distance_to(tip) * .5 * MAGIC_AURA.MARGIN, .05), true)
		if is_instance_valid(_aura): _aura.set_visual_layer(_visual_layer)
	super._apply()
	var eased := intensity * intensity * (3.0 - 2.0 * intensity)
	if is_instance_valid(_aura):
		var disc: Variant = _aura.get("_disc")
		if disc is Node3D: (disc as Node3D).visible = false
	_glow(eased)


func _glow(eased: float) -> void:
	if eased <= 0.0:
		if is_instance_valid(_shell): _shell.visible = false
		if is_instance_valid(_hum) and _hum.playing: _hum.stop()
		return
	if not is_instance_valid(_shell) and not _make_shell(): return
	_shell.visible = true
	_shell.layers = _visual_layer
	_shell_material.set_shader_parameter("strength", eased)
	if not _hum.playing: _hum.play()
	_hum.volume_db = linear_to_db(maxf(HUM_PEAK * eased, 0.0001))
	_hum.global_position = _anchor.global_position


func _make_shell() -> bool:
	if not is_instance_valid(_glow_horn): _glow_horn = _horn
	if not is_instance_valid(_glow_horn) or _glow_horn.mesh == null: return false
	var baked := _baked(_glow_horn.mesh)
	var length := maxf(_length, 0.0001)
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = GLOW_SHADER
	_shell_material.render_priority = 90
	_shell_material.set_shader_parameter("glow_color", vivid(color))
	_shell_material.set_shader_parameter("own_horn", _glow_horn != _horn)
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
	_shell.skeleton = _shell.get_path_to(_glow_horn.get_node(_glow_horn.skeleton))
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "HornGlowHum"
	_hum.stream = HUM
	_hum.unit_size = 4.0
	_hum.volume_db = -80.0
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("route"): settings.route(_hum, "SFX")
	_hum.finished.connect(func() -> void: if intensity > 0.0: _hum.play())
	_anchor.add_child(_hum)
	return true


func _exit_tree() -> void:
	if is_instance_valid(_shell): _shell.queue_free()


## The excited flare (excitement.gd): the glow plus a quiet puff of sparkles at the tip, no disc.
func sparkle() -> bool:
	if not cast(.7): return false
	var tip := (_skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)) * _tip_local
	var holder := Node3D.new(); holder.name = "MagicBurst"
	add_child(holder); holder.global_position = tip
	var aura: Node3D = MAGIC_AURA.create(holder, vivid(color), 1.0, .054, true)
	if aura == null: holder.queue_free(); return true
	var disc: Variant = aura.get("_disc")
	if disc is Node3D: (disc as Node3D).visible = false
	var tween := holder.create_tween()
	tween.tween_interval(.35)
	tween.tween_callback(aura.release)
	tween.tween_interval(.8)
	tween.tween_callback(holder.queue_free)
	return true


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


## A pony with a horn of her own (Celestia's long princess horn, on her body rig) glows on that,
## not on the generic unicorn horn hidden inside it. The sparkles, light and hum stay where the
## game puts them (the generic horn, at the base of hers).
func setup(horn: MeshInstance3D, magic_color: Color) -> void:
	_glow_horn = _own_horn(horn)
	super.setup(horn, magic_color)


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
	# Her own horn names no skeleton (it skins to the Skeleton3D it sits under); unicorn_magic.gd
	# reads the path, so give it the one it already uses.
	if best != horn and best.skeleton.is_empty() and best.get_parent() is Skeleton3D: best.skeleton = NodePath("..")
	return best



# ---------------------------------------------------------------- for other mods

## Other mods (Kissing's slow build-up) light the horn glow to `level` (0-1) for this frame;
## call it every frame while it should show. It eases off on its own once they stop.
var _outside := 0.0

func is_horn_glow() -> bool: return true

func glow_from_outside(level: float) -> void:
	if not _build(): return
	_outside = clampf(level, 0.0, 1.0)
	set_process(true)

func _process(delta: float) -> void:
	super._process(delta)
	if _outside <= 0.0: return
	var eased := intensity * intensity * (3.0 - 2.0 * intensity)
	_glow(maxf(eased, _outside))
	_outside = move_toward(_outside, 0.0, delta * 2.0)
	set_process(true)

## A quiet puff of sparkles (no disc, no cast sound) at `holder`, for magic leaving the horn
## (Idle Life's magic sparkle); the game's burst is loud and drew its round disc.
func quiet_burst(holder: Node3D, magic_color: Color, seconds := 1.6, size := 0.2) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree(): return
	var aura: Node3D = MAGIC_AURA.create(holder, magic_color, 1.0, maxf(size * .6, .05), true)
	if aura == null: return
	var disc: Variant = aura.get("_disc")
	if disc is Node3D: (disc as Node3D).visible = false
	var tween := holder.create_tween()
	tween.tween_interval(maxf(seconds, .1))
	tween.tween_callback(aura.release)
