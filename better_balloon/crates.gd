extends RefCounted
## Better Balloon: the basket built for ponies. Its rim 0.40 m lower (0.80 m over the deck instead
## of 1.2 m, the height the rim lean is keyed for: a Canon pony rears and peeks over), and the
## balloon's ropes rebuilt to reach it (the game cut the original model's basket away, so its ropes
## ended in mid-air). The step crates (add()) are no longer used.
## Spots: where a pony leans on the rim (balloon local): the inner wall face at the rim top, the
## way out, and whether it is a crate spot (her hooves on the crate top) or the floor.

const FITTINGS := preload("res://world/vehicles/balloon/basket.gd")
const NAME := "BetterBalloonCrate"
const SIZE := Vector3(0.6, 0.20, 0.75)
const FLOOR_Y := 0.26 # The basket's deck top (basket.gd).
const LOWER := 0.40 # How much lower the rim is than the game builds it.
const GAME_RIM_Y := 1.46 # The walls' top as basket.gd builds them.
const RIM_Y := GAME_RIM_Y - LOWER
const FRONT_FACE := -1.267 # The front wall's inner face (z).
const SIDE_FACE := 1.417 # The side walls' inner faces (|x|).
const CRATE_X := [-1.05, 1.05]

const SPOTS := [
	{"wall": Vector3(-1.05, RIM_Y, FRONT_FACE), "out": Vector3.FORWARD, "crate": false},
	{"wall": Vector3(1.05, RIM_Y, FRONT_FACE), "out": Vector3.FORWARD, "crate": false},
	{"wall": Vector3(-SIDE_FACE, RIM_Y, 0.1), "out": Vector3.LEFT, "crate": false},
	{"wall": Vector3(SIDE_FACE, RIM_Y, -0.3), "out": Vector3.RIGHT, "crate": false},
]


static func top_y(spot: Dictionary) -> float:
	return FLOOR_Y + (SIZE.y if spot.get("crate", false) else 0.0)


static func add(ship: Node3D) -> Array[Node3D]:
	var made: Array[Node3D] = []
	for i in CRATE_X.size():
		var name := "%s%d" % [NAME, i]
		var existing := ship.get_node_or_null(name) as Node3D
		if existing != null:
			made.append(existing)
			continue
		var crate := StaticBody3D.new()
		crate.name = name
		crate.collision_layer = 1
		crate.collision_mask = 0
		ship.add_child(crate)
		crate.position = Vector3(CRATE_X[i], FLOOR_Y + SIZE.y * 0.5, FRONT_FACE + SIZE.z * 0.5)
		FITTINGS.box(crate, Vector3.ZERO, SIZE, Color("8a5a32"), true)
		# Slats on top, a darker band round the middle.
		for j in 3: FITTINGS.box(crate, Vector3(0, SIZE.y * 0.5 + 0.005, (j - 1) * SIZE.z / 3.0), Vector3(SIZE.x - 0.02, 0.01, SIZE.z / 3.0 - 0.02), Color("a06b3c"))
		FITTINGS.box(crate, Vector3(0, 0, 0), SIZE + Vector3(0.012, -SIZE.y + 0.05, 0.012), Color("5d3a1f"))
		made.append(crate)
	return made


## The basket's walls, corner posts and gate LOWER shorter (their bottoms stay), and the rails,
## the gate's bell and its label on top of them LOWER down. basket.gd builds them as plain boxes
## straight under the ship (and the gate); the helm, ropes, burner and envelope are left alone.
## Each change is remembered on the node (meta) so restore_rim() can put it back.
const CUT := 1.30 # Ship-local height: boxes reaching over it are walls; boxes starting over it, rails.
const TOP := 1.75 # Nothing starting above this is touched (ropes, pulleys, burner, envelope).
const META := &"better_balloon_rim"


