shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Ordered-dither radial glow on the ground (no alpha blending, so it stays crisp in the pixel pipeline).
uniform vec3 glow_color : source_color = vec3(1.0, 0.82, 0.38);
uniform float strength = 0.62;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz) / 2.5;
	float a = (1.0 - smoothstep(0.25, 1.0, r)) * strength;
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (b > a) discard;
	ALBEDO = glow_color;
}
