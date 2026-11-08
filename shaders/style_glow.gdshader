shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, blend_mix, depth_draw_never;
// Radial glow on the ground. Checkpoint 7: no dithering; a soft alpha falloff from the centre to the rim of the plane.
uniform vec3 glow_color : source_color = vec3(1.0, 0.82, 0.38);
uniform float strength = 0.62;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz) / 2.5;
	float fall = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = glow_color;
	ALPHA = fall * fall * strength;
}