static func lower_rim(ship: Node3D) -> void:
	if not is_instance_valid(ship) or ship.has_meta(META): return
	ship.set_meta(META, true)
	var gate := ship.get_node_or_null("Gate") as Node3D
	var parts: Array[Node] = ship.get_children()
	if gate != null: parts.append_array(gate.get_children())
	for part: Node in parts:
		if not (part is MeshInstance3D or part is CollisionShape3D): continue
		var node := part as Node3D
		var size := _box_size(node)
		if size == Vector3.ZERO: continue
		var base := gate.position.y if node.get_parent() == gate else 0.0
		var bottom := base + node.position.y - size.y * 0.5
		var top := base + node.position.y + size.y * 0.5
		if bottom >= TOP: continue
		if bottom >= CUT: _shift(node, -LOWER)
		elif top > CUT: _shorten(node, size)
		elif node is MeshInstance3D and bottom > RIM_Y - 0.02: _hide(node) # trim bands above the new rim
		elif node is MeshInstance3D and top > RIM_Y - 0.04: _shift(node, RIM_Y - 0.04 - top) # the sign board
	for name: String in ["GateBell"]:
		var bell := ship.get_node_or_null(name) as Node3D
		if bell != null: _shift(bell, -LOWER)
	for part: Node in ship.get_children():
		if not part is Label3D: continue
		var label := part as Node3D
		if label.position.y > RIM_Y - 0.05 and label.position.y < TOP: _shift(label, -LOWER)
		elif label.position.y > RIM_Y - 0.25 and label.position.y < TOP and absf(label.position.x) > 1.3: _shift(label, RIM_Y - 0.25 - label.position.y) # the sign's text
	_add_ropes(ship)


static func restore_rim(ship: Node3D) -> void:
	if not is_instance_valid(ship) or not ship.has_meta(META): return
	ship.remove_meta(META)
	var parts: Array[Node] = ship.get_children()
	var gate := ship.get_node_or_null("Gate")
	if gate != null: parts.append_array(gate.get_children())
	for part: Node in parts:
		if not part.has_meta(META): continue
		var was: Array = part.get_meta(META)
		(part as Node3D).position = was[0]
		if was[1] is Vector3: _set_box_size(part as Node3D, was[1])
		if was.size() > 2: (part as Node3D).visible = bool(was[2])
		part.remove_meta(META)
	_remove_ropes(ship)


static func _box_size(node: Node3D) -> Vector3:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh: return ((node as MeshInstance3D).mesh as BoxMesh).size
	if node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D: return ((node as CollisionShape3D).shape as BoxShape3D).size
	return Vector3.ZERO


static func _set_box_size(node: Node3D, size: Vector3) -> void:
	if node is MeshInstance3D: ((node as MeshInstance3D).mesh as BoxMesh).size = size
	elif node is CollisionShape3D: ((node as CollisionShape3D).shape as BoxShape3D).size = size


static func _remember(node: Node3D, size: Variant) -> void:
	if not node.has_meta(META): node.set_meta(META, [node.position, size])


static func _hide(node: Node3D) -> void:
	if not node.has_meta(META): node.set_meta(META, [node.position, null, node.visible])
	node.visible = false


## Ropes: the balloon's four ropes rebuilt in Blender for the lower basket (ropes.json, made by
## renders/better_balloon/blender/rope_rebuild.py from the RNL balloon model: each rope keeps its
## top under the envelope, its shape and thickness, re-aimed to the new corners and wrapped three
## turns round the corner posts). The old rope triangles (modelled in the two surfaces the game
## colours rope tan) are taken out of the model's mesh; the original mesh is kept to put back.
const ROPES := "res://mods/better_balloon/ropes.json"
const ROPE := "BetterBalloonRopes"
const ROPE_COLOR := Color("d4ad65") # balloon.gd's colour for the model's rope surfaces
const OLD_MESH := &"better_balloon_old_mesh"


