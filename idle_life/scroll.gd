extends RefCounted
## The scroll idle's scroll, made here (no model file): a parchment between two wooden rods with
## gold knobs. set_open() unrolls it downward from the top rod (0 rolled up .. 1 fully open).
## The parchment's face (toward her) has a border, rows of word-like squiggles and a little sun
## seal: no real writing. Its back is plain.

## Size at an ordinary mare's size (metres).
const WIDTH := 0.22
const HEIGHT := 0.30
const ROD := 0.008
const ROLL := 0.014
const PAPER := Color(0.95, 0.89, 0.74)
const INK := Color(0.32, 0.22, 0.14)
const WOOD := Color(0.5, 0.32, 0.16)
const GOLD := Color(0.86, 0.67, 0.26)
## The rows of writing on the face, as fractions of its height from the top, for her eyes to follow.
const LINES := [0.30, 0.42, 0.54, 0.66]

## Writing (make(true)): the ink runs across these fractions of the width, one row per LINES
## entry; the last row is a short signature, ending at SIGN_END.
const INK_LEFT := 0.18
const INK_RIGHT := 0.82
const SIGN_END := 0.5

static var _face_texture: Texture2D
static var _blank_texture: Texture2D
static var _ink_texture: Texture2D
const WRITE_SHADER := """
shader_type spatial;
uniform sampler2D blank : source_color, filter_linear_mipmap;
uniform sampler2D ink : source_color, filter_linear_mipmap;
uniform float open = 1.0;
uniform vec4 written = vec4(0.0);
uniform vec4 rows = vec4(0.3, 0.42, 0.54, 0.66);
void fragment() {
	vec2 uv = vec2(UV.x, UV.y * open);
	vec4 b = texture(blank, uv);
	vec4 k = texture(ink, uv);
	float show = 0.0;
	for (int i = 0; i < 4; i++) {
		float near = 1.0 - step(0.045, abs(uv.y - rows[i]));
		show = max(show, near * (1.0 - step(written[i], uv.x)));
	}
	ALBEDO = mix(b.rgb, k.rgb, k.a * show);
	ROUGHNESS = 0.9;
}
"""


## `writing`: a blank scroll whose rows of ink appear as set_written() says (the writing idle).
static func make(writing := false) -> Node3D:
	var root := Node3D.new()
	root.name = "IdleLifeScroll"
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	var front := MeshInstance3D.new()
	front.name = "Front"
	front.mesh = quad
	if writing:
		var sm := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = WRITE_SHADER
		sm.shader = shader
		sm.set_shader_parameter("blank", _face(false))
		sm.set_shader_parameter("ink", _ink())
		sm.set_shader_parameter("rows", Vector4(LINES[0], LINES[1], LINES[2], LINES[3]))
		front.material_override = sm
	else:
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = _face()
		fm.roughness = 0.9
		front.material_override = fm
	root.add_child(front)
	var back := MeshInstance3D.new()
	back.name = "Back"
	back.mesh = quad
	var bm := StandardMaterial3D.new()
	bm.albedo_color = PAPER.darkened(0.06)
	bm.roughness = 0.95
	back.material_override = bm
	back.rotation.y = PI
	root.add_child(back)
	for n: String in ["Top", "Bottom"]:
		var roll := Node3D.new()
		roll.name = n
		root.add_child(roll)
		roll.add_child(_cylinder(ROLL, WIDTH, PAPER))
		roll.add_child(_cylinder(ROD, WIDTH + 0.04, WOOD))
		for s: float in [-1.0, 1.0]:
			var knob := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = ROD * 1.8
			ball.height = ROD * 3.6
			knob.mesh = ball
			var km := StandardMaterial3D.new()
			km.albedo_color = GOLD
			km.metallic = 0.6
			km.roughness = 0.35
			knob.material_override = km
			knob.position.x = s * (WIDTH / 2.0 + 0.022)
			roll.add_child(knob)
	set_open(root, 0.0)
	return root


