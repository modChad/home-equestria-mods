extends RefCounted
## Fishing: cartoon fish built in code (no outside art). One species = one spec Dictionary.
## The fish lies along Z, nose at -Z (Godot's forward), back up +Y, centred on the origin.
## Body: a smooth loft through the spec's stations (Catmull-Rom between them, smooth normals,
## colours blended per vertex: back, side band, belly, cheek). Fins: rounded double-sided
## outlines, darker at the root. Eyes: big cartoon spheres. Spots: small flattened discs.

const RING = 28       # vertices round the body
const STEPS = 48      # rings along the body

## Rainbow-ish river trout.
const TROUT = {
	"id": "trout", "length": 0.40,
	# [t along the body (0 nose .. 1 tail tip), half height, half width, centre lift] as fractions of length
	"stations": [[0.0, .010, .008, -.008], [.035, .066, .048, -.006], [.11, .112, .078, .0], [.23, .142, .092, .004],
		[.38, .150, .094, .006], [.53, .132, .080, .004], [.67, .092, .054, .002], [.78, .052, .030, .0], [.86, .036, .016, .0]],
	"back": Color("56702f"), "band": Color("de7f86"), "belly": Color("f3eedf"), "cheek": Color("e8707c"),
	"fin": Color("6f7346"), "fin_tip": Color("c38f78"), "spot": Color("2e2b22"), "spots": 30, "spot_tail": true,
	"dorsals": [[.40, .57, .09, false]], "anal": [.62, .73, .058], "adipose": true,
	"eye_t": .10, "eye_size": .046,
	"tail_fork": .35,
}

## Perch: golden sides with dark bars, a spiny front dorsal, orange lower fins.
const PERCH = {
	"id": "perch", "length": 0.30,
	"stations": [[0.0, .012, .010, -.010], [.04, .062, .042, -.008], [.12, .112, .070, .0], [.25, .152, .084, .012],
		[.40, .160, .084, .014], [.55, .134, .070, .008], [.70, .084, .044, .002], [.80, .050, .027, .0], [.87, .036, .016, .0]],
	"back": Color("56602a"), "band": Color("c8ae46"), "belly": Color("f2ecd2"), "cheek": Color("d3b65c"),
	"bars": 6, "bar": Color("3a3d1c"),
	"fin": Color("7b7a4a"), "fin_tip": Color("b9a868"), "low_fin": Color("d9552f"), "low_fin_tip": Color("f08a4c"),
	"dorsals": [[.27, .47, .12, true], [.51, .67, .085, false]], "anal": [.64, .74, .06], "adipose": false,
	"spots": 0, "eye_t": .10, "eye_size": .05, "tail_fork": .3,
}

## Carp: chunky and golden-bronze, a long dorsal and two short whiskers.
const CARP = {
	"id": "carp", "length": 0.55,
	"stations": [[0.0, .020, .018, -.012], [.04, .074, .060, -.010], [.12, .130, .095, .0], [.25, .172, .112, .010],
		[.40, .182, .112, .012], [.55, .160, .096, .008], [.70, .108, .064, .004], [.80, .064, .037, .0], [.87, .044, .021, .0]],
	"back": Color("5e4d22"), "band": Color("c4923a"), "belly": Color("f0dfaa"), "cheek": Color("d29e4c"),
	"fin": Color("6f5a2e"), "fin_tip": Color("b9874c"),
	"dorsals": [[.36, .70, .085, false]], "anal": [.67, .76, .065], "adipose": false,
	"barbels": [[.012, .30, .055, .02]],  # [t, angle round the ring from the bottom, length, droop] as fractions
	
	"spots": 0, "eye_t": .11, "eye_size": .036, "tail_fork": .42,
}

