extends RefCounted
## The princesses' grazing (graze_magic): a tuft of grass with a little clump of soil, made in
## code: BLADES tapered blades fanning up from the clump, darker at the root, about HEIGHT tall
## at an ordinary mare's size. Its origin is the bottom of the clump.

const BLADES := 12
const HEIGHT := 0.085
const ROOT := Color(0.24, 0.46, 0.16)
const TIP := Color(0.55, 0.8, 0.3)
const SOIL := Color(0.36, 0.25, 0.16)


static func make(seed := 0) -> Node3D:
	var tuft := Node3D.new()
	tuft.name = "IdleLifeTuft"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES:
		var turn := TAU * i / BLADES + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var lean := rng.randf_range(0.15, 0.55)
		var tall := HEIGHT * rng.randf_range(0.7, 1.1)
		var base := out * rng.randf_range(0.002, 0.008) + Vector3.UP * 0.008
		var side := Vector3.UP.cross(out).normalized() * rng.randf_range(0.0035, 0.005)
		var mid := base + (out * lean * 0.45 + Vector3.UP) * tall * 0.55
		var tip := base + (out * lean + Vector3.UP).normalized() * tall
		# Two quads tapering to a point, both faces drawn (no culling on the material).
		for q in [[base - side, base + side, mid + side * 0.6, mid - side * 0.6, ROOT, ROOT.lerp(TIP, 0.5)]]:
			_quad(st, q[0], q[1], q[2], q[3], q[4], q[5])
		_tri(st, mid - side * 0.6, mid + side * 0.6, tip, ROOT.lerp(TIP, 0.5), TIP)
	var grass := MeshInstance3D.new()
	grass.mesh = st.commit()
	grass.material_override = _material(true)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tuft.add_child(grass)
	var clump := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.016; ball.height = 0.018; ball.radial_segments = 10; ball.rings = 5
	clump.mesh = ball
	var soil := _material(false)
	soil.albedo_color = SOIL
	clump.material_override = soil
	clump.position.y = 0.006
	clump.name = "Soil"
	tuft.add_child(clump)
	return tuft


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
	_tri(st, a, b, c, low, high, true)
	_tri(st, a, c, d, low, high, true)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, low: Color, high: Color, quad := false) -> void:
	for v: Vector3 in [a, b, c]:
		st.set_color(low.lerp(high, clampf(v.y / HEIGHT, 0.0, 1.0)) if not quad else (low if v.y < 0.02 else high))
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


static func _material(blades: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	if blades:
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A crumb of soil shaken off the tuft (main.gd drops it to the ground).
static func crumb(size: float) -> MeshInstance3D:
	var bit := MeshInstance3D.new()
	bit.name = "IdleLifeCrumb"
	var ball := SphereMesh.new()
	var r := 0.004 * size
	ball.radius = r; ball.height = r * 1.6; ball.radial_segments = 6; ball.rings = 3
	bit.mesh = ball
	var soil := _material(false)
	soil.albedo_color = SOIL
	bit.material_override = soil
	bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bit
