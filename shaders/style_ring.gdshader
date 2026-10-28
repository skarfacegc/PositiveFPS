shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// A flat ring or disc on the ground in the pixel style (the grab warning and the stage ripple): an ordered-dither fill, a
// solid ink outer pixel and a bright rim. The mesh is a plane two units across (radius 1); the node is scaled to the real
// radius. `inner` > 0 cuts the middle out (a ring). `fade` thins the dither (and the rim) as an effect dies away.
uniform vec3 fill_color : source_color = vec3(1.0, 0.4, 0.35);
uniform vec3 rim_color : source_color = vec3(1.0, 0.7, 0.6);
uniform vec3 ink_color : source_color = vec3(0.23, 0.16, 0.125);
uniform float density = 0.4;
uniform float inner = 0.0;
uniform float rim_width = 0.1;
uniform float fade = 1.0;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	if (r > 1.0 || r < inner) discard;
	float d = min(1.0 - r, r - inner);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (b > fade) discard;
	if (d < rim_width * 0.5) {
		ALBEDO = ink_color;
	} else if (d < rim_width * 1.5) {
		ALBEDO = rim_color;
	} else {
		if (b > density * fade) discard;
		ALBEDO = fill_color;
	}
}