static func _cylinder(radius: float, length: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 16
	c.rings = 1
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.7
	mi.material_override = m
	mi.rotation.z = PI / 2.0
	return mi


## Unrolled `open` of the way: the top rod stays put, the bottom one comes down, and only the top
## part of the writing shows until it is fully open.
static func set_open(root: Node3D, open: float) -> void:
	var u := clampf(open, 0.0, 1.0)
	var shown := HEIGHT * u
	var top_y := HEIGHT / 2.0
	(root.get_node("Top") as Node3D).position = Vector3(0.0, top_y, 0.0)
	(root.get_node("Bottom") as Node3D).position = Vector3(0.0, top_y - maxf(shown, ROLL * 2.0), 0.0)
	for n: String in ["Front", "Back"]:
		var face := root.get_node(n) as MeshInstance3D
		face.visible = u > 0.02
		face.scale = Vector3(1.0, maxf(u, 0.001), 1.0)
		face.position = Vector3(0.0, top_y - shown / 2.0, 0.0)
	var m := (root.get_node("Front") as MeshInstance3D).material_override
	if m is StandardMaterial3D: (m as StandardMaterial3D).uv1_scale = Vector3(1.0, maxf(u, 0.001), 1.0)
	elif m is ShaderMaterial: (m as ShaderMaterial).set_shader_parameter("open", maxf(u, 0.001))


## How far along each row the ink has reached, 0..1 per row (x, y, z, w: rows 0..3).
static func set_written(root: Node3D, done: Vector4) -> void:
	var m := (root.get_node("Front") as MeshInstance3D).material_override
	if not m is ShaderMaterial: return
	var at := Vector4()
	for i in 4:
		var end := SIGN_END if i == 3 else INK_RIGHT
		at[i] = lerpf(INK_LEFT, end, clampf(done[i], 0.0, 1.0)) if done[i] > 0.0 else 0.0
	(m as ShaderMaterial).set_shader_parameter("written", at)


## Where the ink is at `along` (0..1) of row `line`, in the scroll's own space (scaled with it).
static func ink_spot(line: int, along: float) -> Vector3:
	var end := SIGN_END if line == 3 else INK_RIGHT
	var u := lerpf(INK_LEFT, end, clampf(along, 0.0, 1.0))
	var down := float(LINES[clampi(line, 0, LINES.size() - 1)])
	return Vector3((u - 0.5) * WIDTH, HEIGHT / 2.0 - HEIGHT * down, 0.0)


## A point on row `line` of the writing, `across` -1 (one end) .. 1 (the other), in the scroll's
## own space (scaled with it).
static func line_spot(line: int, across: float) -> Vector3:
	var down := float(LINES[clampi(line, 0, LINES.size() - 1)])
	return Vector3(across * WIDTH * 0.32, HEIGHT / 2.0 - HEIGHT * down, 0.0)


## The face: `rows` false leaves it blank (border and seal only) for the ink to go on.
static func _face(rows := true) -> Texture2D:
	if rows and _face_texture != null: return _face_texture
	if not rows and _blank_texture != null: return _blank_texture
	var w := 256
	var h := 352
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	# Faint age: a few slightly darker blotches.
	for i in 40:
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, h - 1)
		var r := rng.randi_range(6, 22)
		for y in range(maxi(cy - r, 0), mini(cy + r, h)):
			for x in range(maxi(cx - r, 0), mini(cx + r, w)):
				if Vector2(x - cx, y - cy).length() < r: img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.015))
	# Double border.
	for inset: int in [10, 15]:
		var t := 2 if inset == 10 else 1
		img.fill_rect(Rect2i(inset, inset, w - inset * 2, t), GOLD)
		img.fill_rect(Rect2i(inset, h - inset - t, w - inset * 2, t), GOLD)
		img.fill_rect(Rect2i(inset, inset, t, h - inset * 2), GOLD)
		img.fill_rect(Rect2i(w - inset - t, inset, t, h - inset * 2), GOLD)
	if rows:
		# A heading: one thicker squiggle, centred.
		_word_row(img, rng, 52, 70, w - 70, 4)
		# Rows of writing: the first LINES rows a little bolder (where her eyes go), more below.
		var y := 92
		while y < h - 70:
			var right := w - 30 if y < h - 100 else rng.randi_range(110, 170)
			_word_row(img, rng, y, 30, right, 3)
			y += 15
	# The seal: a small sun, bottom right.
	var sc := Vector2(w - 46, h - 44)
	for py in range(h - 70, h - 18):
		for px in range(w - 72, w - 20):
			var d := Vector2(px, py) - sc
			var a := atan2(d.y, d.x)
			var ray := 13.0 + 6.0 * maxf(cos(a * 8.0), 0.0)
			if d.length() < 9.0: img.set_pixel(px, py, GOLD.darkened(0.1))
			elif d.length() < ray and d.length() > 11.0: img.set_pixel(px, py, GOLD)
	img.generate_mipmaps()
	var texture := ImageTexture.create_from_image(img)
	if rows: _face_texture = texture
	else: _blank_texture = texture
	return texture


