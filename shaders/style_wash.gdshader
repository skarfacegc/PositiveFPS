shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, blend_mix, depth_draw_never;
// Walls and gates: Style update (#94). A soft-edged rectangle of light laid flat over a town cell: a faint fill and a
// brighter band just inside the edge, both fading smoothly to nothing (no dither). `size` is the plane's size in
// metres; `soft` how far in the fade runs; `rim` how bright the edge band is.
uniform vec3 wash_color : source_color = vec3(1.0, 0.82, 0.38);
uniform float fill = 0.25;
uniform float rim = 0.6;
uniform vec2 size = vec2(12.0, 12.0);
uniform float soft = 1.6;
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	vec2 inside = size * 0.5 - abs(lp);
	float e = min(inside.x, inside.y);
	float edge = smoothstep(0.0, soft, e);
	float band = 1.0 - smoothstep(0.0, soft * 0.9, abs(e - soft * 0.55));
	ALBEDO = wash_color;
	ALPHA = clamp(edge * fill + band * rim, 0.0, 1.0);
}