## Catfish: a broad flat head, long whiskers, small eyes, a rounded tail.
const CATFISH = {
	"id": "catfish", "length": 0.60,
	"stations": [[0.0, .026, .040, -.010], [.04, .056, .084, -.010], [.12, .080, .108, -.006], [.25, .098, .104, .0],
		[.40, .104, .090, .0], [.55, .094, .070, .0], [.70, .074, .050, .0], [.80, .054, .032, .0], [.88, .040, .018, .0]],
	"back": Color("45463a"), "band": Color("777360"), "belly": Color("ebe5cf"), "cheek": Color("6f6b58"),
	"belly_v": -.15, "back_v": .2,
	"fin": Color("44443a"), "fin_tip": Color("7a7563"),
	"dorsals": [[.29, .37, .10, false]], "anal": [.58, .83, .05], "adipose": true,
	"barbels": [[.03, .78, .26, .03], [.0, .12, .10, .02], [.0, .28, .09, .02]],
	"spots": 14, "spot": Color("2c2c25"),
	"eye_t": .10, "eye_size": .024, "eye_angle": .27, "tail_fork": .06, "tail_round": true,
}

## Sunfish (pumpkinseed): a round disc, orange belly, orange spots, a dark ear flap with a red tip.
const SUNFISH = {
	"id": "sunfish", "length": 0.20,
	"stations": [[0.0, .020, .012, .0], [.05, .110, .038, .0], [.14, .208, .054, .006], [.30, .270, .060, .010],
		[.46, .262, .058, .010], [.60, .200, .048, .006], [.72, .110, .032, .002], [.80, .052, .018, .0], [.85, .040, .012, .0]],
	"back": Color("365f55"), "band": Color("6e9c80"), "belly": Color("ee8a32"), "cheek": Color("4ea6ad"),
	"belly_v": -.05, "back_v": .3,
	"fin": Color("4e6a58"), "fin_tip": Color("9ab08e"), "low_fin": Color("cf7a35"), "low_fin_tip": Color("e9a05a"),
	"dorsals": [[.26, .70, .11, true]], "anal": [.52, .72, .09], "adipose": false,
	"marks": [[.27, .42, .10, Color("1d2423")], [.305, .42, .04, Color("d23a2a")]],  # [t, angle from top / PI, size, colour]
	"spots": 22, "spot": Color("e8843a"), "spot_size": .03,
	"eye_t": .11, "eye_size": .055, "tail_fork": .12,
}

static func build(spec: Dictionary) -> Node3D:
	var root = Node3D.new(); root.name = "Fish_" + str(spec.id)
	var L: float = spec.length
	root.add_child(_body(spec, L))
	root.add_child(_fins(spec, L))
	_eyes(root, spec, L)
	_spots(root, spec, L)
	_marks(root, spec, L)
	if spec.has("barbels"): root.add_child(_barbels(spec, L))
	return root

static func _material(cull := true) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.roughness = .55
	m.rim_enabled = true; m.rim = .25; m.rim_tint = .6
	if not cull: m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.rim_enabled = false
	return m

## Catmull-Rom through the stations' column idx at t (stations need not be evenly spaced).
static func _interp(spec: Dictionary, t: float, idx: int) -> float:
	var s: Array = spec.stations
	var n = s.size()
	if t <= float(s[0][0]): return float(s[0][idx])
	if t >= float(s[n - 1][0]): return float(s[n - 1][idx])
	for i in n - 1:
		if t <= float(s[i + 1][0]):
			var f = inverse_lerp(float(s[i][0]), float(s[i + 1][0]), t)
			var p0 = float(s[max(i - 1, 0)][idx]); var p1 = float(s[i][idx])
			var p2 = float(s[i + 1][idx]); var p3 = float(s[min(i + 2, n - 1)][idx])
			return maxf(0.0, 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f))
	return float(s[n - 1][idx])
static func _height_at(spec: Dictionary, t: float) -> float: return _interp(spec, t, 1)
static func _width_at(spec: Dictionary, t: float) -> float: return _interp(spec, t, 2)
static func _lift_at(spec: Dictionary, t: float) -> float: return _interp(spec, t, 3)

