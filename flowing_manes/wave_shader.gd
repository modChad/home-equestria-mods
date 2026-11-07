extends RefCounted
## Makes "flowing" copies of the game's hair shaders: the cel shader the hair wears and the
## outline hull drawn as its next pass. The game's own source is copied at runtime and two things
## are added, so the look stays exactly the game's and follows its updates:
##   - vertex: a travelling wave from root to tip (fm_wave), in BOTH passes so the outline stays
##     on the hair;
##   - fragment (cel pass only): twinkling sparkles, optionally drifting along the strands (stars).
## The strand coordinate is the texture's v, which runs root to tip on the princess hair
## (fm_v_root .. fm_v_tip, measured from the mesh by main.gd).

const WAVE := """
// --- Flowing Manes (mod): travelling wave along the strand ---
uniform float fm_v_root = 0.0;
uniform float fm_v_tip = 1.0;
uniform float fm_amount = 1.0;
uniform float fm_amp = 0.06;
uniform float fm_speed = 0.45;
uniform float fm_waves = 1.25;
uniform vec3 fm_side = vec3(1.0, 0.0, 0.0);
uniform vec3 fm_back = vec3(0.0, 0.0, -1.0);
uniform vec3 fm_up = vec3(0.0, 1.0, 0.0);
uniform float fm_seed = 0.0;
// Driven by main.gd every frame: the pony's own clock (seconds, sped up or slowed by her mood, so
// a change of pace never jumps), the trail her movement leaves (mesh space), turbulence and droop.
uniform float fm_clock = 0.0;
uniform vec3 fm_trail = vec3(0.0);
uniform float fm_turb = 0.0;
uniform float fm_sag = 0.0;

// Her head, in this mesh's space, updated every frame (main.gd): skull centre, nose tip and skull
// radius (0 = no head here, the tail). Hair in front of her face moves far less and never back into
// it, and nothing is pushed inside the skull-to-nose capsule.
uniform vec3 fm_head_c = vec3(0.0);
uniform vec3 fm_nose = vec3(0.0, 0.0, 1.0);
uniform float fm_head_r = 0.0;
// The viewer's head (mesh space, one point for both VR eyes): moving hair never crosses between
// the viewer and her face. Hair that rests there stays; only motion into that line is stopped.
uniform vec3 fm_view = vec3(0.0, 0.0, 100.0);

vec3 fm_wave(vec3 at, vec2 uv) {
	float s = clamp((uv.y - fm_v_root) / (fm_v_tip - fm_v_root), 0.0, 1.0);
	// Roots stay put, tips swing most.
	float reach = s * s * (3.0 - 2.0 * s);
	// Neighbouring locks drift out of step a little (smooth in position: no cracks at UV seams).
	float spread = dot(at, vec3(2.3, 0.9, 1.7));
	float ph = 6.2831853 * (fm_speed * fm_clock - fm_waves * s) + fm_seed + spread;
	vec3 sway = fm_side * sin(ph) + fm_back * 0.55 * sin(ph * 0.8 + 1.9) + fm_up * 0.25 * sin(ph * 1.3 + 0.7);
	// Boiling: quicker, smaller, out-of-step churn for strong feelings.
	vec3 boil = vec3(sin(fm_clock * 5.1 + at.y * 9.0 + s * 7.0), sin(fm_clock * 4.3 + at.z * 8.0 + s * 5.0), sin(fm_clock * 6.2 + at.x * 7.0 + s * 6.0));
	// Close to her head everything is calmer and the churn of strong feelings fades out, so it
	// stays on the long flowing parts and never throws locks across her face.
	float prox = 0.0;
	if (fm_head_r > 0.0) prox = 1.0 - smoothstep(fm_head_r * 1.5, fm_head_r * 4.5, length(at - fm_head_c));
	vec3 d = (sway * (1.0 - 0.6 * prox) + boil * 0.6 * fm_turb * (1.0 - prox)) * fm_amp * reach;
	d += fm_trail * reach;
	d -= fm_up * fm_sag * fm_amp * 1.5 * s;
	d *= fm_amount;
	if (fm_head_r > 0.0) {
		vec3 seg = fm_nose - fm_head_c;
		vec3 fwd = normalize(seg);
		vec3 rel = at - fm_head_c;
		// In front of her face (the forelock): much calmer, and never moving back into the face.
		float near = 1.0 - smoothstep(fm_head_r * 1.8, fm_head_r * 3.6, length(rel));
		float front = smoothstep(-0.3, 0.25, dot(normalize(rel), fwd));
		float fw = near * front;
		d *= 1.0 - 0.9 * fw;
		float into = dot(d, -fwd);
		if (into > 0.0) d += fwd * into * fw;
		// Anywhere beside or in front of her head, hair never swings forward past its rest (it may
		// stream back, as in the show), nor sideways toward the middle of her face.
		float ahead = smoothstep(-0.7, -0.1, dot(normalize(rel), fwd));
		float fore = dot(d, fwd);
		if (fore > 0.0) d -= fwd * fore * ahead * 0.95;
		vec3 lateral = normalize(cross(fwd, fm_up));
		float side_of_face = sign(dot(rel, lateral));
		float across = -side_of_face * dot(d, lateral);
		if (across > 0.0) d += lateral * side_of_face * across * max(fw, ahead);
		// And the forelock never drops down over her eyes.
		float drop = -dot(d, fm_up);
		if (drop > 0.0) d += fm_up * drop * fw;
		// Never inside the skull-to-nose capsule (unless that vertex already rests inside it).
		float len2 = max(dot(seg, seg), 1e-6);
		vec3 rest_q = fm_head_c + seg * clamp(dot(rel, seg) / len2, 0.0, 1.0);
		float rest_t = clamp(dot(rel, seg) / len2, 0.0, 1.0);
		float rest_r = mix(fm_head_r * 1.15, fm_head_r * 0.75, rest_t);
		vec3 p = at + d;
		float t = clamp(dot(p - fm_head_c, seg) / len2, 0.0, 1.0);
		vec3 q = fm_head_c + seg * t;
		float r = mix(fm_head_r * 1.15, fm_head_r * 0.75, t);
		float dist = length(p - q);
		if (dist < r && length(at - rest_q) >= rest_r * 0.9) p = q + (p - q) / max(dist, 1e-4) * r;
		// Keep the line between the viewer and her face clear of moving hair.
		vec3 face = fm_head_c + seg * 0.55;
		vec3 ray = face - fm_view;
		float ray2 = max(dot(ray, ray), 1e-6);
		if (dot(normalize(fm_view - face), fwd) > -0.2) {
			float tp = clamp(dot(p - fm_view, ray) / ray2, 0.0, 1.0);
			vec3 cp = fm_view + ray * tp;
			float dp = length(p - cp);
			float tr = clamp(dot(at - fm_view, ray) / ray2, 0.0, 1.0);
			float dr = length(at - (fm_view + ray * tr));
			float clear_r = fm_head_r * 1.3;
			if (tp > 0.5 && dp < clear_r && dr >= clear_r) p = cp + (p - cp) / max(dp, 1e-4) * clear_r;
		}
		d = p - at;
	}
	return d;
}
"""

