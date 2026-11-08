shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// Round 25: the border ribbon. A solid core with a soft halo. Checkpoint 7: the halo is a smooth alpha falloff (no
// ordered dither), and the core's light band is a hard toon band. Low resolution and the outlines stay as they are.
// Vertex colour rgb = tint (gold, amber, coral), a = fade. UV.x = -1..1 across the quad, UV2.x = the share of that which
// is solid ribbon.
uniform float halo_strength = 0.5;
void fragment() {
	float lat = abs(UV.x);
	float core = UV2.x;
	float a = 1.0;
	if (lat > core) {
		float t = clamp((lat - core) / max(1.0 - core, 0.001), 0.0, 1.0);
		a = (1.0 - t) * (1.0 - t) * halo_strength;
	}
	a *= COLOR.a;
	if (a <= 0.01) {
		discard;
	}
	vec3 c = COLOR.rgb;
	if (lat <= core * 0.4) {
		c = mix(c, vec3(1.0, 0.95, 0.75), 0.45);
	}
	// The tints are written as plain sRGB colours; the albedo is linear.
	ALBEDO = pow(c, vec3(2.2));
	ALPHA = a;
}