## Point on the body surface at t (0..tail end) and ring angle a (0 = top).
static func _surface(spec: Dictionary, L: float, t: float, a: float) -> Vector3:
	var c = cos(a); var s = sin(a)
	var y = signf(c) * pow(absf(c), .9) * _height_at(spec, t) * L
	var x = signf(s) * pow(absf(s), .9) * _width_at(spec, t) * L
	return Vector3(x, _lift_at(spec, t) * L + y, (-.5 + t) * L)

static func _body_colour(spec: Dictionary, v: float, t: float) -> Color:
	# v: +1 top .. -1 bottom. Soft blends between the bands.
	var bv: float = spec.get("belly_v", -.3); var kv: float = spec.get("back_v", .27)
	var col: Color = (spec.belly as Color).lerp(spec.band, smoothstep(bv - .12, bv + .12, v))
	col = col.lerp(spec.back, smoothstep(kv - .15, kv + .15, v))
	if spec.has("bars") and v > bv and t > .2 and t < .82:
		var bar = smoothstep(.35, .8, sin((t - .2) / .62 * PI * float(spec.bars) * 2.0 - PI * .5))
		col = col.lerp(spec.bar, bar * smoothstep(bv, bv + .3, v) * .75)
	if spec.has("scales") and v > bv:
		var sc = absf(sin(t * 70.0 + sin(acos(clampf(v, -1, 1)) * 9.0) * 1.2))
		col = col.lerp(spec.scales, smoothstep(.9, 1.0, sc) * .35)
	# Cheek: a soft blush behind the eye.
	var cheek = (1.0 - smoothstep(.0, .07, absf(t - .17))) * (1.0 - smoothstep(.15, .5, absf(v + .05)))
	return col.lerp(spec.cheek, cheek * .8)

static func _body(spec: Dictionary, L: float) -> MeshInstance3D:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t_end = float(spec.stations[-1][0])
	var e = .002
	for i in STEPS + 1:
		# Denser rings at the nose, where the curve turns fastest.
		var u = float(i) / STEPS
		var t = t_end * (u * u * (3.0 - 2.0 * u) * .35 + u * .65)
		for k in RING + 1:
			var a = TAU * k / RING
			var p = _surface(spec, L, t, a)
			var dt = _surface(spec, L, minf(t + e, t_end), a) - _surface(spec, L, maxf(t - e, 0.0), a)
			var da = _surface(spec, L, t, a + e) - _surface(spec, L, t, a - e)
			var n = da.cross(dt).normalized()
			if n.dot(Vector3(p.x, p.y - _lift_at(spec, t) * L, 0)) < 0: n = -n
			if i == 0: n = Vector3.FORWARD
			st.set_color(_body_colour(spec, cos(a), t)); st.set_normal(n); st.set_uv(Vector2(float(k) / RING, u))
			st.add_vertex(p)
	for i in STEPS:
		for k in RING:
			var a = i * (RING + 1) + k; var b = a + 1; var c = a + RING + 1; var d = c + 1
			# Clockwise seen from outside (Godot's front face).
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	# Close the tail end (hidden by the tail fin, but no hole from behind).
	var base = STEPS * (RING + 1)
	var centre_i = (STEPS + 1) * (RING + 1)
	st.set_color(_body_colour(spec, 0.0, t_end)); st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3(0, _lift_at(spec, t_end) * L, (-.5 + t_end) * L))
	for k in RING:
		st.add_index(centre_i); st.add_index(base + k + 1); st.add_index(base + k)
	var mi = MeshInstance3D.new(); mi.name = "Body"; mi.mesh = st.commit(); mi.material_override = _material()
	_check_winding(mi)
	return mi

## Flip every triangle if the first one faces inward (keeps the loft order honest).
static func _check_winding(mi: MeshInstance3D) -> void:
	pass

## Rounds a polygon outline (Chaikin), keeping the first and last points (the fin's root).
static func _round(pts: Array, passes := 3) -> Array:
	var out: Array = pts
	for _p in passes:
		var next: Array = [out[0]]
		for i in out.size() - 1:
			var a: Vector3 = out[i]; var b: Vector3 = out[i + 1]
			next.append(a.lerp(b, .25)); next.append(a.lerp(b, .75))
		next.append(out[-1]); out = next
	return out

