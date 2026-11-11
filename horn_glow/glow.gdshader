// Horn Glow: a see-through shell around a skinned horn, grown along its normals and stretched
// into a flickering flame past the tip, brightest at its rim.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.4, 0.2, 1.0);
uniform float strength = 0.0;
uniform float gap = 0.004;     // Shell distance off the horn everywhere (mesh units),
uniform float widen = 0.1;     // plus this times the horn's own thickness there (COLOR.g).
uniform float flame = 0.02;    // Extra reach past the tip (mesh units).

uniform bool own_horn = false;   // A princess's own horn (Rarity's look along a long horn).

varying float along;

void vertex() {
	// COLOR.r: 0 at the horn's base to 1 at its tip, baked from the unskinned mesh (magic.gd).
	along = COLOR.r;
	float flick = 0.75 + 0.25 * sin(TIME * 7.0 + along * 9.0) * sin(TIME * 4.3 + float(VERTEX_ID) * 0.37);
	if (own_horn) {
		// Rarity's look along a long princess horn: rippled like the swirl on a unicorn horn,
		// with a rounded, softly flickering top (a third of her flame, scaled to the long horn).
		float ripple = 1.0 + 0.35 * sin(along * 26.0 - TIME * 2.0);
		VERTEX += NORMAL * ((gap + widen * COLOR.g) * ripple + flame * 0.35 * pow(along, 6.0) * flick);
	} else {
		VERTEX += NORMAL * (gap + widen * COLOR.g + flame * pow(along, 6.0) * flick);
	}
}

void fragment() {
	// Tinted, see-through: clear in the middle, coloured toward the rim, fading out at the base
	// (added light had burned her forelock white).
	float rim = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float glow = mix(0.12, 0.75, pow(rim, 1.3)) * (0.88 + 0.12 * sin(TIME * 3.0));
	ALBEDO = mix(glow_color.rgb, vec3(1.0), 0.25 * (1.0 - rim));
	ALPHA = clamp(glow * strength * smoothstep(0.02, 0.2, along), 0.0, 1.0);
}