## The writing idle's ink, on its own (clear elsewhere): joined-up, looping strokes along each
## LINES row between INK_LEFT and INK_RIGHT (the last row a short signature with a flourish).
static func _ink() -> Texture2D:
	if _ink_texture != null: return _ink_texture
	var w := 256
	var h := 352
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(INK, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in LINES.size():
		var y0 := float(LINES[i]) * h
		var x0 := INK_LEFT * w
		var x1 := (SIGN_END if i == 3 else INK_RIGHT) * w
		var x := x0
		while x < x1 - 4.0:
			var word := minf(rng.randf_range(14.0, 34.0), x1 - x)
			var freq := rng.randf_range(0.7, 1.0)
			var steps := int(word * 4.0)
			for k in steps:
				var px := x + word * k / steps
				# Loops: a wave with a second, faster one riding on it, like joined-up letters.
				var py := y0 + 3.2 * sin(px * freq) + 1.2 * sin(px * freq * 2.7 + 1.0)
				_dot(img, px, py, 1.0 if i < 3 else 1.3)
			x += word + rng.randf_range(5.0, 8.0)
		if i == 3:
			# The signature's flourish: a long underline sweeping back.
			for k in 160:
				var f := k / 160.0
				_dot(img, lerpf(x1, x0, f), y0 + 7.0 + 2.0 * sin(f * PI), 0.9)
	img.generate_mipmaps()
	_ink_texture = ImageTexture.create_from_image(img)
	return _ink_texture


static func _dot(img: Image, x: float, y: float, r: float) -> void:
	for dy in range(int(floor(y - r)), int(ceil(y + r)) + 1):
		for dx in range(int(floor(x - r)), int(ceil(x + r)) + 1):
			if dx < 0 or dy < 0 or dx >= img.get_width() or dy >= img.get_height(): continue
			var d := Vector2(dx - x, dy - y).length()
			if d <= r: img.set_pixel(dx, dy, Color(INK, maxf(img.get_pixel(dx, dy).a, clampf(1.2 - d / r * 0.4, 0.0, 1.0))))


## Word-like squiggles along one row: short runs of ink with gaps, each wobbling a little.
static func _word_row(img: Image, rng: RandomNumberGenerator, y: int, left: int, right: int, thick: int) -> void:
	var x := left
	while x < right - 8:
		var word := mini(rng.randi_range(10, 34), right - x)
		for i in word:
			var wob := int(round(sin((x + i) * 0.9 + y) * 1.2))
			img.fill_rect(Rect2i(x + i, y + wob, 1, thick), INK)
		x += word + rng.randi_range(5, 8)


## The writing idle's quill: a white feather on a pale shaft with a gold nib. Its origin is the
## nib's tip; the shaft runs up along +Y, the feather's flat face toward +Z.
static func make_quill() -> Node3D:
	var quill := Node3D.new()
	quill.name = "IdleLifeQuill"
	var nib := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0022
	cone.bottom_radius = 0.0
	cone.height = 0.018
	cone.radial_segments = 10
	nib.mesh = cone
	var gm := StandardMaterial3D.new()
	gm.albedo_color = GOLD
	gm.metallic = 0.7
	gm.roughness = 0.3
	nib.material_override = gm
	nib.position.y = 0.009
	quill.add_child(nib)
	var shaft := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.0012
	rod.bottom_radius = 0.0022
	rod.height = 0.15
	rod.radial_segments = 8
	shaft.mesh = rod
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.96, 0.94, 0.88)
	sm.roughness = 0.5
	shaft.material_override = sm
	shaft.position.y = 0.018 + 0.075
	quill.add_child(shaft)
	# The vane: a flattened, stretched sphere along the upper shaft, slightly curved by a tilt.
	var vane := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 10
	vane.mesh = ball
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.98, 0.93, 0.82)
	vm.roughness = 0.8
	vane.material_override = vm
	vane.scale = Vector3(0.03, 0.12, 0.005)
	vane.position = Vector3(0.006, 0.105, 0.0)
	vane.rotation.z = -0.08
	quill.add_child(vane)
	return quill
