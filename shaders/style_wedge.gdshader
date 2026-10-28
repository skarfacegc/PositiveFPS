shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// The guarded open-side wedge (round 17), in the pixel style: an ordered-dither fan with a solid one-pixel ink edge and a
// bright rim inside it, so the angle reads on any ground (no alpha blending, so it stays crisp in the pixel pipeline).
// The mesh is the flat fan from the person's feet; lp is the local position, forward is -Z.
uniform vec3 fill_color : source_color = vec3(1.0, 0.8, 0.36);
uniform vec3 rim_color : source_color = vec3(1.0, 0.93, 0.7);
uniform vec3 ink_color : source_color = vec3(0.23, 0.16, 0.125);
uniform float density = 0.3;
uniform float radius = 2.0;
uniform float half_angle = 1.92;
uniform float rim_width = 0.1;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	float ang = atan(lp.x, -lp.z);
	float d = min((half_angle - abs(ang)) * max(r, 0.001), radius - r);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (d < rim_width * 0.55) {
		ALBEDO = ink_color;
	} else if (d < rim_width * 1.7) {
		ALBEDO = rim_color;
	} else {
		float a = density * (0.55 + 0.45 * smoothstep(0.0, 1.0, r / radius));
		if (b > a) discard;
		ALBEDO = fill_color;
	}
}
