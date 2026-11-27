extends RefCounted
## His own lower face in his own view while he is kissed: nose, lips, chin and lower cheeks,
## cut at kiss time out of the player body's own head mesh (head_smd) with the body's own skin
## material. The body mesh itself is never changed. The game hides his head from his camera by
## collapsing its bone (player/head_hide_modifier.gd), so in a kiss her mouth met empty air.
##
## The piece is drawn on a render layer no other camera sees (LAYER; mirrors, spectator and
## capture cameras keep the default 20 layers), and the player's own camera gets that layer only
## while the piece exists. Nothing here runs outside a kiss.

## Render layer 24: outside every default camera mask.
const LAYER := 1 << 23
## The eye (camera) point of the body model, from its head bone's rest, in model axes: y up, z
## the way he faces (player/anon_body.gd MODEL_EYE_HEIGHT and head_offset).
const EYE_FROM_BONE := Vector3(0.0, 0.089, 0.083)
## Where the game takes his mouth to be, from his eye, in camera axes (player/pony_kisser.gd).
const MOUTH_OFFSET := Vector3(0.0, -0.07, -0.02)
## The seam of the model's lips on its middle line, from the model's eye point, camera axes
## (y up, -z ahead). Measured on the fitted Blender insert at the resting seam.
const MODEL_MOUTH := Vector3(0.0, -0.076, -0.0175)
const LOWER_LIP := Vector3(0.0, -0.0805, -0.01506)
const LOWER_TRAVEL := Vector3(0.0, -0.002, 0.0002)
const MODEL := preload("res://mods/kiss_intensity/kiss_model.gd")
## From the game's mouth point to his visible mouth, in his head's axes (y up, z toward him):
## what her lip target moves by while the piece shows, so her lips meet skin and not air.
const HIS_LIPS := MODEL_MOUTH - MOUTH_OFFSET
## How far below the eye line the piece starts (metres, negative = below). On a screen the ridge
## of his nose runs up to just under the eye; in a headset nothing above his nose tip is drawn.
const TOP_DESKTOP := -0.012
const TOP_HEADSET := -0.032
## The piece ends here below the eye (under his chin) and this far behind the eye plane.
const BOTTOM := -0.140
const BACK := 0.030
const HALF_WIDTH := 0.072

static var _source: Array = []
static var _gathered: Dictionary = {}
static var _shapes: Dictionary = {}


## The head's triangles in camera axes about the model's eye point, per surface.
static func gather(skeleton: Skeleton3D, head_bone: StringName) -> Dictionary:
	var head := skeleton.find_bone(head_bone)
	var body := skeleton.get_node_or_null("head_smd") as MeshInstance3D
	if head < 0 or body == null or body.mesh == null or body.skin == null: return {}
	var source := [skeleton.get_instance_id(), head, body.mesh, body.skin]
	for surface in body.mesh.get_surface_count(): source.append(body.get_active_material(surface))
	if source == _source: return _gathered
	_source = source
	_shapes.clear()
	_gathered.clear()
	var in_head := {}
	var stack: Array[int] = [head]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		in_head[bone] = true
		for child: int in skeleton.get_bone_children(bone): stack.append(child)
	var skin := body.skin
	var bind_bone := PackedInt32Array()
	var head_bind := -1
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(i))
		bind_bone.append(bone)
		if bone == head: head_bind = i
	if head_bind < 0: return {}
	var rest := skeleton.get_bone_global_rest(head)
	var to_model := rest * skin.get_bind_pose(head_bind)
	var eye := rest.origin + EYE_FROM_BONE
	var surfaces: Array = []
	for surface in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if points.is_empty() or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null: continue
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var per := bones.size() / points.size()
		var placed := PackedVector3Array()
		placed.resize(points.size())
		var faces := PackedVector3Array()
		faces.resize(points.size())
		var of_head := PackedByteArray()
		of_head.resize(points.size())
		for vertex in points.size():
			var weight := 0.0
			for k in per:
				var bind := bones[vertex * per + k]
				if bind >= 0 and bind < bind_bone.size() and in_head.has(bind_bone[bind]): weight += weights[vertex * per + k]
			of_head[vertex] = 1 if weight > 0.5 else 0
			var model := to_model * points[vertex] - eye
			placed[vertex] = Vector3(-model.x, model.y, -model.z)
			if not normals.is_empty():
				var normal := (to_model.basis * normals[vertex]).normalized()
				faces[vertex] = Vector3(-normal.x, normal.y, -normal.z)
		if index.is_empty():
			index.resize(points.size())
			for i in points.size(): index[i] = i
		surfaces.append({"points": placed, "normals": faces if not normals.is_empty() else PackedVector3Array(), "uvs": uvs, "index": index, "head": of_head, "material": body.get_active_material(surface)})
	_gathered = {"surfaces": surfaces}
	return _gathered