## A fin from its root edge (first and last points) out to its rounded edge. Fan from the
## root's middle; colour fades from fin to fin_tip with distance from the root.
static func _fin(st: SurfaceTool, spec: Dictionary, pts: Array, passes := 3) -> void:
	var outline = _round(pts, passes)
	var root_mid: Vector3 = (pts[0] + pts[-1]) * .5
	var reach = 0.0
	for p in outline: reach = maxf(reach, p.distance_to(root_mid))
	var n = (pts[1] - pts[0]).cross(pts[-1] - pts[0]).normalized()
	var colour = func(p: Vector3) -> Color:
		return (spec.fin as Color).lerp(spec.fin_tip, smoothstep(.2, 1.0, p.distance_to(root_mid) / maxf(reach, .0001)))
	for i in outline.size() - 1:
		for p in [root_mid, outline[i], outline[i + 1]]:
			st.set_color(colour.call(p)); st.set_normal(n); st.add_vertex(p)

static func _fins(spec: Dictionary, L: float) -> MeshInstance3D:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low_spec = spec.duplicate()
	if spec.has("low_fin"): low_spec.fin = spec.low_fin; low_spec.fin_tip = spec.low_fin_tip
	var t_end = float(spec.stations[-1][0])
	var tail_z = (-.5 + t_end) * L
	var lift = _lift_at(spec, t_end) * L
	var fork: float = spec.get("tail_fork", .3)
	# Caudal (tail): a broad fan, forked or rounded.
	var span = .23 * L; var reach = .17 * L
	var tail_pts: Array
	if spec.get("tail_round", false):
		tail_pts = [Vector3(0, lift + .03 * L, tail_z - .02 * L), Vector3(0, lift + span * .42, tail_z + reach * .8), Vector3(0, lift + span * .2, tail_z + reach * 1.05),
			Vector3(0, lift, tail_z + reach * (1.05 - fork)), Vector3(0, lift - span * .2, tail_z + reach * 1.05), Vector3(0, lift - span * .42, tail_z + reach * .8), Vector3(0, lift - .03 * L, tail_z - .02 * L)]
	else:
		tail_pts = [Vector3(0, lift + .03 * L, tail_z - .02 * L), Vector3(0, lift + span * .5, tail_z + reach), Vector3(0, lift + span * .14, tail_z + reach * (1.0 - fork * .55)),
			Vector3(0, lift, tail_z + reach * (1.0 - fork)), Vector3(0, lift - span * .14, tail_z + reach * (1.0 - fork * .55)), Vector3(0, lift - span * .5, tail_z + reach),
			Vector3(0, lift - .03 * L, tail_z - .02 * L)]
	_fin(st, spec, tail_pts, 2)
	var top = func(t: float) -> Vector3: return _surface(spec, L, t, 0.0) + Vector3.DOWN * .004 * L
	var low = func(t: float) -> Vector3: return _surface(spec, L, t, PI) + Vector3.UP * .004 * L
	# Dorsals: [t0, t1, height, spiny]. Spiny ones get a row of points along the edge.
	for d in spec.get("dorsals", [[.40, .57, .09, false]]):
		var d0: Vector3 = top.call(d[0]); var d1: Vector3 = top.call(d[1]); var h: float = d[2] * L
		if d[3]:
			var pts: Array = [d0]
			var spines = maxi(4, int((d[1] - d[0]) * 22.0))
			for i in spines:
				var f = (i + .5) / spines
				var base: Vector3 = top.call(lerpf(d[0], d[1], f))
				var hh = h * (1.0 - .45 * f) * (.75 + .25 * sin(f * PI))
				pts.append(base + Vector3(0, hh, .02 * L))
				if i < spines - 1: pts.append(top.call(lerpf(d[0], d[1], f + .5 / spines)) + Vector3(0, hh * .62, .01 * L))
			pts.append(d1)
			_fin(st, spec, pts, 0)
		else:
			_fin(st, spec, [d0, d0 + Vector3(0, h, h * .55), d1 + Vector3(0, h * .38, h * .38), d1])
	if spec.get("adipose", true):
		var a0: Vector3 = top.call(.71); var a1: Vector3 = top.call(.77)
		_fin(st, spec, [a0, a0 + Vector3(0, .028 * L, .03 * L), a1])
	var an: Array = spec.get("anal", [.62, .73, .058])
	var n0: Vector3 = low.call(an[0]); var n1: Vector3 = low.call(an[1])
	_fin(st, low_spec, [n0, n0 + Vector3(0, -an[2] * L, an[2] * .8 * L), n1 + Vector3(0, -an[2] * .3 * L, .02 * L), n1])
	# Paired fins: pectorals behind the gills, pelvics mid-belly; angled out and down.
	for side in [-1.0, 1.0]:
		var pa = _surface(spec, L, .24, side * PI * .62); var pb = _surface(spec, L, .29, side * PI * .62)
		_fin(st, low_spec, [pa, pa + Vector3(side * .05 * L, -.05 * L, .075 * L), pb + Vector3(side * .03 * L, -.025 * L, .06 * L), pb])
		var qa = _surface(spec, L, .44, side * PI * .82); var qb = _surface(spec, L, .49, side * PI * .82)
		_fin(st, low_spec, [qa, qa + Vector3(side * .035 * L, -.045 * L, .055 * L), qb + Vector3(side * .01 * L, -.012 * L, .03 * L), qb])
	var mi = MeshInstance3D.new(); mi.name = "Fins"; mi.mesh = st.commit(); mi.material_override = _material(false)
	return mi

