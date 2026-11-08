shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// 0.3.2 (#49): the soft pool of light a street lamp throws on the ground. A flat quad: the light is brightest in the
// middle and falls off smoothly to nothing at its rim (a soft edge, no dither). The instance colour is the light's
// colour and its alpha the strength (kept low: it must never hide a person or a gap). The cone above it is
// shaders/style_lamp_cone.gdshader. Scenery only.

varying vec4 light;

void vertex() {
	light = COLOR;
}

void fragment() {
	float r = clamp(length(UV * 2.0 - 1.0), 0.0, 1.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.6);
	ALBEDO = light.rgb;
	ALPHA = clamp(light.a * a, 0.0, 1.0);
}
