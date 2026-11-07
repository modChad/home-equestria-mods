extends RefCounted
## Builds the two brush models from primitives (no imported art). Used only by
## res://mods/grooming/tools/make_models.gd, which saves them as models/<kind>_brush.scn; the game
## shows those through its own item visual (merge/world/food/definitions.json "model").
## Frame: grip at the origin, brush head toward -Z, bristles facing -Y. Every mesh sits under a
## "container_brush" node so the game treats it as a container part (never eaten, never hidden).

const WOOD := Color("b07a46")
const WOOD_DARK := Color("6e4527")
const BRISTLE := Color("3b2f2a")
const STRAP := Color("7a2f3a")


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ManeBrush" if kind == "mane" else "CoatBrush"
	var parts := Node3D.new()
	parts.name = "container_brush"
	root.add_child(parts)
	if kind == "coat": _coat(parts)
	else: _mane(parts)
	for child: Node in parts.get_children(): child.owner = root
	parts.owner = root
	return root


## Paddle brush: handle, oval head, a cushion of short bristles underneath.
static func _mane(parts: Node3D) -> void:
	_part(parts, _cylinder(0.014, 0.012, 0.13), WOOD, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.03)))
	_part(parts, _cylinder(0.015, 0.015, 0.006), WOOD_DARK, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.035)))
	_part(parts, _cylinder(0.034, 0.034, 0.016), WOOD, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.45)), Vector3(0, 0, -0.165)))
	_part(parts, _cylinder(0.029, 0.029, 0.006), Color("2a2626"), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.45)), Vector3(0, -0.01, -0.165)))
	_part(parts, _cylinder(0.027, 0.025, 0.016), BRISTLE, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.45)), Vector3(0, -0.021, -0.165)))
	# Ball tips: a few rows of beads on the cushion.
	var tips := SphereMesh.new(); tips.radius = 0.0022; tips.height = 0.0044; tips.radial_segments = 6; tips.rings = 3
	for x in range(-3, 4):
		for z in range(-5, 6):
			var p := Vector2(x * 0.0075, z * 0.0075)
			if (p / Vector2(0.025, 0.036)).length() > 1.0: continue
			_part(parts, tips, Color("1b1b1b"), Transform3D(Basis.IDENTITY, Vector3(p.x, -0.03, -0.165 + p.y)))


## Body brush: a wide block with a strap over the back, dense bristles below.
static func _coat(parts: Node3D) -> void:
	_part(parts, _box(Vector3(0.07, 0.024, 0.15)), WOOD, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.06)))
	_part(parts, _box(Vector3(0.072, 0.004, 0.152)), WOOD_DARK, Transform3D(Basis.IDENTITY, Vector3(0, 0.013, -0.06)))
	_part(parts, _box(Vector3(0.05, 0.004, 0.13)), STRAP, Transform3D(Basis.IDENTITY, Vector3(0, 0.022, -0.06)))
	_part(parts, _box(Vector3(0.064, 0.024, 0.142)), BRISTLE, Transform3D(Basis.IDENTITY, Vector3(0, -0.024, -0.06)))
	_part(parts, _box(Vector3(0.06, 0.004, 0.138)), BRISTLE.lightened(0.18), Transform3D(Basis.IDENTITY, Vector3(0, -0.037, -0.06)))


static func _part(parent: Node3D, mesh: Mesh, color: Color, at: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.75
	mi.material_override = m
	mi.transform = at
	parent.add_child(mi)


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top; c.bottom_radius = bottom; c.height = height; c.radial_segments = 16; c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size
	return b