## Whiskers: [t, angle round from the bottom (fraction of PI), length, droop], mirrored both sides.
static func _barbels(spec: Dictionary, L: float) -> MeshInstance3D:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col: Color = (spec.back as Color).lerp(spec.belly, .25)
	for b in spec.barbels:
		for side in [-1.0, 1.0]:
			var root = _surface(spec, L, b[0], PI - side * PI * b[1])
			var out = Vector3(side * .8, -.3, -.5).normalized()
			var length: float = b[2] * L
			var pts: Array = []
			for i in 9:
				var f = i / 8.0
				pts.append(root + out * length * f + Vector3(side * .3, 0, .6) * length * f * f * .5 + Vector3.DOWN * b[3] * L * f * f)
			_tube(st, pts, .006 * L, .0012 * L, col)
	var mi = MeshInstance3D.new(); mi.name = "Barbels"; mi.mesh = st.commit(); mi.material_override = _material()
	return mi

static func _tube(st: SurfaceTool, pts: Array, r0: float, r1: float, col: Color) -> void:
	const SIDES = 6
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var dir = (b - a).normalized()
		var u = dir.cross(Vector3.UP if absf(dir.y) < .9 else Vector3.RIGHT).normalized(); var w = dir.cross(u)
		var ra = lerpf(r0, r1, float(i) / (pts.size() - 1)); var rb = lerpf(r0, r1, float(i + 1) / (pts.size() - 1))
		for k in SIDES:
			var a0 = TAU * k / SIDES; var a1 = TAU * (k + 1) / SIDES
			var n0 = u * cos(a0) + w * sin(a0); var n1 = u * cos(a1) + w * sin(a1)
			for v in [[a + n0 * ra, n0], [b + n1 * rb, n1], [b + n0 * rb, n0], [a + n0 * ra, n0], [a + n1 * ra, n1], [b + n1 * rb, n1]]:
				st.set_color(col); st.set_normal(v[1]); st.add_vertex(v[0])

