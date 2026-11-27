extends RefCounted
## Her mane fades out right in front of a camera while she is kissed (critique 2026-11-25: from the
## held moment on her forelock covered most of his view, and in a headset it sits a few centimetres
## from the lenses). In the material, per pixel, by its distance from the camera that draws it:
## gone inside FROM, whole from FULL. Every other camera (side views, mirrors, other players) is
## further away and sees her mane whole. No screen-space effect: each eye judges its own distance.
##
## For the one kissed mare only: her hair meshes get their own copies of their materials (the
## shared ones are never changed), with the same values, the near fade added to the shader, and
## the same for the ink shell (next_pass). Handed back as they were by release().

const FROM := 0.10
const FULL := 0.22
## A fragment closer than FULL is dropped against a fixed noise in screen pixels (as Godot's own
## distance fade, dither mode): no transparency sorting, nothing drawn on top.
const FADE := "\n\t{ float ki_near = clamp((length(VERTEX) - %.3f) / %.3f, 0.0, 1.0);\n\tif (ki_near < 1.0 && ki_near <= fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))))) { discard; } }\n"

## Source shader -> its faded copy (null: cannot be patched). Shared by every kiss of the session.
static var _shaders: Dictionary = {}
## [mesh, surface, the override it had (or null), ours].
var _taken: Array = []


func take(mare: Node) -> void:
	var hair: Node = mare.get("hair")
	if hair == null: return
	for mi: MeshInstance3D in hair.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.material_override != null: continue
		for surface in mi.mesh.get_surface_count():
			var own := mi.get_surface_override_material(surface)
			var faded := faded_copy(own if own != null else mi.mesh.surface_get_material(surface))
			if faded == null: continue
			mi.set_surface_override_material(surface, faded)
			_taken.append([mi, surface, own, faded])


## Once a frame: the game swaps her hair's merged mesh and its materials when the hair level of
## detail changes; then take it again.
func keep(mare: Node) -> void:
	var changed := false
	for entry: Array in _taken:
		var mi: MeshInstance3D = entry[0]
		if not is_instance_valid(mi) or mi.get_surface_override_material(entry[1]) != entry[3]:
			changed = true
			break
	if not changed: return
	release()
	take(mare)


func release() -> void:
	for entry: Array in _taken:
		var mi: MeshInstance3D = entry[0]
		if is_instance_valid(mi) and entry[1] < mi.get_surface_override_material_count() and mi.get_surface_override_material(entry[1]) == entry[3]:
			mi.set_surface_override_material(entry[1], entry[2])
	_taken.clear()


## Her own copy of `source` with the near fade, or null when it cannot have one.
static func faded_copy(source: Material) -> Material:
	var copy: Material = null
	if source is ShaderMaterial:
		var shader := faded_shader((source as ShaderMaterial).shader)
		if shader == null: return null
		var made := ShaderMaterial.new()
		made.shader = shader
		for uniform: Dictionary in (source as ShaderMaterial).shader.get_shader_uniform_list():
			var key := str(uniform.name)
			made.set_shader_parameter(key, (source as ShaderMaterial).get_shader_parameter(key))
		copy = made
	elif source is BaseMaterial3D:
		var made: BaseMaterial3D = source.duplicate()
		made.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		made.distance_fade_min_distance = FROM
		made.distance_fade_max_distance = FULL
		copy = made
	else: return null
	copy.render_priority = source.render_priority
	if source.next_pass != null:
		var hull := faded_copy(source.next_pass)
		copy.next_pass = hull if hull != null else source.next_pass
	return copy


static func faded_shader(shader: Shader) -> Shader:
	if shader == null: return null
	if _shaders.has(shader): return _shaders[shader]
	var code := shader.code
	var found := RegEx.create_from_string("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{").search(code)
	var out: Shader = null
	if found != null and RegEx.create_from_string("shader_type\\s+spatial").search(code) != null:
		out = Shader.new()
		out.code = code.substr(0, found.get_end()) + FADE % [FROM, FULL - FROM] + code.substr(found.get_end())
	_shaders[shader] = out
	return out
