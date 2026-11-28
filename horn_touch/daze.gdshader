shader_type spatial;
// Horn Touch daze (daze.gd): the world blurred, doubled and swaying, darker at the rim, faintly
// tinted in her magic colour. A quad in front of the camera, so both XR eyes see it.
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix, shadows_disabled;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
uniform vec3 tint = vec3(1.0);

void fragment() {
	float t = TIME;
	vec2 sway = vec2(sin(t * 1.3), cos(t * 0.9)) * vec2(0.012, 0.008) * amount;
	vec2 ghost = vec2(sin(t * 0.7), cos(t * 1.1)) * 0.02 * amount;
	float lod = 3.2 * amount;
	vec3 a = textureLod(screen, SCREEN_UV + sway, lod).rgb;
	vec3 b = textureLod(screen, SCREEN_UV + sway + ghost, lod).rgb;
	vec3 col = mix(a, b, 0.45);
	col = mix(col, col * tint, 0.18 * amount);
	vec2 p = (UV - 0.5) * vec2(1.3, 1.0);
	float rim = smoothstep(0.12, 0.55, length(p));
	float pulse = 0.5 + 0.5 * sin(t * 2.2);
	col *= 1.0 - rim * (0.5 + 0.15 * pulse) * amount;
	ALBEDO = col;
	ALPHA = clamp(amount * 1.3, 0.0, 1.0);
}