## His lower face as a mesh in camera axes about his eye, cut `top` metres under the eye line.
static func shape(skeleton: Skeleton3D, head_bone: StringName, top: float) -> ArrayMesh:
	var gathered := gather(skeleton, head_bone)
	if gathered.is_empty(): return null
	if _shapes.has(top): return _shapes[top]
	var mesh := ArrayMesh.new()
	for surface: Dictionary in gathered.surfaces:
		var points: PackedVector3Array = surface.points
		var of_head: PackedByteArray = surface.head
		var keep := PackedByteArray()
		keep.resize(points.size())
		for vertex in points.size():
			var p := points[vertex]
			keep[vertex] = 1 if of_head[vertex] == 1 and p.y < top and p.y > BOTTOM and p.z < BACK and absf(p.x) < HALF_WIDTH else 0
		var index: PackedInt32Array = surface.index
		var out_index := PackedInt32Array()
		var remap := {}
		var out_points := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_uvs := PackedVector2Array()
		for corner in range(0, index.size() - 2, 3):
			if keep[index[corner]] == 0 or keep[index[corner + 1]] == 0 or keep[index[corner + 2]] == 0: continue
			# Cut the aperture in this view-only copy under the fitted lip flange.
			var center := (points[index[corner]] + points[index[corner + 1]] + points[index[corner + 2]]) / 3.0
			if Vector2(center.x / 0.025, (center.y - MODEL_MOUTH.y) / 0.0105).length_squared() < 1.0: continue
			for k in 3:
				var vertex := index[corner + k]
				if not remap.has(vertex):
					remap[vertex] = out_points.size()
					out_points.append(points[vertex])
					if not (surface.normals as PackedVector3Array).is_empty(): out_normals.append(surface.normals[vertex])
					if not (surface.uvs as PackedVector2Array).is_empty(): out_uvs.append(surface.uvs[vertex])
				out_index.append(int(remap[vertex]))
		if out_index.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_points
		if not out_normals.is_empty(): arrays[Mesh.ARRAY_NORMAL] = out_normals
		if not out_uvs.is_empty(): arrays[Mesh.ARRAY_TEX_UV] = out_uvs
		arrays[Mesh.ARRAY_INDEX] = out_index
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface.material)
	if mesh.get_surface_count() == 0: return null
	_shapes[top] = mesh
	return mesh


## The piece as a node, not yet in the tree. Null when the body has no usable head mesh.
static func piece(skeleton: Skeleton3D, head_bone: StringName, headset: bool) -> MeshInstance3D:
	var mesh := shape(skeleton, head_bone, TOP_HEADSET if headset else TOP_DESKTOP)
	if mesh == null: return null
	var node := MeshInstance3D.new()
	node.name = "KissOwnFace"
	node.mesh = mesh
	node.layers = LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 1.0
	# The body's own skin material without its ink outline: from inside his own head the
	# outline shell is a black wall in front of his eye.
	for surface in mesh.get_surface_count():
		var skin := mesh.surface_get_material(surface)
		if skin == null or skin.next_pass == null: continue
		var bare: Material = skin.duplicate()
		bare.next_pass = null
		node.set_surface_override_material(surface, bare)
	var model := MODEL.instantiate("res://mods/kiss_intensity/human_mouth.glb")
	if model == null:
		node.free()
		return null
	node.add_child(model)
	var lips := model.find_child("LipInsert", true, false) as MeshInstance3D
	if lips == null or lips.find_blend_shape_by_name("Part") < 0:
		node.free()
		return null
	lips.layers = LAYER
	lips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in lips.mesh.get_surface_count():
		if lips.mesh.surface_get_material(surface).resource_name == "ReplaceWithBodySkin":
			lips.set_surface_override_material(surface, node.get_active_material(0))
	node.set_meta("lip_insert", lips)
	return node


static func part(node: MeshInstance3D, jaw: float) -> Vector3:
	var lips: MeshInstance3D = node.get_meta("lip_insert")
	lips.set_blend_shape_value(0, jaw)
	return node.global_transform * (LOWER_LIP + LOWER_TRAVEL * jaw)


## Where the piece sits in his head's frame (the untipped camera): where the body model's own
## face is under his eye, nothing moved. `size`: his height scale.
static func seat(size: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)