static func _add_ropes(ship: Node3D) -> void:
	if ship.get_node_or_null(ROPE) != null or not FileAccess.file_exists(ROPES): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROPES))
	if not data is Dictionary: return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array((data.positions as Array).map(func(v: Array) -> Vector3: return Vector3(v[0], v[1], v[2])))
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array((data.normals as Array).map(func(v: Array) -> Vector3: return Vector3(v[0], v[1], v[2])))
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array((data.uvs as Array).map(func(v: Array) -> Vector2: return Vector2(v[0], v[1])))
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.indices as Array)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ropes := MeshInstance3D.new()
	ropes.name = ROPE
	ropes.mesh = mesh
	ropes.material_override = FITTINGS.material(ROPE_COLOR)
	ship.add_child(ropes)
	# The old ropes out of the model: triangles of the rope-coloured surfaces lying along a rope line.
	var lines: Array = data.get("lines", [])
	var reach := float(data.get("reach", 0.16))
	var removed := 0
	for child: Node in ship.get_children():
		if not String(child.name).to_lower().contains("airballoon"): continue
		for mesh_node: Node in child.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh_node as MeshInstance3D
			if not mi.mesh is ArrayMesh or mi.has_meta(OLD_MESH): continue
			var old := mi.mesh as ArrayMesh
			var to_ship := ship.global_transform.affine_inverse() * mi.global_transform
			var rebuilt := ArrayMesh.new()
			for si in old.get_surface_count():
				var a: Array = old.surface_get_arrays(si)
				var material := old.surface_get_material(si)
				var rope_surface := material is StandardMaterial3D and (material as StandardMaterial3D).albedo_color.is_equal_approx(ROPE_COLOR)
				if rope_surface and not (a[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
					var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
					var kept := PackedInt32Array()
					for i in range(0, indices.size(), 3):
						var c: Vector3 = to_ship * ((verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]]) / 3.0)
						if c.y > 1.6 and c.y < 3.6 and _on_line(c, lines, reach):
							removed += 1
							continue
						kept.append(indices[i]); kept.append(indices[i + 1]); kept.append(indices[i + 2])
					if kept.is_empty(): continue
					a[Mesh.ARRAY_INDEX] = kept
				rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
				rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, material)
			mi.set_meta(OLD_MESH, old)
			mi.mesh = rebuilt
	print("[better_balloon] ropes rebuilt for the lower basket (%d old rope triangles hidden)" % removed)


## Within `reach` of one of the old ropes' lines (each extended up toward the envelope).
static func _on_line(c: Vector3, lines: Array, reach: float) -> bool:
	for line: Array in lines:
		var a := Vector3(line[0][0], line[0][1], line[0][2])
		var b := Vector3(line[1][0], line[1][1], line[1][2])
		var d := b - a
		var t := clampf((c - a).dot(d) / d.length_squared(), -3.0, 1.1)
		if c.distance_to(a + d * t) < reach: return true
	return false


static func _remove_ropes(ship: Node3D) -> void:
	var ropes := ship.get_node_or_null(ROPE)
	if ropes != null: ropes.queue_free()
	for child: Node in ship.get_children():
		if not String(child.name).to_lower().contains("airballoon"): continue
		for mesh_node: Node in child.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.has_meta(OLD_MESH):
				(mesh_node as MeshInstance3D).mesh = mesh_node.get_meta(OLD_MESH)
				mesh_node.remove_meta(OLD_MESH)


static func _shift(node: Node3D, by: float) -> void:
	_remember(node, null)
	node.position.y += by


static func _shorten(node: Node3D, size: Vector3) -> void:
	_remember(node, size)
	_set_box_size(node, size - Vector3(0, LOWER, 0))
	node.position.y -= LOWER * 0.5


static func remove(ship: Node3D) -> void:
	if not is_instance_valid(ship): return
	for i in CRATE_X.size():
		var crate := ship.get_node_or_null("%s%d" % [NAME, i])
		if crate != null: crate.queue_free()
