extends RefCounted
## The mod's own art, drawn here so the pack ships no outside assets. An original mint pony in the
## show's flat cartoon look (coral and gold mane, pinwheel cutie mark) with no tail, facing left,
## and a dashed gold ring on her rump where the tail belongs.

## Poster size in metres and the SVG canvas it is drawn on (same aspect).
const POSTER_SIZE := Vector2(1.30, 1.10)
const CANVAS := Vector2(520, 440)
## Where the tail belongs, in canvas pixels.
const TARGET_PX := Vector2(414, 226)

const POSTER_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="880" viewBox="0 0 520 440">
<defs>
<linearGradient id="iris" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5b3aa0"/><stop offset="1" stop-color="#b48ae6"/></linearGradient>
<linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbf4ff"/><stop offset="1" stop-color="#efe3fb"/></linearGradient>
</defs>
<rect width="520" height="440" fill="url(#paper)"/>
<rect x="9" y="9" width="502" height="422" rx="14" fill="none" stroke="#f29ac4" stroke-width="10"/>
<rect x="20" y="20" width="480" height="400" rx="8" fill="none" stroke="#f9c9df" stroke-width="3"/>
<g fill="none" stroke-width="7" stroke-linecap="round">
<path d="M30 30 C 50 50, 30 70, 50 90 S 40 130, 60 150" stroke="#7fc8f0"/>
<path d="M490 28 C 470 48, 492 70, 472 92 S 482 130, 462 148" stroke="#ffcf5c"/>
<path d="M60 28 C 76 44, 62 60, 80 74" stroke="#f29ac4"/>
<path d="M458 30 C 444 46, 460 62, 444 78" stroke="#8fd9b6"/>
</g>
<g>
<rect x="96" y="44" width="9" height="9" fill="#ffcf5c" transform="rotate(20 100 48)"/>
<rect x="300" y="36" width="8" height="8" fill="#7fc8f0" transform="rotate(-25 304 40)"/>
<rect x="420" y="110" width="9" height="9" fill="#f29ac4" transform="rotate(35 424 114)"/>
<rect x="46" y="210" width="8" height="8" fill="#8fd9b6" transform="rotate(10 50 214)"/>
<rect x="470" y="300" width="9" height="9" fill="#ffcf5c" transform="rotate(-15 474 304)"/>
<rect x="70" y="350" width="8" height="8" fill="#f29ac4" transform="rotate(40 74 354)"/>
<rect x="250" y="60" width="7" height="7" fill="#b48ae6" transform="rotate(15 253 63)"/>
<rect x="440" y="380" width="8" height="8" fill="#7fc8f0" transform="rotate(-30 444 384)"/>
<rect x="150" y="392" width="7" height="7" fill="#ffcf5c" transform="rotate(25 153 395)"/>
<rect x="380" y="62" width="8" height="8" fill="#8fd9b6" transform="rotate(-10 384 66)"/>
</g>
<ellipse cx="290" cy="384" rx="160" ry="12" fill="#e2d2f2"/>
<!-- far legs -->
<g fill="#b3e6cd" stroke="#6fb994" stroke-width="5" stroke-linejoin="round">
<path d="M220 262 L 252 262 L 248 370 C 248 380, 224 380, 224 370 Z"/>
<path d="M336 262 L 368 262 L 364 370 C 364 380, 340 380, 340 370 Z"/>
</g>
<g stroke="#6fb994" stroke-width="4"><path d="M225 360 L 247 360"/><path d="M341 360 L 363 360"/></g>
<!-- near body: outline pass -->
<g fill="#c9f2de" stroke="#6fb994" stroke-width="10" stroke-linejoin="round">
<path d="M180 168 C 188 200, 200 222, 216 240 L 276 222 C 250 196, 236 160, 226 126 Z"/>
<ellipse cx="296" cy="250" rx="108" ry="56"/>
<ellipse cx="364" cy="254" rx="52" ry="54"/>
<path d="M190 260 L 226 260 L 222 376 C 222 388, 196 388, 196 376 Z"/>
<path d="M366 264 L 402 264 L 398 376 C 398 388, 372 388, 372 376 Z"/>
<path d="M116 170 C 92 170, 84 150, 94 134 C 102 120, 114 112, 122 96 C 132 70, 170 56, 202 70 C 238 86, 244 130, 226 158 C 210 182, 160 188, 116 170 Z"/>
</g>
<!-- near body: fill pass hides the inner seams -->
<g fill="#c9f2de">
<path d="M180 168 C 188 200, 200 222, 216 240 L 276 222 C 250 196, 236 160, 226 126 Z"/>
<ellipse cx="296" cy="250" rx="108" ry="56"/>
<ellipse cx="364" cy="254" rx="52" ry="54"/>
<path d="M190 260 L 226 260 L 222 376 C 222 388, 196 388, 196 376 Z"/>
<path d="M366 264 L 402 264 L 398 376 C 398 388, 372 388, 372 376 Z"/>
<path d="M116 170 C 92 170, 84 150, 94 134 C 102 120, 114 112, 122 96 C 132 70, 170 56, 202 70 C 238 86, 244 130, 226 158 C 210 182, 160 188, 116 170 Z"/>
</g>
<g fill="none" stroke="#6fb994" stroke-width="4" stroke-linecap="round">
<path d="M196 366 L 222 366"/><path d="M372 366 L 398 366"/>
<path d="M332 228 C 344 214, 366 210, 384 218"/>
<path d="M204 166 C 214 176, 222 186, 226 200"/>
</g>
<!-- mane -->
<path d="M166 66 C 214 48, 258 80, 254 124 C 252 158, 268 186, 292 202 C 256 208, 230 188, 220 160 C 212 134, 198 110, 176 98 Z" fill="#ff9f8c" stroke="#e0705c" stroke-width="5" stroke-linejoin="round"/>
<path d="M196 70 C 230 78, 242 106, 240 136 C 240 160, 250 178, 266 192 C 240 186, 226 162, 224 138 C 222 110, 212 92, 194 82 Z" fill="#ffd36e"/>
<path d="M172 64 C 136 58, 112 80, 116 108 C 128 96, 144 92, 160 96 C 152 108, 154 120, 160 126 C 170 108, 184 96, 200 92 Z" fill="#ff9f8c" stroke="#e0705c" stroke-width="5" stroke-linejoin="round"/>
<path d="M150 72 C 132 76, 122 90, 122 100" fill="none" stroke="#ffd36e" stroke-width="6" stroke-linecap="round"/>
<!-- ear -->
<path d="M196 76 L 214 30 L 232 84 Z" fill="#c9f2de" stroke="#6fb994" stroke-width="5" stroke-linejoin="round"/>
<path d="M204 72 L 214 44 L 224 76 Z" fill="#a5dcc1"/>
<!-- face -->
<ellipse cx="152" cy="126" rx="21" ry="28" fill="#ffffff" stroke="#2f2a3a" stroke-width="3"/>
<ellipse cx="146" cy="130" rx="15" ry="21" fill="url(#iris)"/>
<ellipse cx="144" cy="132" rx="7" ry="11" fill="#1c1626"/>
<ellipse cx="139" cy="119" rx="6" ry="7" fill="#ffffff"/>
<circle cx="151" cy="142" r="3" fill="#ffffff"/>
<path d="M164 102 C 172 98, 178 94, 182 88 M 168 106 C 176 104, 182 102, 188 98" fill="none" stroke="#2f2a3a" stroke-width="3" stroke-linecap="round"/>
<ellipse cx="99" cy="143" rx="3" ry="2.5" fill="#6fb994"/>
<path d="M104 158 C 112 166, 124 166, 132 158" fill="none" stroke="#6fb994" stroke-width="4" stroke-linecap="round"/>
<ellipse cx="176" cy="154" rx="13" ry="7" fill="#ffb6c8" opacity="0.7"/>
<!-- cutie mark: a pinwheel -->
<g transform="translate(362 262)">
<path d="M0 0 L 0 -20 C 12 -20, 16 -8, 0 0 Z" fill="#ff9f8c"/>
<path d="M0 0 L 20 0 C 20 12, 8 16, 0 0 Z" fill="#ffd36e"/>
<path d="M0 0 L 0 20 C -12 20, -16 8, 0 0 Z" fill="#7fc8f0"/>
<path d="M0 0 L -20 0 C -20 -12, -8 -16, 0 0 Z" fill="#f29ac4"/>
<circle r="3.5" fill="#ffffff" stroke="#e0705c" stroke-width="1.5"/>
</g>
<!-- where the tail goes -->
<circle cx="414" cy="226" r="20" fill="none" stroke="#e8b923" stroke-width="5" stroke-dasharray="8 6"/>
<path d="M404 216 L 424 236 M 424 216 L 404 236" stroke="#e8b923" stroke-width="5" stroke-linecap="round"/>
</svg>"""


## The poster's texture.
static func poster_texture() -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(POSTER_SVG) != OK: return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## The target in the poster's local plane (metres, centred, y up).
static func target_local() -> Vector2:
	var uv := TARGET_PX / CANVAS
	return Vector2((uv.x - 0.5) * POSTER_SIZE.x, (0.5 - uv.y) * POSTER_SIZE.y)


static func material(hex: String, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.9
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## How far away a tail is still drawn (metres). They are small and the room is small.
const TAIL_RANGE := 12.0
## Tail looks made once and shared by every tail (seed picks one): strands differ in length and fan.
const TAIL_VARIANTS := 4
const TAIL_COLOURS := ["ff9f8c", "ffd36e", "e0705c", "ff9f8c", "ffd36e"]
const PIN_COLOUR := "e8b923"
## Sides round a strand and round the pin head. 6 keeps a tail at 144 triangles.
const SIDES := 6
static var _tail_meshes: Array[ArrayMesh] = []
static var _tail_material: StandardMaterial3D


## A yarn tail on a gold pin. Its origin is the pin head; local +z points out of the surface it is
## pinned to and the strands hang down local -y.
## 0.4.2: one shared low-poly mesh (144 triangles, vertex coloured, one material) instead of a
## 64-segment sphere and five 64-segment capsules each with its own material (~21,500 triangles and
## six draw calls a tail). Same size, colours and layout; drawn out to TAIL_RANGE.
static func make_tail(seed_value: int) -> Node3D:
	if _tail_meshes.is_empty():
		for v in TAIL_VARIANTS: _tail_meshes.append(_build_tail_mesh(1000 + v * 7919))
		_tail_material = StandardMaterial3D.new()
		_tail_material.vertex_color_use_as_albedo = true
		_tail_material.vertex_color_is_srgb = true
		_tail_material.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.name = "PinnedTail"
	mi.mesh = _tail_meshes[posmod(seed_value, TAIL_VARIANTS)]
	mi.material_override = _tail_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = TAIL_RANGE
	return mi


static func _build_tail_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Pin head: radius 0.018 at z 0.03 (a pole, two rings, a pole).
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.03))
	_lathe(st, head, [Vector2(0.0, 0.018), Vector2(0.0156, 0.009), Vector2(0.0156, -0.009), Vector2(0.0, -0.018)], Color(PIN_COLOUR))
	# Strands: as 0.4.1's capsules (radius 0.022, 0.30-0.40 long, hung from z 0.022, fanned), a
	# little narrower at the tip.
	for i in TAIL_COLOURS.size():
		var length := rng.randf_range(0.30, 0.40)
		var fan := (float(i) - 2.0) * 0.16 + rng.randf_range(-0.04, 0.04)
		var tilt := rng.randf_range(-0.08, 0.08)
		var at := Transform3D(Basis.from_euler(Vector3(tilt, 0, fan)), Vector3(0, 0, 0.022))
		var r := 0.022
		_lathe(st, at, [Vector2(0.0, 0.0), Vector2(r, -r), Vector2(r * 0.8, -(length - r * 0.8)), Vector2(0.0, -length)], Color(TAIL_COLOURS[i]))
	st.index()
	st.generate_normals()
	return st.commit()


## A closed SIDES-sided solid of revolution round local y: profile points (radius, y), first and
## last on the axis. 2 * SIDES * (points - 2) triangles.
static func _lathe(st: SurfaceTool, xf: Transform3D, profile: Array, colour: Color) -> void:
	st.set_color(colour)
	var rings: Array = []
	for p: Vector2 in profile:
		var ring: Array[Vector3] = []
		for k in SIDES:
			var a := TAU * k / SIDES
			ring.append(xf * Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
		rings.append(ring)
	for j in rings.size() - 1:
		var top: Array[Vector3] = rings[j]
		var low: Array[Vector3] = rings[j + 1]
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			if j > 0:
				st.add_vertex(top[k]); st.add_vertex(low[k]); st.add_vertex(top[k2])
			if j < rings.size() - 2:
				st.add_vertex(top[k2]); st.add_vertex(low[k]); st.add_vertex(low[k2])