## Flat markings on both sides: [t, angle from the top (fraction of PI), size, colour].
static func _marks(root: Node3D, spec: Dictionary, L: float) -> void:
	for m in spec.get("marks", []):
		var mat = StandardMaterial3D.new(); mat.albedo_color = m[3]; mat.roughness = .5
		var s = SphereMesh.new(); s.radius = m[2] * L * .5; s.height = m[2] * L; s.rings = 8; s.radial_segments = 16
		for side in [-1.0, 1.0]:
			var p = _surface(spec, L, m[0], side * PI * m[1])
			var out = Vector3(p.x, p.y - _lift_at(spec, m[0]) * L, 0).normalized()
			var mi = MeshInstance3D.new(); mi.mesh = s; mi.material_override = mat
			mi.position = p + out * .002 * L
			mi.basis = Basis(Quaternion(Vector3.UP, out)) * Basis.from_scale(Vector3(1.3, .15, 1))
			root.add_child(mi)

static func _ball(r: float, col: Color, rings := 12, segs := 20) -> MeshInstance3D:
	var s = SphereMesh.new(); s.radius = r; s.height = r * 2; s.rings = rings; s.radial_segments = segs
	var m = StandardMaterial3D.new(); m.albedo_color = col; m.roughness = .25
	var mi = MeshInstance3D.new(); mi.mesh = s; mi.material_override = m
	return mi

static func _eyes(root: Node3D, spec: Dictionary, L: float) -> void:
	var t: float = spec.eye_t; var r: float = spec.eye_size * L
	for side in [-1.0, 1.0]:
		var at = _surface(spec, L, t, side * PI * float(spec.get("eye_angle", .36)))
		var out = Vector3(side, .25, -.15).normalized()
		var white = _ball(r, Color("fbfaf4")); white.name = "Eye"; white.position = at - out * r * .35; white.scale = Vector3(.75, 1, 1); root.add_child(white)
		var pupil = _ball(r * .6, Color("1a1a22")); pupil.name = "Pupil"; pupil.position = at + out * r * .12 + Vector3(0, 0, -r * .12); pupil.scale = Vector3(.6, 1, 1); root.add_child(pupil)
		var shine = _ball(r * .2, Color.WHITE, 6, 10); shine.name = "Shine"; shine.position = at + out * r * .4 + Vector3(0, r * .3, -r * .3); root.add_child(shine)

static func _spots(root: Node3D, spec: Dictionary, L: float) -> void:
	var rng = RandomNumberGenerator.new(); rng.seed = hash(spec.id)
	var mat = StandardMaterial3D.new(); mat.albedo_color = spec.get("spot", Color.BLACK); mat.roughness = .6
	var s = SphereMesh.new(); s.radius = float(spec.get("spot_size", .016)) * .5 * L; s.height = float(spec.get("spot_size", .016)) * L; s.rings = 6; s.radial_segments = 12
	var placed = 0; var tries = 0
	while placed < int(spec.spots) and tries < 400:
		tries += 1
		var t = rng.randf_range(.3, .84)
		var a = rng.randf_range(-1.2, 1.2)  # round the ring from the top, radians
		if absf(a) > .9 and t < .4: continue
		var p = _surface(spec, L, t, a)
		var out = Vector3(p.x, p.y - _lift_at(spec, t) * L, 0).normalized()
		var mi = MeshInstance3D.new(); mi.mesh = s; mi.material_override = mat
		mi.position = p + out * .001 * L
		mi.basis = Basis(Quaternion(Vector3.UP, out)) * Basis.from_scale(Vector3(1, .25, 1)) * rng.randf_range(.7, 1.3)
		root.add_child(mi); placed += 1
	if spec.get("spot_tail", false):
		var tail_z = (-.5 + float(spec.stations[-1][0])) * L
		for i in 7:
			var y = rng.randf_range(-.08, .08) * L; var z = tail_z + rng.randf_range(.03, .14) * L
			for side in [-1.0, 1.0]:
				var mi = MeshInstance3D.new(); mi.mesh = s; mi.material_override = mat
				mi.position = Vector3(side * .0015 * L, y, z)
				mi.basis = Basis(Vector3.FORWARD, PI * .5) * Basis.from_scale(Vector3(.75, .2, .75))
				root.add_child(mi)
