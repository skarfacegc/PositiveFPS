shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// 0.3.2 (#49): the soft cone of light under a street lamp's head. A cone mesh (top at y = +0.5, bottom at y = -0.5)
// from the head to the ground. It is brightest at the head and fades smoothly toward the ground, and its sides are
// softer than its middle. The instance colour is the light's colour and its alpha the strength (kept low: it must
// never hide a person or a gap). Both walls are drawn: drawing only the far wall (cull_front) was tried and left the
// cone too faint to read at play zoom. Scenery only.

varying vec4 light;
varying float along;

void vertex() {
	light = COLOR;
	along = clamp(0.5 - VERTEX.y, 0.0, 1.0);
}

void fragment() {
	float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = pow(1.0 - along, 1.5) * smoothstep(0.0, 0.06, along) * mix(0.45, 1.0, edge);
	ALBEDO = light.rgb;
	ALPHA = clamp(light.a * a, 0.0, 1.0);
}
