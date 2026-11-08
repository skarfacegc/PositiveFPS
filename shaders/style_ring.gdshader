shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, blend_mix, depth_draw_never;
// A flat ring or disc on the ground in the pixel style (the grab warning and the stage ripple): a soft translucent fill, a
// solid ink outer pixel and a bright rim (checkpoint 7: no dithering). The mesh is a plane two units across (radius 1); the
// node is scaled to the real radius. `inner` > 0 cuts the middle out (a ring). `fade` thins the whole piece as an effect dies
// away; `density` is the fill's opacity.
uniform vec3 fill_color : source_color = vec3(1.0, 0.4, 0.35);
uniform vec3 rim_color : source_color = vec3(1.0, 0.7, 0.6);
uniform vec3 ink_color : source_color = vec3(0.23, 0.16, 0.125);
uniform float density = 0.4;
uniform float inner = 0.0;
uniform float rim_width = 0.1;
uniform float fade = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	if (r > 1.0 || r < inner) discard;
	float d = min(1.0 - r, r - inner);
	float f = clamp(fade, 0.0, 1.0);
	if (d < rim_width * 0.5) {
		ALBEDO = ink_color;
		ALPHA = f;
	} else if (d < rim_width * 1.5) {
		ALBEDO = rim_color;
		ALPHA = f;
	} else {
		ALBEDO = fill_color;
		ALPHA = clamp(density, 0.0, 1.0) * f * (0.8 + 0.2 * smoothstep(rim_width * 1.5, rim_width * 4.0, d));
	}
}
