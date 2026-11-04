shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// Checkpoint 5: the faint fill of the shape preview (the zone a stretch would make), flat on the ground in the pixel style.
// A sparse ordered dither of `fill_color`. When `limited` is set (something holds the tip back) the dither becomes
// diagonal hatching in the warning colour, which reads as "no" in one glance even without colour.
uniform vec3 fill_color : source_color = vec3(0.61, 0.94, 0.86);
uniform vec3 hatch_color : source_color = vec3(0.91, 0.27, 0.23);
uniform float density = 0.16;
uniform float limited = 0.0;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (limited > 0.5) {
		float stripe = step(0.62, fract((wp.x + wp.z) * 0.7));
		if (stripe < 0.5 || b > 0.7) discard;
		ALBEDO = hatch_color;
	} else {
		if (b > density) discard;
		ALBEDO = fill_color;
	}
}
