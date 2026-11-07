shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// Round 25: the border ribbon. A solid core with an ordered-dither halo, so it stays pixel-crisp in the 640x360 pass.
// Vertex colour rgb = tint (gold, amber, coral), a = fade. UV.x = -1..1 across the quad, UV2.x = the share of that which
// is solid ribbon.
uniform float halo_strength = 0.5;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
void fragment() {
	float lat = abs(UV.x);
	float core = UV2.x;
	float a = 1.0;
	if (lat > core) {
		a = (1.0 - (lat - core) / max(1.0 - core, 0.001)) * halo_strength;
	}
	a *= COLOR.a;
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (b > a) discard;
	vec3 c = COLOR.rgb;
	if (lat <= core * 0.4) {
		c = mix(c, vec3(1.0, 0.95, 0.75), 0.45);
	}
	// The tints are written as plain sRGB colours; the albedo is linear.
	ALBEDO = pow(c, vec3(2.2));
}
