extends RefCounted
## The tea idle's cup and saucer. Each princess has her own set, modelled in Blender
## (renders/idle_life/tea_sets_v2.blend) and exported to models/tea_<set>_cup.glb and
## tea_<set>_saucer.glb: Celestia's white with gold and a sun, Luna's night blue with silver and
## a crescent, about 440 triangles a set. Without a set (or its files) the plain white-and-gold
## pair below is made in code. The cup's origin is the middle of its base; its handle is on its
## +X side, the motif on its -X side.

## Sizes at an ordinary mare's size (metres).
const CUP_HEIGHT := 0.0505
const CUP_TOP := 0.035
const MODELS := "res://mods/idle_life/models/tea_%s_%s.glb"
const CUP_FOOT := 0.024
const SAUCER := 0.066
const PORCELAIN := Color(0.97, 0.96, 0.93)
const GOLD := Color(0.86, 0.67, 0.26)
const TEA := Color(0.5, 0.27, 0.1)


## A cup from `set`'s model ("celestia", "luna"), else made in code.
static func make_cup(set := "") -> Node3D:
	var model := _model(set, "cup")
	if model != null:
		model.name = "IdleLifeTeacup"
		return model
	var cup := Node3D.new()
	cup.name = "IdleLifeTeacup"
	var body := _mesh(_cylinder(CUP_TOP, CUP_FOOT, CUP_HEIGHT), _porcelain())
	body.position.y = CUP_HEIGHT / 2.0
	cup.add_child(body)
	var rim := _mesh(_torus(CUP_TOP - 0.002, CUP_TOP + 0.0025), _gold())
	rim.position.y = CUP_HEIGHT
	cup.add_child(rim)
	var foot := _mesh(_torus(CUP_FOOT - 0.002, CUP_FOOT + 0.002), _gold())
	foot.position.y = 0.002
	cup.add_child(foot)
	var tea := _mesh(_cylinder(CUP_TOP - 0.003, CUP_TOP - 0.004, 0.002), _flat(TEA, 0.15))
	tea.position.y = CUP_HEIGHT - 0.008
	cup.add_child(tea)
	var handle := _mesh(_torus(0.009, 0.0145), _porcelain())
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(CUP_TOP - 0.001, CUP_HEIGHT * 0.55, 0.0)
	cup.add_child(handle)
	return cup


static func make_saucer(set := "") -> Node3D:
	var model := _model(set, "saucer")
	if model != null:
		model.name = "IdleLifeSaucer"
		return model
	var saucer := Node3D.new()
	saucer.name = "IdleLifeSaucer"
	var plate := _mesh(_cylinder(SAUCER, SAUCER * 0.62, 0.008), _porcelain())
	plate.position.y = 0.004
	saucer.add_child(plate)
	var rim := _mesh(_torus(SAUCER - 0.003, SAUCER + 0.002), _gold())
	rim.position.y = 0.008
	saucer.add_child(rim)
	return saucer


## The point of the cup's rim nearest `toward` (a direction in the cup's own space, sideways).
static func rim_point(toward: Vector3) -> Vector3:
	var flat := Vector3(toward.x, 0.0, toward.z)
	flat = flat.normalized() if not flat.is_zero_approx() else Vector3.FORWARD
	return Vector3(0.0, CUP_HEIGHT, 0.0) + flat * CUP_TOP


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 28
	c.rings = 1
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 8
	return t


static func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	return mi


static func _porcelain() -> StandardMaterial3D:
	return _flat(PORCELAIN, 0.22)


static func _gold() -> StandardMaterial3D:
	var m := _flat(GOLD, 0.3)
	m.metallic = 0.7
	return m


static func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m


static func _model(set: String, part: String) -> Node3D:
	if set.is_empty(): return null
	var path := MODELS % [set, part]
	if not ResourceLoader.exists(path): return null
	var scene: Variant = load(path)
	return (scene as PackedScene).instantiate() as Node3D if scene is PackedScene else null