const SPARKLE := """
// --- Flowing Manes (mod): twinkling sparkles / drifting stars ---
uniform float fm_sparkle = 1.0;
uniform vec3 fm_sparkle_color : source_color = vec3(1.0, 0.98, 0.9);
uniform float fm_drift = 0.0;
uniform vec2 fm_sparkle_cells = vec2(14.0, 22.0);

float fm_twinkle(vec2 uv) {
	vec2 g = uv * fm_sparkle_cells + vec2(0.0, fm_drift * TIME);
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	if (h < 0.8) { return 0.0; }
	vec2 o = vec2(fract(h * 13.1) - 0.5, fract(h * 7.7) - 0.5) * 0.5;
	vec2 d = abs(f - o);
	// A small four-point star: a dot plus thin cross arms.
	float star = smoothstep(0.09, 0.0, length(d)) + 0.6 * smoothstep(0.02, 0.0, min(d.x, d.y)) * smoothstep(0.28, 0.0, max(d.x, d.y));
	float tw = pow(max(0.0, sin(TIME * (0.9 + h * 2.2) + h * 40.0)), 6.0);
	return star * tw;
}
"""

## Mood light (cel pass only, needs the cel shader's base_texture): a glow of her own colours when
## she is happy, and a flickering flame gradient root -> tip when she is angry.
const MOOD := """
// --- Flowing Manes (mod): mood light ---
uniform float fm_glow_amt = 0.0;
uniform float fm_fire = 0.0;
uniform vec3 fm_fire_root : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 fm_fire_tip : source_color = vec3(1.0, 0.32, 0.08);

vec3 fm_mood(vec2 uv) {
	float s = clamp((uv.y - fm_v_root) / (fm_v_tip - fm_v_root), 0.0, 1.0);
	vec3 own = texture(base_texture, uv).rgb * fm_glow_amt;
	float flick = 0.75 + 0.25 * sin(TIME * 9.0 + s * 12.0 + uv.x * 7.0) * sin(TIME * 5.3 + uv.y * 9.0);
	vec3 fire = mix(fm_fire_root, fm_fire_tip, s) * fm_fire * flick * (0.55 + 0.45 * s) * 1.35;
	return own + fire;
}
"""


