shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// Soft, low-opacity helper band for the living border. Ordered-dither "alpha" so it stays pixel-crisp.
// Vertex colour rgb = tint, a = intensity (thin and reddish in gaps). UV.x = -1..1 across the band, UV.y = distance along it.
uniform float strength = 0.3;
uniform float gap_pulse = 0.0;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
void fragment() {
	float lat = abs(UV.x);
	float a = pow(max(1.0 - lat, 0.0), 1.0) * COLOR.a * strength;
	a *= 1.0 + gap_pulse * UV2.x * 2.6;
	a *= 0.7 + 0.3 * sin(UV.y * 2.1 + sin(UV.y * 0.63) * 2.5);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (b > a) discard;
	ALBEDO = COLOR.rgb;
}
