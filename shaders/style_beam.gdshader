shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// Checkpoint 5: a column of light in the pixel style (a gap's coral breach, a patch's ward posts, the light that lifts a
// person the burst cleared). Open cylinder (no caps), centred on its middle: `height` is the mesh height. An ordered
// dither whose density is highest at the foot and thins toward the top, broken into a few vertical rays, with a brighter
// core where it is densest. No alpha blending, so it stays crisp in the 640x360 pass. `fade` thins the whole column as an
// effect dies away.
uniform vec3 beam_color : source_color = vec3(1.0, 0.85, 0.45);
uniform vec3 core_color : source_color = vec3(1.0, 0.97, 0.85);
uniform float height = 3.0;
uniform float density = 0.85;
uniform float fade = 1.0;
uniform float rays = 5.0;
const float M4[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float h = clamp((lp.y + height * 0.5) / height, 0.0, 1.0);
	float ang = atan(lp.z, lp.x);
	float ray = 0.55 + 0.45 * step(0.45, fract(ang * rays / 6.2831853 + h * 0.35 + TIME * 0.25));
	float a = density * fade * (1.0 - h * 0.9) * ray;
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	float b = (M4[y * 4 + x] + 0.5) / 16.0;
	if (b > a) discard;
	ALBEDO = a > 0.55 ? core_color : beam_color;
}