## Luna's see-through glowing edge, drawn as the hair's second pass instead of the outline: a hull
## grown along the normal, back faces only, so only the rim beyond the hair shows. It shares WAVE.
const GLOW_HEAD := """// Flowing Manes (mod): Luna's see-through glowing edge. Drawn as the hair's second pass in place
// of the outline: a hull grown along the normal, back faces only, so only the rim beyond the hair
// shows. Uses the same travelling wave as the hair (WAVE, from wave_shader.gd), and
// the rim's own width ripples a little, like the show's shimmering edge.
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_never, blend_mix, shadows_disabled;

"""
const GLOW_BODY := """uniform vec4 fm_glow_color : source_color = vec4(0.62, 0.48, 1.0, 0.55);
uniform float fm_glow_width = 0.03;
uniform float fm_glow = 1.0;
// Fade toward the tips (0 = none, 1 = the tips' rim fully clear).
uniform float fm_tip_fade = 0.35;
// The unshaded rim kept daylight-bright at night; the game drives `brightness` on its outlines.
uniform float brightness = 1.0;
// The rim shows against open space, not over her own face or neck: it fades where the scene
// directly behind it is this close (metres, view space).
uniform vec2 fm_backing_fade = vec2(0.08, 0.4);
uniform sampler2D fm_depth : hint_depth_texture, filter_nearest;

varying float fm_s;
// 1 on hair close in front of her face: its rim fades there, so it never streaks across her face.
varying float fm_face;

void vertex() {
	fm_face = 0.0;
	if (fm_head_r > 0.0) {
		vec3 rel = VERTEX - fm_head_c;
		float near = 1.0 - smoothstep(fm_head_r * 1.6, fm_head_r * 4.0, length(rel));
		float front = smoothstep(-0.35, 0.2, dot(normalize(rel), normalize(fm_nose - fm_head_c)));
		fm_face = near * front;
	}
	VERTEX += fm_wave(VERTEX, UV);
	fm_s = clamp((UV.y - fm_v_root) / (fm_v_tip - fm_v_root), 0.0, 1.0);
	float spread = dot(VERTEX, vec3(3.1, 1.3, 2.2));
	float shimmer = 0.75 + 0.25 * sin(6.2831853 * (fm_speed * 1.7 * fm_clock - 2.5 * fm_s) + spread) * (1.0 + 0.4 * fm_turb);
	// Thin at the roots, full along the strand.
	float root = smoothstep(0.0, 0.15, fm_s);
	VERTEX += normalize(NORMAL) * fm_glow_width * shimmer * (0.35 + 0.65 * root) * fm_glow * fm_amount;
}

void fragment() {
	float depth = texture(fm_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = (-behind.z / behind.w) - (-VERTEX.z);
	float open_space = smoothstep(fm_backing_fade.x, fm_backing_fade.y, gap);
	ALBEDO = fm_glow_color.rgb * brightness;
	ALPHA = fm_glow_color.a * (1.0 - 0.9 * fm_face) * open_space * (1.0 - fm_tip_fade * smoothstep(0.6, 1.0, fm_s)) * clamp(fm_glow, 0.0, 1.0) * fm_amount;
}
"""

static var _cache: Dictionary = {}
static var _glow: Shader


static func glow() -> Shader:
	if _glow == null:
		_glow = Shader.new()
		_glow.code = GLOW_HEAD + WAVE + "\n" + GLOW_BODY
	return _glow


## The flowing copy of `source` (cached). `pass_kind` is "base" (cel pass, gets sparkles) or
## "outline". Null when the shader's layout is not what this mod expects (it then leaves it alone).
static func flowing(source: Shader, pass_kind: String) -> Shader:
	if source == null: return null
	var key := "%s|%s|%s" % [source.resource_path, source.get_rid(), pass_kind]
	if _cache.has(key): return _cache[key]
	var code := _absolute_includes(source.code, source.resource_path.get_base_dir())
	var vertex_at := code.find("void vertex()")
	if vertex_at < 0: _cache[key] = null; return null
	var open := code.find("{", vertex_at)
	if open < 0: _cache[key] = null; return null
	# The wave goes first in vertex(), before the outline's push along the normal.
	code = code.insert(open + 1, "\n\tVERTEX += fm_wave(VERTEX, UV);")
	var head := WAVE
	if pass_kind == "base":
		var fragment_at := code.find("void fragment()")
		var close := _closing_brace(code, code.find("{", fragment_at)) if fragment_at >= 0 else -1
		if close > 0:
			var mood := code.contains("uniform sampler2D base_texture")
			code = code.insert(close, "\tEMISSION += (fm_sparkle_color * fm_twinkle(UV) * fm_sparkle%s) * fm_amount;\n" % (" + fm_mood(UV)" if mood else ""))
			head += SPARKLE + (MOOD if mood else "")
	code = code.insert(code.find("void vertex()"), head + "\n")
	var shader := Shader.new()
	shader.code = code
	_cache[key] = shader
	return shader


## A copied shader has no path, so its relative #include lines must name the original folder.
static func _absolute_includes(code: String, folder: String) -> String:
	var lines := code.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if not line.begins_with("#include \""): continue
		var target := line.get_slice("\"", 1)
		if target.begins_with("res://"): continue
		lines[i] = lines[i].replace("\"" + target + "\"", "\"" + folder.path_join(target).simplify_path() + "\"")
	return "\n".join(lines)


static func _closing_brace(code: String, open: int) -> int:
	if open < 0: return -1
	var depth := 0
	for i in range(open, code.length()):
		var c := code[i]
		if c == "{": depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0: return i
	return -1
